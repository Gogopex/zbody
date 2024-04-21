const std = @import("std");
const sokol = @import("sokol");
const zlm = @import("zlm");
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const slog = sokol.log;
const sgl = sokol.gl;

const body = struct {
    pos: zlm.Vec2,
    vel: zlm.Vec2,
    radius: f32,
    color: sg.color,
    indexCount: u32,
};

const particle = struct {
    pos: sg.vec2,
    vel: sg.vec2,
    radius: f32,
    color: sg.color,
};

const MAX_BODIES = 1;
const MAX_PARTICLES = 1024;

const state = struct {
    var bodies: [MAX_BODIES]body = .{
        .{ .pos = .{ .x = 0.0, .y = 0.0 }, .vel = .{ .x = 0.01, .y = 0.01 }, .radius = 0.1, .color = .{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 }, .indexCount = 6 },
    };
    var num_bodies: u32 = 0;
    var particles: [MAX_PARTICLES]particle = .{};
    var num_particles: u32 = 0;
    var time: f32 = 0;
    var tick: f32 = 0;
    var bindings: sg.Bindings = .{};
    var pipeline: sg.Pipeline = .{};
    var pass_action: sg.PassAction = .{};
};

const BodyUniforms = struct {
    modelMatrix: sg.mat4,
    color: sg.color,
};

const ParticleUniforms = struct {
    modelMatrix: sg.mat4,
    color: sg.color,
};

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });
}

export fn frame() callconv(.C) void {
    // Begin the default rendering pass

    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });

    // Update bodies
    for (state.bodies[0..state.num_bodies]) |*b| {
        b.pos += b.vel * 1.0 / 60.0;
        // Handle boundary conditions
        if (b.pos.x < -1.0 or b.pos.x > 1.0) {
            b.vel.x = -b.vel.x;
        }
        if (b.pos.y < -1.0 or b.pos.y > 1.0) {
            b.vel.y = -b.vel.y;
        }
    }

    // Update particles
    for (state.particles[0..state.num_particles]) |*p| {
        p.pos += p.vel * 1.0 / 60.0;
        // Handle boundary conditions
        if (p.pos.x < -1.0 or p.pos.x > 1.0) {
            p.vel.x = -p.vel.x;
        }
        if (p.pos.y < -1.0 or p.pos.y > 1.0) {
            p.vel.y = -p.vel.y;
        }
    }

    sg.applyPipeline(state.pipeline);
    sg.applyBindings(state.bindings);

    // Rendering commands
    renderParticlesAndBodies();

    // End the pass and commit the frame
    sg.endPass();
    sg.commit();
}

fn renderParticlesAndBodies() void {
    // Bind the pipeline and vertex/index buffers
    sg.applyPipeline(state.pipeline);
    sg.applyBindings(&state.bindings);

    // Loop through and render all bodies
    for (state.bodies[0..state.num_bodies]) |b| {
        // Update uniforms for the body
        var uniforms = BodyUniforms{
            .modelMatrix = calculateModelMatrix(b),
            .color = body.color,
        };
        sg.applyUniforms(.VertexShader, 0, &uniforms, @sizeOf(BodyUniforms));

        // Draw the body
        sg.draw(0, body.indexCount, 1);
    }

    // Loop through and render all particles
    for (state.particles[0..state.num_particles]) |p| {
        // Update uniforms for the particle
        var uniforms = ParticleUniforms{
            .modelMatrix = calculateModelMatrix(p),
            .color = p.color,
        };
        sg.applyUniforms(.VertexShader, 0, &uniforms, @sizeOf(ParticleUniforms));

        // Draw the particle
        sg.draw(0, p.indexCount, 1);
    }
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

fn calculateModelMatrix(entity: anytype) sg.mat4 {
    const modelMatrix = zlm.translation(entity.pos.x, entity.pos.y, 0.0) * zlm.scaling(entity.radius, entity.radius, 1.0);
    return modelMatrix;
}
