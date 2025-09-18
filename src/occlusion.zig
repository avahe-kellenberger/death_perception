const std = @import("std");

const sdl = @import("sdl3");

const Color = @import("color.zig").Color;
const Game = @import("game.zig");
const Line = @import("math/collisionshape.zig").Line;

const Vector = @import("math/vector.zig").Vector(f32);

// https://www.redblobgames.com/articles/visibility/

const Endpoint = struct {
    point: Vector,
    wall: *Line,
    angle: f32,
    is_start: bool,
};

const Endpoints = struct {
    pub const Self = @This();

    items: []Endpoint,

    /// Find and sort all points by angle to pov
    pub fn init(pov: Vector, walls: []Line) Self {
        var items: []Endpoint = Game.alloc.alloc(Endpoint, walls.len * 2) catch unreachable;

        for (walls, 0..) |*wall, i| {
            const angle_start = wall.start.subtract(pov).getAngleRadians();
            const angle_end = wall.end.subtract(pov).getAngleRadians();
            const is_start_first = Vector.getSignedAngleDifference(angle_start, angle_end) > 0.0;
            items[i * 2] = .{
                .point = wall.start,
                .wall = wall,
                .angle = angle_start,
                .is_start = is_start_first,
            };
            items[i * 2 + 1] = .{
                .point = wall.end,
                .wall = wall,
                .angle = angle_end,
                .is_start = !is_start_first,
            };
        }

        std.mem.sortUnstable(Endpoint, items, {}, compare);

        return .{ .items = items };
    }

    pub fn deinit(self: *Self) void {
        Game.alloc.free(self.list);
    }

    fn compare(_: void, e1: Endpoint, e2: Endpoint) bool {
        if (e1.angle < e2.angle) return true;
        if (e2.angle < e1.angle) return false;
        return e1.is_start and !e2.is_start;
    }
};

const OpenWalls = struct {
    pub const Self = @This();
    const Heap = std.PriorityQueue(*Line, Vector, compare);

    heap: Heap,

    pub fn init(pov: Vector, cap: usize) Self {
        var heap: Heap = .init(Game.alloc, pov);
        heap.ensureTotalCapacityPrecise(cap) catch unreachable;
        return .{
            .heap = heap,
        };
    }

    pub fn deinit(self: *Self) void {
        self.heap.deinit();
    }

    pub fn empty(self: *const Self) bool {
        return self.heap.count() == 0;
    }

    pub fn nearest(self: *Self) ?*Line {
        return self.heap.peek();
    }

    pub fn add(self: *Self, l: *Line) void {
        self.heap.add(l) catch unreachable;
    }

    pub fn remove(self: *Self, l: *Line) void {
        const idx = std.mem.indexOfScalar(*Line, self.heap.items, l) orelse return;
        _ = self.heap.removeIndex(idx);
    }

    fn compare(pov: Vector, l1: *Line, l2: *Line) std.math.Order {
        // TODO distance to center of walls is a temp solution
        // const d1 = pov.distanceSquared(l1.middle());
        // const d2 = pov.distanceSquared(l2.middle());
        const d1 = distance(pov, l1);
        const d2 = distance(pov, l2);
        return std.math.order(d1, d2);
    }

    fn distance(p: Vector, v: *Line) f32 {
        const dist_squared = v.start.distanceSquared(v.end);
        // start == end
        if (dist_squared == 0.0) return v.start.distance(p);
        const t: f32 = p.subtract(v.start).dotProduct(v.end.subtract(v.start)) / dist_squared;
        if (t < 0.0) return v.start.distance(p);
        if (t > 1.0) return v.end.distance(p);
        // Projection is on the line segment
        const projection = v.start.add(v.end.subtract(v.start).scale(t));
        return p.distance(projection);
    }
};

