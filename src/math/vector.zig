const std = @import("std");

const pow = std.math.pow;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

pub fn Vector(T: type) type {
    return packed struct {
        pub const Self = @This();
        pub const zero = switch (@typeInfo(T)) {
            .float => vector(0, 0),
            .int => ivector(0, 0),
            else => unreachable,
        };
        pub const one = switch (@typeInfo(T)) {
            .float => vector(1.0, 1.0),
            .int => ivector(1, 1),
            else => unreachable,
        };

        x: T,
        y: T,

        pub fn init(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{ .x = self.x + other.x, .y = self.y + other.y };
        }

        pub fn subtract(self: Self, other: Self) Self {
            return .{ .x = self.x - other.x, .y = self.y - other.y };
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{ .x = self.x * other.x, .y = self.y * other.y };
        }

        pub fn div(self: Self, other: Self) Self {
            return .{ .x = self.x / other.x, .y = self.y / other.y };
        }

        pub fn scale(self: Self, scalar: f32) Self {
            return .{ .x = self.x * scalar, .y = self.y * scalar };
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
            const scalar = 1.0 / self.getMagnitude();
            return .{ .x = self.x * scalar, .y = self.y * scalar };
        }

        pub fn maxMagnitude(self: Self, magnitude: f32) Self {
            const mag = self.getMagnitude();
            if (mag <= magnitude) {
                return self;
            }
            return self.scale(magnitude / mag);
        }

        pub fn distanceSquared(self: Self, other: Self) f32 {
            return other.subtract(self).getMagnitudeSquared();
        }

        pub fn distance(self: Self, other: Self) f32 {
            return other.subtract(self).getMagnitude();
        }

        pub fn dotProduct(self: Self, other: Self) f32 {
            const result = self.x * other.x + self.y * other.y;
            switch (@typeInfo(T)) {
                .float => return result,
                .int => return @floatFromInt(result),
                else => unreachable,
            }
        }

        pub fn crossProduct(self: Self, other: Self) f32 {
            const result = self.x * other.y - self.y * other.x;
            switch (@typeInfo(T)) {
                .float => return result,
                .int => return @floatFromInt(result),
                else => unreachable,
            }
        }

        pub fn negate(self: Self) Self {
            return .{ .x = -self.x, .y = -self.y };
        }

        pub fn perpRight(self: Self) Self {
            return .init(self.y, -self.x);
        }

        pub fn perpLeft(self: Self) Self {
            return .init(-self.y, self.x);
        }

        pub fn round(self: Self) Self {
            return .init(@round(self.x), @round(self.y));
        }

        /// Gets a copy of this vector rotated around its origin by the given amount.
        /// @param theta the number of radians to rotate the vector.
        pub fn rotate(self: Self, theta: f32) Self {
            const x = self.x * @cos(theta) - self.y * @sin(theta);
            const y = self.x * @sin(theta) + self.y * @cos(theta);
            switch (@typeInfo(T)) {
                .float => return .{ .x = x, .y = y },
                .int => return .{
                    .x = @as(T, @intFromFloat(@round(x))),
                    .y = @as(T, @intFromFloat(@round(y))),
                },
                else => unreachable,
            }
        }

        /// Rotates counter-clockwise around the given anchor point.
        /// @param theta The radians to rotate.
        /// @param anchorPoint The anchor point to rotate around.
        /// @return A rotated point around the anchor point.
        pub fn rotateAround(self: Self, theta: f32, anchor: Self) Self {
            const x = anchor.x + (@cos(theta) * (self.x - anchor.x) - @sin(theta) * (self.y - anchor.y));
            const y = anchor.y + (@sin(theta) * (self.x - anchor.x) + @cos(theta) * (self.y - anchor.y));
            switch (@typeInfo(T)) {
                .float => return .{ .x = x, .y = y },
                .int => return .{
                    .x = @as(T, @intFromFloat(@round(x))),
                    .y = @as(T, @intFromFloat(@round(y))),
                },
                else => unreachable,
            }
        }

        /// Gets the angle of this vector, in radians.
        /// (from -pi to pi)
        pub fn getAngleRadians(self: Self) f32 {
            return std.math.atan2(self.y, self.x);
        }

        pub fn getAngleDegrees(self: Self) f32 {
            return std.math.radiansToDegrees(self.getAngleRadians());
        }

        pub fn getSignedAngleDifference(angle1: f32, angle2: f32) f32 {
            var diff = angle2 - angle1;
            if (diff <= -std.math.pi) diff += std.math.tau;
            if (diff > std.math.pi) diff -= std.math.tau;
            return diff;
        }

        pub fn equals(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y;
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
