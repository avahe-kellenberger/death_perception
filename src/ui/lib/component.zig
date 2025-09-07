const std = @import("std");
const Allocator = std.mem.Allocator;

const Game = @import("../../game.zig");
const Color = @import("../../color.zig").Color;
const Alignment = @import("./alignment.zig").Alignment;
const StackDirection = @import("./stack.zig").StackDirection;

pub const ComponentID = u32;
const ChildrenMap = std.array_hash_map.AutoArrayHashMapUnmanaged(ComponentID, Component);

pub const SizeKind = enum {
    pixel,
    ratio,
};

pub const Size = union(SizeKind) {
    const Self = @This();

    pixel: f32,
    ratio: f32, // 0.0 to 1.0, inclusive

    pub fn equals(self: Self, other: Self) bool {
        if (self == .pixel and other == .pixel) {
            return self.pixel == other.pixel;
        } else if (self == .ratio and other == .ratio) {
            return self.ratio == other.ratio;
        } else {
            return false;
        }
    }

    pub fn pixelSize(self: Self, available_parent_size: f32) f32 {
        return switch (self) {
            .pixel => |p| p,
            .ratio => |r| r * available_parent_size,
        };
    }
};

pub const Insets = struct {
    const Self = @This();

    left: f32 = 0,
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,

    pub const zero: Self = .{};
    pub const inf: Self = .{
        .left = -std.math.inf(f32),
        .top = -std.math.inf(f32),
        .right = std.math.inf(f32),
        .bottom = std.math.inf(f32),
    };

    pub fn width(self: *const Self) f32 {
        return self.right - self.left;
    }

    pub fn height(self: *const Self) f32 {
        return self.bottom - self.top;
    }
};

const ValidationStatus = enum {
    valid,
    invalid,
    invalid_child,
};

/// Zero ID can be used as an invalid sentinel.
var next_id: ComponentID = 1;

