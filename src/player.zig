const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Texture = sdl.render.Texture;

const Game = @import("game.zig");
const Input = @import("input.zig");
const Vector = @import("math/vector.zig").Vector(f32);
const CollisionShape = @import("math/collisionshape.zig").CollisionShape;

const animation = @import("animation/animation.zig");
const Animation = animation.Animation;
const Track = animation.Track;
const Keyframe = animation.Keyframe;
const AnimationPlayer = @import("animation/animation_player.zig").AnimationPlayer;

const max_speed = 85.0 * Game.tile_size / 16.0;

pub const Player = struct {
    pub const Self = @This();

    pub const collision_shape: CollisionShape = .{ .circle = .init(.init(0, -7), 7.0) };

    loc: Vector = .zero,
    scale: Vector = .init(1, 1),
    image: Texture,
    image_size: Vector,
    anim_player: AnimationPlayer,
    sprite_offset: Vector = .zero,
    /// Range from -1 to 1; 0 means no skewing.
    sprite_skew: f32 = 0,

    pub fn init() *Player {
        const image = Game.loadTexture("./assets/images/player.png", .nearest);

        var player: *Player = Game.alloc.create(Player) catch unreachable;
        player.* = .{ // init with defaults
            .image = image,
            .image_size = .{ .x = Game.tile_size, .y = Game.tile_size },
            .sprite_offset = .init(0, -8),
            .anim_player = .init(Game.alloc),
        };

        // Create idle animation
        {
            var idle_anim: Animation = .init(Game.alloc, 1.8);
            idle_anim.addTrack(Vector, .init(
                Game.alloc,
                &player.scale,
                &.{
                    .{ .value = .init(1, 1), .time = 0.0 },
                    .{ .value = .init(1.0, 1.1), .time = 0.7 },
                    .{ .value = .init(1, 1), .time = 1.8 },
                },
                .{},
            ));

            idle_anim.addTrack(f32, .init(
                Game.alloc,
                &player.sprite_skew,
                &.{
                    .{ .value = 0, .time = 0.0 },
                    .{ .value = 0.0112, .time = 0.3 },
                    .{ .value = 0, .time = 1.8 },
                },
                .{},
            ));

            player.anim_player.addAnimation("idle", idle_anim);
            player.anim_player.setAnimation("idle");
            player.anim_player.looping = true;
        }

        return player;
    }

    pub fn deinit(self: *Self) void {
        self.image.deinit();
        self.anim_player.deinit();
    }

    pub fn update(self: *Self, dt: f32) void {
        var vel: Vector = .init(0, 0);
        if (Input.isKeyPressed(.left)) vel.x -= max_speed;
        if (Input.isKeyPressed(.right)) vel.x += max_speed;

        if (Input.isKeyPressed(.up)) vel.y -= max_speed;
        if (Input.isKeyPressed(.down)) vel.y += max_speed;

        vel = vel.maxMagnitude(max_speed);

        self.loc.x += vel.x * dt;
        self.loc.y += vel.y * dt;

        self.anim_player.update(dt);
    }

    pub fn render(self: *Self) void {
        var top_left: Vector = .init(
            self.loc.x - self.image_size.x * 0.5 * self.scale.x + self.sprite_offset.x * self.scale.x,
            self.loc.y - self.image_size.y * 0.5 * self.scale.y + self.sprite_offset.y * self.scale.y,
        );
        const bottom_left: Vector = .init(top_left.x, top_left.y + self.image_size.y * self.scale.y);
        top_left = top_left.rotateAround(self.sprite_skew * std.math.pi * 0.5, bottom_left);
        const top_right: Vector = .init(top_left.x + self.image_size.x * self.scale.x, top_left.y);

        Game.renderTextureAffine(self.image, null, top_left, top_right, bottom_left);
    }
};
