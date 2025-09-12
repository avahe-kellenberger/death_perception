const std = @import("std");
const Vector = @import("vector.zig").Vector;

pub fn EasingFn(T: type) type {
    return fn (T: type, start: T, end: T, completion: f32) T;
}

pub fn lerp(T: type, start: T, end: T, completion: f32) T {
    switch (T) {
        Vector(f32) => return Vector(f32).init(
            lerp(f32, start.x, end.x, completion),
            lerp(f32, start.y, end.y, completion),
        ),
        Vector(i32) => return Vector(i32).init(
            lerp(i32, start.x, end.x, completion),
            lerp(i32, start.y, end.y, completion),
        ),
        else => switch (@typeInfo(T)) {
            .float, .comptime_float => return start + (end - start) * completion,
            .bool => return if (completion == 1.0) end else start,
            .int, .comptime_int => {
                if (start < end) {
                    const diff: f32 = @floatFromInt(end - start);
                    return start + @as(T, @intFromFloat(@floor(diff * completion)));
                }
                const diff: f32 = @floatFromInt(end - start);
                return start + @as(T, @intFromFloat(@ceil(diff * completion)));
            },
            else => unreachable,
        },
    }
}

test "lerp floats" {
    const x = 14.0;
    const result = lerp(f32, x, x * 2, 0.5);
    try std.testing.expectEqual(21.0, result);
}

test "lerp ints" {
    const x = 13;
    const result = lerp(i32, x, x * 2, 0.5);
    try std.testing.expectEqual(19, result);
}

test "lerp bools" {
    const x = false;
    var result = lerp(bool, x, true, 0.5);
    try std.testing.expectEqual(false, result);

    result = lerp(bool, x, true, 1.0);
    try std.testing.expectEqual(true, result);
}

test "lerp Vector(f32)" {
    const start: Vector(f32) = .init(15.0, 32.5);
    const end: Vector(f32) = .init(35.0, 12.9);
    const result = lerp(Vector(f32), start, end, 0.5);
    const expected = Vector(f32).init(25, 22.7);
    try std.testing.expectEqual(expected, result);
}

test "lerp Vector(i32)" {
    const start: Vector(i32) = .init(15, 32);
    const end: Vector(i32) = .init(35, 12);
    const result = lerp(Vector(i32), start, end, 0.5);
    const expected: Vector(i32) = .init(25, 22);
    try std.testing.expectEqual(expected, result);
}
