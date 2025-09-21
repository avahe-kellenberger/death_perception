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

const BodyKind = @import("entity.zig").BodyKind;

const max_speed = 85.0 * Game.tile_size / 16.0;

pub const Player = struct {
    pub const Self = @This();

    pub const kind: BodyKind = .static;
    pub const collision_shape: CollisionShape = .{ .circle = .init(.init(0, -7), 7.0) };
    // pub const collision_shape: CollisionShape = .{ .aabb = .init(.init(-8, -15), .init(7.0, -1)) };

    loc: Vector = .zero,
    velocity: Vector = .zero,
    scale: Vector = .init(1, 1),
    rotation: f32 = 0,
    image: Texture,
    image_size: Vector,
    anim_player: AnimationPlayer(Self),
    sprite_offset: Vector,
    /// Range from -1 to 1; 0 means no skewing.
    sprite_skew: f32 = 0,
    sprite_flip: struct {
        horizontal: bool = false,
        vertical: bool = false,
    },

    pub fn init() Player {
        const image = Game.loadTexture("./assets/images/player.png", .nearest);

        // Create idle animation
        // var idle_anim: Animation(Player) = .init(Game.alloc, 1.8);
        // idle_anim.addTrack(Vector, Track(Player, Vector).init(
        //     Game.alloc,
        //     &getScale,
        //     &.{
        //         .{ .value = .init(1, 1), .time = 0.0 },
        //         .{ .value = .init(1.0, 1.1), .time = 0.7 },
        //         .{ .value = .init(1, 1), .time = 1.8 },
        //     },
        //     .{},
        // ));
        //
        // idle_anim.addTrack(f32, .init(
        //     Game.alloc,
        //     &getSkew,
        //     &.{
        //         .{ .value = 0, .time = 0.0 },
        //         .{ .value = 0.0112, .time = 0.3 },
        //         .{ .value = 0, .time = 1.8 },
        //     },
        //     .{},
        // ));

        const anim_player: AnimationPlayer(Self) = .init();
        // anim_player.addAnimation("idle", idle_anim);
        // anim_player.setAnimation("idle");
        // anim_player.looping = true;

        return .{ // init with defaults
            .image = image,
            .image_size = .{ .x = Game.tile_size, .y = Game.tile_size },
            .sprite_offset = .init(0, -8),
            .anim_player = anim_player,
            .sprite_flip = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.image.deinit();
        self.anim_player.deinit();
    }

    pub fn getScale(self: *Self) *Vector {
        return &self.scale;
    }

    pub fn getSkew(self: *Self) *f32 {
        return &self.sprite_skew;
    }

    pub fn update(self: *Self, dt: f32) void {
        self.velocity = Vector.zero;
        if (Input.isKeyPressed(.left)) {
            self.velocity.x -= max_speed;
            self.sprite_flip.horizontal = true;
        }
        if (Input.isKeyPressed(.right)) {
            self.velocity.x += max_speed;
            self.sprite_flip.horizontal = false;
        }

        if (Input.isKeyPressed(.up)) self.velocity.y -= max_speed;
        if (Input.isKeyPressed(.down)) self.velocity.y += max_speed;

        self.velocity = self.velocity.maxMagnitude(max_speed);

        self.anim_player.update(self, dt);
    }

    pub fn render(self: *Self) void {
        var top_left: Vector = .init(
            self.loc.x - self.image_size.x * 0.5 * self.scale.x + self.sprite_offset.x * self.scale.x,
            self.loc.y - self.image_size.y * 0.5 * self.scale.y + self.sprite_offset.y * self.scale.y,
        );
        const bottom_left: Vector = .init(top_left.x, top_left.y + self.image_size.y * self.scale.y);
        if (self.sprite_flip.horizontal) {
            top_left = top_left.rotateAround(-self.sprite_skew * std.math.pi * 0.5, bottom_left);
        } else {
            top_left = top_left.rotateAround(self.sprite_skew * std.math.pi * 0.5, bottom_left);
        }
        const top_right: Vector = .init(top_left.x + self.image_size.x * self.scale.x, top_left.y);
        const bottom_right: Vector = .init(top_right.x, top_right.y + self.image_size.y * self.scale.y);

        Game.renderTextureByCorners(
            self.image,
            top_left,
            top_right,
            bottom_left,
            bottom_right,
            self.sprite_flip.horizontal,
            self.sprite_flip.vertical,
        );
    }
};
