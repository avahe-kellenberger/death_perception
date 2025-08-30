const std = @import("std");
const sdl = @import("sdl3");

const Allocator = std.mem.Allocator;
const Keycode = sdl.keycode.Keycode;

pub var handler: InputHandler = undefined;

const InputState = enum {
    pressed,
    released,
    just_pressed,
    just_released,
};

pub const InputHandler = struct {
    pub const Self = @This();

    alloc: Allocator,
    keys: std.AutoHashMapUnmanaged(Keycode, InputState) = .empty,

    pub fn init(alloc: Allocator) InputHandler {
        return .{
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Self) void {
        self.keys.deinit(self.alloc);
    }

    pub fn update(self: *Self, e: sdl.events.Keyboard) !void {
        if (e.key) |keycode| {
            const state = blk: {
                if (e.down) {
                    if (e.repeat) break :blk .pressed;
                    break :blk InputState.just_pressed;
                }

                if (e.repeat) break :blk .released;
                break :blk .just_released;
            };
            try self.keys.put(self.alloc, keycode, state);
        }
    }

    pub fn isPressed(self: *Self, keycode: Keycode) bool {
        if (self.keys.get(keycode)) |k| {
            return k == .pressed or k == .just_pressed;
        }
        return false;
    }

    pub fn wasJustPressed(self: *Self, keycode: Keycode) bool {
        if (self.keys.get(keycode)) |k| {
            return k == .just_pressed;
        }
        return false;
    }
};
