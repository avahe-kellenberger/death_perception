const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;
const FPoint = sdl.rect.FPoint;

const Camera = @import("camera.zig").Camera;

const Level1 = @import("levels/level1.zig").Level1;

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

pub var state: GameState = .in_game;
pub var renderer: Renderer = undefined;
pub var camera: Camera = undefined;

var offset: FPoint = .{ .x = 0, .y = 0 };

var level: Level1 = undefined;

pub fn init(alloc: Allocator, _renderer: Renderer, _camera: Camera) void {
    renderer = _renderer;
    camera = _camera;

    level = Level1.init(alloc);
    // TODO
}

pub fn deinit() void {
    level.deinit();
}

pub fn update(frame_delay: f32) void {
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
            const relative_z = 1.0 - camera.z;
            if (relative_z <= 0) return;

            offset = .{
                .x = -1 * (camera.loc.x - camera.half_viewport_size.w * relative_z),
                .y = -1 * (camera.loc.y - camera.half_viewport_size.h * relative_z),
            };

            const inversedScalar = 1.0 / relative_z;
            renderer.setScale(inversedScalar, inversedScalar) catch unreachable;

            level.render();

            renderer.setScale(relative_z, relative_z) catch unreachable;
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

pub fn renderTexture(t: Texture, src: ?FRect, dst: ?*FRect) void {
    if (dst) |d| if (camera.intersects(d.*)) {
        // NOTE: I assume this is better than creating an entirely new rect,
        // but it is odd needing to pass in a pointer.
        d.x += offset.x;
        d.y += offset.y;

        renderer.renderTexture(t, src, d.*) catch unreachable;

        d.x -= offset.x;
        d.y -= offset.y;
    };
}
