// UI to join an existing game lobby

const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");

const Game = @import("../game.zig");

const ui = @import("./lib/component.zig");
const UIComponent = ui.Component;

const Button = @import("./components/button.zig").Button;
const TextBox = @import("./components/textbox.zig").TextBox;

const Color = @import("../color.zig").Color;
const Input = @import("../input.zig");
const t = @import("./lib/content/sprite.zig").SpriteCoord.xy;
const Spritesheet = @import("../spritesheet.zig").Spritesheet;

const PORT = @import("../net/server.zig").PORT;
const NetworkSession = @import("../net/session.zig");

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
                    &(.{t(4, 3)} ** 3 ++ .{t(4, 2)} ++ .{t(4, 3)} ** 3 ++ .{t(4, 2)} ++ .{t(4, 3)} ** 3),
                    &(.{t(4, 3)} ** 11),
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

    var sub_title = UIComponent.init();
    sub_title.setHeight(100);
    sub_title.content = .{
        .text = .{
            .string = .borrow("Lobby"),
            .align_h = .center,
            .align_v = .start,
            .font = .{
                .size = 80,
                .outline = .{
                    .color = .black,
                    .size = 2,
                    .align_h = .center,
                    .align_v = .center,
                },
            },
            .color = .{ .r = 200, .g = 200, .b = 200 },
        },
    };
    foreground.add(sub_title);

    var lobby = UIComponent.init();
    lobby.setStackDirection(.vertical);
    lobby.background_color = .blue;

    foreground.add(lobby);

    var buttons = UIComponent.init();
    buttons.setStackDirection(.horizontal);
    buttons.setMarginInsets(.{ .top = 50 });
    buttons.setHeight(60);

    var multiplayer_button = Button("Connect");
    multiplayer_button.setWidth(350);
    multiplayer_button.on_mouse_button = .{
        .handler = struct {
            fn handler(comp: *UIComponent, event: sdl.events.MouseButton, _: ui.EventContext) void {
                if (event.button == .left and event.down) {
                    if (NetworkSession.isActive()) {
                        NetworkSession.stop();
                        comp.content.text.setStr("Connect");
                    } else if (NetworkSession.start("127.0.0.1", PORT)) {
                        comp.content.text.setStr("Disconnect");
                    } else {
                        comp.content.text.setStr("Uh oh!");
                    }
                }
            }
        }.handler,
    };
    buttons.add(multiplayer_button);

    var ip_box = TextBox();
    ip_box.setMarginInsets(.{ .left = 20 });
    buttons.add(ip_box);

    buttons.add(UIComponent.init());

    var start_button = Button("Start!");
    start_button.setWidth(250);
    start_button.on_mouse_button = .{
        .handler = struct {
            fn handler(_: *UIComponent, event: sdl.events.MouseButton, _: ui.EventContext) void {
                if (event.button == .left and event.down) {
                    Game.state = .in_game;
                }
            }
        }.handler,
    };
    buttons.add(start_button);

    foreground.add(buttons);

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
