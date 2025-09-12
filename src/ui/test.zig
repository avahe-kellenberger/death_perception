// Testing UI

const sdl = @import("sdl3");

const Game = @import("../game.zig");
const ui = @import("./lib/component.zig");
const UIComponent = ui.Component;

const Input = @import("../input.zig");

var root: ?UIComponent = null;
var fit: bool = false;

pub fn init() void {
    deinit();

    var top_left = UIComponent.init();
    top_left.setMarginInsets(.{ .right = 50 });
    top_left.setWidth(200);
    top_left.setHeight(200);
    top_left.background_color = .{
        .r = 255,
    };
    top_left.content = .{
        .text = .{
            .content = .borrow("Top left"),
            .align_h = .start,
            .align_v = .start,
            .fit = fit,
        },
    };

    var top_center = UIComponent.init();
    top_center.setMarginInsets(.{ .right = 50 });
    top_center.setWidth(200);
    top_center.setHeight(200);
    top_center.background_color = .{
        .g = 255,
    };
    top_center.content = .{
        .text = .{
            .content = .borrow("Top center"),
            .align_h = .center,
            .align_v = .start,
            .fit = fit,
        },
    };

    var top_right = UIComponent.init();
    top_right.setWidth(200);
    top_right.setHeight(200);
    top_right.background_color = .{
        .r = 255,
    };
    top_right.content = .{
        .text = .{
            .content = .borrow("Top right"),
            .align_h = .end,
            .align_v = .start,
            .fit = fit,
        },
    };

    var center_left = UIComponent.init();
    center_left.setMarginInsets(.{ .right = 50 });
    center_left.setWidth(200);
    center_left.setHeight(200);
    center_left.background_color = .{
        .g = 255,
    };
    center_left.content = .{
        .text = .{
            .content = .borrow("Center left"),
            .align_h = .start,
            .align_v = .center,
            .fit = fit,
        },
    };

    var center_center = UIComponent.init();
    center_center.setMarginInsets(.{ .right = 50 });
    center_center.setPadding(10);
    center_center.setWidth(200);
    center_center.setHeight(200);
    center_center.background_color = .{
        .r = 255,
    };
    center_center.content = .{
        .image = .{
            .file_path = "./assets/images/player.png",
            .align_h = .start,
            .align_v = .center,
            .fit = .none,
            .scale = 6.0,
        },
    };
    center_center.enableInput();
    center_center.on_mouse_enter = .{
        .context = undefined,
        .handler = struct {
            fn handler(comp: *UIComponent, _: sdl.events.MouseMotion, _: *anyopaque) void {
                comp.background_color = .{ .b = 255 };
            }
        }.handler,
    };
    center_center.on_mouse_exit = .{
        .context = undefined,
        .handler = struct {
            fn handler(comp: *UIComponent, _: sdl.events.MouseMotion, _: *anyopaque) void {
                comp.background_color = .{ .r = 255 };
            }
        }.handler,
    };

    var center_right = UIComponent.init();
    center_right.setWidth(200);
    center_right.setHeight(200);
    center_right.background_color = .{
        .g = 255,
    };
    center_right.content = .{
        .text = .{
            .content = .borrow("Center right"),
            .align_h = .end,
            .align_v = .center,
            .fit = fit,
        },
    };

    var bottom_left = UIComponent.init();
    bottom_left.setMarginInsets(.{ .right = 50 });
    bottom_left.setWidth(200);
    bottom_left.setHeight(200);
    bottom_left.background_color = .{
        .r = 255,
    };
    bottom_left.content = .{
        .text = .{
            .content = .borrow("Bottom left"),
            .align_h = .start,
            .align_v = .end,
            .fit = fit,
        },
    };

    var bottom_center = UIComponent.init();
    bottom_center.setMarginInsets(.{ .right = 50 });
    bottom_center.setWidth(200);
    bottom_center.setHeight(200);
    bottom_center.background_color = .{
        .g = 255,
    };
    bottom_center.content = .{
        .text = .{
            .content = .borrow("Bottom center"),
            .align_h = .center,
            .align_v = .end,
            .fit = fit,
        },
    };

    var bottom_right = UIComponent.init();
    bottom_right.setWidth(200);
    bottom_right.setHeight(200);
    bottom_right.background_color = .{
        .r = 255,
    };
    bottom_right.content = .{
        .text = .{
            .content = .borrow("Bottom right"),
            .align_h = .end,
            .align_v = .end,
            .fit = fit,
        },
    };

    var top_row = UIComponent.init();
    top_row.setStackDirection(.horizontal);
    top_row.setHorizontalAlignment(.center);
    top_row.setMarginInsets(.{ .bottom = 50 });
    top_row.setHeight(200);
    top_row.add(top_left);
    top_row.add(top_center);
    top_row.add(top_right);

    var center_row = UIComponent.init();
    center_row.setStackDirection(.horizontal);
    center_row.setHorizontalAlignment(.center);
    center_row.setMarginInsets(.{ .bottom = 50 });
    center_row.setHeight(200);
    center_row.add(center_left);
    center_row.add(center_center);
    center_row.add(center_right);

    var bottom_row = UIComponent.init();
    bottom_row.setStackDirection(.horizontal);
    bottom_row.setHorizontalAlignment(.center);
    bottom_row.setHeight(200);
    bottom_row.add(bottom_left);
    bottom_row.add(bottom_center);
    bottom_row.add(bottom_right);

    var box = UIComponent.init();
    box.setStackDirection(.vertical);
    box.setHorizontalAlignment(.center);
    box.setVerticalAlignment(.center);
    box.background_color = .{
        .r = 50,
        .g = 50,
        .b = 50,
    };
    box.add(top_row);
    box.add(center_row);
    box.add(bottom_row);

    var r = UIComponent.init();
    r.setPadding(50);
    r.add(box);

    root = r;
}

pub fn deinit() void {
    if (root) |*r| {
        r.deinit();
        root = null;
    }
}

pub fn input(event: sdl.events.Event) void {
    if (root) |*r| {
        ui.handleInputEvent(r, event);
    }
}

pub fn update(frame_delay: f32) void {
    // TODO
    _ = frame_delay;

    if (Input.isKeyPressed(.f)) {
        fit = !fit;
        init();
    }
}

pub fn render(width: f32, height: f32) void {
    if (root) |*r| {
        ui.render(r, width, height);
    }
}
