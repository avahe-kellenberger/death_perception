const Insets = @import("../types.zig").Insets;

pub const ComponentText = struct {
    const Self = @This();

    content: []const u8,
    font_size: f32,
    font_family: []const u8,

    pub fn render(self: *const Self, content_area: Insets) void {
        _ = self;
        _ = content_area;
    }
};
