const std = @import("std");
const sokol = @import("sokol");
const mat4 = @import("math.zig").Mat4;
const mat3 = @import("math.zig").Mat3;
const vec2 = @import("math.zig").Vec2;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const slog = sokol.log;
const sgl = sokol.gl;
const math = @import("std").math;

const MAX_BODIES = 100;
const G = 6.67430e-11;
const SMALL_G = 6.67430e-4;
const damping = 0.99;

const State = struct {
    var bodies: [MAX_BODIES]Body = undefined;
    var bindings: sg.Bindings = .{};
    var pipeline: sg.Pipeline = .{};
    var pass_action: sg.PassAction = .{};
};

pub const RGBA = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn new() RGBA {
        return RGBA{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    }
};

const Body = struct {
    pos: vec2,
    vel: vec2,
    mass: f32,
    radius: f32,
    color: RGBA,

    fn updateForce(this: *Body, other: *Body) vec2 {
        const r = other.pos.sub(this.pos);
        const distanceSquared = r.lengthSquared();
        if (distanceSquared > 0.00001) {
            const f = G * this.mass * other.mass / distanceSquared;
            return r.normalize().scale(f);
        }
        return vec2{ .x = 0.0, .y = 0.0 };
    }
};

var bodies: [MAX_BODIES]Body = undefined;

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });
    sgl.setup(.{
        .logger = .{ .func = slog.func },
    });
    State.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0 },
    };

    var rng = std.rand.DefaultPrng.init(42);

    for (0..MAX_BODIES) |i| {
        const base = rng.random().float(f32);
        State.bodies[i] = Body{ .pos = vec2{ .x = (sapp.widthf() / 2) * (base * (100 - 0.15) + 0.15), .y = (sapp.heightf() / 2) * (base * (0.80 - 0.15) + 0.15) }, .mass = 10, .radius = 5, .color = RGBA{ .r = 10.0, .g = 0.0, .b = 0.0, .a = 255 }, .vel = vec2{ .x = 0.5, .y = 0.5 } };
        std.debug.print("mass: {}\n", .{State.bodies[i].mass});
        std.debug.print("x: {}, y: {}\n", .{ State.bodies[i].pos.x, State.bodies[i].pos.y });
    }
}

export fn frame() callconv(.C) void {
    const frame_count = sapp.frameCount();
    std.debug.print("Frame count: {}\n", .{frame_count});

    sgl.defaults();
    sgl.beginPoints();

    updatePhysics();

    for (0..MAX_BODIES) |i| {
        sgl.c3f(10.0, 0.0, 0.0);
        sgl.v2f(State.bodies[i].pos.x, State.bodies[i].pos.y);
        sgl.pointSize(State.bodies[i].radius);
        std.debug.print("Body #{}: x: {}, y: {}\n", .{ i, State.bodies[i].pos.x, State.bodies[i].pos.y });
    }

    sgl.end();

    sg.beginPass(.{ .action = State.pass_action, .swapchain = sglue.swapchain() });
    sgl.draw();
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    sgl.shutdown();
    sg.shutdown();
}

export fn updatePhysics() void {
    var forces: [MAX_BODIES]vec2 = undefined;
    for (0..MAX_BODIES) |i| {
        forces[i] = vec2{ .x = 0.0, .y = 0.0 };
        for (0..MAX_BODIES) |j| {
            if (i != j) {
                const force = bodies[i].updateForce(&bodies[j]);
                forces[i] = forces[i].add(force);
            }
        }
        std.debug.print("Body {}: Force x: {}, y: {}\n", .{ i, forces[i].x, forces[i].y });
    }

    const dt: f32 = 0.1; // Example time step
    for (0..MAX_BODIES) |i| {
        const acceleration = forces[i].scale(1.0 / bodies[i].mass);
        bodies[i].vel = bodies[i].vel.add(acceleration.scale(dt));
        bodies[i].pos = bodies[i].pos.add(bodies[i].vel.scale(dt));
        std.debug.print("Body {}: Pos x: {}, y: {}, Vel x: {}, y: {}\n", .{ i, bodies[i].pos.x, bodies[i].pos.y, bodies[i].vel.x, bodies[i].vel.y });
    }
}

pub fn main() !void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = 700,
        .height = 700,
        .sample_count = 4,
        .window_title = "Z-Body Simulation",
        .logger = .{ .func = slog.func },
    });
}
