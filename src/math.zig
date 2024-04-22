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
