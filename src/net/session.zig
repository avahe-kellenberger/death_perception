// Controls a networked game session

const std = @import("std");
const sdl = @import("sdl3");

const Game = @import("../game.zig");
const ServerConnection = @import("./client.zig").ServerConnection;

var running: std.atomic.Value(bool) = .init(false);
var thread: ?std.Thread = null;

pub fn isActive() bool {
    return thread != null;
}

pub fn start() bool {
    if (thread != null) return true;
    running.store(true, .monotonic);
    const server_connection = ServerConnection.connect();
    thread = std.Thread.spawn(.{}, network_thread, .{server_connection}) catch |err| {
        std.log.err("{}", .{err});
        running.store(false, .monotonic);
        return false;
    };
    return true;
}

fn network_thread(conn: ServerConnection) void {
    var server_connection = conn;
    defer server_connection.deinit();
    while (running.load(.monotonic)) {
        const pollable: sdl.net.Pollable = p: {
            Game.mutex.lock();
            defer Game.mutex.unlock();
            server_connection.read() catch return;
            break :p .{ .stream = server_connection.socket.value };
        };
        sdl.net.waitUntilInputAvailable(Game.alloc, &.{pollable}, .{ .milliseconds = 50 });
    }
}

pub fn stop() void {
    if (thread) |t| {
        running.store(false, .monotonic);
        t.join();
        thread = null;
    }
}
