const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");

const Game = @import("../../game.zig");
const Color = @import("../../color.zig").Color;
const Alignment = @import("./alignment.zig").Alignment;
const ComponentContent = @import("./content.zig").ComponentContent;

const types = @import("./types.zig");
const StackDirection = types.StackDirection;
const Insets = @import("../../math/insets.zig").Insets;
const Size = types.Size;

pub const ComponentID = u32;
const ChildrenMap = std.array_hash_map.AutoArrayHashMapUnmanaged(ComponentID, Component);

pub fn EventSpec(comptime Event: type) type {
    return _EventSpec(Event, *anyopaque);
}

fn _EventSpec(comptime Event: type, comptime Context: type) type {
    return struct {
        handler: *const fn (comp: *Component, event: Event, ctx: Context) void,
        context: Context,
    };
}

pub const DisplayMode = enum(u2) {
    // The component should be included in layout and rendered.
    visible,
    // The component should be included in layout, but not rendered.
    invisible,
    // The component shouldn't be included in layout nor rendered.
    disabled,
};

const ValidationStatus = enum(u2) {
    valid,
    invalid,
    invalid_child,
};

/// Zero ID can be used as an invalid sentinel.
var next_id: ComponentID = 1;

pub const Component = struct {
    const Self = @This();

    _id: u32,

    // Top-down design: child components cannot cause their parent components to resize.
    _parent: ?*Component = null,
    _children: ChildrenMap = .empty,

    // If width or height are == 0, fill out all space available in layout.
    _width: Size = .{ .pixel = 0 },
    _height: Size = .{ .pixel = 0 },
    _margin: Insets = .zero,
    _padding: Insets = .zero,
    _border_width: f32 = 0.0,
    _layout: packed struct {
        /// The display mode of the component.
        mode: DisplayMode = .visible,
        /// How child components should be aligned along the horizontal axis.
        align_h: Alignment = .start,
        /// How child components should be aligned along the vertical axis.
        align_v: Alignment = .start,
        /// The main axis of the child component layout.
        stack_direction: StackDirection = .vertical,
        /// The validation status of the component layout.
        status: ValidationStatus = .invalid,
        // Whether the component accepts input events.
        input: bool = false,
    } = .{},
    _bounds: Insets = .zero, // Bounds including padding, excluding margin.

    // These fields can be set directly without impacting layout.
    background_color: Color = .transparent,
    border_color: Color = .black,
    content: ComponentContent = .none,

    // Event handlers
    on_mouse_button: ?EventSpec(sdl.events.MouseButton) = null,
    on_mouse_motion: ?EventSpec(sdl.events.MouseMotion) = null,
    on_mouse_enter: ?EventSpec(sdl.events.MouseMotion) = null,
    on_mouse_exit: ?EventSpec(sdl.events.MouseMotion) = null,

    pub fn init() Self {
        defer next_id += 1;
        return .{
            ._id = next_id,
        };
    }

    pub fn deinit(self: *Self) void {
        while (self._children.pop()) |kv| {
            var child = kv.value;
            child.deinit();
        }
        self._children.deinit(Game.alloc);
        self.content.deinit();
    }

    /// Add a child component to this parent component.
    /// Ownership of the component is transferred to the parent component.
    pub fn add(self: *Self, child: Component) void {
        var new_child = child;
        new_child._parent = self;
        self._children.put(Game.alloc, new_child._id, new_child) catch unreachable;
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
        self._layout.status = new_layout_status;
        if (new_layout_status != .valid) {
            if (self._parent) |p| {
                if (p._layout.status == .valid) {
                    p.setLayoutStatus(.invalid_child);
                }
            }
        }
    }

    pub fn setDisplayMode(self: *Self, mode: DisplayMode) void {
        if (self._layout.mode != mode) {
            self._layout.mode = mode;
            self.setLayoutStatus(.invalid);
        }
    }

    pub fn setStackDirection(self: *Self, direction: StackDirection) void {
        if (self._layout.stack_direction != direction) {
            self._layout.stack_direction = direction;
            self.setLayoutStatus(.invalid);
        }
    }

    pub fn setHorizontalAlignment(self: *Self, alignment: Alignment) void {
        if (self._layout.align_h != alignment) {
            self._layout.align_h = alignment;
            self.setLayoutStatus(.invalid);
        }
    }

    pub fn setVerticalAlignment(self: *Self, alignment: Alignment) void {
        if (self._layout.align_v != alignment) {
            self._layout.align_v = alignment;
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

    fn validateLayout(self: *Self) void {
        if (self._layout.status == .valid) return;

        // Updates this component's bounds, and all children (deep).
        self._bounds.left = 0;
        self._bounds.top = 0;
        self._bounds.right = self._width.pixelSize(0);
        self._bounds.bottom = self._height.pixelSize(0);
        self.setLayoutStatus(.valid);

        self.updateChildrenBounds();
    }

    fn updateChildrenBounds(self: *Self) void {
        if (self._children.count() == 0) return;
        self._layout.align_v.process(self, .vertical);
        self._layout.align_h.process(self, .horizontal);
        for (self._children.values()) |*c| {
            c.setLayoutStatus(.valid);
        }
        for (self._children.values()) |*c| {
            c.updateChildrenBounds();
        }
    }

    pub fn enableInput(self: *Self) void {
        self._layout.input = true;
    }

    /// Find the deepest component at the given point that can accept input events.
    fn findDeepestComponentContainingPoint(self: *Self, x: f32, y: f32) ?*Self {
        // Check conditions that affect child components too
        if (self._layout.mode == .visible and self._bounds.contains(x, y)) {
            // Must iterate children backwards because when children are rendered in overlap stack direction,
            // the last child shows on top and should be the first one to receive input events.
            const children = self._children.values();
            var i: usize = children.len;
            while (i > 0) {
                i -= 1;
                const child: *Component = &children[i];
                if (child.findDeepestComponentContainingPoint(x, y)) |deep| {
                    return deep;
                }
            }
            // If no child component produces a hit, try the current component
            if (self._layout.input) {
                return self;
            }
        }
        return null;
    }

    pub fn render(self: *const Self, parent_bounds: Insets) void {
        if (self._layout.mode != .visible) return;

        if (self._bounds.left >= parent_bounds.right or
            self._bounds.top >= parent_bounds.bottom or
            self._bounds.width() <= 0 or self._bounds.height() <= 0)
        {
            // Prevents rendering outside parent_bounds.
            // Maybe can be optimized.
            return;
        }

        const clipped_render_bounds: Insets = parent_bounds.intersect(&self._bounds);

        Game.renderer.setClipRect(clipped_render_bounds.irect()) catch unreachable;
        defer Game.renderer.setClipRect(null) catch unreachable;

        if (self.background_color.a != 0) {
            Game.renderer.setDrawColor(self.background_color.sdl()) catch unreachable;
            Game.renderer.renderFillRect(self._bounds.frect()) catch unreachable;
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

        const content_area: Insets = .{
            .left = self._bounds.left + self._padding.left + self._border_width,
            .top = self._bounds.top + self._padding.top + self._border_width,
            .right = self._bounds.right - self._padding.right - self._border_width,
            .bottom = self._bounds.bottom - self._padding.bottom - self._border_width,
        };
        self.content.render(content_area);

        for (self._children.values()) |*child| {
            child.render(clipped_render_bounds);
        }
    }
};

/// Keeps track of the deepest hovered component.
/// This is used to calculate and generated enter and exit events.
var hovered_component: ?*Component = null;

pub fn handleInputEvent(root: *Component, event: sdl.events.Event) void {
    switch (event) {
        .mouse_motion => |mme| {
            handleMouseMotion(root, mme);
        },
        .mouse_button_down, .mouse_button_up => |mbe| {
            handleMouseButton(root, mbe);
        },
        else => {},
    }
}

fn handleMouseButton(root: *Component, mouse_button: sdl.events.MouseButton) void {
    if (root.findDeepestComponentContainingPoint(mouse_button.x, mouse_button.y)) |comp| {
        if (comp.on_mouse_button) |spec| {
            spec.handler(comp, mouse_button, spec.context);
        }
    }
}

fn handleMouseMotion(root: *Component, mouse_motion: sdl.events.MouseMotion) void {
    if (root.findDeepestComponentContainingPoint(mouse_motion.x, mouse_motion.y)) |comp| {
        if (comp.on_mouse_motion) |spec| {
            spec.handler(comp, mouse_motion, spec.context);
        }
        if (hovered_component) |hc| {
            if (hc != comp) {
                handleMouseExit(hc, mouse_motion);
                handleMouseEnter(comp, mouse_motion);
            }
        } else {
            handleMouseEnter(comp, mouse_motion);
        }
    } else if (hovered_component) |hc| {
        handleMouseExit(hc, mouse_motion);
    }
}

fn handleMouseEnter(comp: *Component, event: sdl.events.MouseMotion) void {
    hovered_component = comp;
    if (comp.on_mouse_enter) |spec| {
        spec.handler(comp, event, spec.context);
    }
}

fn handleMouseExit(comp: *Component, event: sdl.events.MouseMotion) void {
    hovered_component = null;
    if (comp.on_mouse_exit) |spec| {
        spec.handler(comp, event, spec.context);
    }
}

/// Render a root component to the screen
pub fn render(root: *Component, width: f32, height: f32) void {
    root.setWidth(width);
    root.setHeight(height);
    root.validateLayout();
    root.render(Insets.inf);
}
