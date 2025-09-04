const std = @import("std");

pub var random: std.Random = undefined;
var prng: std.Random.DefaultPrng = undefined;

pub fn init() void {
    const seed = blk: {
        var s: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&s)) catch unreachable;
        break :blk s;
    };
    prng = .init(seed);
    random = prng.random();
}

pub fn rand(T: type, at_least: T, at_most: T) T {
    return switch (@typeInfo(T)) {
        .float => at_least + (random.float(T) * (at_most - at_least)),
        .int => random.intRangeAtMost(T, at_least, at_most),
        else => unreachable,
    };
}
