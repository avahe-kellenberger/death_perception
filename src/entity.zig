const std = @import("std");

const Game = @import("game.zig");

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
    pub const Self = @This();
    player: Player,
    bullet: Bullet,

    pub fn deinit(self: *Self) void {
        switch (self) {
            inline else => |e| e.deinit(),
        }
    }
};

fn strEquals(s1: []const u8, s2: []const u8) bool {
    return std.mem.eql(u8, s1, s2);
}

// Comptime assertions for all Entity types.
// comptime {
//     // Example:
//     // const MyEntity = struct {
//     //     pub const Self = @This();
//     //     pub const kind: BodyKind = .dynamic;
//     //     pub const collision_shape: CollisionShape = .{ .circle = .init(Vector.zero, 4.0) };
//     //
//     //     kind: BodyKind,
//     //     loc: Vector(f32),
//     //     scale: Vector(f32),
//     //
//     //     pub fn update(self: *Self, dt: f32) void {
//     //         _ = self;
//     //         _ = dt;
//     //     }
//     // };
//
//     const assert = std.debug.assert;
//     for (@typeInfo(Entity).@"union".fields) |entity_field| {
//         // Decls
//         assert(@TypeOf(@field(entity_field.type, "kind")) == BodyKind);
//         assert(@TypeOf(@field(entity_field.type, "collision_shape")) == CollisionShape);
//
//         // Functions
//         const update_fn = @typeInfo(@TypeOf(@field(entity_field.type, "update"))).@"fn";
//         assert(update_fn.return_type.? == void);
//         assert(update_fn.params.len == 2);
//         assert(update_fn.params[0].type.? == *entity_field.type);
//         assert(update_fn.params[1].type.? == f32);
//
//         // Fields
//         assert(@hasField(entity_field.type, "id"));
//         for (@typeInfo(entity_field.type).@"struct".fields) |field| {
//             if (strEquals(field.name, "id")) {
//                 assert(field.type == u32);
//             } else if (strEquals(field.name, "loc")) {
//                 assert(field.type == Vector(f32));
//             } else if (strEquals(field.name, "scale")) {
//                 assert(field.type == Vector(f32));
//             } else if (strEquals(field.name, "velocity")) {
//                 assert(field.type == Vector(f32));
//             } else if (strEquals(field.name, "rotation")) {
//                 assert(field.type == f32);
//             }
//         }
//     }
// }

pub const EntityList = struct {
    pub const Self = @This();

    entities: std.AutoArrayHashMap(u32, Entity),
    // NOTE: even ids are client side, odd are server side.
    current_id: u32 = 0,

    pub fn init() EntityList {
        return .{ .entities = .init(Game.alloc) };
    }

    pub fn deinit(self: *Self) void {
        for (self.entities.values()) |v| {
            v.deinit();
        }
        self.entities.deinit();
        self.current_id = 0;
    }

    pub fn add(self: *Self, e: Entity) u32 {
        self.entities.put(self.current_id, e) catch unreachable;
        defer self.current_id += 2;
        return self.current_id;
    }

    pub fn get(self: *Self, id: u32) ?*Entity {
        return self.entities.getPtr(id);
    }

    pub fn getAs(self: *Self, tag: std.meta.Tag(Entity), id: u32) ?*std.meta.TagPayload(Entity, tag) {
        if (self.entities.getPtr(id)) |ptr| {
            return &@field(ptr, @tagName(tag));
        }
        return null;
    }

    pub fn remove(self: *Self, id: u32) void {
        if (self.entities.fetchSwapRemove(id)) |kv| {
            // TODO: ytho
            var foo = kv;
            foo.value.deinit();
            // var val: *Entity = &(kv.value);
            // &(kv.value).deinit();
        }
    }
};

test {
    const p = Player.init();
    var list = EntityList.init();
    const id = list.add(Entity{ .player = p });
    list.remove(id);

    const foo = list.getAs(.player, 1);
    std.log.err("{s}", .{@typeName(foo)});
}
