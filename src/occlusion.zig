const std = @import("std");
const sdl = @import("sdl3");

const Vector = @import("math/vector.zig").Vector(f32);
const Game = @import("game.zig");

pub const Wall = struct {
    start: Vector,
    end: Vector,
};

// https://www.redblobgames.com/articles/visibility/

// TODO: Use Game.renderer.setTarget and getTarget

pub fn init(target: sdl.render.Texture, pov: Vector, walls: []const Wall) void {
    //
}
