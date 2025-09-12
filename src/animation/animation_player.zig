const std = @import("std");
const Allocator = std.mem.Allocator;

const animation = @import("animation.zig");
const Animation = animation.Animation;

pub const AnimationPlayer = struct {
    pub const Self = @This();

    alloc: Allocator,
    animations: std.StringHashMap(Animation),
    current_animation: []u8,
    current_time: f32 = 0,

    pub fn init(alloc: Allocator) Self {
        return .{
            .alloc = alloc,
            .animations = std.StringHashMap(Animation).init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        self.animations.deinit();
    }

    pub fn addAnimation(self: *Self, name: []const u8, anim: Animation) void {
        self.animations.put(name, anim) catch unreachable;
    }

    pub fn setAnimation(self: *Self, name: []const u8) void {
        self.current_animation = name;
    }

    pub fn update(self: *Self, dt: f32) void {
        if (self.looping) {
            self.current_time = @mod((self.current_time + dt), self.duration);
        } else {
            if (self.current_time < self.duration) {
                self.current_time = @min(self.current_time + dt, self.duration);
            }
        }

        var anim = self.animations.get(self.current_animation) orelse unreachable;
        anim.update(self.current_time);
    }
};
