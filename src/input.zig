const std = @import("std");
const sdl = @import("sdl3");

const Allocator = std.mem.Allocator;
const Keycode = sdl.keycode.Keycode;

const InputState = enum {
    pressed,
    released,
    just_pressed,
    just_released,
};

var alloc: Allocator = undefined;
var keys: std.AutoHashMapUnmanaged(Keycode, InputState) = .empty;

pub fn init(a: Allocator) void {
    alloc = a;
}

pub fn deinit() void {
    keys.deinit(alloc);
}

pub fn update(e: sdl.events.Keyboard) !void {
    if (e.key) |keycode| {
        const state = blk: {
            if (e.down) {
                if (e.repeat) break :blk .pressed;
                break :blk InputState.just_pressed;
            }

            if (e.repeat) break :blk .released;
            break :blk .just_released;
        };
        try keys.put(alloc, keycode, state);
    }
}

pub fn isPressed(keycode: Keycode) bool {
    if (keys.get(keycode)) |k| {
        return k == .pressed or k == .just_pressed;
    }
    return false;
}

pub fn wasJustPressed(keycode: Keycode) bool {
    if (keys.get(keycode)) |k| {
        return k == .just_pressed;
    }
    return false;
}
