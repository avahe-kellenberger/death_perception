const std = @import("std");

const Player = @import("player.zig").Player;
const Bullet = @import("projectiles/bullet.zig").Bullet;

pub const Entity = union(enum) {
    player: Player,
    bullet: Bullet,
};
