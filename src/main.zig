const sdl = @import("sdl3");
const std = @import("std");

const Game = @import("game.zig");
const Camera = @import("camera.zig").Camera;

const Input = @import("input.zig");

const random_mod = @import("random.zig");

const screen_width = 1600;
const screen_height = 900;

pub fn main() !void {
    defer sdl.shutdown();

    // Initialize SDL with subsystems you need here.

    const init_flags = sdl.InitFlags{
        .video = true,
        .joystick = true,
        .gamepad = true,
    };
    try sdl.init(init_flags);
    defer sdl.quit(init_flags);

    try sdl.net.init();
    defer sdl.net.quit();

    try sdl.ttf.init();
    defer sdl.ttf.quit();

    // End of SDL init

    const alloc = std.heap.smp_allocator;

    Input.init(alloc);
    defer Input.deinit();

    random_mod.init();

    const initResult = try sdl.render.Renderer.initWithWindow(
        "Death Perception",
        screen_width,
        screen_height,
        .{},
    );
    const renderer = initResult.renderer;
    const window = initResult.window;

    var display = try sdl.video.Display.getPrimaryDisplay();
    const modes = try display.getFullscreenModes(alloc);
    defer alloc.free(modes);

    const refresh_rate: usize = if (modes[0].refresh_rate) |rr| @intFromFloat(rr) else 60;

    var fps_capper = sdl.extras.FramerateCapper(f32){ .mode = .{ .limited = refresh_rate } };

    std.log.info("FPS set to {}", .{refresh_rate});

    const window_size = try window.getSizeInPixels();

    Game.init(
        alloc,
        renderer,
        Camera.init(.{ .x = 0, .y = 0 }, .{
            .x = @floatFromInt(window_size.width),
            .y = @floatFromInt(window_size.height),
        }),
    );
    defer Game.deinit();

    while (Game.state != .quit) {
        // Delay to limit the FPS
        const dt = fps_capper.delay();
        // std.log.err("{}", .{dt});
        // std.log.err("Real FPS: {}", .{fps_capper.getObservedFps()});

        Input.resetFrameSpecificState();
        while (sdl.events.poll()) |event| {
            switch (event) {
                .key_up, .key_down => try Input.update(event),
                .mouse_motion, .mouse_button_up, .mouse_button_down => {
                    try Input.update(event);
                    Game.input(event);
                },
                .quit, .terminating => Game.state = .quit,
                .window_pixel_size_changed => |e| {
                    Game.camera.setSize(@floatFromInt(e.width), @floatFromInt(e.height));
                },
                .mouse_wheel => |e| {
                    Game.camera.zoom(e.scroll_y * 0.05);
                },
                else => {},
            }
        }

        if (Game.state == .quit or Input.isKeyPressed(.escape)) break;

        Game.update(dt);
        Game.render();

        try renderer.present();
    }
}

test {
    // Required for `zig build test` to find all tests in src
    std.testing.refAllDecls(@This());
    // TODO: Why do I have to do this
    _ = @import("math/easings.zig");
    _ = @import("animation//animation.zig");
}
