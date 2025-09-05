const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Keycode = sdl.keycode.Keycode;
const FPoint = sdl.rect.FPoint;
const Button = sdl.mouse.Button;

pub const InputState = enum {
    pressed,
    released,
    just_pressed,
    just_released,
};

const Mouse = struct {
    pub const Self = @This();

    alloc: Allocator,

    loc: FPoint,
    buttons: std.AutoHashMap(Button, InputState),

    pub fn init(a: Allocator) Self {
        const mouse_state = sdl.mouse.getState();
        return .{
            .alloc = a,
            .loc = .{ .x = mouse_state.x, .y = mouse_state.y },
            .buttons = .init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        self.buttons.deinit();
    }

    pub fn update(self: *Self, e: sdl.events.Event) void {
        switch (e) {
            .mouse_motion => |m| {
                self.loc.x = m.x;
                self.loc.y = m.y;
            },
            .mouse_button_up, .mouse_button_down => |b| {
                const res = self.buttons.getOrPut(b.button) catch unreachable;
                if (!res.found_existing) {
                    res.value_ptr.* = if (b.down) .just_pressed else .just_released;
                } else switch (res.value_ptr.*) {
                    .pressed, .just_pressed => res.value_ptr.* = if (b.down) .pressed else .just_released,
                    .released, .just_released => res.value_ptr.* = if (b.down) .just_pressed else .released,
                }
            },
            else => {},
        }
    }

    pub fn isPressed(self: *Self, btn: Button) bool {
        const res = self.buttons.getOrPut(btn) catch unreachable;
        if (!res.found_existing) res.value_ptr.* = false;
        return res.value_ptr.*;
    }
};

const Keyboard = struct {
    pub const Self = @This();

    alloc: Allocator,

    keys: std.AutoHashMap(Keycode, InputState),

    pub fn init(a: Allocator) Self {
        return .{
            .alloc = a,
            .keys = .init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        self.keys.deinit();
    }

    pub fn update(self: *Self, event: sdl.events.Event) void {
        switch (event) {
            .key_up, .key_down => |e| if (e.key) |keycode| {
                const state = blk: {
                    if (e.down) {
                        if (e.repeat) break :blk .pressed;
                        break :blk InputState.just_pressed;
                    }
                    if (e.repeat) break :blk .released;
                    break :blk .just_released;
                };

                self.keys.put(keycode, state) catch unreachable;
            },
            else => {},
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

var alloc: Allocator = undefined;
pub var mouse: Mouse = undefined;
pub var keyboard: Keyboard = undefined;

pub fn init(a: Allocator) void {
    alloc = a;
    mouse = .init(alloc);
    keyboard = .init(alloc);
}

pub fn deinit() void {
    mouse.deinit();
    keyboard.deinit();
}

pub fn update(e: sdl.events.Event) !void {
    switch (e) {
        .key_up, .key_down => keyboard.update(e),
        .mouse_motion, .mouse_button_up, .mouse_button_down => mouse.update(e),
        else => {},
    }
}

pub fn isKeyPressed(k: Keycode) bool {
    return keyboard.isPressed(k);
}

pub fn getButtonState(btn: Button) InputState {
    const res = mouse.buttons.getOrPut(btn) catch unreachable;
    if (!res.found_existing) res.value_ptr.* = .released;
    return res.value_ptr.*;
}

/// Update just_pressed and just_released input properties.
/// This function should be called once per frame.
pub fn resetFrameSpecificState() void {
    {
        var iter = mouse.buttons.valueIterator();
        while (iter.next()) |v| {
            switch (v.*) {
                .just_pressed => v.* = .pressed,
                .just_released => v.* = .released,
                else => {},
            }
        }
    }

    {
        var iter = keyboard.keys.valueIterator();
        while (iter.next()) |v| {
            switch (v.*) {
                .just_pressed => v.* = .pressed,
                .just_released => v.* = .released,
                else => {},
            }
        }
    }
}
