const sdl = @import("sdl3");
const std = @import("std");

const input = @import("input.zig");
const Level1 = @import("level1/level1.zig").Level1;

const screen_width = 800;
const screen_height = 600;

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

    const window = try sdl.video.Window.init(
        "Death Perception",
        screen_width,
        screen_height,
        .{},
    );
    defer window.deinit();

    const alloc = std.heap.smp_allocator;
    input.handler = .init(alloc);
    input.handler = .init(alloc);
    defer input.handler.deinit();

    var display = try sdl.video.Display.getPrimaryDisplay();
    const modes = try display.getFullscreenModes(alloc);
    defer alloc.free(modes);

    const refresh_rate: usize = if (modes[0].refresh_rate) |rr| @intFromFloat(rr) else 60;

    var fps_capper = sdl.extras.FramerateCapper(f32){ .mode = .{ .limited = refresh_rate } };

    std.log.info("FPS set to {}", .{refresh_rate});

    var level = try Level1.init(alloc);
    defer level.deinit();

    const level_surface = try sdl.surface.Surface.init(
        screen_width,
        screen_height,
        .packed_xrgb_8_8_8_8,
    );

    const scale = 3.0;

    while (true) {
        // Delay to limit the FPS
        const dt = fps_capper.delay();

        while (sdl.events.poll()) |event| {
            switch (event) {
                .key_up, .key_down => |e| try input.handler.update(e),
                .quit, .terminating => break,
                else => {},
            }
        }

        if (input.handler.isPressed(.escape)) break;

        try level.update(dt);

        const surface = try window.getSurface();

        try level_surface.fillRect(null, surface.mapRgb(100, 100, 100));
        try level.render(level_surface);

        try level_surface.blitScaled(null, surface, .{
            .x = (screen_width * 0.5) * -(scale - 1.0),
            .y = (screen_height * 0.5) * -(scale - 1.0),
            .w = screen_width * scale,
            .h = screen_height * scale,
        }, .nearest);

        try window.updateSurface();
    }
}
