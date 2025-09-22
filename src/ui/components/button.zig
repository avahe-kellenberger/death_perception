const sdl = @import("sdl3");

const ui = @import("../lib/component.zig");
const UIComponent = ui.Component;

const Color = @import("../../color.zig").Color;

pub fn Button(comptime text: []const u8) UIComponent {
    const button_color: Color = .{ .r = 11, .g = 50, .b = 69 };
    var button = UIComponent.init();
    button.setHeight(60);
    button.background_color = button_color;
    button.content = .{
        .text = .{
            .string = .borrow(text),
            .align_h = .center,
            .align_v = .center,
            .color = .white,
        },
    };
    button.enableInput();
    button.on_mouse_enter = .{
        .handler = struct {
            fn handler(comp: *UIComponent, _: sdl.events.MouseMotion, _: ui.EventContext) void {
                var hover_color = button_color;
                hover_color.a = 100;
                comp.background_color = hover_color;
            }
        }.handler,
    };
    button.on_mouse_exit = .{
        .handler = struct {
            fn handler(comp: *UIComponent, _: sdl.events.MouseMotion, _: ui.EventContext) void {
                comp.background_color = button_color;
            }
        }.handler,
    };
    return button;
}
