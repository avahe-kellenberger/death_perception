const std = @import("std");
const Allocator = std.mem.Allocator;

const Game = @import("../game.zig");
const animation = @import("animation.zig");
const Animation = animation.Animation;

pub fn AnimationPlayer(T: type) type {
    return struct {
        pub const Self = @This();

        animations: std.StringHashMap(Animation(T)),
        current_animation: ?[]const u8 = null,
        current_time: f32 = 0,
        looping: bool = false,

        pub fn init() Self {
            return .{
                .animations = std.StringHashMap(Animation(T)).init(Game.alloc),
            };
        }

        pub fn deinit(self: *Self) void {
            var it = self.animations.valueIterator();
            while (it.next()) |anim| anim.deinit();
            self.animations.deinit();
        }

        pub fn addAnimation(self: *Self, name: []const u8, anim: Animation(T)) void {
            self.animations.put(name, anim) catch unreachable;
        }

        pub fn setAnimation(self: *Self, name: ?[]const u8) void {
            self.current_animation = name;
        }

        pub fn update(self: *Self, t: *T, dt: f32) void {
            if (self.current_animation) |anim_name| {
                var anim = self.animations.get(anim_name) orelse unreachable;

                if (self.looping) {
                    self.current_time = @mod((self.current_time + dt), anim.duration);
                } else {
                    if (self.current_time < anim.duration) {
                        self.current_time = @min(self.current_time + dt, anim.duration);
                    }
                }

                anim.update(t, self.current_time);
            }
        }
    };
}
