const std = @import("std");

pub const Vec3 = struct {
    data: @Vector(3, f32),

    pub inline fn new(x: f32, y: f32, z: f32) Vec3 {
        return .{
            .data = .{ x, y, z },
        };
    }

    pub inline fn zero() Vec3 {
        return .{
            .data = @splat(0),
        };
    }

    pub inline fn add(v: Vec3, o: Vec3) Vec3 {
        return .{
            .data = v.data + o.data,
        };
    }

    pub inline fn sub(v: Vec3, o: Vec3) Vec3 {
        return .{
            .data = v.data - o.data,
        };
    }

    pub inline fn scale(v: Vec3, s: f32) Vec3 {
        return .{
            .data = v.data * @as(@Vector(3, f32), @splat(s)),
        };
    }

    pub inline fn dot(v: Vec3, o: Vec3) f32 {
        return @reduce(.Add, v.data * o.data);
    }

    pub inline fn length(v: Vec3) f32 {
        return @sqrt(v.dot(v));
    }

    pub inline fn normalize(v: Vec3) Vec3 {
        const l = v.length();

        return if (l > 0) v.scale(1.0 / l) else v;
    }

    pub inline fn cross(a: Vec3, b: Vec3) Vec3 {
        return Vec3.new(
            a.data[1] * b.data[2] - a.data[2] * b.data[1],
            a.data[2] * b.data[0] - a.data[0] * b.data[2],
            a.data[0] * b.data[1] - a.data[1] * b.data[0],
        );
    }
};

pub const Mat4 = struct {
    data: [16]f32,

    pub inline fn mul(a: Mat4, b: Mat4) Mat4 {
        var r: Mat4 = undefined;

        inline for (0..4) |c| {
            inline for (0..4) |row| {
                var s: f32 = 0;

                inline for (0..4) |k| s += a.data[k * 4 + row] * b.data[c * 4 + k];

                r.data[c * 4 + row] = s;
            }
        }

        return r;
    }

    pub inline fn mulVec(m: Mat4, v: Vec3) @Vector(4, f32) {
        const x = m.data[0] * v.data[0] + m.data[4] * v.data[1] + m.data[8] * v.data[2] + m.data[12];
        const y = m.data[1] * v.data[0] + m.data[5] * v.data[1] + m.data[9] * v.data[2] + m.data[13];
        const z = m.data[2] * v.data[0] + m.data[6] * v.data[1] + m.data[10] * v.data[2] + m.data[14];
        const w = m.data[3] * v.data[0] + m.data[7] * v.data[1] + m.data[11] * v.data[2] + m.data[15];

        return .{ x, y, z, w };
    }
};

pub inline fn perspective(fov: f32, asp: f32, n: f32, f: f32) Mat4 {
    const t = @tan(fov * std.math.pi / 360) * n;
    const r = t * asp;

    return .{
        .data = .{
            n / r,
            0,
            0,
            0,
            0,
            n / t,
            0,
            0,
            0,
            0,
            -(f + n) / (f - n),
            -1,
            0,
            0,
            -(2 * f * n) / (f - n),
            0,
        },
    };
}

test "Vec3.new and zero" {
    const v = Vec3.new(1.0, 2.0, 3.0);
    try std.testing.expect(v.data[0] == 1.0);
    try std.testing.expect(v.data[1] == 2.0);
    try std.testing.expect(v.data[2] == 3.0);

    const z = Vec3.zero();
    try std.testing.expect(z.data[0] == 0.0);
    try std.testing.expect(z.data[1] == 0.0);
    try std.testing.expect(z.data[2] == 0.0);
}

test "Vec3.add and sub" {
    const a = Vec3.new(1, 2, 3);
    const b = Vec3.new(4, 5, 6);
    const sum = Vec3.add(a, b);
    try std.testing.expect(sum.data[0] == 5);
    try std.testing.expect(sum.data[1] == 7);
    try std.testing.expect(sum.data[2] == 9);

    const diff = Vec3.sub(b, a);
    try std.testing.expect(diff.data[0] == 3);
    try std.testing.expect(diff.data[1] == 3);
    try std.testing.expect(diff.data[2] == 3);
}

test "Vec3.scale" {
    const v = Vec3.new(1, 2, 3);
    const s = Vec3.scale(v, 2.0);
    try std.testing.expect(s.data[0] == 2);
    try std.testing.expect(s.data[1] == 4);
    try std.testing.expect(s.data[2] == 6);
}

test "Vec3.dot and length" {
    const a = Vec3.new(1, 0, 0);
    const b = Vec3.new(0, 1, 0);
    try std.testing.expect(a.dot(b) == 0.0);

    const c = Vec3.new(3, 4, 0);
    try std.testing.expect(c.length() == 5.0);
}

test "Vec3.normalize" {
    const v = Vec3.new(3, 0, 4);
    const n = v.normalize();
    const len = n.length();
    try std.testing.expect(@abs(len - 1.0) < 0.0001);
}

test "Vec3.cross" {
    const a = Vec3.new(1, 0, 0);
    const b = Vec3.new(0, 1, 0);
    const c = Vec3.cross(a, b);
    try std.testing.expect(c.data[0] == 0);
    try std.testing.expect(c.data[1] == 0);
    try std.testing.expect(c.data[2] == 1);
}

test "Mat4.mul identity" {
    var a: Mat4 = undefined;
    var b: Mat4 = undefined;

    // identity matrices
    a.data = [_]f32{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    };
    b.data = a.data;

    const r = Mat4.mul(a, b);

    inline for (0..16) |i| {
        try std.testing.expect(r.data[i] == a.data[i]);
    }
}

test "Mat4.mulVec simple translation" {
    var m: Mat4 = undefined;
    m.data = [_]f32{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        2, 3, 4, 1, // translation in last row
    };

    const v = Vec3.new(1, 2, 3);
    const result = Mat4.mulVec(m, v);

    try std.testing.expect(result[0] == 3); // 1 + 2
    try std.testing.expect(result[1] == 5); // 2 + 3
    try std.testing.expect(result[2] == 7); // 3 + 4
    try std.testing.expect(result[3] == 1);
}

test "perspective matrix basic" {
    const fov = 90.0;
    const asp = 1.0;
    const n = 0.1;
    const f = 100.0;
    const p = perspective(fov, asp, n, f);

    // basic sanity checks
    try std.testing.expect(p.data[15] == 0); // bottom-right is 0 in this perspective
    try std.testing.expect(p.data[11] == -1); // correct projection
}
