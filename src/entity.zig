const std = @import("std");

const Vector = @import("math/vector.zig").Vector;

const CollisionShape = @import("math/collisionshape.zig").CollisionShape;

const Player = @import("player.zig").Player;
const Bullet = @import("projectiles/bullet.zig").Bullet;

pub const BodyKind = enum {
    /// Physics body that is controlled by code, and unaffected by physics,
    /// but move other objects in its path.
    /// E.g. player, enemy npc, moving platforms.
    static,
    /// An unmovable, like a wall or fixed platform.
    fixed,
    /// A body that is only moved by a physics simulation.
    rigid,
};

pub const Entity = union(enum) {
    player: Player,
    bullet: Bullet,
};

fn strEquals(s1: []const u8, s2: []const u8) bool {
    return std.mem.eql(u8, s1, s2);
}

// Comptime assertions for all Entity types.
comptime {
    // Example:
    // const MyEntity = struct {
    //     pub const Self = @This();
    //     pub const kind: BodyKind = .dynamic;
    //     pub const collision_shape: CollisionShape = .{ .circle = .init(Vector.zero, 4.0) };
    //
    //     kind: BodyKind,
    //     loc: Vector(f32),
    //     scale: Vector(f32),
    //
    //     pub fn update(self: *Self, dt: f32) void {
    //         _ = self;
    //         _ = dt;
    //     }
    // };

    const assert = std.debug.assert;
    for (@typeInfo(Entity).@"union".fields) |entity_field| {
        // Decls
        assert(@TypeOf(@field(entity_field.type, "kind")) == BodyKind);
        assert(@TypeOf(@field(entity_field.type, "collision_shape")) == CollisionShape);

        // Functions
        const update_fn = @typeInfo(@TypeOf(@field(entity_field.type, "update"))).@"fn";
        assert(update_fn.return_type.? == void);
        assert(update_fn.params.len == 2);
        assert(update_fn.params[0].type.? == *entity_field.type);
        assert(update_fn.params[1].type.? == f32);

        // Fields
        for (@typeInfo(entity_field.type).@"struct".fields) |field| {
            if (strEquals(field.name, "loc")) {
                assert(field.type == Vector(f32));
            } else if (strEquals(field.name, "scale")) {
                assert(field.type == Vector(f32));
            } else if (strEquals(field.name, "velocity")) {
                assert(field.type == Vector(f32));
            } else if (strEquals(field.name, "rotation")) {
                assert(field.type == f32);
            }
        }
    }
}
