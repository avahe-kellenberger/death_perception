const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;

const Game = @import("../game.zig");
const Input = @import("../input.zig");
const Vector = @import("../math/vector.zig").Vector(f32);
const CollisionShape = @import("../math/collisionshape.zig").CollisionShape;

const BodyKind = @import("../entity.zig").BodyKind;

const max_speed = 85.0 * Game.tile_size / 16.0;

var bullet_image: ?Texture = null;
var image_size: Vector = undefined;

pub const Bullet = struct {
    pub const Self = @This();

    pub const kind: BodyKind = .dynamic;
    pub const collision_shape: CollisionShape = .{ .circle = .init(Vector.zero, 4.0) };

    loc: Vector,
    scale: Vector = .init(1, 1),
    velocity: Vector,
    rotation: f32,

    pub fn init(loc: Vector, velocity: Vector) *Bullet {
        if (bullet_image == null) {
            bullet_image = Game.loadTexture("./assets/images/bullet2.png", .nearest);
            image_size = .{
                .x = Game.tile_size * (@as(f32, @floatFromInt(bullet_image.?.getWidth())) / Game.tile_size),
                .y = Game.tile_size * (@as(f32, @floatFromInt(bullet_image.?.getHeight())) / Game.tile_size),
            };
        }

        const res: *Bullet = Game.alloc.create(Bullet) catch unreachable;
        res.* = .{
            .loc = loc,
            .velocity = velocity,
            .rotation = velocity.getAngleDegrees(),
        };
        return res;
    }

    pub fn deinit(self: *Self) void {
        Game.alloc.free(self);
    }

    pub fn update(self: *Self, dt: f32) void {
        self.loc.x += self.velocity.x * dt;
        self.loc.y += self.velocity.y * dt;
    }

    pub fn render(self: *Self) void {
        if (bullet_image) |image| {
            const dest: FRect = .{
                .x = self.loc.x - image_size.x * 0.5 * self.scale.x,
                .y = self.loc.y - image_size.y * 0.5 * self.scale.y,
                .w = image_size.x,
                .h = image_size.y,
            };
            Game.renderTextureRotated(
                image,
                null,
                dest,
                // NOTE: Use this if we want rotated bullet images?
                0, // self.velocity.getAngleDegrees(),
                .init(image_size.x * 0.5, image_size.y * 0.5),
                .{},
            );
        }
    }
};
