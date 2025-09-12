const std = @import("std");
const easings = @import("../math/easings.zig");

const ArrayList = std.ArrayList;
const Vector = @import("../math/vector.zig").Vector;

pub fn Keyframe(T: type) type {
    return struct { value: T, time: f32 };
}

pub const TrackKind = enum { i32, f32, bool, vector, ivector };

pub fn TrackOpts(T: type) type {
    return struct {
        wrap_interpolation: bool = false,
        ease: easings.EasingFn(T) = easings.lerp,
    };
}

pub fn Track(kind: TrackKind) type {
    const T = switch (kind) {
        .i32 => i32,
        .f32 => f32,
        .bool => bool,
        .vector => Vector(f32),
        .ivector => Vector(i32),
    };

    return struct {
        pub const Self = @This();

        field: *T,
        frames: []Keyframe(T),
        wrap_interpolation: bool,
        ease: easings.EasingFn(T) = easings.lerp,

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
    current_time: f32,
    duration: f32,
    looping: bool,

    i32_tracks: ArrayList(Track(.i32)) = .empty,
    f32_tracks: ArrayList(Track(.f32)) = .empty,
    bool_tracks: ArrayList(Track(.bool)) = .empty,
    vector_tracks: ArrayList(Track(.vector)) = .empty,
    ivector_tracks: ArrayList(Track(.ivector)) = .empty,

    pub fn init(alloc: std.mem.Allocator, duration: f32, looping: bool) Self {
        return .{
            .alloc = alloc,
            .current_time = 0,
            .duration = duration,
            .looping = looping,
        };
    }

    pub fn addTrack(self: *Self, T: TrackKind, track: Track(T)) void {
        switch (T) {
            .i32 => try self.i32_tracks.append(self.alloc, track) catch unreachable,
            .f32 => try self.f32_tracks.append(self.alloc, track) catch unreachable,
            .bool => try self.bool_tracks.append(self.alloc, track) catch unreachable,
            .vector => try self.vector_tracks.append(self.alloc, track) catch unreachable,
            .ivector => try self.ivector_tracks.append(self.alloc, track) catch unreachable,
        }
    }

    pub fn update(self: *Self, dt: f32) void {
        if (self.looping) {
            self.current_time = @mod((self.current_time + dt), self.duration);
        } else {
            if (self.current_time < self.duration) {
                self.current_time = @min(self.current_time + dt, self.duration);
            }
        }

        // for (self.i32_tracks.items) |track| {}
        for (self.f32_tracks.items) |*track| self.updateTrackF32(track);
        // for (self.bool_tracks.items) |track| {}
        // for (self.vector_tracks.items) |track| {}
        // for (self.ivector_tracks.items) |track| {}
    }

    fn updateTrackF32(self: *Self, track: *Track(f32)) void {
        var curr_index: i32 = -1;
        for (0..track.frames.len) |i| {
            if (self.current_time >= track.frames[i].time and
                self.current_time <= track.frames[i + 1].time)
            {
                curr_index = i;
                break;
            }
        }

        // Between last and first frames
        if (curr_index == -1) {
            curr_index = track.frames[track.frames.len - 1];
        }

        const curr_frame = track.frames[curr_index];
        // Between last and first frame, and NOT interpolating between them.
        if (curr_index == track.frames.len and !track.wrap_interpolation) {
            track.field.* = curr_frame.value;
            return;
        }

        // Ease between current and next frame
        const next_frame = track.frames[curr_index % track.frames.len];

        const time_between_frames = blk: {
            if (curr_index == track.frames.len) {
                break :blk self.duration - curr_frame.time + next_frame.time;
            }
            break :blk next_frame.time - curr_frame.time;
        };

        const completion: f32 = (self.current_time - curr_frame.time) / time_between_frames;
        const eased_value = track.ease(
            @TypeOf(track.field),
            curr_frame.value,
            next_frame.value,
            completion,
        );

        track.field.* = eased_value;
    }
};

test "Animation" {
    const alloc = std.testing.allocator;
    const anim: Animation = .init(alloc, 4.0, false);

    var foo: f32 = 1.0;
    const track: Track(.f32) = .init(
        &foo,
        .{ foo, 2.0, 3.0, 4.0 },
        .{},
    );

    anim.addTrack(.f32, track);

    std.testing.expectEqual(1.0, foo);

    anim.update(1.0);
    std.testing.expectEqual(2.0, foo);

    anim.update(1.0);
    std.testing.expectEqual(3.0, foo);

    anim.update(1.0);
    std.testing.expectEqual(4.0, foo);
}
