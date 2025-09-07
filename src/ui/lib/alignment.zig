const std = @import("std");

const StackDirection = @import("./stack.zig").StackDirection;
const Component = @import("./component.zig").Component;

pub const Alignment = enum {
    const Self = @This();

    start,
    center,
    end,
    space_evenly,

    pub fn process(self: Self, target: *Component, comptime axis: StackDirection) void {
        switch (self) {
            .start => alignStart(target, axis),
            .center => alignCenter(target, axis),
            .end => alignEnd(target, axis),
            .space_evenly => alignSpaceEvenly(target, axis),
        }
    }
};

fn alignStart(comp: *Component, comptime axis: StackDirection) void {
    // Aligns children along the given axis with Alignment.start
    if (axis == comp.stackDirection) {
        alignStartMainAxis(comp, axis);
    } else {
        alignStartCrossAxis(comp, axis);
    }
}

fn alignCenter(comp: *Component, comptime axis: StackDirection) void {
    // Aligns children along the given axis with Alignment.center
    if (axis == comp.stackDirection) {
        alignCenterMainAxis(comp, axis);
    } else {
        alignCenterCrossAxis(comp, axis);
    }
}

fn alignEnd(comp: *Component, comptime axis: StackDirection) void {
    // Aligns children along the given axis with Alignment.end
    if (axis == comp.stackDirection) {
        alignEndMainAxis(comp, axis);
    } else {
        alignEndCrossAxis(comp, axis);
    }
}

fn alignSpaceEvenly(comp: *Component, comptime axis: StackDirection) void {
    // Aligns children along the given axis with Alignment.space_evenly
    if (axis == comp.stackDirection) {
        alignSpaceEvenlyMainAxis(comp, axis);
    } else {
        // NOTE: Intentionally use "center" cross axis algorithm
        alignCenterCrossAxis(comp, axis);
    }
}

//
// Alignment implementations
//

fn alignStartMainAxis(comp: *Component, comptime axis: StackDirection) void {
    var child_start = if (axis == .horizontal)
        comp.bounds.left + comp.border_width + comp.padding.left
    else
        comp.bounds.top + comp.border_width + comp.padding.top;

    const max_child_len = determineDynamicChildLenMainAxis(comp, axis);

    var prev_child: ?*Component = null;

    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            layout(child, axis, 0, 0);
            continue;
        }

        const child_pixel_len = pixelLen(comp, child, axis);
        const child_len = if (child_pixel_len > 0) child_pixel_len else max_child_len;

        child_start += startMargin(child, axis);

        if (prev_child) |pc| {
            const sm = startMargin(pc, axis);
            const em = endMargin(pc, axis);
            if (em > sm) {
                child_start += em - sm;
            }
        }

        layout(child, axis, child_start, child_len);

        child_start += child_len;
        prev_child = child;
    }
}

fn alignStartCrossAxis(comp: *Component, comptime axis: StackDirection) void {
    const child_start = if (axis == .horizontal)
        comp.bounds.left + comp.border_width + comp.padding.left
    else
        comp.bounds.top + comp.border_width + comp.padding.top;

    const max_child_len = determineDynamicChildLenCrossAxis(comp, axis);

    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            layout(child, axis, 0, 0);
            continue;
        }

        const child_pixel_len = pixelLen(comp, child, axis);
        const child_len = if (child_pixel_len > 0) child_pixel_len else max_child_len - startMargin(child, axis) - endMargin(child, axis);

        layout(child, axis, child_start + startMargin(child, axis), child_len);
    }
}

