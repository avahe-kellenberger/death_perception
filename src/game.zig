const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;

const Camera = @import("camera.zig").Camera;
const Input = @import("input.zig");

const ui = @import("./ui/lib/component.zig");
const TestUI = @import("./ui/test.zig");
const MainMenu = @import("./ui/main_menu.zig");

const Vector = @import("math/vector.zig").Vector(f32);
const Color = @import("color.zig").Color;
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
    quit,

    test_ui,
};

pub var observed_fps: f32 = 0;

pub var alloc: Allocator = undefined;
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
        else => {
            // Others
        },
    }
}

pub fn update(frame_delay: f32) void {
    if (Input.isKeyPressed(.m)) {
        state = .main_menu;
    } else if (Input.isKeyPressed(.g)) {
        state = .in_game;
    }
    switch (state) {
        .test_ui => {
            TestUI.update(frame_delay);
        },
        .main_menu => {
            MainMenu.update(frame_delay);
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
        .quit => {},
    }
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
        .quit => {},
    }

    if (builtin.mode == .Debug) {
        var buf: [1 + std.fmt.count("{d}", .{std.math.maxInt(i32)})]u8 = undefined;
        const str = std.fmt.bufPrintZ(&buf, "{d}", .{
            @as(i32, @intFromFloat(@round(observed_fps))),
        }) catch unreachable;
        setRenderColor(Color.green);
        renderDebugText(.init(4, 4), str);
    }
}

pub fn setRenderColor(color: Color) void {
    renderer.setDrawColor(color.sdl()) catch unreachable;
}

pub fn loadTexture(path: [:0]const u8, mode: sdl.surface.ScaleMode) Texture {
    const tex = sdl.image.loadTexture(renderer, path) catch unreachable;
    tex.setScaleMode(mode) catch unreachable;
    return tex;
}

pub fn renderTexture(t: Texture, src: ?FRect, dest: FRect) void {
    if (camera.intersects(dest)) {
        var r = dest;
        r.x -= camera.viewport.x;
        r.y -= camera.viewport.y;
        renderer.renderTexture(t, src, r) catch unreachable;
    }
}

pub fn renderTextureRotated(
    t: Texture,
    src: ?FRect,
    dest: FRect,
    angle: f32,
    center: Vector,
    flip: sdl.surface.FlipMode,
) void {
    if (camera.intersects(dest)) {
        var r = dest;
        r.x -= camera.viewport.x;
        r.y -= camera.viewport.y;
        renderer.renderTextureRotated(t, src, r, angle, @bitCast(center), flip) catch unreachable;
    }
}

pub fn renderTextureAffine(
    t: Texture,
    src: ?FRect,
    top_left: Vector,
    top_right: Vector,
    bottom_left: Vector,
) void {
    const x = @min(top_left.x, bottom_left.x);
    const y = @min(top_left.y, top_right.y);
    const dest: FRect = .{
        .x = x,
        .y = y,
        .w = top_right.x - x,
        .h = bottom_left.y - y,
    };
    if (camera.intersects(dest)) {
        const viewportLoc = camera.viewportLoc();
        renderer.renderTextureAffine(
            t,
            src,
            @bitCast(top_left.subtract(viewportLoc)),
            @bitCast(top_right.subtract(viewportLoc)),
            @bitCast(bottom_left.subtract(viewportLoc)),
        ) catch unreachable;
    }
}

pub fn renderTextureByCorners(
    t: Texture,
    top_left: Vector,
    top_right: Vector,
    bottom_left: Vector,
    bottom_right: Vector,
    flip_horizontal: bool,
    flip_vertical: bool,
) void {
    const x: f32 = @min(top_left.x, top_right.x, bottom_left.x, bottom_right.x);
    const y: f32 = @min(top_left.y, top_right.y, bottom_left.y, bottom_right.y);
    const max_x: f32 = @max(top_left.x, top_right.x, bottom_left.x, bottom_right.x);
    const max_y: f32 = @max(top_left.y, top_right.y, bottom_left.y, bottom_right.y);
    const dest: FRect = .{
        .x = x,
        .y = y,
        .w = max_x - x,
        .h = max_y - y,
    };
    if (!camera.intersects(dest)) return;

    var tl = top_left;
    var tr = top_right;
    var bl = bottom_left;
    var br = bottom_right;

    if (flip_horizontal) {
        var tmp = tr;
        tr = tl;
        tl = tmp;

        tmp = br;
        br = bl;
        bl = tmp;
    }

    if (flip_vertical) {
        var tmp = tl;
        tl = bl;
        bl = tmp;

        tmp = tr;
        tr = br;
        br = tmp;
    }

    const verts: []const sdl.render.Vertex = &.{
        .{
            .position = @bitCast(tl.subtract(camera.viewportLoc())),
            .color = .{ .r = 1.0, .b = 1.0, .g = 1.0, .a = 1.0 },
            .tex_coord = .{ .x = 0, .y = 0.0 },
        },
        .{
            .position = @bitCast(tr.subtract(camera.viewportLoc())),
            .color = .{ .r = 1.0, .b = 1.0, .g = 1.0, .a = 1.0 },
            .tex_coord = .{ .x = 1.0, .y = 0.0 },
        },
        .{
            .position = @bitCast(br.subtract(camera.viewportLoc())),
            .color = .{ .r = 1.0, .b = 1.0, .g = 1.0, .a = 1.0 },
            .tex_coord = .{ .x = 1.0, .y = 1.0 },
        },
        .{
            .position = @bitCast(bl.subtract(camera.viewportLoc())),
            .color = .{ .r = 1.0, .b = 1.0, .g = 1.0, .a = 1.0 },
            .tex_coord = .{ .x = 0, .y = 1.0 },
        },
    };

    renderer.renderGeometry(t, verts, &.{ 3, 1, 0, 2, 1, 3 }) catch unreachable;
}

pub fn fillRect(dest: FRect, color: Color) void {
    if (camera.intersects(dest)) if (camera.getScale()) |_| {
        var r = dest;
        r.x -= camera.viewport.x;
        r.y -= camera.viewport.y;

        renderer.setDrawColor(color.sdl()) catch unreachable;
        renderer.renderFillRect(r) catch unreachable;
    };
}

pub fn renderDebugText(top_left: Vector, str: [:0]const u8) void {
    renderer.renderDebugText(@bitCast(top_left), str) catch unreachable;
}

pub fn renderDebugTextInGame(top_left: Vector, str: [:0]const u8) void {
    renderer.renderDebugText(@bitCast(top_left.subtract(camera.viewportLoc())), str) catch unreachable;
}
