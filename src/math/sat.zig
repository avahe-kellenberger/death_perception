const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const CollisionShape = @import("collisionshape.zig").CollisionShape;
const Vector = @import("vector.zig").Vector(f32);

pub const CollisionResult = struct {
    pub const Self = @This();

    collision_owner_a: bool,
    intrusion: f32,
    contact_normal: Vector,
    contact_ratio: ?f32,
    contact_loc: ?Vector,

    pub fn init(
        collision_owner_a: bool,
        intrusion: f32,
        contact_normal: Vector,
        contact_ratio: ?f32,
        contact_loc: ?Vector,
    ) Self {
        return .{
            .collision_owner_a = collision_owner_a,
            .intrusion = intrusion,
            .contact_normal = contact_normal,
            .contact_ratio = contact_ratio,
            .contact_loc = contact_loc,
        };
    }

    pub fn getMinTranslationVector(self: Self) Vector {
        return self.contact_normal.multiply(-self.intrusion);
    }

    pub fn invert(self: Self) Self {
        return init(
            !self.collision_owner_a,
            self.intrusion,
            self.contact_normal.negate(),
            self.contact_ratio,
            self.contact_loc,
        );
    }
};

fn getOverlap(proj_a: Vector, proj_b: Vector) f32 {
    return @min(proj_a.y - proj_b.x, proj_b.y - proj_a.x);
}

