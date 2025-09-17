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
};

pub fn init(target: sdl.render.Texture, pov: Vector, walls: []const Line) void {
    const old_target = Game.renderer.getTarget();
    defer Game.renderer.setTarget(old_target) catch unreachable;

    Game.renderer.setTarget(target) catch unreachable;
    Game.fillRect(Game.camera.viewport, Color.black);
    Game.renderer.setDrawBlendMode(.none) catch unreachable;

    // Game.camera.viewport

    // Draw triangles
    //renderer.renderGeometry(t, verts, &.{ 3, 1, 0, 2, 1, 3 }) catch unreachable;

    // Find and sort all points by angle to pov
    var endpoints: std.ArrayList(Endpoint) = .initCapacity(Game.alloc, 4 + walls.len * 2);
    defer endpoints.deinit(Game.alloc);

    for (walls) |*wall| {
        endpoints.append(Game.alloc, .{
            .point = wall.start,
            .wall = wall,
            .angle = wall.start.subtract(pov).getAngleRadians(),
        }) catch unreachable;
        endpoints.append(Game.alloc, .{
            .point = wall.end,
            .wall = wall,
            .angle = wall.end.subtract(pov).getAngleRadians(),
        }) catch unreachable;
    }
    const camera_walls = cameraWalls();
    for (camera_walls) |*wall| {
        endpoints.append(Game.alloc, .{
            .point = wall.start,
            .wall = wall,
            .angle = wall.start.subtract(pov).getAngleRadians(),
        }) catch unreachable;
        endpoints.append(Game.alloc, .{
            .point = wall.end,
            .wall = wall,
            .angle = wall.end.subtract(pov).getAngleRadians(),
        }) catch unreachable;
    }

    std.mem.sort(Endpoint, endpoints.items, {}, compareByAngle);

    // Find nearest walls
    var open_walls: std.ArrayList(*Line) = .empty;
    defer open_walls.deinit(Game.alloc);

    var closest: ?*Line = null;
    for (endpoints.items) |endpoint| {
        const wall = endpoint.wall;
        if (endpoint.point.equals(wall.start)) {
            open_walls.append(Game.alloc, wall) catch unreachable;
        } else {
            // Remove this wall from open walls
            for (open_walls, 0..) |open_wall, i| {
                if (open_wall == endpoint.wall) {
                    open_walls.swapRemove(i);
                    break;
                }
            }
        }
        const new_closest: ?*Line = findClosest(pov, open_walls.items);
        if (new_closest != closest) closest = new_closest;
    }
}

fn findIntersection(ray_origin: Vector, dir: Vector, wall: *Line) Vector {
    _ = ray_origin; // autofix
    _ = dir; // autofix
    _ = wall; // autofix
    return Vector.zero;
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
    return e1.angle < e2.angle;
}