pub const Component = struct {
    const Self = @This();

    id: u32,
    alloc: Allocator,

    // Top-down design: child components cannot cause their parent components to resize.
    parent: ?*Component = null,
    children: ChildrenMap = .empty,
    visible: bool = true,
    enabled: bool = true,

    // If width or height are == 0, fill out all space available in layout.
    width: Size = .{ .pixel = 0 },
    height: Size = .{ .pixel = 0 },
    margin: Insets = .zero,
    padding: Insets = .zero,
    alignHorizontal: Alignment = .start,
    alignVertical: Alignment = .start,
    stackDirection: StackDirection = .vertical,
    layoutStatus: ValidationStatus = .invalid,

    // Bounds including padding, excluding margin.
    bounds: Insets = .zero,
    background_color: Color = .transparent,
    border_width: f32 = 0.0,
    border_color: Color = .black,

    pub fn init(alloc: Allocator) Self {
        // Dummy defaults that get overridden.
        var result: Self = .{ .id = 0, .alloc = alloc };
        result._init(alloc);
        return result;
    }

    pub fn allocInit(alloc: Allocator) *Self {
        var result = alloc.create(Self) catch unreachable;
        result._init(alloc);
        return result;
    }

    fn _init(self: *Self, alloc: Allocator) void {
        defer next_id += 1;
        self.id = next_id;
        self.alloc = alloc;
    }

    pub fn deinit(self: *Self) void {
        while (self.children.pop()) |kv| {
            kv.value.deinit();
        }
        self.children.deinit(self.alloc);
    }

    /// Add a child component to this parent component.
    /// Ownership of the component is transferred to the parent component.
    pub fn add(self: *Self, child: Component) void {
        var new_child = child;
        new_child.parent = self;
        self.children.put(self.alloc, new_child.id, new_child) catch unreachable;
        self.setLayoutStatus(.invalid);
    }

    /// Remove a child component from this parent component.
    pub fn remove(self: *Self, id: ComponentID) bool {
        if (self.fetchRemove(id)) |removed| {
            removed.deinit();
            return true;
        }
        return false;
    }

    /// Remove a child component from this parent component.
    /// Caller acquires ownership over removed child component.
    pub fn fetchRemove(self: *Self, id: ComponentID) ?Component {
        if (self.children.fetchOrderedRemove(id)) |removed| {
            self.setLayoutStatus(.invalid);
            return removed.value;
        }
        return null;
    }

    pub fn setLayoutStatus(self: *Self, new_layout_status: ValidationStatus) void {
        self.layoutStatus = new_layout_status;
        if (new_layout_status != .valid) {
            if (self.parent) |p| {
                if (p.layoutStatus == .valid) {
                    p.setLayoutStatus(.invalid_child);
                }
            }
        }
    }

    pub fn setWidth(self: *Self, new_width: anytype) void {
        if (self._setWidth(new_width)) {
            self.setLayoutStatus(.invalid);
        }
    }

    /// Returns true if the width value was changed.
    fn _setWidth(self: *Self, new_width: anytype) bool {
        switch (@TypeOf(new_width)) {
            Size => {
                if (self.width.equals(new_width)) {
                    return false;
                }
                self.width = new_width;
                return true;
            },
            else => |t| switch (@typeInfo(t)) {
                .float, .int, .comptime_float, .comptime_int => {
                    switch (self.width) {
                        .pixel => |p| {
                            if (new_width == p) {
                                return false;
                            }
                            self.width = .{ .pixel = new_width };
                        },
                        .ratio => {
                            self.width = .{ .pixel = new_width };
                        },
                    }
                    return true;
                },
                else => @compileError("Unsupported width type: " ++ @typeName(@TypeOf(new_width))),
            },
        }
    }

    pub fn setHeight(self: *Self, new_height: anytype) void {
        if (self._setHeight(new_height)) {
            self.setLayoutStatus(.invalid);
        }
    }

    fn _setHeight(self: *Self, new_height: anytype) bool {
        switch (@TypeOf(new_height)) {
            Size => {
                if (self.height.equals(new_height)) {
                    return false;
                }
                self.height = new_height;
                return true;
            },
            else => |t| switch (@typeInfo(t)) {
                .float, .int, .comptime_float, .comptime_int => {
                    switch (self.height) {
                        .pixel => |p| {
                            if (new_height == p) {
                                return false;
                            }
                            self.height = .{ .pixel = new_height };
                        },
                        .ratio => {
                            self.height = .{ .pixel = new_height };
                        },
                    }
                    return true;
                },
                else => @compileError("Unsupported height type: " ++ @typeName(@TypeOf(new_height))),
            },
        }
    }

    fn updateBounds(self: *Self, x: f32, y: f32, width: f32, height: f32) void {
        // Updates this component's bounds, and all children (deep).
        self.bounds.left = x;
        self.bounds.top = y;
        self.bounds.right = x + width;
        self.bounds.bottom = y + height;
        self.setLayoutStatus(.valid);

        self.updateChildrenBounds();
    }

    fn updateChildrenBounds(self: *Self) void {
        if (self.children.count() == 0) return;
        self.updateChildren(.vertical);
        self.updateChildren(.horizontal);
        for (self.children.values()) |*c| {
            c.updateChildrenBounds();
        }
    }

    fn updateChildren(self: *Self, comptime axis: StackDirection) void {
        const alignment = if (axis == .horizontal) self.alignHorizontal else self.alignVertical;
        alignment.process(self, axis);
        for (self.children.values()) |*c| {
            c.setLayoutStatus(.valid);
        }
    }

    pub fn preRender(self: *Self, _: Insets) void {
        if (self.background_color.a != 0) {
            Game.renderer.setDrawColor(.{
                .r = self.background_color.r,
                .g = self.background_color.g,
                .b = self.background_color.b,
                .a = self.background_color.a,
            }) catch unreachable;
            Game.renderer.renderFillRect(.{
                .x = self.bounds.left,
                .y = self.bounds.top,
                .w = self.bounds.right - self.bounds.left,
                .h = self.bounds.bottom - self.bounds.top,
            }) catch unreachable;
        }

        if (self.border_width > 0) {
            // Draw 4 filled rectangles to create the border
            Game.renderer.setDrawColor(.{
                .r = self.border_color.r,
                .g = self.border_color.g,
                .b = self.border_color.b,
                .a = self.border_color.a,
            }) catch unreachable;
            // TODO
        }
    }

    pub fn render(self: *Self, parent_bounds: Insets) void {
        if (!self.visible) return;

        if (self.bounds.left >= parent_bounds.right or
            self.bounds.top >= parent_bounds.bottom or
            self.bounds.width() <= 0 or self.bounds.height() <= 0)
        {
            // Prevents rendering outside parent_bounds.
            // Maybe can be optimized.
            return;
        }

        const clipped_render_bounds: Insets = .{
            .left = @max(parent_bounds.left, self.bounds.left),
            .top = @max(parent_bounds.top, self.bounds.top),
            .right = @min(parent_bounds.right, self.bounds.right),
            .bottom = @min(parent_bounds.bottom, self.bounds.bottom),
        };

        const floor_left: i32 = @intFromFloat(@floor(clipped_render_bounds.left));
        const floor_top: i32 = @intFromFloat(@floor(clipped_render_bounds.top));
        const ceil_right: i32 = @intFromFloat(@ceil(clipped_render_bounds.right));
        const ceil_bottom: i32 = @intFromFloat(@ceil(clipped_render_bounds.bottom));
        Game.renderer.setClipRect(.{
            .x = floor_left,
            .y = floor_top,
            .w = ceil_right - floor_left,
            .h = ceil_bottom - floor_top,
        }) catch unreachable;
        defer Game.renderer.setClipRect(null) catch unreachable;

        self.preRender(clipped_render_bounds);

        for (self.children.values()) |*child| {
            child.render(clipped_render_bounds);
        }

        self.postRender();
    }

    pub fn postRender(_: *Self) void {
        // No-op
    }
};

/// Render a root component to the screen
pub fn render(root: *Component, width: f32, height: f32) void {
    root.setWidth(width);
    root.setHeight(height);

    switch (root.layoutStatus) {
        .valid => {},
        .invalid, .invalid_child => {
            root.updateBounds(0, 0, width, height);
        },
    }

    root.render(Insets.inf);
}