/// Performs the SAT algorithm on the given collision shapes
/// to determine whether they are colliding or will collide.
///
/// All locations and move vectors are relative to shape_b.
///
/// @param loc_a:
///   The world location of collision shape A.
///
/// @param shape_a:
///   The collision shape of the moving object.
///
/// @param move_vector_a:
///   The movement vector of collision shape A.
///
/// @param loc_b:
///   The world location of the collision shape B.
///
/// @param shape_b:
///   The collision shape of the stationary object.
///
/// @param move_vector_b:
///   The movement vector of collision shape B.
///
/// @return:
///   A collision result containing information for collision resolution,
///   or null if the collision shapes are not and will not collide.
pub fn collides(
    alloc: Allocator,
    loc_a: Vector,
    shape_a: CollisionShape,
    move_vector_a: Vector,
    loc_b: Vector,
    shape_b: CollisionShape,
    move_vector_b: Vector,
) ?CollisionResult {
    const num_axes_a = shape_a.getProjectionAxesCount(shape_b);
    const num_axes_b = shape_b.getProjectionAxesCount(shape_a);
    const num_axes = num_axes_a + num_axes_b;

    var axes = ArrayList(Vector).initCapacity(alloc, num_axes) catch unreachable;
    defer axes.deinit(alloc);

    // Get the location of A relative to B (assume B is at origin)
    const relative_loc = loc_a.subtract(loc_b);
    // Get the move vector of A relative to B.
    const relative_move_vector = move_vector_a.subtract(move_vector_b);

    // Load axes into "axes" list
    shape_a.getProjectionAxes(&axes, shape_b, relative_loc);
    shape_b.getProjectionAxes(&axes, shape_a, relative_loc);

    // const proj_axes_a = axes.items[0..num_axes_a];
    // const proj_axes_b = axes.items[num_axes_a..axes.items.len];

    var is_shape_a_mtv = true;
    var intrusion_mtv = std.math.inf(f32);
    var mtv_normal: ?Vector = null;

    var is_shape_a_contact: bool = true;
    var intrusion_contact: f32 = 0;
    var contact_normal: ?Vector = null;
    var min_exit_time_ratio: f32 = std.math.inf(f32);
    var max_enter_time_ratio: f32 = std.math.inf(f32);

    for (axes.items, 0..) |axis, i| {
        const is_a = i < num_axes_a;
        // Find the projection of each shape on the current axis
        const proj_a = shape_a.project(relative_loc, axis);
        const proj_b = shape_b.project(Vector.Zero, axis);

        // Project the velocity on the current axis.
        const move_vector_proj = relative_move_vector.dotProduct(axis);
        var total_proj_min_a = proj_a.x;
        var total_proj_max_a = proj_a.y;

        // BELOW IS NO TOUCHY ZONE

        // Calculate contact time ratio
        var enter_time_ratio: f32 = 0.0;
        var exit_time_ratio: f32 = 0.0;
        if (proj_a.x > proj_b.x) { // A is to the right of B
            if (move_vector_proj >= 0) return null;
            enter_time_ratio = (proj_b.y - proj_a.x) / move_vector_proj;
            exit_time_ratio = (proj_b.x - proj_a.y) / move_vector_proj;
            total_proj_min_a += move_vector_proj;
        } else if (proj_a.y < proj_b.x) { // A is to the left of B
            if (move_vector_proj <= 0) return null;
            enter_time_ratio = (proj_b.x - proj_a.y) / move_vector_proj;
            exit_time_ratio = (proj_b.y - proj_a.x) / move_vector_proj;
            total_proj_max_a += move_vector_proj;
        } else { // A is intersecting B (already)
            if (move_vector_proj > 0) {
                enter_time_ratio = (proj_b.x - proj_a.y) / move_vector_proj;
                exit_time_ratio = (proj_b.y - proj_a.x) / move_vector_proj;
                total_proj_max_a += move_vector_proj;
            } else if (move_vector_proj < 0) {
                enter_time_ratio = (proj_b.y - proj_a.x) / move_vector_proj;
                exit_time_ratio = (proj_b.x - proj_a.y) / move_vector_proj;
                total_proj_max_a += move_vector_proj;
            } else {
                enter_time_ratio = -std.math.inf(f32);
                exit_time_ratio = std.math.inf(f32);
            }
        }

        if (enter_time_ratio > 1.0) {
            // Shapes are not intersecting and will not intersect.
            return null;
        }

        // END OF NO TOUCHY ZONE

        // Calculate intrusion
        const right_overlap = total_proj_max_a - proj_b.x;
        const left_overlap = proj_b.y - total_proj_min_a;
        // Get min overlap distance along the axis
        const overlap = @min(left_overlap, right_overlap);
        if (overlap < intrusion_mtv) {
            intrusion_mtv = overlap;
            mtv_normal = normalizeNormal(is_a, axis, proj_a, proj_b);
            is_shape_a_mtv = is_a;
        }

        min_exit_time_ratio = @min(min_exit_time_ratio, exit_time_ratio);

        if (enter_time_ratio > max_enter_time_ratio) {
            max_enter_time_ratio = enter_time_ratio;
            intrusion_contact = overlap;
            contact_normal = normalizeNormal(is_a, axis, proj_a, proj_b);
            is_shape_a_contact = is_a;
        }
    }

    if (max_enter_time_ratio <= min_exit_time_ratio) {
        if (contact_normal) |normal| {
            // Dynamic collision
            const move_vector_dot = normal.dotProduct(relative_move_vector);
            if (move_vector_dot != 0) {
                // Calculate the location of shape_a at time of collision
                const collision_loc_a = loc_a.add(relative_move_vector.scale(max_enter_time_ratio));
                const contact_loc = getContactLoc(
                    &axes,
                    collision_loc_a,
                    shape_a,
                    loc_b,
                    shape_b,
                    normal,
                    is_shape_a_contact,
                );
                return .init(
                    is_shape_a_contact,
                    intrusion_contact,
                    contact_normal,
                    max_enter_time_ratio,
                    contact_loc,
                );
            }
        } else if (mtv_normal) |normal| {
            // Static collision
            const contact_loc = getContactLoc(&axes, loc_a, shape_a, loc_b, shape_b, mtv_normal, is_shape_a_contact);
            return .init(is_shape_a_mtv, intrusion_mtv, normal, null, contact_loc);
        }
    }

    // No collision
    return null;
}

/// Generates a normal that is always pointing away from shape A.
fn normalizeNormal(is_a: bool, axis: Vector, proj_a: Vector, proj_b: Vector) Vector {
    const center_proj_a = (proj_a.x + proj_a.y); // * 0.5 not needed because we only compare
    const center_proj_b = (proj_b.x + proj_b.y); // * 0.5 not needed because we only compare
    return if (is_a == (center_proj_a > center_proj_b)) axis.negate() else axis;
}

