// Main menu UI when the game launches

const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");

const Game = @import("../game.zig");

const ui = @import("./lib/component.zig");
const UIComponent = ui.Component;

const Button = @import("./components/button.zig").Button;

const Color = @import("../color.zig").Color;
const Input = @import("../input.zig");
const t = @import("./lib/content/sprite.zig").SpriteCoord.xy;
const Spritesheet = @import("../spritesheet.zig").Spritesheet;

var root: ui.Root = .{};

var background_texture: ?sdl.render.Texture = null;

pub fn init() void {
    deinit();

    const new_background_texture = Game.loadTexture("./assets/tilemap_packed.png", .nearest);
    background_texture = new_background_texture;
    const background_sheet = Spritesheet.init(new_background_texture, 12, 11);

    var background = UIComponent.init();
    background.setStackDirection(.overlap);
    background.content = .{
        .sprite = .{
            .sheet = background_sheet,
            .mode = .{
                .tiled = .clone(&.{
                    &(.{t(4, 3)} ** 11),
                    &(.{t(4, 3)} ** 11),
                    &(.{t(4, 3)} ** 4 ++ .{ t(5, 2), t(9, 3), t(5, 2) } ++ .{t(4, 3)} ** 4),
                    &(.{t(2, 4)} ** 11),
                }),
            },
            .scale = .init(16, 13),
            .align_h = .center,
        },
    };

    var background_filter = UIComponent.init();
    background_filter.background_color = .{ .r = 50, .g = 10, .b = 10, .a = 150 };
    background.add(background_filter);

    var foreground = UIComponent.init();
    foreground.setHorizontalAlignment(.center);
    foreground.setPadding(50);

    var title = UIComponent.init();
    title.setMarginInsets(.{ .top = 50 });
    title.setHeight(100);
    title.content = .{
        .text = .{
            .string = .borrow("Death Perception"),
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

    var menu = UIComponent.init();
    menu.setStackDirection(.vertical);
    menu.setMargin(100);
    menu.setWidth(250);

    var new_game_button = MenuButton("New Game");
    new_game_button.on_mouse_button = .{
        .handler = struct {
            fn handler(_: *UIComponent, _: sdl.events.MouseButton, _: ui.EventContext) void {
                // TODO should animate going into the door in the background
                Game.state = .lobby;
            }
        }.handler,
    };
    menu.add(new_game_button);

    var load_game_button = MenuButton("Load Game");
    load_game_button.on_mouse_button = .{
        .handler = struct {
            fn handler(_: *UIComponent, _: sdl.events.MouseButton, _: ui.EventContext) void {
                // TODO should animate going into the door in the background
            }
        }.handler,
    };
    menu.add(load_game_button);

    var join_game_button = MenuButton("Join Game");
    join_game_button.on_mouse_button = .{
        .handler = struct {
            fn handler(_: *UIComponent, _: sdl.events.MouseButton, _: ui.EventContext) void {
                // TODO should animate going into the door in the background
                Game.state = .join_game;
            }
        }.handler,
    };
    menu.add(join_game_button);

    var settings_button = MenuButton("Settings");
    settings_button.on_mouse_button = .{
        .handler = struct {
            fn handler(_: *UIComponent, _: sdl.events.MouseButton, _: ui.EventContext) void {
                // TODO display main menu settings
            }
        }.handler,
    };
    menu.add(settings_button);

    var quit_button = MenuButton("Quit");
    quit_button.on_mouse_button = .{
        .handler = struct {
            fn handler(_: *UIComponent, _: sdl.events.MouseButton, _: ui.EventContext) void {
                Game.state = .quit;
            }
        }.handler,
    };
    menu.add(quit_button);

    foreground.add(menu);

    var r = UIComponent.init();
    r.setStackDirection(.overlap);
    r.add(background);
    r.add(foreground);

    root.set(r);
}

pub fn deinit() void {
    root.deinit();
    if (background_texture) |*bs| {
        bs.deinit();
        background_texture = null;
    }
}

pub fn input(event: sdl.events.Event) void {
    root.handleInputEvent(event);
}

pub fn update(frame_delay: f32) void {
    root.update(frame_delay);
}

pub fn render(width: f32, height: f32) void {
    root.render(width, height);
}

fn MenuButton(comptime text: []const u8) UIComponent {
    var button = Button(text);
    button.setMarginInsets(.{ .bottom = 25 });
    return button;
}
