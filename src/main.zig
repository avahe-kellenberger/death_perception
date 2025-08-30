const sdl = @import("sdl3");
const std = @import("std");

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

    var display = try sdl.video.Display.getPrimaryDisplay();
    const modes = try display.getFullscreenModes(alloc);
    defer alloc.free(modes);

    const refresh_rate: usize = if (modes[0].refresh_rate) |rr| @intFromFloat(rr) else 60;

    var fps_capper = sdl.extras.FramerateCapper(f32){ .mode = .{ .limited = refresh_rate } };

    std.log.info("FPS set to {}", .{refresh_rate});

    var level = try Level1.init(alloc);
    defer level.deinit();

    var running = true;
    while (running) {

        // Delay to limit the FPS, returned delta time not needed.
        const dt = fps_capper.delay();

        try level.update(dt);

        const surface = try window.getSurface();

        const level_surface = try sdl.surface.Surface.init(
            screen_width / 3,
            screen_height / 3,
            .packed_xrgb_8_8_8_8,
        );
        try level_surface.fillRect(null, surface.mapRgb(100, 100, 100));
        try level.render(level_surface);

        try level_surface.blitScaled(null, surface, null, .nearest);

        try surface.fillRect(.{
            .x = 400,
            .y = 300,
            .w = 1,
            .h = 1,
        }, .{ .value = 999999 });

        try window.updateSurface();

        while (sdl.events.poll()) |event| {
            switch (event) {
                .key_down => |e| {
                    if (e.key) |key| if (key == .escape) {
                        running = false;
                    };
                },
                .quit, .terminating => running = false,
                else => {},
            }
        }
    }
}
