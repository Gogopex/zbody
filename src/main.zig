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
    vel: vec2,
    mass: f32,
    radius: f32,
    color: RGB,
};

const MAX_BODIES = 3;
const G = 6.67430e-11;

const State = struct {
    // instantiate bodies with 3 elements
    var bodies: [MAX_BODIES]Body = .{
        .{ .pos = .{ .x = 0.0, .y = 0.0 }, .mass = 0.0, .radius = 0.0, .color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 }, .vel = .{ .x = 0.0, .y = 0.0 } },
        .{ .pos = .{ .x = 0.0, .y = 0.0 }, .mass = 0.0, .radius = 0.0, .color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 }, .vel = .{ .x = 0.0, .y = 0.0 } },
        .{ .pos = .{ .x = 0.0, .y = 0.0 }, .mass = 0.0, .radius = 0.0, .color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 }, .vel = .{ .x = 0.0, .y = 0.0 } },
    };
    var bindings: sg.Bindings = .{};
    var pipeline: sg.Pipeline = .{};
    var pass_action: sg.PassAction = .{};
};

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
    for (&State.bodies) |*b| {
        b.*.pos = vec2{
            .x = rng.random().float(f32) * 800.0, // Range from 0 to 800
            .y = rng.random().float(f32) * 600.0, // Range from 0 to 600
        };
        b.*.mass = 1.0;
        b.*.radius = 50.0; // Set radius to 50 pixels for bodies
        b.*.color = RGB{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 }; // Red color for bodies
    }

    State.pass_action.colors[0].load_action = .CLEAR;
    State.pass_action.colors[0].clear_value = sg.Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 }; // Clear to black
    State.pass_action.depth.load_action = .DONTCARE;
    State.pass_action.stencil.load_action = .DONTCARE;
}

export fn frame() callconv(.C) void {
    sg.beginPass(.{ .action = State.pass_action, .swapchain = sglue.swapchain() });

    std.debug.print("Rendering frame\n", .{});

    const bodyRadius = pixelsToWorldUnits(50.0, 600.0, 2.0);

    // Update bodies based on gravity from bodies
    for (0..MAX_BODIES) |i| {
        var force = vec2{ .x = 0.0, .y = 0.0 };
        for (0..MAX_BODIES) |j| {
            if (i != j) {
                const r = State.bodies[j].pos.sub(State.bodies[i].pos);
                const r_squared = r.lengthSquared();
                if (r_squared > 0.0001) {
                    const f = G * State.bodies[j].mass * State.bodies[i].mass / r_squared;
                    force = force.add(r.normalize().scale(f));
                }
            }
        }
        State.bodies[i].vel = State.bodies[i].vel.add(force.scale(1.0 / State.bodies[i].mass));
        State.bodies[i].pos = State.bodies[i].pos.add(State.bodies[i].vel.scale(1.0 / 60.0)); // Assuming 60 FPS
    }

    // debug
    drawCircle(vec2{ .x = 15.0, .y = 15.0 }, bodyRadius, 12, RGB{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 });

    // Render bodies
    for (State.bodies) |b| {
        std.debug.print("Body position: ({}, {})\n", .{ b.pos.x, b.pos.y });
        drawCircle(b.pos, bodyRadius, 12, b.color);
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
    sgl.sgl_c4f(color.r, color.g, color.b, color.a);
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

fn pixelsToWorldUnits(pixels: f32, screenSize: f32, worldSize: f32) f32 {
    return (pixels / screenSize) * worldSize;
}

pub fn getOrthographicProjectionMatrix(width: f32, height: f32) mat4 {
    const left = 0.0;
    const right = width;
    const bottom = height;
    const top = 0.0;
    const near = -1.0;
    const far = 1.0;

    return mat4.orthographic(left, right, bottom, top, near, far);
}
