const math = @import("std").math;
const std = @import("std");

pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub fn zero() Vec2 {
        return Vec2{ .x = 0.0, .y = 0.0 };
    }

    pub fn new() Vec2 {
        return Vec2{ .x = 0.0, .y = 0.0 };
    }

    pub fn sub(a: Vec2, b: Vec2) Vec2 {
        return Vec2{ .x = a.x - b.x, .y = a.y - b.y };
    }

    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return Vec2{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn lengthSquared(v: Vec2) f32 {
        return v.x * v.x + v.y * v.y;
    }

    pub fn normalize(v: Vec2) Vec2 {
        const len = math.sqrt(v.x * v.x + v.y * v.y);
        return Vec2{ .x = v.x / len, .y = v.y / len };
    }

    pub fn scale(v: Vec2, s: f32) Vec2 {
        return Vec2{ .x = v.x * s, .y = v.y * s };
    }

    pub fn length(v: Vec2) f32 {
        return math.sqrt(v.x * v.x + v.y * v.y);
    }
};

pub const Mat3 = extern struct {
    m: [3][3]f32,

    pub fn identity() Mat3 {
        return Mat3{ .m = [_][3]f32{
            [_]f32{ 1.0, 0.0, 0.0 },
            [_]f32{ 0.0, 1.0, 0.0 },
            [_]f32{ 0.0, 0.0, 1.0 },
        } };
    }

    pub fn zero() Mat3 {
        return Mat3{
            .m = [_][3]f32{
                [_]f32{ 0.0, 0.0, 0.0 },
                [_]f32{ 0.0, 0.0, 0.0 },
                [_]f32{ 0.0, 0.0, 0.0 },
            },
        };
    }

    pub fn translate(tx: f32, ty: f32) Mat3 {
        var res = Mat3.identity();
        res.m[2][0] = tx;
        res.m[2][1] = ty;
        return res;
    }

    pub fn scale(sx: f32, sy: f32) Mat3 {
        var res = Mat3.zero();
        res.m[0][0] = sx;
        res.m[1][1] = sy;
        res.m[2][2] = 1.0;
        return res;
    }

    pub fn mul(a: Mat3, b: Mat3) Mat3 {
        var result: Mat3 = undefined;
        inline for (0..3) |row| {
            inline for (0..3) |col| {
                var sum: f32 = 0.0;
                inline for (0..3) |i| {
                    sum += a.m[row][i] * b.m[i][col];
                }
                result.m[row][col] = sum;
            }
        }
        return result;
    }

    // pub fn rotate(angle: f32) Mat3 {}
    // pub fn mul(angle: f32) Mat3 {}
};

pub const Mat4 = extern struct {
    m: [4][4]f32,

    pub fn orthographic(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        var result: Mat4 = undefined;
        result.m[0][0] = 2.0 / (right - left);
        result.m[1][1] = 2.0 / (top - bottom);
        result.m[2][2] = -2.0 / (far - near);
        result.m[3][0] = -(right + left) / (right - left);
        result.m[3][1] = -(top + bottom) / (top - bottom);
        result.m[3][2] = -(far + near) / (far - near);
        return result;
    }
};
