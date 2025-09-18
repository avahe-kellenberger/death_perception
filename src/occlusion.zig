const std = @import("std");
const sdl = @import("sdl3");

const Vector = @import("math/vector.zig").Vector(f32);
const Game = @import("game.zig");

const Line = @import("math/collisionshape.zig").Line;
const Color = @import("color.zig").Color;

// https://www.redblobgames.com/articles/visibility/

const Endpoint = struct {
    point: Vector,
    wall: *Line,
    angle: f32,
    is_start: bool,
};

const TriangleVertices = struct {
    pub const Self = @This();

    vertices: std.ArrayList(Vector) = .empty,
    indicies: std.ArrayList(c_int) = .empty,
    triangle_vertices: std.ArrayList(sdl.render.Vertex) = .empty,

    pub fn init() Self {
        return .{};
    }

    pub fn deinit(self: *Self) void {
        self.vertices.deinit(Game.alloc);
        self.indicies.deinit(Game.alloc);
        self.triangle_vertices.deinit(Game.alloc);
    }

    pub fn add(self: *Self, v: Vector) void {
        self.indicies.append(Game.alloc, @intCast(self.vertices.items.len)) catch unreachable;
        self.vertices.append(Game.alloc, v) catch unreachable;
    }

    pub fn closeTriangle(self: *Self) void {
        std.debug.assert(self.indicies.items.len >= 3);

        const num_indicies = self.indicies.items.len;
        for (num_indicies - 3..num_indicies) |i| {
            self.triangle_vertices.append(Game.alloc, .{
                .position = @bitCast(self.vertices.items[@intCast(self.indicies.items[i])]),
                .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.0 },
                .tex_coord = @bitCast(Vector.zero),
            }) catch unreachable;
        }
    }

    pub fn mostRecentPoint(self: *Self) ?Vector {
        if (self.vertices.items.len == 0) return null;
        return self.vertices.items[@intCast(self.indicies.getLast())];
    }
};

fn getWalls(initial_walls: []Line) []Line {
    var walls = std.ArrayList(Line).initCapacity(Game.alloc, initial_walls.len + 4) catch unreachable;
    for (initial_walls) |wall| walls.appendAssumeCapacity(wall);

    const camera_walls = cameraWalls();
    inline for (camera_walls) |wall| walls.appendAssumeCapacity(wall);

    return walls.toOwnedSlice(Game.alloc) catch unreachable;
}

pub fn renderVisibleAreas(target: sdl.render.Texture, pov: Vector, initial_walls: []Line) void {
    var r = target.getRenderer() catch unreachable;
    r.setDrawBlendMode(.none) catch unreachable;

    const walls = getWalls(initial_walls);
    defer Game.alloc.free(walls);

    // Game.setRenderColor(Color.red);
    // for (walls) |wall| {
    //     Game.drawLine(wall);
    // }
    // Game.renderer.renderTexture(target, null, null) catch unreachable;

    // Find and sort all points by angle to pov
    var endpoints = std.ArrayList(Endpoint).initCapacity(Game.alloc, walls.len * 2) catch unreachable;
    defer endpoints.deinit(Game.alloc);

    for (walls) |*wall| {
        const angle_start = wall.start.subtract(pov).getAngleRadians();
        const angle_end = wall.end.subtract(pov).getAngleRadians();
        const angle_diff = Vector.getSignedAngleDifference(angle_start, angle_end);
        const is_start_first = angle_diff > 0;
        endpoints.append(Game.alloc, .{
            .point = wall.start,
            .wall = wall,
            .angle = angle_start,
            .is_start = is_start_first,
        }) catch unreachable;
        endpoints.append(Game.alloc, .{
            .point = wall.end,
            .wall = wall,
            .angle = angle_end,
            .is_start = !is_start_first,
        }) catch unreachable;
    }

    std.mem.sort(Endpoint, endpoints.items, {}, compareByAngle);

    // Find nearest walls
    var open_walls: std.ArrayList(*Line) = .empty;
    defer open_walls.deinit(Game.alloc);

    var closest: ?*Line = null;
    var triangles: TriangleVertices = .init();

    for (endpoints.items) |endpoint| {
        const wall = endpoint.wall;
        if (endpoint.is_start) {
            open_walls.append(Game.alloc, wall) catch unreachable;
        } else {
            // Closest wall closed
            if (closest) |c| if (wall == c) {
                if (wall.start != endpoint.point) {
                    triangles.add(wall.start);
                } else {
                    triangles.add(wall.end);
                }

                triangles.add(endpoint.point);
                triangles.add(pov);
                triangles.closeTriangle();
            };

            // Remove this wall from open walls
            for (open_walls.items, 0..) |open_wall, i| {
                if (open_wall == endpoint.wall) {
                    _ = open_walls.swapRemove(i);
                    break;
                }
            }
        }

        const new_closest: ?*Line = findClosest(pov, open_walls.items);
        // Can be null before we find our first wall to open
        if (new_closest == null) continue;

        if (new_closest != closest) {
            closest = new_closest;
            // ???
            if (closest == null) continue;
            const c = closest.?;

            // Need to check if the most recent point is the same as the new closest's start
            if (triangles.mostRecentPoint()) |most_recent_point| {
                if (!most_recent_point.equals(c.start)) {
                    if (c.findIntersection(pov, most_recent_point.subtract(pov).normalize())) |intersection| {
                        triangles.add(intersection);
                    } else {
                        const dir = most_recent_point.subtract(pov).normalize();
                        std.log.err("new closest wall: {}", .{c});
                        std.log.err("pov: {}", .{pov});
                        std.log.err("dir: {}", .{dir});
                        unreachable;
                    }
                }
            }
        }
    }

    Game.renderer.renderGeometry(
        target,
        triangles.triangle_vertices.items,
        triangles.indicies.items,
    ) catch unreachable;
}

fn cameraWalls() [4]Line {
    var res: [4]Line = undefined;
    const camera_verts = Game.camera.verticies();
    res[0] = .init(camera_verts[0], camera_verts[1]);
    res[1] = .init(camera_verts[1], camera_verts[2]);
    res[2] = .init(camera_verts[2], camera_verts[3]);
    res[3] = .init(camera_verts[3], camera_verts[0]);
    return res;
}

fn findClosest(pov: Vector, walls: []*Line) ?*Line {
    var closest_dist: f32 = std.math.inf(f32);
    var closest: ?*Line = null;
    for (walls) |wall| {
        const dist = pov.distance(wall.middle());
        if (dist < closest_dist) {
            closest_dist = dist;
            closest = wall;
        }
    }
    return closest;
}

fn compareByAngle(_: void, e1: Endpoint, e2: Endpoint) bool {
    if (e1.angle < e2.angle) return true;
    if (e2.angle < e1.angle) return false;
    return e1.is_start and !e2.is_start;
}
