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

const MAX_BODIES = 3;
const G = 6.67430e-11;
const SMALL_G = 6.67430e-7;
const damping = 0.9999;

const State = struct {
    var bodies: [MAX_BODIES]Body = .{
        .{ .pos = .{ .x = 0.0, .y = 0.0 }, .mass = 0.0, .radius = 3.0, .color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 }, .vel = .{ .x = 0.0, .y = 0.0 } },
        .{ .pos = .{ .x = 0.0, .y = 0.0 }, .mass = 0.0, .radius = 3.0, .color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 }, .vel = .{ .x = 0.0, .y = 0.0 } },
        .{ .pos = .{ .x = 0.0, .y = 0.0 }, .mass = 0.0, .radius = 3.0, .color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 }, .vel = .{ .x = 0.0, .y = 0.0 } },
    };
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
};

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

    // Initialize bodies at random positions
    // var rng = std.rand.DefaultPrng.init(42);
    for (&State.bodies) |*b| {
        // const base = rng.random().float(f32);
        // std.debug.print("base: {}\n", .{base});
        // std.debug.print("(base * (0.80 - 0.15) + 0.15): {}\n", .{base * (0.80 - 0.15) + 0.15});
        b.*.pos.x = 250.0;
        b.*.pos.y = 250.0;
        b.*.radius = 50.0;
        b.*.color = RGBA{ .r = 10.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    }
}

export fn frame() callconv(.C) void {
    const frame_count = sapp.frameCount();
    std.debug.print("Frame count: {}\n", .{frame_count});

    sgl.defaults();
    sgl.beginPoints();

    // const angle: f32 = @floatFromInt(sapp.frameCount() % 360);
    // var psize: f32 = 5;
    // var idx: usize = 0;
    // while (idx < 300) : (idx += 1) {
    //     const a = sgl.asRadians(angle + @as(f32, @floatFromInt(idx)));
    //     const r = math.sin(a * 4.0);
    //     const s = math.sin(a);
    //     const c = math.cos(a);
    //     const x = s * r;
    //     const y = c * r;
    //     std.debug.print("x: {}, y: {}\n", .{ x, y });
    //     sgl.c3f(10.0, 0.0, 0.0);
    //     sgl.pointSize(psize);
    //     sgl.v2f(x, y);
    //     psize *= 1.005;
    //     std.debug.print("x: {}, y: {}\n", .{ x, y });
    // }

    updatePhysics();

    for (0..MAX_BODIES) |i| {
        // sgl.c4b(State.bodies[i].color.r, State.bodies[i].color.g, State.bodies[i].color.b, 1);
        sgl.c3f(10.0, 0.0, 0.0);
        sgl.v2f(State.bodies[i].pos.x, State.bodies[i].pos.y);
        sgl.pointSize(50);
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
    for (0..State.bodies.len) |i| {
        var force = vec2{ .x = 0.0, .y = 0.0 };
        for (0..State.bodies.len) |j| {
            if (i != j) {
                const r = State.bodies[j].pos.sub(State.bodies[i].pos);
                const distance = math.sqrt(r.lengthSquared());
                const distanceSquared = r.lengthSquared();
                if (distanceSquared > 0.0001) {
                    const f = SMALL_G * State.bodies[j].mass * State.bodies[i].mass / distanceSquared;
                    force = force.add(r.scale(f / distance));
                }
            }
        }

        // Update velocity and position
        State.bodies[i].vel = State.bodies[i].vel.add(force.scale(1.0 / State.bodies[i].mass));
        State.bodies[i].vel = State.bodies[i].vel.scale(damping);
        State.bodies[i].pos = State.bodies[i].pos.add(State.bodies[i].vel.scale(1.0 / 60.0));

        // Wrap positions around screen edges
        // State.bodies[i].pos.x = if (State.bodies[i].pos.x < 0) sapp.widthf() + State.bodies[i].pos.x else @mod(State.bodies[i].pos.x, sapp.widthf());
        // State.bodies[i].pos.y = if (State.bodies[i].pos.y < 0) sapp.heightf() + State.bodies[i].pos.y else @mod(State.bodies[i].pos.y, sapp.heightf());

        std.debug.print("Body: {}, x: {}, y: {}\n", .{ i, State.bodies[i].pos.x, State.bodies[i].pos.y });
    }
}

pub fn main() !void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = 512,
        .height = 512,
        .sample_count = 4,
        .window_title = "Z-Body Simulation",
        .logger = .{ .func = slog.func },
    });
}
