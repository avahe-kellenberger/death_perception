const Insets = @import("../types.zig").Insets;

pub const ComponentImage = struct {
    const Self = @This();

    // TODO

    pub fn render(self: *const Self, content_area: Insets) void {
        _ = self;
        _ = content_area;
    }
};
