const std = @import("std");
const sokol = @import("sokol");
const mat3 = @import("math.zig").Mat3;
const vec2 = @import("math.zig").Vec2;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const slog = sokol.log;
const sgl = sokol.gl;

pub const RGB = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn new() RGB {
        return RGB{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    }
};

const Body = struct {
    pos: vec2,
    mass: f32,
    radius: f32,
    color: RGB,
};

const Particle = struct {
    pos: vec2,
    vel: vec2,
    mass: f32,
    radius: f32,
    color: RGB,
};

const MAX_BODIES = 3;
const MAX_PARTICLES = 10;
const G = 6.67430e-11;

const State = struct {
    bodies: [MAX_BODIES]Body,
    particles: [MAX_PARTICLES]Particle,
    bindings: sg.Bindings,
    pipeline: sg.Pipeline,
    pass_action: sg.PassAction,
};

var state: State = undefined;

const Uniforms = struct {
    modelMatrix: mat3,
    color: RGB,
};

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    sgl.setup(.{
        .logger = .{ .func = slog.func },
    });

    // Initialize bodies at random positions
    var rng = std.rand.DefaultPrng.init(0);
    for (&state.bodies) |*b| {
        b.*.pos = vec2{
            .x = rng.random().float(f32) * 2.0 - 1.0,
            .y = rng.random().float(f32) * 2.0 - 1.0,
        };
        b.*.mass = 1.0;
        b.*.radius = 0.1;
        b.*.color = RGB{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    }

    // Initialize particles at random positions
    for (&state.particles) |*p| {
        p.pos = vec2{
            .x = rng.random().float(f32) * 2.0 - 1.0,
            .y = rng.random().float(f32) * 2.0 - 1.0,
        };
        p.vel = vec2{ .x = 0.0, .y = 0.0 };
        p.mass = 0.1;
        p.radius = 0.05;
        p.color = RGB{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 };
    }

    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0 },
    };
}

export fn frame() callconv(.C) void {
    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });

    std.debug.print("Rendering frame\n", .{});

    // Update particles based on gravity from bodies
    for (&state.particles) |*p| {
        var force = vec2{ .x = 0.0, .y = 0.0 };
        for (state.bodies) |b| {
            const r = b.pos.sub(p.pos);
            const r_squared = r.lengthSquared();
            const f = G * b.mass * p.mass / r_squared;
            force = force.add(r.normalize().scale(f));
        }
        p.vel = p.vel.add(force.scale(1.0 / p.mass));
        p.pos = p.pos.add(p.vel.scale(1.0 / 60.0));
    }

    drawCircle(vec2{ .x = 15.0, .y = 15.0 }, 1000, 12, RGB{ .r = 0.5, .g = 1.0, .b = 0.5, .a = 1.0 });

    // Render bodies and particles
    for (state.bodies) |b| {
        std.debug.print("Body position: ({}, {})\n", .{ b.pos.x, b.pos.y });
        drawCircle(b.pos, b.radius, 12, b.color);
    }

    for (state.particles) |p| {
        std.debug.print("Particle position: ({}, {})\n", .{ p.pos.x, p.pos.y });
        drawCircle(p.pos, p.radius, 12, p.color);
    }

    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    sgl.shutdown();
    sg.shutdown();
}

pub fn main() !void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = 800,
        .height = 600,
        .sample_count = 4,
        .window_title = "N-Body Simulation",
    });
}

fn calculateModelMatrix(entity: anytype) mat3 {
    const translation = mat3.translate(entity.pos.x, entity.pos.y);
    const scaling = mat3.scale(entity.radius, entity.radius);
    const modelMatrix = translation.mul(scaling);
    return modelMatrix;
}

pub fn drawCircle(center: vec2, radius: f32, segments: u32, color: RGB) void {
    sgl.sgl_c4f(color.r, color.g, color.b, color.a); // Set color
    sgl.sgl_begin_triangles();
    std.debug.print("Drawing circle at: ({}, {})\n", .{ center.x, center.y });
    var i: u32 = 0;
    while (i < segments) : (i += 1) {
        const segments_f32 = @as(f32, @floatFromInt(segments));
        const i_f32 = @as(f32, @floatFromInt(i));
        // Central vertex
        sgl.sgl_v2f(center.x, center.y);

        // First vertex on the edge of the circle
        const angle1: f32 = 2.0 * std.math.pi * (i_f32 / segments_f32);
        const x1 = center.x + radius * std.math.cos(angle1);
        const y1 = center.y + radius * std.math.sin(angle1);
        sgl.sgl_v2f(x1, y1);

        // Second vertex on the edge of the circle
        const angle2 = 2.0 * std.math.pi * ((i_f32 + 1) / segments_f32);
        const x2 = center.x + radius * std.math.cos(angle2);
        const y2 = center.y + radius * std.math.sin(angle2);
        sgl.sgl_v2f(x2, y2);
    }
    sgl.sgl_end();
}
