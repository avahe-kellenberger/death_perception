const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const sdl = @import("sdl3");
const FPoint = sdl.rect.FPoint;

const aabb_projection_axes = [2]FPoint{ point(1, 0), point(0, 1) };

fn point(x: f32, y: f32) FPoint {
    return .{ .x = x, .y = y };
}

pub const CollisionShape = union(enum) {
    pub const Self = @This();

    AABB: AABB,
    Circle: Circle,
    Polygon: Polygon,

    /// Caller owns the returned memory.
    ///
    /// Generates projection axes facing away from this shape towards the given other shape.
    /// otherShape is the collision shape being tested against.
    /// toOther isa a vector from this shape's reference frame to the other shape's reference frame.
    pub fn getProjectionAxes(self: *Self, alloc: Allocator, other: *CollisionShape, to_other: FPoint) []FPoint {
        var result: ArrayList(FPoint) = undefined;

        switch (self) {
            .AABB => |aabb| switch (other) {
                .AABB => {
                    result = .initCapacity(alloc, 2);
                    for (aabb_projection_axes) |axis| result.append(alloc, axis) catch unreachable;
                },
                .Circle => {
                    result = .initCapacity(alloc, 4);
                    circleToAABBProjectionAxes(&result, self, aabb, to_other);
                },
                .Polygon => {
                    //
                },
            },
            .Circle => |circle| {
                const axes = circle.getProjectionAxes(self);
                std.debug.print("Processing Circle with projection axes: {}\n", .{axes});
            },
            .Polygon => |polygon| {
                const axes = polygon.getProjectionAxes(self);
                std.debug.print("Processing Polygon with projection axes: {}\n", .{axes});
            },
        }
        return result.toOwnedSlice(alloc);
    }
};

pub const AABB = struct {
    pub const Self = @This();

    top_left: FPoint,
    bottom_right: FPoint,

    pub fn init(top_left: FPoint, bottom_right: FPoint) AABB {
        return AABB{ .top_left = top_left, .bottom_right = bottom_right };
    }

    pub fn verticies(self: *Self) [4]FPoint {
        return .{
            self.top_left,
            point(self.bottom_right.x, self.top_left.y),
            point(self.top_left.x, self.bottom_right.y),
            self.bottom_right,
        };
    }
};

pub const Circle = struct {
    center: FPoint,
    radius: f32,

    pub fn init(center: FPoint, radius: f32) Circle {
        return Circle{ .center = center, .radius = radius };
    }
};

pub const Polygon = struct {
    vertices: []FPoint,

    pub fn init(vertices: []FPoint) Polygon {
        return Polygon{ .vertices = vertices };
    }
};

fn circleToAABBProjectionAxes(
    list: *ArrayList(FPoint),
    circle: Circle,
    aabb: AABB,
    circle_to_aabb: FPoint,
) void {
    // for every vertex v in aab,
    // normalize(v - circle.center + circle_to_aabb)
}

test {
    // const aabb = AABB.init(
    //     FPoint{ .x = 0, .y = 0 },
    //     FPoint{ .x = 1, .y = 1 },
    // );
    // const circle = Circle.init(FPoint{ .x = 0, .y = 0 }, 1.0);
    //
    // const polygon = Polygon.init(.{
    //     FPoint{ .x = 0, .y = 0 },
    //     FPoint{ .x = 1, .y = 0 },
    //     FPoint{ .x = 0, .y = 1 },
    // });
    //
    // // Example usage
    // processCollisionShape(&CollisionShape{ .AABB = aabb });
    // processCollisionShape(&CollisionShape{ .Circle = circle });
    // processCollisionShape(&CollisionShape{ .Polygon = polygon });
}
