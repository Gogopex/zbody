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

const State = struct {
    // instantiate bodies with 3 elements
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
    // var rng = std.rand.DefaultPrng.init(0);
    for (&State.bodies) |*b| {
        b.*.pos = vec2{
            .x = -7.0, // Range from 0 to 800
            .y = 2.0, // Range from 0 to 600
        };
        b.*.mass = 1.0;
        b.*.radius = 50.0; // Set radius to 50 pixels for bodies
        b.*.color = RGBA{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 }; // Red color for bodies
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
    //     sgl.c3f(10.0, 0.0, 0.0);
    //     sgl.pointSize(psize);
    //     sgl.v2f(x, y);
    //     psize *= 1.005;
    //     std.debug.print("x: {}, y: {}\n", .{ x, y });
    // }

    updatePhysics();

    for (0..MAX_BODIES) |i| {
        sgl.c4b(State.bodies[i].color.r, State.bodies[i].color.g, State.bodies[i].color.b, State.bodies[i].color.a);
        sgl.v2f(State.bodies[i].pos.x, State.bodies[i].pos.y);
        sgl.pointSize(5);
        std.debug.print("Body {} at x: {}, y: {}\n", .{ i, State.bodies[i].pos.x, State.bodies[i].pos.y });
        std.debug.print("Body {} mass: {}\n", .{ i, State.bodies[i].mass });
        std.debug.print("Body {} radius: {}\n", .{ i, State.bodies[i].radius });
        std.debug.print("Body {} color: r: {}, g: {}, b: {}, a: {}\n", .{ i, State.bodies[i].color.r, State.bodies[i].color.g, State.bodies[i].color.b, State.bodies[i].color.a });
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
                const distanceSquared = r.x * r.x + r.y * r.y;
                if (distanceSquared > 0.0001) {
                    const distance = math.sqrt(distanceSquared);
                    const f = G * State.bodies[j].mass * State.bodies[i].mass / distanceSquared;
                    force = force.add(r.scale(f / distance));
                }
            }
        }
        // Update velocity and position
        State.bodies[i].vel = State.bodies[i].vel.add(force.scale(1.0 / State.bodies[i].mass));
        State.bodies[i].pos = State.bodies[i].pos.add(State.bodies[i].vel.scale(1.0 / 60.0)); // Assuming 60 FPS
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
