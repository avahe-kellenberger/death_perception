const std = @import("std");

const sdl = @import("sdl3");

const Color = @import("color.zig").Color;
const Game = @import("game.zig");
const CollisionShape = @import("math/collisionshape.zig").CollisionShape;

const Vector = @import("math/vector.zig").Vector(f32);

// https://www.redblobgames.com/articles/visibility/

const Endpoint = struct {
    point: Vector,
    wall: *CollisionShape,
    angle: f32,
    is_start: bool,
};

const Endpoints = struct {
    pub const Self = @This();

    items: []Endpoint = &.{},
    _list: std.ArrayList(Endpoint) = .empty,

    /// Find and sort all points by angle to pov
    pub fn update(self: *Self, pov: Vector, walls: []CollisionShape) void {
        self._list.clearRetainingCapacity();
        self._list.ensureTotalCapacity(Game.alloc, walls.len * 2) catch unreachable;

        for (walls) |*wall| {
            const angle_start = wall.line.start.subtract(pov).getAngleRadians();
            const angle_end = wall.line.end.subtract(pov).getAngleRadians();
            const is_start_first = Vector.getSignedAngleDifference(angle_start, angle_end) > 0.0;
            self._list.appendAssumeCapacity(.{
                .point = wall.line.start,
                .wall = wall,
                .angle = angle_start,
                .is_start = is_start_first,
            });
            self._list.appendAssumeCapacity(.{
                .point = wall.line.end,
                .wall = wall,
                .angle = angle_end,
                .is_start = !is_start_first,
            });
        }

        self.items = self._list.items;
        std.mem.sortUnstable(Endpoint, self.items, {}, compare);
    }

    pub fn deinit(self: *Self) void {
        self._list.deinit(Game.alloc);
        self.items = &.{};
    }

    fn compare(_: void, e1: Endpoint, e2: Endpoint) bool {
        if (e1.angle < e2.angle) return true;
        if (e2.angle < e1.angle) return false;
        return e1.is_start and !e2.is_start;
    }
};

const OpenWalls = struct {
    pub const Self = @This();
    const Heap = std.PriorityQueue(*CollisionShape, Vector, compare);

    heap: Heap,

    pub fn init() Self {
        return .{ .heap = .init(Game.alloc, Vector.zero) };
    }

    pub fn update(self: *Self, pov: Vector, cap: usize) void {
        self.heap.clearRetainingCapacity();
        self.heap.context = pov;
        self.heap.ensureTotalCapacity(cap) catch unreachable;
    }

    pub fn deinit(self: *Self) void {
        self.heap.deinit();
    }

    pub fn nearest(self: *Self) ?*CollisionShape {
        return self.heap.peek();
    }

    pub fn add(self: *Self, l: *CollisionShape) void {
        self.heap.add(l) catch unreachable;
    }

    pub fn remove(self: *Self, l: *CollisionShape) void {
        const idx = std.mem.indexOfScalar(*CollisionShape, self.heap.items, l) orelse return;
        _ = self.heap.removeIndex(idx);
    }

    fn compare(pov: Vector, l1: *CollisionShape, l2: *CollisionShape) std.math.Order {
        var gap: f32 = 0; // negative, l1 is closer, otherwise l2 is closer
        gap = absMax(gap, diff(l2, l1.line.start, pov));
        gap = absMax(gap, diff(l2, l1.line.end, pov));
        gap = absMax(gap, -diff(l1, l2.line.start, pov));
        gap = absMax(gap, -diff(l1, l2.line.end, pov));
        return std.math.order(gap, 0);
    }

    fn diff(shape: *const CollisionShape, point: Vector, pov: Vector) f32 {
        var intersection: Vector = undefined;
        if (shape.line.findIntersection(pov, point.subtract(pov).normalize(), &intersection)) {
            return point.distanceSquared(pov) - intersection.distanceSquared(pov);
        }
        return 0;
    }

    fn absMax(v1: f32, v2: f32) f32 {
        return if (@abs(v1) > @abs(v2)) v1 else v2;
    }
};

