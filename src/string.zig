const Game = @import("./game.zig");

pub const String = union(enum) {
    const Self = @This();

    borrowed: []const u8,
    owned: []const u8,

    /// Borrow a string without taking ownership.
    pub fn borrow(comptime data: []const u8) Self {
        return .{ .borrowed = data };
    }

    /// Take ownership of string data.
    pub fn take(data: []const u8) Self {
        return .{ .owned = data };
    }

    /// Use string data to create an owned copy.
    pub fn clone(data: []const u8) Self {
        return .take(Game.alloc.dupe(u8, data));
    }

    /// Free string data if owned.
    pub fn deinit(self: *Self) void {
        if (self.* == .owned) {
            Game.alloc.free(self.owned);
        }
    }

    /// Access a read-only reference to the string data.
    pub fn ref(self: *const Self) []const u8 {
        return switch (self.*) {
            .borrowed => |d| d,
            .owned => |o| o,
        };
    }
};
