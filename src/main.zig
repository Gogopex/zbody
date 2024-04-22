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
}

export fn frame() callconv(.C) void {
    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });

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

    // Render bodies and particles
    for (state.bodies) |b| {
        const translation = mat3.translate(b.pos.x, b.pos.y);
        const scaling = mat3.scale(b.radius, b.radius);
        const modelMatrix = translation.mul(scaling);

        const uniforms = Uniforms{
            .modelMatrix = modelMatrix,
            .color = b.color,
        };
        sg.applyUniforms(sg.ShaderStage.vs, 0, &uniforms);
        sg.draw(0, 6, 1);
    }

    for (state.particles) |p| {
        const translation = mat3.translate(p.pos.x, p.pos.y);
        const scaling = mat3.scale(p.radius, p.radius);
        const modelMatrix = translation.mul(scaling);

        const uniforms = Uniforms{
            .modelMatrix = modelMatrix,
            .color = p.color,
        };

        sg.applyUniforms(sg.ShaderStage.vs, 0, &uniforms);
        sg.draw(0, 6, 1);
    }

    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
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
