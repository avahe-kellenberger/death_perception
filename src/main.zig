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

    Input.init(std.heap.smp_allocator);
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

    const alloc = std.heap.smp_allocator;

    var display = try sdl.video.Display.getPrimaryDisplay();
    const modes = try display.getFullscreenModes(alloc);
    defer alloc.free(modes);

    const refresh_rate: usize = if (modes[0].refresh_rate) |rr| @intFromFloat(rr) else 60;
    const frame_delay: f32 = 1.0 / @as(f32, @floatFromInt(refresh_rate));

    var fps_capper = sdl.extras.FramerateCapper(f32){ .mode = .{ .limited = refresh_rate } };

    std.log.info("FPS set to {}", .{refresh_rate});

    const window_size = try window.getSizeInPixels();

    Game.init(
        alloc,
        renderer,
        Camera.init(.{ .x = 0, .y = 0 }, .{
            .w = @floatFromInt(window_size.width),
            .h = @floatFromInt(window_size.height),
        }),
    );
    defer Game.deinit();

    var running = true;
    while (running) {
        // Delay to limit the FPS
        const dt = fps_capper.delay();
        std.log.err("{}", .{dt});
        std.log.err("Real FPS: {}", .{fps_capper.getObservedFps()});

        while (sdl.events.poll()) |event| {
            switch (event) {
                .key_up, .key_down => |e| try Input.update(e),
                .quit, .terminating => running = false,
                .window_pixel_size_changed => |e| {
                    Game.camera.setSize(@floatFromInt(e.width), @floatFromInt(e.height));
                },
                .mouse_wheel => |e| {
                    Game.camera.zoom(e.scroll_y * 0.05);
                },
                else => {},
            }
        }

        if (!running or Input.isPressed(.escape)) break;

        try renderer.clear();
        Game.update(frame_delay);
        Game.render();

        try renderer.present();
    }
}

test {
    // Required for `zig build test` to find all tests in src
    std.testing.refAllDecls(@This());
}
