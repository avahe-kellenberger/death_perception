const std = @import("std");
const Allocator = std.mem.Allocator;

const Game = @import("../../game.zig");
const Color = @import("../../color.zig").Color;
const Alignment = @import("./alignment.zig").Alignment;
const ComponentContent = @import("./content.zig").ComponentContent;

const types = @import("./types.zig");
const StackDirection = types.StackDirection;
const Insets = types.Insets;
const Size = types.Size;

pub const ComponentID = u32;
const ChildrenMap = std.array_hash_map.AutoArrayHashMapUnmanaged(ComponentID, Component);

const ValidationStatus = enum {
    valid,
    invalid,
    invalid_child,
};

/// Zero ID can be used as an invalid sentinel.
var next_id: ComponentID = 1;

pub const Component = struct {
    const Self = @This();

    _id: u32,
    _alloc: Allocator,

    // Top-down design: child components cannot cause their parent components to resize.
    _parent: ?*Component = null,
    _children: ChildrenMap = .empty,
    _visible: bool = true,
    _enabled: bool = true,

    // If width or height are == 0, fill out all space available in layout.
    _width: Size = .{ .pixel = 0 },
    _height: Size = .{ .pixel = 0 },
    _margin: Insets = .zero,
    _padding: Insets = .zero,
    _border_width: f32 = 0.0,
    _align_h: Alignment = .start,
    _align_v: Alignment = .start,
    _stack_direction: StackDirection = .vertical,
    _layout_status: ValidationStatus = .invalid,
    _bounds: Insets = .zero, // Bounds including padding, excluding margin.

    // These fields can be set directly without impacting layout.
    background_color: Color = .transparent,
    border_color: Color = .black,
    content: ComponentContent = .none,

    pub fn init(alloc: Allocator) Self {
        defer next_id += 1;
        return .{
            ._id = next_id,
            ._alloc = alloc,
        };
    }

    pub fn deinit(self: *Self) void {
        while (self._children.pop()) |kv| {
            var child = kv.value;
            child.deinit();
        }
        self._children.deinit(self._alloc);
    }

    /// Add a child component to this parent component.
    /// Ownership of the component is transferred to the parent component.
    pub fn add(self: *Self, child: Component) void {
        var new_child = child;
        new_child._parent = self;
        self._children.put(self._alloc, new_child._id, new_child) catch unreachable;
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
        if (self._children.fetchOrderedRemove(id)) |removed| {
            self.setLayoutStatus(.invalid);
            return removed.value;
        }
        return null;
    }

    pub fn setLayoutStatus(self: *Self, new_layout_status: ValidationStatus) void {
        self._layout_status = new_layout_status;
        if (new_layout_status != .valid) {
            if (self._parent) |p| {
                if (p._layout_status == .valid) {
                    p.setLayoutStatus(.invalid_child);
                }
            }
        }
    }

    pub fn setVisible(self: *Self, visible: bool) void {
        if (self._visible != visible) {
            self._visible = visible;
            self.setLayoutStatus(.invalid);
        }
    }

    pub fn setEnabled(self: *Self, enabled: bool) void {
        if (self._enabled != enabled) {
            self._enabled = enabled;
            self.setLayoutStatus(.invalid);
        }
    }

    pub fn setStackDirection(self: *Self, direction: StackDirection) void {
        if (self._stack_direction != direction) {
            self._stack_direction = direction;
            self.setLayoutStatus(.invalid);
        }
    }

    pub fn setHorizontalAlignment(self: *Self, alignment: Alignment) void {
        if (self._align_h != alignment) {
            self._align_h = alignment;
            self.setLayoutStatus(.invalid);
        }
    }

    pub fn setVerticalAlignment(self: *Self, alignment: Alignment) void {
        if (self._align_v != alignment) {
            self._align_v = alignment;
            self.setLayoutStatus(.invalid);
        }
    }

    pub fn setWidth(self: *Self, new_width: f32) void {
        self._setWidth(new_width);
    }

    pub fn setWidthRatio(self: *Self, new_width_ratio: f32) void {
        self._setWidth(Size{ .ratio = new_width_ratio });
    }

    /// Returns true if the width value was changed.
    fn _setWidth(self: *Self, new_width: anytype) void {
        switch (@TypeOf(new_width)) {
            Size => {
                if (self._width.equals(new_width)) {
                    return;
                }
                self._width = new_width;
            },
            else => |t| switch (@typeInfo(t)) {
                .float, .int, .comptime_float, .comptime_int => {
                    switch (self._width) {
                        .pixel => |p| {
                            if (new_width == p) {
                                return;
                            }
                            self._width = .{ .pixel = new_width };
                        },
                        .ratio => {
                            self._width = .{ .pixel = new_width };
                        },
                    }
                },
                else => @compileError("Unsupported width type: " ++ @typeName(@TypeOf(new_width))),
            },
        }
        self.setLayoutStatus(.invalid);
    }

    pub fn setHeight(self: *Self, new_height: f32) void {
        self._setHeight(new_height);
    }

    pub fn setHeightRatio(self: *Self, new_height_ratio: f32) void {
        self._setHeight(Size{ .ratio = new_height_ratio });
    }

    fn _setHeight(self: *Self, new_height: anytype) void {
        switch (@TypeOf(new_height)) {
            Size => {
                if (self._height.equals(new_height)) {
                    return;
                }
                self._height = new_height;
            },
            else => |t| switch (@typeInfo(t)) {
                .float, .int, .comptime_float, .comptime_int => {
                    switch (self._height) {
                        .pixel => |p| {
                            if (new_height == p) {
                                return;
                            }
                            self._height = .{ .pixel = new_height };
                        },
                        .ratio => {
                            self._height = .{ .pixel = new_height };
                        },
                    }
                },
                else => @compileError("Unsupported height type: " ++ @typeName(@TypeOf(new_height))),
            },
        }
        self.setLayoutStatus(.invalid);
    }

    pub fn setBorderWidth(self: *Self, new_border_width: f32) void {
        if (self._border_width != new_border_width) {
            self._border_width = new_border_width;
            self.setLayoutStatus(.invalid);
        }
    }

    pub fn setMargin(self: *Self, new_margin: f32) void {
        self._setMargin(new_margin);
    }

    pub fn setMarginInsets(self: *Self, new_margin_insets: Insets) void {
        self._setMargin(new_margin_insets);
    }

    fn _setMargin(self: *Self, new_margin: anytype) void {
        const new_insets: Insets = switch (@TypeOf(new_margin)) {
            Insets => new_margin,
            else => |t| switch (@typeInfo(t)) {
                .float, .int, .comptime_float, .comptime_int => .{
                    .left = new_margin,
                    .top = new_margin,
                    .right = new_margin,
                    .bottom = new_margin,
                },
                else => @compileError("Unsupported margin type: " ++ @typeName(@TypeOf(new_margin))),
            },
        };
        if (!self._margin.equals(&new_insets)) {
            self._margin = new_insets;
            self.setLayoutStatus(.invalid);
        }
    }

    pub fn setPadding(self: *Self, new_padding: f32) void {
        self._setPadding(new_padding);
    }

    pub fn setPaddingInsets(self: *Self, new_padding_insets: Insets) void {
        self._setPadding(new_padding_insets);
    }

    fn _setPadding(self: *Self, new_padding: anytype) void {
        const new_insets: Insets = switch (@TypeOf(new_padding)) {
            Insets => new_padding,
            else => |t| switch (@typeInfo(t)) {
                .float, .int, .comptime_float, .comptime_int => .{
                    .left = new_padding,
                    .top = new_padding,
                    .right = new_padding,
                    .bottom = new_padding,
                },
                else => @compileError("Unsupported padding type: " ++ @typeName(@TypeOf(new_padding))),
            },
        };
        if (!self._padding.equals(&new_insets)) {
            self._padding = new_insets;
            self.setLayoutStatus(.invalid);
        }
    }

    fn updateBounds(self: *Self, x: f32, y: f32, width: f32, height: f32) void {
        // Updates this component's bounds, and all children (deep).
        self._bounds.left = x;
        self._bounds.top = y;
        self._bounds.right = x + width;
        self._bounds.bottom = y + height;
        self.setLayoutStatus(.valid);

        self.updateChildrenBounds();
    }

    fn updateChildrenBounds(self: *Self) void {
        if (self._children.count() == 0) return;
        self.updateChildren(.vertical);
        self.updateChildren(.horizontal);
        for (self._children.values()) |*c| {
            c.updateChildrenBounds();
        }
    }

    fn updateChildren(self: *Self, comptime axis: StackDirection) void {
        const alignment = if (axis == .horizontal) self._align_h else self._align_v;
        alignment.process(self, axis);
        for (self._children.values()) |*c| {
            c.setLayoutStatus(.valid);
        }
    }

    pub fn render(self: *const Self, parent_bounds: Insets) void {
        if (!self._visible) return;

        if (self._bounds.left >= parent_bounds.right or
            self._bounds.top >= parent_bounds.bottom or
            self._bounds.width() <= 0 or self._bounds.height() <= 0)
        {
            // Prevents rendering outside parent_bounds.
            // Maybe can be optimized.
            return;
        }

        const clipped_render_bounds: Insets = .{
            .left = @max(parent_bounds.left, self._bounds.left),
            .top = @max(parent_bounds.top, self._bounds.top),
            .right = @min(parent_bounds.right, self._bounds.right),
            .bottom = @min(parent_bounds.bottom, self._bounds.bottom),
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

        if (self.background_color.a != 0) {
            Game.renderer.setDrawColor(.{
                .r = self.background_color.r,
                .g = self.background_color.g,
                .b = self.background_color.b,
                .a = self.background_color.a,
            }) catch unreachable;
            Game.renderer.renderFillRect(.{
                .x = self._bounds.left,
                .y = self._bounds.top,
                .w = self._bounds.right - self._bounds.left,
                .h = self._bounds.bottom - self._bounds.top,
            }) catch unreachable;
        }

        if (self._border_width > 0) {
            // Draw 4 filled rectangles to create the border
            Game.renderer.setDrawColor(.{
                .r = self.border_color.r,
                .g = self.border_color.g,
                .b = self.border_color.b,
                .a = self.border_color.a,
            }) catch unreachable;
            // TODO
        }

        self.content.render(clipped_render_bounds);

        for (self._children.values()) |*child| {
            child.render(clipped_render_bounds);
        }
    }
};

/// Render a root component to the screen
pub fn render(root: *Component, width: f32, height: f32) void {
    root.setWidth(width);
    root.setHeight(height);

    switch (root._layout_status) {
        .valid => {},
        .invalid, .invalid_child => {
            root.updateBounds(0, 0, width, height);
        },
    }

    root.render(Insets.inf);
}
