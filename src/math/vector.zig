const std = @import("std");

const pow = std.math.pow;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

pub fn Vector(T: type) type {
    return struct {
        pub const Self = @This();

        x: T,
        y: T,

        pub fn add(self: Self, other: Self) Self {
            return .{ .x = self.x + other.x, .y = self.y + other.y };
        }

        pub fn subtract(self: Self, other: Self) Self {
            return .{ .x = self.x - other.x, .y = self.y - other.y };
        }

        pub fn getMagnitudeSquared(self: Self) f32 {
            const result = self.x * self.x + self.y * self.y;
            switch (@typeInfo(T)) {
                .float => return result,
                .int => return @floatFromInt(result),
                else => unreachable,
            }
        }

        pub fn getMagnitude(self: Self) f32 {
            return @sqrt(self.getMagnitudeSquared());
        }

        pub fn normalize(self: Self) Self {
            const scale = 1.0 / self.getMagnitude();
            return .{ .x = self.x * scale, .y = self.y * scale };
        }

        pub fn distanceSquared(self: Self, other: Self) f32 {
            const result = pow(T, self.x - other.x, 2) + pow(T, self.y - other.y, 2);
            switch (@typeInfo(T)) {
                .float => return result,
                .int => return @floatFromInt(result),
                else => unreachable,
            }

            return @floatFromInt(
                pow(T, self.x - other.x, 2) +
                    pow(T, self.y - other.y, 2),
            );
        }

        pub fn distance(self: Self, other: Self) f32 {
            return @sqrt(self.distanceSquared(other));
        }

        pub fn dotProduct(self: Self, other: Self) f32 {
            const result = self.x * other.x + self.y * other.y;
            switch (@typeInfo(T)) {
                .float => return result,
                .int => return @floatFromInt(result),
                else => unreachable,
            }
        }
    };
}

// Factory function for creating a Vector of type f32
pub fn vector(x: f32, y: f32) Vector(f32) {
    return Vector(f32){ .x = x, .y = y };
}

// Factory function for creating a Vector of type i32
pub fn ivector(x: i32, y: i32) Vector(i32) {
    return Vector(i32){ .x = x, .y = y };
}

const floating_point_tolerance = 0.000001;

test "add" {
    const sum = vector(10.4, -15.1).add(vector(12.9, 8.2));
    try expectApproxEqAbs(23.3, sum.x, floating_point_tolerance);
    try expectApproxEqAbs(-6.9, sum.y, floating_point_tolerance);

    const isum = ivector(10, 15).add(ivector(12, 8));
    try expectEqual(22, isum.x);
    try expectEqual(23, isum.y);
}

test "getMagnitudeSquared" {
    try expectEqual(100.0, vector(10.0, 0).getMagnitudeSquared());
    try expectEqual(100.0, vector(0, 10.0).getMagnitudeSquared());
    try expectEqual(200.0, vector(10.0, 10.0).getMagnitudeSquared());

    try expectEqual(100.0, ivector(10, 0).getMagnitudeSquared());
    try expectEqual(100.0, ivector(0, 10).getMagnitudeSquared());
    try expectEqual(200.0, ivector(10, 10).getMagnitudeSquared());
}

test "distance" {
    try expectEqual(10.0, vector(10.0, 0).distance(vector(0.0, 0.0)));
    try expectEqual(10, ivector(10, 0).distance(ivector(0, 0)));
}

test "dotProduct" {
    try expectEqual(275.0, vector(10.0, 1.0).dotProduct(vector(25.0, 25.0)));
    try expectEqual(275.0, ivector(10, 1).dotProduct(ivector(25, 25)));
}
