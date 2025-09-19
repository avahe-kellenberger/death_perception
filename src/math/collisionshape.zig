const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Game = @import("../game.zig");
const Vector = @import("vector.zig").Vector(f32);

const sdl = @import("sdl3");

pub const aabb_projection_axes = [2]Vector{ point(1, 0), point(0, 1) };

fn point(x: f32, y: f32) Vector {
    return .{ .x = x, .y = y };
}

pub const CollisionShape = union(enum) {
    pub const Self = @This();

    aabb: AABB,
    circle: Circle,
    line: Line,

    pub fn getProjectionAxesCount(self: Self, other: Self) u32 {
        switch (self) {
            .aabb => return 2,
            .circle => switch (other) {
                .aabb => return 4,
                .circle => return 1,
                .line => return 2,
            },
            .line => return 1,
        }
    }

    /// Caller owns the returned memory.
    ///
    /// Generates projection axes facing away from this shape towards the given other shape.
    /// otherShape is the collision shape being tested against.
    /// toOther isa a vector from this shape's reference frame to the other shape's reference frame.
    pub fn getProjectionAxes(
        self: Self,
        verticies: *ArrayList(Vector),
        other: CollisionShape,
        to_other: Vector,
    ) void {
        switch (self) {
            .aabb => for (aabb_projection_axes) |axis| verticies.appendAssumeCapacity(axis),
            .circle => |circle| switch (other) {
                .aabb => |aabb| {
                    circleToAABBProjectionAxes(verticies, circle, aabb, to_other);
                },
                .circle => |other_circle| {
                    verticies.appendAssumeCapacity(
                        other_circle.center.subtract(circle.center).add(to_other).normalize(),
                    );
                },
                .line => |line| {
                    circleToLineProjectionAxes(verticies, circle, line, to_other);
                },
            },
            .line => |line| verticies.appendAssumeCapacity(line.end.subtract(line.start).perpRight()),
        }
    }

    pub fn project(self: Self, loc: Vector, axis: Vector) Vector {
        switch (self) {
            .aabb => |aabb| {
                var projection = Vector.init(std.math.inf(f32), -std.math.inf(f32));
                inline for (aabb.verticies()) |v| {
                    const dot_product = axis.dotProduct(v.add(loc));
                    if (dot_product < projection.x) projection.x = dot_product;
                    if (dot_product > projection.y) projection.y = dot_product;
                }
                return projection;
            },
            .circle => |circle| {
                const center_dot = axis.dotProduct(circle.center.add(loc));
                return .init(center_dot - circle.radius, center_dot + circle.radius);
            },
            .line => |line| {
                const dot_product_start = axis.dotProduct(line.start.add(loc));
                const dot_product_end = axis.dotProduct(line.end.add(loc));
                return .{
                    .x = @min(dot_product_start, dot_product_end),
                    .y = @max(dot_product_start, dot_product_end),
                };
            },
        }
    }

    /// Assumes the ArrayList has enough capacity.
    pub fn getFarthest(self: Self, direction: Vector, out: *ArrayList(Vector)) []Vector {
        switch (self) {
            .aabb => |aabb| {
                if (direction.x == 0) {
                    if (direction.y > 0) {
                        // Return bottom 2 verts
                        out.appendAssumeCapacity(point(aabb.top_left.x, aabb.bottom_right.y));
                        out.appendAssumeCapacity(aabb.bottom_right);
                    } else if (direction.y < 0) {
                        // Return top 2 verts
                        out.appendAssumeCapacity(aabb.top_left);
                        out.appendAssumeCapacity(point(aabb.bottom_right.x, aabb.top_left.y));
                    }
                } else if (direction.x > 0) {
                    if (direction.y == 0) {
                        // Return right 2 verts
                        out.appendAssumeCapacity(point(aabb.bottom_right.x, aabb.top_left.y));
                        out.appendAssumeCapacity(aabb.bottom_right);
                    } else if (direction.y > 0) {
                        // Bottom right
                        out.appendAssumeCapacity(aabb.bottom_right);
                    } else if (direction.y < 0) {
                        // Top right
                        out.appendAssumeCapacity(point(aabb.bottom_right.x, aabb.top_left.y));
                    }
                } else {
                    if (direction.y == 0) {
                        // Return left 2 verts
                        out.appendAssumeCapacity(aabb.top_left);
                        out.appendAssumeCapacity(point(aabb.top_left.x, aabb.bottom_right.y));
                    } else if (direction.y > 0) {
                        // Bottom left
                        out.appendAssumeCapacity(point(aabb.top_left.x, aabb.bottom_right.y));
                    } else if (direction.y < 0) {
                        // Top left
                        out.appendAssumeCapacity(aabb.top_left);
                    }
                }
            },
            .circle => |circle| {
                out.appendAssumeCapacity(circle.center.add(direction.scale(circle.radius)));
            },
            .line => |line| {
                if (line.start.dotProduct(direction) > line.end.dotProduct(direction)) {
                    out.appendAssumeCapacity(line.start);
                } else {
                    out.appendAssumeCapacity(line.end);
                }
            },
        }
        return out.items;
    }
};

