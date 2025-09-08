// Main menu UI when the game launches

const std = @import("std");
const Allocator = std.mem.Allocator;

const ui = @import("./lib/component.zig");
const UIComponent = ui.Component;

var root: ?UIComponent = null;

pub fn init(alloc: Allocator) void {
    var box = UIComponent.init(alloc);
    box.setStackDirection(.horizontal);
    box.setHorizontalAlignment(.center);
    box.setVerticalAlignment(.center);
    box.background_color = .{
        .r = 50,
        .g = 50,
        .b = 50,
    };

    var one = UIComponent.init(alloc);
    one.setMarginInsets(.{ .right = 50 });
    one.setWidth(200);
    one.setHeight(200);
    one.background_color = .{
        .r = 255,
    };
    box.add(one);

    var two = UIComponent.init(alloc);
    two.setMarginInsets(.{ .right = 50 });
    two.setWidth(200);
    two.setHeight(200);
    two.background_color = .{
        .g = 255,
    };
    box.add(two);

    var three = UIComponent.init(alloc);
    three.setWidth(200);
    three.setHeight(200);
    three.background_color = .{
        .b = 255,
    };
    box.add(three);

    var r = UIComponent.init(alloc);
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

pub fn render(width: f32, height: f32) void {
    if (root) |*r| {
        ui.render(r, width, height);
    }
}
