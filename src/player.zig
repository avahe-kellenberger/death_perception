const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;
const FPoint = sdl.rect.FPoint;

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

    pub const collision_shape: CollisionShape = .{ .circle = .init(Vector.zero, 8.0) };

    image: Texture,
    loc: Vector = .init(0, 0),
    image_size: Vector = undefined,
    scale: Vector = .init(1, 1),
    anim_player: AnimationPlayer,
    render_offset: Vector = .init(0, 0),

    pub fn init() *Player {
        const image = Game.loadTexture("./assets/images/player.png", .nearest);

        var player: *Player = Game.alloc.create(Player) catch unreachable;
        player.image = image;
        player.image_size = .{ .x = Game.tile_size, .y = Game.tile_size };
        player.anim_player = .init(Game.alloc);

        // Create idle animation
        {
            var idle_anim: Animation = .init(Game.alloc, 1.2);
            idle_anim.addTrack(Vector, .init(
                Game.alloc,
                &player.scale,
                &.{
                    .{ .value = .init(1, 1), .time = 0.0 },
                    .{ .value = .init(1.1, 1.05), .time = 0.8 },
                    .{ .value = .init(1, 1), .time = 1.2 },
                },
                .{ .wrap_interpolation = false },
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
        Game.renderTexture(self.image, null, .{
            .x = self.loc.x - self.image_size.x * 0.5 * self.scale.x,
            .y = self.loc.y - self.image_size.y * 0.5 * self.scale.y,
            .w = self.image_size.x * self.scale.x,
            .h = self.image_size.y * self.scale.y,
        });
    }
};