fn alignCenterMainAxis(comp: *Component, comptime axis: StackDirection) void {
    const total_available_len = len(comp, axis) - totalPaddingAndBorders(comp, axis);
    const max_child_len = determineDynamicChildLenMainAxis(comp, axis);

    var total_children_len: f32 = 0.0;
    var first_margin: f32 = -1.0;
    var last_margin: f32 = 0.0;
    var prev_child: ?*Component = null;

    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            layout(child, axis, 0, 0);
            continue;
        }

        if (first_margin < 0) {
            first_margin = startMargin(child, axis);
        }

        const child_pixel_len = pixelLen(comp, child, axis);
        const child_len = if (child_pixel_len > 0) child_pixel_len else max_child_len;

        total_children_len += child_len + startMargin(child, axis);

        if (prev_child) |pc| {
            const sm = startMargin(pc, axis);
            const em = endMargin(pc, axis);
            if (em > sm) {
                total_children_len += em - sm;
            }
        }

        last_margin = endMargin(child, axis);
        prev_child = child;
    }

    if (prev_child) |pc| {
        total_children_len += endMargin(pc, axis);
    }

    // Set child positions and sizes
    prev_child = null;

    const total_children_len_without_outer_margins = total_children_len - first_margin - last_margin;
    const comp_start = startBounds(comp, axis) + startPadding(comp, axis) + comp.border_width;

    var child_start = comp_start;

    if (total_children_len >= total_available_len) {
        child_start += (total_available_len / 2.0) - (total_children_len / 2.0);
    } else {
        child_start += (total_available_len / 2.0) - (total_children_len_without_outer_margins / 2.0) - first_margin;

        const comp_end = endBounds(comp, axis) - endPadding(comp, axis) - comp.border_width;
        if (child_start < comp_start) {
            child_start = comp_start;
        } else if (child_start + total_children_len > comp_end) {
            child_start = comp_end - total_children_len;
        }
    }

    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            continue;
        }

        const child_pixel_len = pixelLen(comp, child, axis);
        const child_len = if (child_pixel_len > 0) child_pixel_len else max_child_len;

        child_start += startMargin(child, axis);

        if (prev_child) |pc| {
            const sm = startMargin(pc, axis);
            const em = endMargin(pc, axis);
            if (em > sm) {
                child_start += em - sm;
            }
        }

        layout(child, axis, child_start, child_len);

        child_start += child_len;
        prev_child = child;
    }
}

fn alignCenterCrossAxis(comp: *Component, comptime axis: StackDirection) void {
    const total_available_len = determineDynamicChildLenCrossAxis(comp, axis);
    const parent_start = startBounds(comp, axis) + startPadding(comp, axis) + comp.border_width;
    const center = parent_start + (total_available_len / 2.0);

    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            layout(child, axis, 0, 0);
            continue;
        }

        const child_pixel_len = pixelLen2(child, total_available_len, axis);
        const child_len = if (child_pixel_len > 0) child_pixel_len else total_available_len - startMargin(child, axis) - endMargin(child, axis);

        const preferred_child_start = center - (child_len / 2.0);
        const child_start_margin = startMargin(child, axis);
        const child_end_margin = endMargin(child, axis);
        const actual_child_start = if (child_len + child_start_margin + child_end_margin > total_available_len)
            // Center the child with margins added to its length
            center - (child_len + child_start_margin + child_end_margin) / 2.0 + child_start_margin
        else if (preferred_child_start - child_start_margin < parent_start)
            // Check if child needs to be pushed away from parent start (top or left)
            parent_start + child_start_margin
        else result: {
            // Check if child needs to be pushed away from parent end (bottom or right)
            const parent_end = endBounds(comp, axis) + comp.border_width + endPadding(comp, axis);
            const child_end = preferred_child_start + child_len + endMargin(child, axis);
            break :result if (child_end > parent_end) parent_end - child_len - child_end_margin else preferred_child_start;
        };

        layout(child, axis, actual_child_start, child_len);
    }
}

