const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;
const FPoint = sdl.rect.FPoint;

const Camera = @import("camera.zig").Camera;
const Input = @import("input.zig");

const syncToClients = @import("./net/client.zig").syncToClients;

const ui = @import("./ui/lib/component.zig");
const TestUI = @import("./ui/test.zig");
const MainMenu = @import("./ui/main_menu.zig");
const Lobby = @import("./ui/lobby.zig");
const JoinGame = @import("./ui/join_game.zig");

const Level1 = @import("./levels/level1.zig").Level1;

pub const GameState = enum {
    main_menu,
    lobby,
    load_game,
    join_game,
    settings,
    in_game,
    paused,
    paused_settings,
    game_over,
    quit,

    test_ui,
};

pub var alloc: Allocator = undefined;
pub var mutex: std.Thread.Mutex = .{};
pub var state: GameState = .main_menu;
pub var renderer: Renderer = undefined;
pub var camera: Camera = undefined;
pub var bg_color: sdl.pixels.Color = .{};

pub const tile_size: f32 = 16.0;

var level: Level1 = undefined;

pub fn init(_alloc: Allocator, _renderer: Renderer, _camera: Camera) void {
    alloc = _alloc;
    renderer = _renderer;
    camera = _camera;

    MainMenu.init();
    Lobby.init();
    JoinGame.init();

    level = Level1.init();
    // TODO
}

pub fn deinit() void {
    level.deinit();
    MainMenu.deinit();
}

pub fn input(event: sdl.events.Event) void {
    switch (state) {
        .test_ui => TestUI.input(event),
        .main_menu => MainMenu.input(event),
        .lobby => Lobby.input(event),
        .join_game => JoinGame.input(event),
        else => {
            // Others
        },
    }
}

pub fn update(frame_delay: f32) void {
    switch (state) {
        .test_ui => {
            TestUI.update(frame_delay);
        },
        .main_menu => {
            MainMenu.update(frame_delay);
        },
        .lobby => {
            Lobby.update(frame_delay);
        },
        .load_game => {
            // TODO
        },
        .join_game => {
            JoinGame.update(frame_delay);
        },
        .settings => {
            // TODO
        },
        .in_game => {
            level.update(frame_delay);
        },
        .paused => {
            // TODO
        },
        .paused_settings => {
            // TODO
        },
        .game_over => {
            // TODO
        },
        .quit => {},
    }

    // Sync game state to connected clients
    syncToClients();
}

pub fn render() void {
    renderer.setDrawBlendMode(.blend) catch unreachable;
    renderer.setDrawColor(bg_color) catch unreachable;
    renderer.clear() catch unreachable;

    switch (state) {
        .test_ui => {
            TestUI.render(camera.size.x, camera.size.y);
        },
        .main_menu => {
            MainMenu.render(camera.size.x, camera.size.y);
        },
        .lobby => {
            Lobby.render(camera.size.x, camera.size.y);
        },
        .load_game => {
            // TODO
        },
        .join_game => {
            JoinGame.render(camera.size.x, camera.size.y);
        },
        .settings => {
            // TODO
        },
        .in_game => {
            if (camera.getScale()) |scale| {
                renderer.setScale(scale, scale) catch unreachable;

                level.render();

                renderer.setScale(1, 1) catch unreachable;
            }
        },
        .paused => {
            // TODO
        },
        .paused_settings => {
            // TODO
        },
        .game_over => {
            // TODO
        },
        .quit => {},
    }
}

pub fn loadTexture(path: [:0]const u8, mode: sdl.surface.ScaleMode) Texture {
    const tex = sdl.image.loadTexture(renderer, path) catch unreachable;
    tex.setScaleMode(mode) catch unreachable;
    return tex;
}

pub fn renderTexture(t: Texture, src: ?FRect, dst: FRect) void {
    if (camera.intersects(dst)) {
        var r = dst;
        r.x -= camera.viewport.x;
        r.y -= camera.viewport.y;

        renderer.renderTexture(t, src, r) catch unreachable;
    }
}

pub fn fillRect(dst: FRect, color: sdl.pixels.Color) void {
    if (camera.intersects(dst)) if (camera.getScale()) |_| {
        var r = dst;
        r.x -= camera.viewport.x;
        r.y -= camera.viewport.y;

        renderer.setDrawColor(color) catch unreachable;
        renderer.renderFillRect(r) catch unreachable;
    };
}
