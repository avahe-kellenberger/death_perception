const sdl = @import("sdl3");
const std = @import("std");

const Level1 = @import("level1/level1.zig").Level1;
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

    const foo = try sdl.render.Renderer.initWithWindow(
        "Death Perception",
        screen_width,
        screen_height,
        .{},
    );

    const renderer = foo.renderer;
    const window = foo.window;

    const scale = 3.0;
    try renderer.setScale(scale, scale);

    const alloc = std.heap.smp_allocator;

    var display = try sdl.video.Display.getPrimaryDisplay();
    const modes = try display.getFullscreenModes(alloc);
    defer alloc.free(modes);

    const refresh_rate: usize = if (modes[0].refresh_rate) |rr| @intFromFloat(rr) else 60;
    const frame_delay: f32 = 1.0 / @as(f32, @floatFromInt(refresh_rate));

    var fps_capper = sdl.extras.FramerateCapper(f32){ .mode = .{ .limited = refresh_rate } };

    std.log.info("FPS set to {}", .{refresh_rate});

    var camera = try Camera.init(window);

    var level = try Level1.init(alloc, renderer);
    defer level.deinit();

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
                    camera.setViewportSize(e.width, e.height);
                },
                else => {},
            }
        }

        if (!running or Input.isPressed(.escape)) break;

        try level.update(frame_delay);
        try level.render(renderer, &camera);

        try renderer.present();
    }
}

test {
    // Required for `zig build test` to find all tests in src
    std.testing.refAllDecls(@This());
}
