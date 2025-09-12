// Main menu UI when the game launches

const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");

const ui = @import("./lib/component.zig");
const UIComponent = ui.Component;

const Color = @import("../color.zig").Color;
const Input = @import("../input.zig");
const Game = @import("../game.zig");

var root: ?UIComponent = null;

pub fn init(alloc: Allocator) void {
    deinit();

    var background = UIComponent.init(alloc);
    background.background_color = .{ .r = 100 };
    // TODO use tiled content

    var foreground = UIComponent.init(alloc);
    foreground.setHorizontalAlignment(.center);
    foreground.setPadding(50);

    var title = UIComponent.init(alloc);
    title.setHeight(200);
    title.content = .{
        .text = .{
            .content = .borrow("Death Perception"),
            .align_h = .center,
            .align_v = .center,
            .font = .{
                .size = 150,
                .outline = .{
                    .color = .black,
                    .size = 4,
                    .align_h = .center,
                    .align_v = .center,
                },
            },
            .color = .white,
        },
    };
    foreground.add(title);

    var menu = UIComponent.init(alloc);
    menu.setStackDirection(.vertical);
    menu.setMargin(100);
    menu.setWidth(250);

    var start_button = createMenuButton(alloc, "Start");
    start_button.on_mouse_button = .{
        .context = undefined,
        .handler = struct {
            fn handler(_: *UIComponent, _: sdl.events.MouseButton, _: *anyopaque) void {
                // TODO should animate going into the door in the background
            }
        }.handler,
    };
    menu.add(start_button);

    var settings_button = createMenuButton(alloc, "Settings");
    settings_button.on_mouse_button = .{
        .context = undefined,
        .handler = struct {
            fn handler(_: *UIComponent, _: sdl.events.MouseButton, _: *anyopaque) void {
                // TODO display main menu settings
            }
        }.handler,
    };
    menu.add(settings_button);

    var quit_button = createMenuButton(alloc, "Quit");
    quit_button.on_mouse_button = .{
        .context = undefined,
        .handler = struct {
            fn handler(_: *UIComponent, _: sdl.events.MouseButton, _: *anyopaque) void {
                Game.state = .quit;
            }
        }.handler,
    };
    menu.add(quit_button);

    foreground.add(menu);

    var r = UIComponent.init(alloc);
    r.setStackDirection(.overlap);
    r.add(background);
    r.add(foreground);

    root = r;
}

pub fn deinit() void {
    if (root) |*r| {
        r.deinit();
        root = null;
    }
}

pub fn input(event: sdl.events.Event) void {
    if (root) |*r| {
        ui.handleInputEvent(r, event);
    }
}

pub fn update(frame_delay: f32) void {
    // TODO
    _ = frame_delay;
}

pub fn render(width: f32, height: f32) void {
    if (root) |*r| {
        ui.render(r, width, height);
    }
}

fn createMenuButton(alloc: Allocator, comptime text: []const u8) UIComponent {
    const button_color: Color = .{ .r = 11, .g = 50, .b = 69 };
    var button = UIComponent.init(alloc);
    button.setHeight(60);
    button.setMarginInsets(.{ .bottom = 25 });
    button.background_color = button_color;
    button.content = .{
        .text = .{
            .content = .borrow(text),
            .align_h = .center,
            .align_v = .center,
            .color = .white,
        },
    };
    button.enableInput();
    button.on_mouse_enter = .{
        .context = undefined,
        .handler = struct {
            fn handler(comp: *UIComponent, _: sdl.events.MouseMotion, _: *anyopaque) void {
                var hover_color = button_color;
                hover_color.a = 100;
                comp.background_color = hover_color;
            }
        }.handler,
    };
    button.on_mouse_exit = .{
        .context = undefined,
        .handler = struct {
            fn handler(comp: *UIComponent, _: sdl.events.MouseMotion, _: *anyopaque) void {
                comp.background_color = button_color;
            }
        }.handler,
    };
    return button;
}
