pub fn Size(T: type) type {
    return struct {
        w: T,
        h: T,

        pub fn init(w: T, h: T) Size(T) {
            return .{ .w = w, .h = h };
        }
    };
}
