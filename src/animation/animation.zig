const std = @import("std");
const easings = @import("../math/easings.zig");

const ArrayList = std.ArrayList;
const Vector = @import("../math/vector.zig").Vector;

pub fn Keyframe(T: type) type {
    return struct { value: T, time: f32 };
}

// pub const TrackKind = enum { i32, f32, bool, vector, ivector };

pub fn TrackOpts(T: type) type {
    return struct {
        wrap_interpolation: bool = false,
        ease: *const easings.EasingFn(T) = easings.lerp(T),
    };
}

pub fn Track(T: type) type {
    return struct {
        pub const Self = @This();

        field: *T,
        frames: []Keyframe(T),
        wrap_interpolation: bool,
        ease: *const easings.EasingFn(T) = easings.lerp(T),

        pub fn init(field: *T, frames: []Keyframe(T), opts: TrackOpts(T)) Self {
            return .{
                .field = field,
                .frames = frames,
                .wrap_interpolation = opts.wrap_interpolation,
                .ease = opts.ease,
            };
        }
    };
}

pub const Animation = struct {
    pub const Self = @This();

    alloc: std.mem.Allocator,
    duration: f32,
    looping: bool,

    i32_tracks: ArrayList(Track(i32)) = .empty,
    f32_tracks: ArrayList(Track(f32)) = .empty,
    bool_tracks: ArrayList(Track(bool)) = .empty,
    vector_tracks: ArrayList(Track(Vector(f32))) = .empty,
    ivector_tracks: ArrayList(Track(Vector(i32))) = .empty,

    pub fn init(alloc: std.mem.Allocator, duration: f32, looping: bool) Self {
        return .{
            .alloc = alloc,
            .duration = duration,
            .looping = looping,
        };
    }

    pub fn deinit(self: *Self) void {
        self.i32_tracks.deinit(self.alloc);
        self.f32_tracks.deinit(self.alloc);
        self.bool_tracks.deinit(self.alloc);
        self.vector_tracks.deinit(self.alloc);
        self.ivector_tracks.deinit(self.alloc);
    }

    pub fn addTrack(self: *Self, comptime T: type, track: Track(T)) void {
        switch (T) {
            i32 => self.i32_tracks.append(self.alloc, track) catch unreachable,
            f32 => self.f32_tracks.append(self.alloc, track) catch unreachable,
            bool => self.bool_tracks.append(self.alloc, track) catch unreachable,
            Vector(f32) => self.vector_tracks.append(self.alloc, track) catch unreachable,
            Vector(i32) => self.ivector_tracks.append(self.alloc, track) catch unreachable,
            else => @compileError("Unsupported animation type"),
        }
    }

    pub fn update(self: *Self, current_time: f32) void {
        for (self.i32_tracks.items) |*track| self.updateTrack(i32, track, current_time);
        for (self.f32_tracks.items) |*track| self.updateTrack(f32, track, current_time);
        for (self.bool_tracks.items) |*track| self.updateTrack(bool, track, current_time);
        for (self.vector_tracks.items) |*track| self.updateTrack(Vector(f32), track, current_time);
        for (self.ivector_tracks.items) |*track| self.updateTrack(Vector(i32), track, current_time);
    }

    fn updateTrack(self: *Self, comptime T: type, track: *Track(T), current_time: f32) void {
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
            track.field.* = curr_frame.value;
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

        track.field.* = eased_value;
    }
};

test "Animation" {
    const alloc = std.testing.allocator;
    var anim: Animation = .init(alloc, 4.0, false);
    defer anim.deinit();

    var foo: f32 = 1.0;
    var frames = [_]Keyframe(f32){
        .{ .value = foo, .time = 0.0 },
        .{ .value = 2.0, .time = 1.0 },
        .{ .value = 3.0, .time = 2.0 },
        .{ .value = 4.0, .time = 3.0 },
    };

    const track: Track(f32) = .init(&foo, &frames, .{});
    anim.addTrack(f32, track);

    try std.testing.expectEqual(1.0, foo);

    anim.update(1.0);
    try std.testing.expectEqual(2.0, foo);

    anim.update(2.0);
    try std.testing.expectEqual(3.0, foo);

    anim.update(3.0);
    try std.testing.expectEqual(4.0, foo);
}