pub const VisibilityMesh = struct {
    pub const Self = @This();

    triangle_vertices: std.ArrayList(sdl.render.Vertex) = .empty,
    indices: std.ArrayList(c_int) = .empty,

    pub fn init(pov: Vector, initial_walls: []Line) Self {
        var mesh: Self = .{};

        // The POV is always the first vertex of the mesh.
        // This can be referenced using the indices array with index zero.
        mesh.addVertex(pov);

        const walls = getWalls(initial_walls);
        defer Game.alloc.free(walls);

        const endpoints: Endpoints = .init(pov, walls);

        var open_walls: OpenWalls = .init(pov, walls.len);
        defer open_walls.deinit();

        var last_point: *const Endpoint = &endpoints.items[0];

        // A first pass must be performed to calculate inital state of `open_walls` and `last_point`.
        // Triangles are not added to the mesh during this first pass.
        // The `last_point` is the endpoint that forms the first point of the first triangle.

        for (0..2) |pass| {
            for (endpoints.items) |*endpoint| {
                const closest: ?*Line = open_walls.nearest();

                if (endpoint.is_start) {
                    open_walls.add(endpoint.wall);
                } else {
                    open_walls.remove(endpoint.wall);
                }

                const new_closest: ?*Line = open_walls.nearest();
                if (new_closest != closest) {
                    if (pass == 1) {
                        mesh.addTriangle(pov, last_point, endpoint, endpoint.wall);
                    }
                    last_point = endpoint;
                }
            }
        }

        return mesh;
    }

    pub fn deinit(self: *Self) void {
        self.indices.deinit(Game.alloc);
        self.triangle_vertices.deinit(Game.alloc);
    }

    fn addTriangle(
        self: *Self,
        pov: Vector,
        p1: *const Endpoint,
        p2: *const Endpoint,
        wall: *const Line,
    ) void {
        var p1i: Vector = undefined;
        var p2i: Vector = undefined;
        _ = wall.findIntersection(pov, p1.point.subtract(pov).normalize(), &p1i);
        _ = wall.findIntersection(pov, p2.point.subtract(pov).normalize(), &p2i);

        // Reference POV vertex
        self.indices.append(Game.alloc, 0) catch unreachable;

        // Add the two far points of the triangle, order doesn't matter ?
        self.addVertex(p1i);
        self.addIndex();
        self.addVertex(p2i);
        self.addIndex();
    }

    fn addVertex(self: *Self, p: Vector) void {
        const viewportLoc = Game.camera.viewportLoc();
        const scale = Game.camera.getScale() orelse return;
        self.triangle_vertices.append(Game.alloc, .{
            .position = @bitCast(p.subtract(viewportLoc).scale(scale)),
            .color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 },
            .tex_coord = .{ .x = 0.0, .y = 0.0 },
        }) catch unreachable;
    }

    fn addIndex(self: *Self) void {
        self.indices.append(Game.alloc, @intCast(self.triangle_vertices.items.len - 1)) catch unreachable;
    }

    pub fn renderTo(self: *const Self, target: sdl.render.Texture) void {
        if (self.triangle_vertices.items.len < 3 or self.indices.items.len < 3) return;

        var r = target.getRenderer() catch unreachable;
        const original_target = r.getTarget();
        r.setTarget(target) catch unreachable;
        defer r.setTarget(original_target) catch unreachable;

        r.setDrawColor(Color.black.sdl()) catch unreachable;
        r.clear() catch unreachable;

        r.setDrawBlendMode(.none) catch unreachable;
        r.setDrawColor(Color.transparent.sdl()) catch unreachable;
        r.renderGeometry(
            null,
            self.triangle_vertices.items,
            self.indices.items,
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

    fn getWalls(initial_walls: []Line) []Line {
        const camera_walls = cameraWalls();
        var walls = std.ArrayList(Line).initCapacity(Game.alloc, initial_walls.len + camera_walls.len) catch unreachable;
        walls.appendSliceAssumeCapacity(initial_walls);
        walls.appendSliceAssumeCapacity(&camera_walls);
        return walls.toOwnedSlice(Game.alloc) catch unreachable;
    }
};