pub const VisibilityMesh = struct {
    pub const Self = @This();

    walls: std.ArrayList(CollisionShape) = .empty,
    endpoints: Endpoints = .{},
    open_walls: OpenWalls,

    triangle_vertices: std.ArrayList(sdl.render.Vertex) = .empty,
    indices: std.ArrayList(c_int) = .empty,

    pub fn init() Self {
        return .{ .open_walls = .init() };
    }

    pub fn update(self: *Self, pov: Vector, initial_walls: []CollisionShape) void {
        self.indices.clearRetainingCapacity();
        self.triangle_vertices.clearRetainingCapacity();

        // The POV is always the first vertex of the mesh.
        // This can be referenced using the indices array with index zero.
        self.addVertex(pov);

        self.updateWalls(initial_walls);
        self.endpoints.update(pov, self.walls.items);
        self.open_walls.update(pov, self.walls.items.len);

        var last_point: *const Endpoint = &self.endpoints.items[0];

        // A first pass must be performed to calculate inital state of `open_walls` and `last_point`.
        // Triangles are not added to the mesh during this first pass.
        // The `last_point` is the endpoint that forms the first point of the first triangle.

        for (0..2) |pass| {
            for (self.endpoints.items) |*endpoint| {
                const closest: ?*CollisionShape = self.open_walls.nearest();

                if (endpoint.is_start) {
                    self.open_walls.add(endpoint.wall);
                } else {
                    self.open_walls.remove(endpoint.wall);
                }

                const new_closest: ?*CollisionShape = self.open_walls.nearest();
                if (new_closest != closest) {
                    if (pass == 1) {
                        self.addTriangle(pov, last_point, endpoint, closest.?);
                    }
                    last_point = endpoint;
                }
            }
        }
    }

    pub fn deinit(self: *Self) void {
        self.indices.deinit(Game.alloc);
        self.triangle_vertices.deinit(Game.alloc);
        self.walls.deinit(Game.alloc);
        self.endpoints.deinit();
        self.open_walls.deinit();
    }

    fn addTriangle(
        self: *Self,
        pov: Vector,
        p1: *const Endpoint,
        p2: *const Endpoint,
        wall: *const CollisionShape,
    ) void {
        var p1i: Vector = undefined;
        var p2i: Vector = undefined;
        _ = wall.line.findIntersection(pov, p1.point.subtract(pov).normalize(), &p1i);
        _ = wall.line.findIntersection(pov, p2.point.subtract(pov).normalize(), &p2i);

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
        self.triangle_vertices.append(Game.alloc, .{
            .position = @bitCast(p.subtract(viewportLoc)),
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

        r.setDrawColor(Color.black.with(.{ .a = 100 }).sdl()) catch unreachable;
        r.clear() catch unreachable;

        r.setDrawBlendMode(.none) catch unreachable;
        r.setDrawColor(Color.transparent.sdl()) catch unreachable;
        if (Game.camera.getScale()) |scale| {
            const original_scale = r.getScale() catch unreachable;
            r.setScale(scale, scale) catch unreachable;
            r.renderGeometry(
                null,
                self.triangle_vertices.items,
                self.indices.items,
            ) catch unreachable;
            r.setScale(original_scale.x, original_scale.y) catch unreachable;
        }
    }

    fn cameraWalls() [4]CollisionShape {
        var res: [4]CollisionShape = undefined;
        const camera_verts = Game.camera.verticies();
        res[0] = .{ .line = .init(camera_verts[0], camera_verts[1]) };
        res[1] = .{ .line = .init(camera_verts[1], camera_verts[2]) };
        res[2] = .{ .line = .init(camera_verts[2], camera_verts[3]) };
        res[3] = .{ .line = .init(camera_verts[3], camera_verts[0]) };
        return res;
    }

    fn updateWalls(self: *Self, initial_walls: []CollisionShape) void {
        self.walls.clearRetainingCapacity();
        const camera_walls = cameraWalls();
        self.walls.ensureTotalCapacity(Game.alloc, initial_walls.len + camera_walls.len) catch unreachable;
        self.walls.appendSliceAssumeCapacity(initial_walls);
        self.walls.appendSliceAssumeCapacity(&camera_walls);
    }
};