fn alignEndMainAxis(comp: *Component, comptime axis: StackDirection) void {
    const max_child_len = determineDynamicChildLenMainAxis(comp, axis);

    var total_children_len: f32 = 0;
    var prev_child: ?*Component = null;

    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            layout(child, axis, 0, 0);
            continue;
        }

        const child_pixel_len = pixelLen(comp, child, axis);
        const child_len = if (child_pixel_len > 0) child_pixel_len else max_child_len;

        total_children_len += child_len + startMargin(child, axis);

        if (prev_child) |pc| {
            const sm = startMargin(pc, axis);
            const em = endMargin(pc, axis);
            if (em > sm) {
                total_children_len += em - sm;
            }
        }

        prev_child = child;
    }

    if (prev_child) |pc| {
        total_children_len += endMargin(pc, axis);
    }

    // Set child positions and sizes
    prev_child = null;

    var child_start = endBounds(comp, axis) - endPadding(comp, axis) - comp.border_width - total_children_len;

    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            continue;
        }

        const child_pixel_len = pixelLen(comp, child, axis);
        const child_len = if (child_pixel_len > 0) child_pixel_len else max_child_len;

        child_start += startMargin(child, axis);

        layout(child, axis, child_start, child_len);

        child_start += child_len;

        if (prev_child) |pc| {
            const sm = startMargin(pc, axis);
            const em = endMargin(pc, axis);
            if (em > sm) {
                child_start += em - sm;
            }
        }

        prev_child = child;
    }
}

fn alignEndCrossAxis(comp: *Component, comptime axis: StackDirection) void {
    const max_child_len = determineDynamicChildLenCrossAxis(comp, axis);
    const end_pos = endBounds(comp, axis) - endPadding(comp, axis) - comp.border_width;
    const total_available_len = len(comp, axis) - totalPaddingAndBorders(comp, axis);

    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            layout(child, axis, 0, 0);
            continue;
        }

        const child_pixel_len = pixelLen2(child, total_available_len, axis);
        const child_len = if (child_pixel_len > 0) child_pixel_len else max_child_len;
        const child_start = end_pos - child_len;

        layout(child, axis, child_start, child_len);
    }
}

fn alignSpaceEvenlyMainAxis(comp: *Component, comptime axis: StackDirection) void {
    const total_available_len = len(comp, axis) - totalPaddingAndBorders(comp, axis);
    const max_child_len = determineDynamicChildLenMainAxis(comp, axis);

    var total_children_len: f32 = 0.0;
    var margins: MarginQueue = .init(comp.alloc, {});
    defer margins.deinit();
    var prev_child: ?*Component = null;

    // Calculate the total length all children use up
    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            layout(child, axis, 0, 0);
            continue;
        }

        const child_pixel_len = pixelLen(comp, child, axis);
        const child_len = if (child_pixel_len > 0) child_pixel_len else max_child_len;

        if (prev_child) |pc| {
            margins.add(@max(startMargin(child, axis), endMargin(pc, axis))) catch unreachable;
        } else {
            margins.add(startMargin(child, axis)) catch unreachable;
        }

        total_children_len += child_len;
        prev_child = child;
    }

    if (prev_child) |pc| {
        margins.add(endMargin(pc, axis)) catch unreachable;
    }

    // Set child positions and sizes
    prev_child = null;

    // Calculate the gap size and remaining space in the parent
    var remaining_space = total_available_len - total_children_len;
    var i = comp.children.count() + 1;
    var gap: f32 = if (remaining_space < 0) 0.0 else (remaining_space / @as(f32, @floatFromInt(i)));

    while (margins.removeOrNull()) |margin| {
        if (margin <= gap) {
            break;
        }

        remaining_space -= margin;
        i -= 1;
        gap = if (remaining_space < 0) 0.0 else remaining_space / @as(f32, @floatFromInt(i));
    }

    var child_start = startBounds(comp, axis) + startPadding(comp, axis) + comp.border_width;
    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            continue;
        }

        const child_pixel_len = pixelLen(comp, child, axis);
        const child_len = if (child_pixel_len > 0) child_pixel_len else max_child_len;

        const max_gap_start_margin = @max(gap, startMargin(child, axis));
        child_start += max_gap_start_margin;

        if (prev_child) |pc| {
            const em = endMargin(pc, axis);
            if (em > max_gap_start_margin) {
                child_start += em - max_gap_start_margin;
            }
        }

        layout(child, axis, child_start, child_len);

        child_start += child_len;
        prev_child = child;
    }
}

