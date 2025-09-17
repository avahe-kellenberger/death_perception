const std = @import("std");

const Game = @import("../game.zig");

const array_2d = @import("../array_2d.zig");
const Array2D = array_2d.Array2D;
const ArrayWindow = array_2d.ArrayWindow;

const Node = std.DoublyLinkedList.Node;

pub fn SpatialPartition(T: type, comptime width: u32, comptime height: u32) type {
    return struct {
        pub const Self = @This();
        // Should we maybe use a hashmap instead (or two hashmaps, for bidirectional lookup)?
        // grid: Array2D(std.DoublyLinkedList, width, height),
        grid: std.AutoHashMap(u64, std.ArrayList(*T)),

        // TODO: Support not removing fixed bodies

        pub fn init() Self {
            return .{ .grid = .init(Game.alloc) };
        }

        pub fn insert(self: *Self, x: u32, y: u32, t: *T) void {
            var key: u64 = @intCast(x);
            key <<= 32;
            key |= y;

            const entry = self.grid.getOrPut(key) catch unreachable;
            if (!entry.found_existing) entry.value_ptr.* = .empty;
            entry.value_ptr.append(Game.alloc, t) catch unreachable;
        }

        pub fn get(self: *Self, x: u32, y: u32) std.DoublyLinkedList {
            return self.grid.get(x, y);
        }

        pub fn window(self: *Self, win: ArrayWindow) Iterator {
            const x = @min(win.x, width);
            const y = @min(win.y, height);
            const w = @min(win.w, width - x);
            const h = if (w != 0) @min(win.h, height - y) else 0;
            return Iterator.init(self, .{ .x = x, .y = y, .w = w, .h = h });
        }

        const Iterator = struct {
            partition: *Self,

            // Window
            win_x: usize, // inclusive
            win_max_x: usize, // exclusive
            win_max_y: usize, // exclusive

            // State
            x: usize,
            y: usize,

            // Pointers of data that have already been returned
            returned_data: std.AutoHashMap(*T, void),
            prev_node: ?Node = null,

            pub fn init(self: *Self, win: ArrayWindow) Iterator {
                return Iterator{
                    .partition = self,
                    .win_x = win.x,
                    .win_max_x = win.x + win.w,
                    .win_max_y = win.y + win.h,
                    .x = win.x,
                    .y = win.y,
                    .returned_data = .init(Game.alloc),
                };
            }

            pub fn deinit(self: *Iterator) void {
                self.returned_data.deinit();
            }

            pub fn next(self: *Iterator) ?*T {
                var current_node: ?Node = blk: {
                    if (self.prev_node) |n| {
                        break :blk n.next;
                    } else {
                        break :blk self.partition.get(self.x, self.y).first;
                    }
                };

                while (current_node) |node| {
                    defer current_node = node.next;
                    const t: *T = @fieldParentPtr("node", node);
                    // We already returned this object
                    if (self.returned_data.contains(t)) continue;
                    self.returned_data.put(t, {}) catch unreachable;
                    return t;
                }

                defer self.x += 1;

                if (self.x >= self.win_max_x) {
                    self.x = self.win_x;
                    self.y += 1;
                }
                if (self.y >= self.win_max_y) return null;
                return self.next();
            }
        };
    };
}
