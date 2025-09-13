// Accepts incoming client connections

const std = @import("std");
const sdl = @import("sdl3");

const Game = @import("../game.zig");
const ClientConnection = @import("./client.zig").ClientConnection;

const PORT: u16 = 33284; // DEATH

var running: std.atomic.Value(bool) = .init(false);
var thread: ?std.Thread = null;

pub fn isListening() bool {
    return thread != null;
}

pub fn start() bool {
    if (thread != null) return true;
    const server = sdl.net.Server.init(null, PORT) catch |err| {
        // Failed to start server, report to UI somehow
        std.log.err("{}", .{err});
        return false;
    };
    running.store(true, .monotonic);
    thread = std.Thread.spawn(.{}, server_thread, .{server}) catch |err| {
        std.log.err("{}", .{err});
        running.store(false, .monotonic);
        server.deinit();
        return false;
    };
    return true;
}

fn server_thread(server: sdl.net.Server) void {
    defer server.deinit();
    while (running.load(.monotonic)) {
        while (server.accept() catch return) |conn| {
            ClientConnection.accept(conn) catch {
                // Failed to create new client, due to ID exhaustion
                conn.deinit();
            };
        }
        _ = sdl.net.waitUntilInputAvailable(Game.alloc, &.{.{ .server = server }}, .{ .milliseconds = 50 }) catch |err| {
            std.log.err("{}", .{err});
            return;
        };
    }
}

pub fn stop() void {
    if (thread) |t| {
        running.store(false, .monotonic);
        t.join();
        thread = null;
    }
}
