const std = @import("std");
const sdl = @import("sdl3");

const Game = @import("../../game.zig");

const ui = @import("../lib/component.zig");
const UIComponent = ui.Component;

const Color = @import("../../color.zig").Color;

pub fn TextBox() UIComponent {
    const background_color: Color = .{ .r = 11, .g = 50, .b = 69 };
    var box = UIComponent.init();
    box.setHeight(60);
    box.setPadding(10);
    box.background_color = background_color;
    box.content = .{
        .text = .{
            .string = .borrow(""),
            .align_h = .start,
            .align_v = .center,
            .color = .white,
        },
    };
    box.enableInput();
    box.enableFocus();
    box.on_mouse_enter = .{
        .handler = struct {
            fn handler(comp: *UIComponent, _: sdl.events.MouseMotion, _: ui.EventContext) void {
                var hover_color = background_color;
                hover_color.a = 100;
                comp.background_color = hover_color;
            }
        }.handler,
    };
    box.on_mouse_exit = .{
        .handler = struct {
            fn handler(comp: *UIComponent, _: sdl.events.MouseMotion, _: ui.EventContext) void {
                comp.background_color = background_color;
            }
        }.handler,
    };

    var cursor = UIComponent.init();
    cursor.setWidth(5);
    cursor.background_color = .white;
    cursor.setDisplayMode(.disabled);
    cursor.on_update = .{
        .handler = struct {
            fn handler(comp: *UIComponent, _: f32, _: ui.EventContext) void {
                if (comp.getDisplayMode() != .disabled) {
                    const rem = Game.frame.time - @floor(Game.frame.time);
                    comp.setDisplayMode(if (rem > 0.5) .visible else .invisible);
                }
            }
        }.handler,
    };
    box.add(cursor);

    box.on_focus = .{
        .context = .{ .u32 = cursor.id },
        .handler = struct {
            fn handler(comp: *UIComponent, _: sdl.events.MouseButton, ctx: ui.EventContext) void {
                if (comp.get(ctx.u32)) |cursor_comp| {
                    cursor_comp.setDisplayMode(.visible);
                }

                const bounds = comp.bounds();
                sdl.keyboard.setTextInputArea(Game.window, .{
                    .x = @intFromFloat(@floor(bounds.left)),
                    .y = @intFromFloat(@floor(bounds.top)),
                    .w = @intFromFloat(@ceil(bounds.width())),
                    .h = @intFromFloat(@ceil(bounds.height())),
                }, 5) catch unreachable;
                sdl.keyboard.startTextInputWithProperties(Game.window, .{ .multi_line = false }) catch unreachable;
            }
        }.handler,
    };
    box.on_blur = .{
        .context = .{ .u32 = cursor.id },
        .handler = struct {
            fn handler(comp: *UIComponent, _: sdl.events.MouseButton, ctx: ui.EventContext) void {
                if (comp.get(ctx.u32)) |cursor_comp| {
                    cursor_comp.setDisplayMode(.disabled);
                }

                sdl.keyboard.stopTextInput(Game.window) catch unreachable;
                sdl.keyboard.setTextInputArea(Game.window, null, 0) catch unreachable;
            }
        }.handler,
    };

    box.on_text = .{
        .context = .{ .u32 = cursor.id },
        .handler = struct {
            fn handler(comp: *UIComponent, e: sdl.events.TextInput, ctx: ui.EventContext) void {
                const curr_str = comp.content.text.string.ref();
                const append_str = e.text;
                const new_str = std.mem.concat(Game.alloc, u8, &.{ curr_str, append_str }) catch unreachable;
                comp.content.text.setString(.take(new_str));
                positionCursor(comp, ctx.u32);
            }
        }.handler,
    };
    box.on_key = .{
        .context = .{ .u32 = cursor.id },
        .handler = struct {
            fn handler(comp: *UIComponent, e: sdl.events.Keyboard, ctx: ui.EventContext) void {
                if (!e.down) return;
                const key = e.key orelse return;
                switch (key) {
                    .backspace => {
                        const curr_str = comp.content.text.string.ref();
                        if (curr_str.len > 0) {
                            comp.content.text.setString(.clone(curr_str[0 .. curr_str.len - 1]));
                            positionCursor(comp, ctx.u32);
                        }
                    },
                    else => {},
                }
            }
        }.handler,
    };

    return box;
}

fn positionCursor(comp: *UIComponent, cursor_id: u32) void {
    const cursor_comp = comp.get(cursor_id) orelse return;
    const text_width: f32 = comp.content.text.measure();
    cursor_comp.setMarginInsets(.{ .left = text_width });
}
