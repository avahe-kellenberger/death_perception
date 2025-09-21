// Socket Connections

const std = @import("std");
const sdl = @import("sdl3");

const Game = @import("../game.zig");

const ClientID = u8;

const ClientState = enum {
    init,
    update,
};

var mutex: std.Thread.Mutex = .{};
var client_connections: std.AutoArrayHashMapUnmanaged(ClientID, ClientConnection) = .empty;

/// Authoritative connection to a game client.
pub const ClientConnection = struct {
    const Self = @This();

    id: ClientID,
    socket: sdl.net.StreamSocket,
    state: ClientState = .init,

    /// Receives a client connection from the listen thread
    pub fn accept(socket: sdl.net.StreamSocket) !void {
        mutex.lock();
        defer mutex.unlock();

        // Find next available client ID
        const id = id: {
            var id: ClientID = std.math.minInt(ClientID);
            while (id < std.math.maxInt(ClientID)) {
                id += 1;
                if (!client_connections.contains(id)) {
                    break :id id;
                }
            }
            return error.NoID;
        };

        const new_client: Self = .{
            .id = id,
            .socket = socket,
        };

        client_connections.put(Game.alloc, new_client.id, new_client) catch unreachable;
    }

    pub fn deinit(self: *Self) void {
        self.socket.deinit();

        mutex.lock();
        defer mutex.unlock();
        _ = client_connections.orderedRemove(self.id);
    }

    /// Write update data to the client.
    fn write(self: *Self) !void {
        while (true) {
            switch (self.state) {
                .init => {
                    try self.socket.write(&.{self.id});
                    self.state = .update;
                },
                .update => {
                    // TODO send game state to client
                },
            }
        }
    }
};

/// The main game mutex should be held.
pub fn syncToClients() void {
    mutex.lock();
    defer mutex.unlock();

    for (client_connections.values()) |*cc| {
        cc.write() catch {
            cc.socket.deinit();
            _ = client_connections.orderedRemove(cc.id);
        };
    }
}

pub const ClientPeer = struct {
    client_id: ClientID = 0,
};

/// A non-authoritative connection to a game server.
/// TODO make this global? only one server connection at a time
pub const ServerConnection = struct {
    const Self = @This();

    me: ClientPeer = .{},
    peers: std.AutoArrayHashMapUnmanaged(ClientID, ClientPeer) = .empty,
    socket: sdl.net.StreamSocket,
    state: ClientState = .init,

    /// Connect to a remote game server.
    pub fn connect(address: sdl.net.Address, port: u16) !Self {
        errdefer address.deinit();
        const socket = try sdl.net.StreamSocket.initClient(address, port);
        // TODO block wait for socket to connect?
        return .{ .socket = socket };
    }

    /// Close and deinit the connection memory.
    pub fn deinit(self: *Self) void {
        self.socket.deinit();
    }

    /// Read update data from the server.
    pub fn read(self: *Self) !void {
        while (true) {
            switch (self.state) {
                .init => {
                    var buf: [4096]u8 = undefined;
                    const bytes_read = try self.socket.read(&buf);
                    _ = bytes_read;
                    // read client id
                    self.state = .update;
                },
                .update => {
                    // TODO read game state
                },
            }
        }
    }
};