//
// Helper functions
//

fn max(_: void, a: f32, b: f32) std.math.Order {
    return std.math.order(b, a);
}

// Max heap queue for margins
const MarginQueue = std.PriorityQueue(f32, void, max);

fn layout(comp: *Component, comptime axis: StackDirection, start: f32, length: f32) void {
    if (axis == .horizontal) {
        comp.bounds.left = start;
        comp.bounds.right = start + length;
    } else {
        comp.bounds.top = start;
        comp.bounds.bottom = start + length;
    }
}

fn pixelLen(parent: *const Component, child: *const Component, comptime axis: StackDirection) f32 {
    const parent_len = len(parent, axis) - totalPaddingAndBorders(parent, axis);
    return pixelLen2(child, parent_len, axis);
}

fn pixelLen2(comp: *const Component, axis_len: f32, comptime axis: StackDirection) f32 {
    return if (axis == .horizontal) comp.width.pixelSize(axis_len) else comp.height.pixelSize(axis_len);
}

fn totalPaddingAndBorders(comp: *const Component, comptime axis: StackDirection) f32 {
    return if (axis == .horizontal) comp.padding.left + comp.padding.right + comp.border_width * 2 else comp.padding.top + comp.padding.bottom + comp.border_width * 2;
}

fn len(comp: *const Component, comptime axis: StackDirection) f32 {
    return if (axis == .horizontal) comp.bounds.width() else comp.bounds.height();
}

fn startMargin(comp: *const Component, comptime axis: StackDirection) f32 {
    return if (axis == .horizontal) comp.margin.left else comp.margin.top;
}

fn endMargin(comp: *const Component, comptime axis: StackDirection) f32 {
    return if (axis == .horizontal) comp.margin.right else comp.margin.bottom;
}

fn startPadding(comp: *const Component, comptime axis: StackDirection) f32 {
    return if (axis == .horizontal) comp.padding.left else comp.padding.top;
}

fn endPadding(comp: *const Component, comptime axis: StackDirection) f32 {
    return if (axis == .horizontal) comp.padding.right else comp.padding.bottom;
}

fn startBounds(comp: *const Component, comptime axis: StackDirection) f32 {
    return if (axis == .horizontal) comp.bounds.left else comp.bounds.top;
}

fn endBounds(comp: *const Component, comptime axis: StackDirection) f32 {
    return if (axis == .horizontal) comp.bounds.right else comp.bounds.bottom;
}

fn determineDynamicChildLenMainAxis(comp: *Component, comptime axis: StackDirection) f32 {
    const total_available_len = len(comp, axis) - totalPaddingAndBorders(comp, axis);

    var unreserved_len = total_available_len;
    var prev_child: ?*Component = null;
    var num_children_without_fixed_len = comp.children.count();

    for (comp.children.values()) |*child| {
        if (!child.visible and !child.enabled) {
            num_children_without_fixed_len -= 1;
            continue;
        }

        const child_pixel_len = pixelLen2(child, total_available_len, axis);
        if (child_pixel_len > 0) {
            unreserved_len -= child_pixel_len;
            num_children_without_fixed_len -= 1;
        }

        if (prev_child) |pc| {
            unreserved_len -= @max(startMargin(child, axis), endMargin(pc, axis));
        } else {
            unreserved_len -= startMargin(child, axis);
        }

        prev_child = child;
    }

    if (prev_child) |pc| {
        unreserved_len -= endMargin(pc, axis);
    }

    if (unreserved_len > 0 and num_children_without_fixed_len > 0) {
        return unreserved_len / @as(f32, @floatFromInt(num_children_without_fixed_len));
    }
    return 0.0;
}

fn determineDynamicChildLenCrossAxis(comp: *Component, comptime axis: StackDirection) f32 {
    return len(comp, axis) - totalPaddingAndBorders(comp, axis);
}