fn getContactLoc(
    buffer: *ArrayList(Vector),
    loc_a: Vector,
    shape_a: CollisionShape,
    loc_b: Vector,
    shape_b: CollisionShape,
    contact_normal: Vector,
    is_shape_a: bool,
) Vector {
    var contact_normal_a: Vector = undefined;
    var contact_normal_b: Vector = undefined;
    if (is_shape_a) {
        contact_normal_a = contact_normal;
        contact_normal_b = contact_normal.negate();
    } else {
        contact_normal_a = contact_normal.negate();
        contact_normal_b = contact_normal;
    }

    if (is_shape_a) {
        return _getContactLoc(buffer, loc_a, shape_a, contact_normal_a, loc_b, shape_b, contact_normal_b);
    } else {
        // Flip the parameters to make the normal relative to shapeA.
        return _getContactLoc(buffer, loc_b, shape_b, contact_normal_b, loc_a, shape_a, contact_normal_a);
    }
}

fn _getContactLoc(
    buffer: *ArrayList(Vector),
    owner_loc: Vector,
    owner_shape: CollisionShape,
    owner_contact_normal: Vector,
    other_loc: Vector,
    other_shape: CollisionShape,
    other_contact_normal: Vector,
) Vector {
    buffer.clearRetainingCapacity();
    const other_farthest_points = translateVerticies(other_shape.getFarthest(other_contact_normal, &buffer), other_loc);
    if (other_farthest_points.len == 1) {
        return other_farthest_points[0];
    }

    // Get the vector perpendicular to the contact normal.
    const edge = owner_contact_normal.perp();

    // Get the projections of the points of the other shape onto the edge.
    const min_max_proj_other = MinMaxProjectionInterval.init(buffer.items, edge);

    buffer.clearRetainingCapacity();
    const owner_farthest_points = translateVerticies(owner_shape.getFarthest(owner_contact_normal, &buffer), owner_loc);
    if (owner_farthest_points.len == 1) {
        return owner_farthest_points[0];
    }

    // Two parallel sides collided with each other.
    //
    // 1) Project points onto the perpendicular of the normal (the edge).
    // 2) Get the minimum and maximum points (2 points) for each shape.
    // 3) Compare the 4 points.
    // 4) Return the two "middle-most" points.
    //

    // Get the projections of the points of the owner shape onto the edge.
    const min_max_proj_owner = MinMaxProjectionInterval.init(buffer.items, edge);

    // Merge interval (finds the inner points)
    const merge_interval = min_max_proj_other.middle(min_max_proj_owner);
    return merge_interval.min_point.add(merge_interval.max_point).scale(0.5);
}

fn translateVerticies(verts: []Vector, delta: Vector) []Vector {
    for (verts) |*v| v = v.add(delta);
    return verts;
}

const MinMaxProjectionInterval = struct {
    pub const Self = @This();

    min: f32,
    min_point: Vector,
    max: f32,
    max_point: Vector,

    pub fn init(verts: []Vector, axis: Vector) Self {
        std.debug.assert(verts.len > 0);

        var min: ?Vector = null;
        var min_point = std.math.inf(f32);
        var max: ?Vector = null;
        var max_point = -std.math.inf(f32);

        for (verts) |v| {
            const value = v.dotProduct(axis);
            if (value < min) {
                min = value;
                min_point = v;
            }
            if (value > max) {
                max = value;
                max_point = v;
            }
        }
        std.debug.assert(min_point != null and max_point != null);
        return .{ .min = min, .min_point = min_point, .max = max, .max_point = max_point };
    }

    pub fn middle(self: Self, other: Self) Self {
        const min_interval = if (self.min > other.min) self else other;
        const max_interval = if (self.max < other.max) self else other;
        return .{
            .min = min_interval.min,
            .min_point = min_interval.min_point,
            .max = max_interval.max,
            .max_point = max_interval.max_point,
        };
    }
};
