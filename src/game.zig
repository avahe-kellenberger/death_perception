const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;
const FPoint = sdl.rect.FPoint;

const Camera = @import("camera.zig").Camera;
const Input = @import("input.zig");

const ui = @import("./ui/lib/component.zig");
const MainMenu = @import("./ui/main_menu.zig");

const Level1 = @import("./levels/level1.zig").Level1;

pub const GameState = enum {
    main_menu,
    lobby,
    join_game,
    settings,
    in_game,
    paused,
    paused_settings,
    game_over,
};

pub var state: GameState = .main_menu;
pub var renderer: Renderer = undefined;
pub var camera: Camera = undefined;
pub var bg_color: sdl.pixels.Color = .{};

var level: Level1 = undefined;

pub fn init(alloc: Allocator, _renderer: Renderer, _camera: Camera) void {
    renderer = _renderer;
    camera = _camera;

    MainMenu.init(alloc);

    level = Level1.init(alloc);
    // TODO
}

pub fn deinit() void {
    level.deinit();
    MainMenu.deinit();
}

pub fn update(frame_delay: f32) void {
    if (Input.isKeyPressed(.m)) {
        state = .main_menu;
    } else if (Input.isKeyPressed(.g)) {
        state = .in_game;
    }
    switch (state) {
        .main_menu => {
            // TODO
        },
        .lobby => {
            // TODO
        },
        .join_game => {
            // TODO
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
    }
}

pub fn render() void {
    renderer.setDrawColor(bg_color) catch unreachable;
    renderer.clear() catch unreachable;

    switch (state) {
        .main_menu => {
            MainMenu.render(camera.size.w, camera.size.h);
        },
        .lobby => {
            // TODO
        },
        .join_game => {
            // TODO
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

pub fn setBlendMode(mode: sdl.blend_mode.Mode) void {
    renderer.setDrawBlendMode(mode) catch unreachable;
}

pub fn resetBlendMode() void {
    renderer.setDrawBlendMode(.none) catch unreachable;
}
