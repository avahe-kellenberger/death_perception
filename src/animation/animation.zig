const std = @import("std");
const easings = @import("../math/easings.zig");

const ArrayList = std.ArrayList;
const Vector = @import("../math/vector.zig").Vector;

pub fn Keyframe(V: type) type {
    return struct { value: V, time: f32 };
}

pub fn TrackOpts(V: type) type {
    return struct {
        wrap_interpolation: bool = false,
        ease: *const easings.EasingFn(V) = easings.lerp(V),
    };
}

pub fn Track(E: type, V: type) type {
    return struct {
        pub const Self = @This();

        alloc: std.mem.Allocator,
        field: *const fn (e: *E) *V,
        frames: []const Keyframe(V),
        wrap_interpolation: bool,
        ease: *const easings.EasingFn(V) = easings.lerp(V),

        pub fn init(
            alloc: std.mem.Allocator,
            field: *const fn (e: *E) *V,
            frames: []const Keyframe(V),
            opts: TrackOpts(V),
        ) Self {
            return .{
                .alloc = alloc,
                .field = field,
                .frames = alloc.dupe(Keyframe(V), frames) catch unreachable,
                .wrap_interpolation = opts.wrap_interpolation,
                .ease = opts.ease,
            };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.frames);
        }
    };
}

pub fn Animation(E: type) type {
    return struct {
        pub const Self = @This();

        alloc: std.mem.Allocator,
        duration: f32,

        i32_tracks: ArrayList(Track(E, i32)) = .empty,
        f32_tracks: ArrayList(Track(E, f32)) = .empty,
        bool_tracks: ArrayList(Track(E, bool)) = .empty,
        vector_tracks: ArrayList(Track(E, Vector(f32))) = .empty,
        ivector_tracks: ArrayList(Track(E, Vector(i32))) = .empty,

        pub fn init(alloc: std.mem.Allocator, duration: f32) Self {
            return .{ .alloc = alloc, .duration = duration };
        }

        pub fn deinit(self: *Self) void {
            for (self.i32_tracks.items) |*t| t.deinit();
            self.i32_tracks.deinit(self.alloc);

            for (self.f32_tracks.items) |*t| t.deinit();
            self.f32_tracks.deinit(self.alloc);

            for (self.bool_tracks.items) |*t| t.deinit();
            self.bool_tracks.deinit(self.alloc);

            for (self.vector_tracks.items) |*t| t.deinit();
            self.vector_tracks.deinit(self.alloc);

            for (self.ivector_tracks.items) |*t| t.deinit();
            self.ivector_tracks.deinit(self.alloc);
        }

        pub fn addTrack(self: *Self, comptime T: type, track: Track(E, T)) void {
            switch (T) {
                i32 => self.i32_tracks.append(self.alloc, track) catch unreachable,
                f32 => self.f32_tracks.append(self.alloc, track) catch unreachable,
                bool => self.bool_tracks.append(self.alloc, track) catch unreachable,
                Vector(f32) => self.vector_tracks.append(self.alloc, track) catch unreachable,
                Vector(i32) => self.ivector_tracks.append(self.alloc, track) catch unreachable,
                else => @compileError("Unsupported animation type"),
            }
        }

        pub fn update(self: *Self, e: *E, current_time: f32) void {
            for (self.i32_tracks.items) |*track| self.updateTrack(i32, e, track, current_time);
            for (self.f32_tracks.items) |*track| self.updateTrack(f32, e, track, current_time);
            for (self.bool_tracks.items) |*track| self.updateTrack(bool, e, track, current_time);
            for (self.vector_tracks.items) |*track| self.updateTrack(Vector(f32), e, track, current_time);
            for (self.ivector_tracks.items) |*track| self.updateTrack(Vector(i32), e, track, current_time);
        }

        fn updateTrack(self: *Self, comptime V: type, e: *E, track: *Track(E, V), current_time: f32) void {
            const inf = std.math.maxInt(usize);
            var curr_index: usize = inf;
            for (0..track.frames.len) |i| {
                if (current_time >= track.frames[i].time and
                    i < (track.frames.len - 1) and
                    current_time < track.frames[i + 1].time)
                {
                    curr_index = i;
                    break;
                }
            }

            // Between last and first frames
            if (curr_index == inf) {
                curr_index = track.frames.len - 1;
            }

            const curr_frame = track.frames[curr_index];

            // Between last and first frame, and NOT interpolating between them.
            if (curr_index == track.frames.len and !track.wrap_interpolation) {
                (track.field(e)).* = curr_frame.value;
                return;
            }

            // Ease between current and next frame
            const next_frame = track.frames[(curr_index + 1) % track.frames.len];

            const time_between_frames = blk: {
                if (curr_index == track.frames.len) {
                    break :blk self.duration - curr_frame.time + next_frame.time;
                }
                break :blk next_frame.time - curr_frame.time;
            };

            const completion: f32 = (current_time - curr_frame.time) / time_between_frames;
            const eased_value = track.ease(
                curr_frame.value,
                next_frame.value,
                completion,
            );
            (track.field(e)).* = eased_value;
        }
    };
}

test "Animation" {
    const alloc = std.testing.allocator;
    var anim: Animation = .init(alloc, 3.0);
    defer anim.deinit();

    var foo: f32 = 1.0;
    var frames = [_]Keyframe(f32){
        .{ .value = foo, .time = 0.0 },
        .{ .value = 2.0, .time = 1.0 },
        .{ .value = 3.0, .time = 2.0 },
        .{ .value = 4.0, .time = 3.0 },
    };

    var track: Track(f32) = .init(alloc, &foo, &frames, .{});
    defer track.deinit();
    anim.addTrack(f32, track);

    try std.testing.expectEqual(1.0, foo);

    anim.update(1.0);
    try std.testing.expectEqual(2.0, foo);

    anim.update(2.0);
    try std.testing.expectEqual(3.0, foo);

    anim.update(3.0);
    try std.testing.expectEqual(4.0, foo);
}
