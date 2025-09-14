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

pub fn start(ip_address: []const u8, port: u16) bool {
    if (thread != null) return true;
    const address = address: {
        const ip_address_z: [:0]const u8 = Game.alloc.dupeZ(u8, ip_address) catch unreachable;
        defer Game.alloc.free(ip_address_z);
        break :address sdl.net.Address.init(ip_address_z) catch |err| {
            std.log.err("Failed to resolve address ({s}): {}", .{ ip_address, err });
            return false;
        };
    };
    var server_connection = ServerConnection.connect(address, port) catch |err| {
        std.log.err("Failed to connect to address ({s}): {}", .{ ip_address, err });
        address.deinit();
        return false;
    };
    running.store(true, .monotonic);
    thread = std.Thread.spawn(.{}, network_thread, .{server_connection}) catch |err| {
        std.log.err("{}", .{err});
        running.store(false, .monotonic);
        server_connection.deinit();
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
            break :p .{ .stream = server_connection.socket };
        };
        _ = sdl.net.waitUntilInputAvailable(Game.alloc, &.{pollable}, .{ .milliseconds = 50 }) catch unreachable;
    }
}

pub fn stop() void {
    if (thread) |t| {
        running.store(false, .monotonic);
        t.join();
        thread = null;
    }
}