pub const AABB = struct {
    pub const Self = @This();

    top_left: Vector,
    bottom_right: Vector,

    pub fn init(top_left: Vector, bottom_right: Vector) AABB {
        return AABB{ .top_left = top_left, .bottom_right = bottom_right };
    }

    pub fn verticies(self: *const Self) [4]Vector {
        return .{
            self.top_left,
            point(self.bottom_right.x, self.top_left.y),
            point(self.top_left.x, self.bottom_right.y),
            self.bottom_right,
        };
    }
};

pub const Circle = struct {
    pub const Self = @This();

    center: Vector,
    radius: f32,

    pub fn init(center: Vector, radius: f32) Circle {
        return Circle{ .center = center, .radius = radius };
    }

    pub fn render(self: Self) void {
        _ = self;
        // TODO:
    }
};

pub const Line = struct {
    pub const Self = @This();

    // Normal should always face right
    start: Vector,
    end: Vector,

    pub fn init(start: Vector, end: Vector) Line {
        return .{ .start = start, .end = end };
    }

    pub fn middle(self: Line) Vector {
        return self.start.add(self.end).scale(0.5);
    }

    pub fn findIntersection(self: *const Self, ray_origin: Vector, direction: Vector, out: *Vector) bool {
        const v2 = self.end.subtract(self.start);
        const v3 = direction.perpLeft();

        const dot = v2.dotProduct(v3);
        if (dot == 0) {
            out.* = ray_origin;
            return false;
        }

        const v1 = ray_origin.subtract(self.start);
        // Distance from ray_origin in direction where the intersection occurred
        const t1 = v2.crossProduct(v1) / dot;
        // 0.0 to 1.0 along the line from self.start to the intersection
        const t2 = v1.dotProduct(v3) / dot;

        // We could also return this
        // return self.start.add(v2.scale(t2));
        out.* = ray_origin.add(direction.scale(t1));
        return t1 >= 0.0 and (t2 >= 0.0 and t2 <= 1.0);
    }

    test {
        const line: Line = .init(.init(4, 1), .init(1, 4));
        const ray_origin: Vector = .init(2, 5);
        const ray_dir: Vector = .init(0, 1);

        const intersection = line.findIntersection(ray_origin, ray_dir);
        try std.testing.expectEqual(null, intersection);
    }

    test {
        const line: Line = .init(.init(4, 1), .init(1, 4));
        const ray_origin: Vector = .init(4, 2);
        const ray_dir: Vector = .init(-1, 0);

        const intersection = line.findIntersection(ray_origin, ray_dir);
        try std.testing.expect(intersection != null);
        try std.testing.expectEqual(3, intersection.?.x);
        try std.testing.expectEqual(2, intersection.?.y);
    }

    test {
        const line: Line = .init(.init(4, 1), .init(1, 4));
        const ray_origin: Vector = .init(5, 4);
        var ray_dir: Vector = .init(-10, -10);
        ray_dir = ray_dir.normalize();

        const intersection = line.findIntersection(ray_origin, ray_dir);
        try std.testing.expect(intersection != null);
        try std.testing.expectEqual(3, intersection.?.x);
        try std.testing.expectEqual(2, intersection.?.y);
    }
};

/// Assumes the provided list has enough capacity to add 4 vectors.
fn circleToAABBProjectionAxes(
    list: *ArrayList(Vector),
    circle: Circle,
    aabb: AABB,
    circle_to_aabb: Vector,
) void {
    for (aabb.verticies()) |v| {
        list.appendAssumeCapacity(v.subtract(circle.center).add(circle_to_aabb).normalize());
    }
}
/// Assumes the provided list has enough capacity to add 2 vectors.
fn circleToLineProjectionAxes(
    list: *ArrayList(Vector),
    circle: Circle,
    line: Line,
    circle_to_line: Vector,
) void {
    list.appendAssumeCapacity(line.start.subtract(circle.center).add(circle_to_line).normalize());
    list.appendAssumeCapacity(line.end.subtract(circle.center).add(circle_to_line).normalize());
}
