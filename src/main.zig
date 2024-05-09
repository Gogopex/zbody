const std = @import("std");
const sokol = @import("sokol");
const vec2 = @import("math.zig").Vec2;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const slog = sokol.log;
const sgl = sokol.gl;

const SimulationParams = struct {
    const max_bodies = 50;
    const gravity_constant = 50.0;
    const damping = 0.9995;
    const softening = 100.0;
    const dt = 0.016;
    const world_size = 700.0;
    const central_mass = 1000.0;
    const central_force_multiplier = 1.0;
    const repulsion_radius = 50.0;
    const repulsion_strength = 500.0;
};

const Body = struct {
    pos: vec2,
    vel: vec2,
    mass: f32,
    radius: f32,
    color: Color,
    force: vec2,

    fn updateForce(this: *Body, other: *Body) vec2 {
        const r = other.pos.sub(this.pos);
        const distanceSquared = r.lengthSquared();
        if (distanceSquared > 0.00001) {
            const f = SimulationParams.gravity_constant * this.mass * other.mass / (distanceSquared + SimulationParams.softening);
            return r.normalize().scale(f);
        }
        return vec2{ .x = 0.0, .y = 0.0 };
    }
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn random(rng: *std.Random.DefaultPrng) Color {
        return .{
            .r = rng.random().int(u8),
            .g = rng.random().int(u8),
            .b = rng.random().int(u8),
            .a = 255,
        };
    }
    
    pub fn toNormalized(self: Color) struct { r: f32, g: f32, b: f32, a: f32 } {
        return .{
            .r = @as(f32, @floatFromInt(self.r)) / 255.0,
            .g = @as(f32, @floatFromInt(self.g)) / 255.0,
            .b = @as(f32, @floatFromInt(self.b)) / 255.0,
            .a = @as(f32, @floatFromInt(self.a)) / 255.0,
        };
    }
};

const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    fn contains(this: Rect, point: vec2) bool {
        return point.x >= this.x and point.x <= this.x + this.width and point.y >= this.y and point.y <= this.y + this.height;
    }

    fn intersects(this: Rect, other: Rect) bool {
        return this.x < other.x + other.width and
            this.x + this.width > other.x and
            this.y < other.y + other.height and
            this.y + this.height > other.y;
    }
};

const QuadTree = struct {
    boundary: Rect,
    depth: u32,
    bodies: std.ArrayList(Body),
    centerOfMass: vec2,
    totalMass: f32,
    divided: bool,
    nw: ?*QuadTree,
    ne: ?*QuadTree,
    sw: ?*QuadTree,
    se: ?*QuadTree,

    fn insert(this: *QuadTree, body: Body) std.mem.Allocator.Error!bool {
        if (!this.boundary.contains(body.pos)) {
            return false;
        }
        try this.bodies.append(body);
        this.updateCenterOfMassAndTotalMass(body);
        return true;
    }

    fn updateCenterOfMassAndTotalMass(this: *QuadTree, body: Body) void {
        const oldTotalMass = this.totalMass;
        this.totalMass += body.mass;
        if (oldTotalMass == 0) {
            this.centerOfMass = body.pos;
        } else {
            this.centerOfMass = this.centerOfMass.scale(oldTotalMass).add(body.pos.scale(body.mass)).scale(1 / this.totalMass);
        }
    }

    fn subdivide(this: *QuadTree) void {
        const x = this.boundary.x;
        const y = this.boundary.y;
        const w = this.boundary.width / 2;
        const h = this.boundary.height / 2;
        const alloc = std.heap.page_allocator;
        this.nw = alloc.create(QuadTree) catch return;
        this.ne = alloc.create(QuadTree) catch return;
        this.sw = alloc.create(QuadTree) catch return;
        this.se = alloc.create(QuadTree) catch return;
        this.nw.* = QuadTree{ .boundary = Rect{ .x = x, .y = y, .width = w, .height = h }, .depth = this.depth + 1, .bodies = std.ArrayList(Body).init(alloc), .centerOfMass = vec2.zero(), .totalMass = 0.0, .divided = false, .nw = null, .ne = null, .sw = null, .se = null };
        this.ne.* = QuadTree{ .boundary = Rect{ .x = x + w, .y = y, .width = w, .height = h }, .depth = this.depth + 1, .bodies = std.ArrayList(Body).init(alloc), .centerOfMass = vec2.zero(), .totalMass = 0.0, .divided = false, .nw = null, .ne = null, .sw = null, .se = null };
        this.sw.* = QuadTree{ .boundary = Rect{ .x = x, .y = y + h, .width = w, .height = h }, .depth = this.depth + 1, .bodies = std.ArrayList(Body).init(alloc), .centerOfMass = vec2.zero(), .totalMass = 0.0, .divided = false, .nw = null, .ne = null, .sw = null, .se = null };
        this.se.* = QuadTree{ .boundary = Rect{ .x = x + w, .y = y + h, .width = w, .height = h }, .depth = this.depth + 1, .bodies = std.ArrayList(Body).init(alloc), .centerOfMass = vec2.zero(), .totalMass = 0.0, .divided = false, .nw = null, .ne = null, .sw = null, .se = null };
        this.divided = true;

        for (this.bodies.items) |body| {
            _ = this.insert(body);
        }
        this.bodies.clearRetainingCapacity();
    }

    fn shouldApproximate(this: *QuadTree, body: *Body) bool {
        const d = this.centerOfMass.sub(body.pos).length();
        return this.boundary.width / d < 0.5;
    }

    fn calculateApproximateForce(body: *Body, centerOfMass: vec2, totalMass: f32) vec2 {
        const r = centerOfMass.sub(body.pos);
        const distanceSquared = r.lengthSquared();
        if (distanceSquared > 0.00001) {
            const f = SimulationParams.gravity_constant * body.mass * totalMass / (distanceSquared + SimulationParams.softening);
            return r.normalize().scale(f);
        }
        return vec2{ .x = 0.0, .y = 0.0 };
    }

    fn calculateForce(this: *QuadTree, body: *Body, force: *vec2) void {
        if (this.divided) {
            if (this.shouldApproximate(body)) {
                const f = calculateApproximateForce(body, this.centerOfMass, this.totalMass);
                force.* = force.*.add(f);
            } else {
                if (this.nw) |nw| {
                    nw.calculateForce(body, force);
                }
                if (this.ne) |ne| {
                    ne.calculateForce(body, force);
                }
                if (this.sw) |sw| {
                    sw.calculateForce(body, force);
                }
                if (this.se) |se| {
                    se.calculateForce(body, force);
                }
            }
        } else {
            for (this.bodies.items) |*other| {
                if (other != body) {
                    const f = body.updateForce(other);
                    force.* = force.*.add(f);
                }
            }
        }
    }
};

var bodies: std.ArrayList(Body) = undefined;
var quadtree: QuadTree = undefined;
var pass_action: sg.PassAction = .{};

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });
    sgl.setup(.{
        .logger = .{ .func = slog.func },
    });
    pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.02, .g = 0.02, .b = 0.05 },
    };

    const gpa = std.heap.page_allocator;
    bodies = std.ArrayList(Body).init(gpa);

    var prng = std.Random.DefaultPrng.init(42);
    for (0..SimulationParams.max_bodies) |_| {
        const angle = prng.random().float(f32) * 2.0 * std.math.pi;
        const orbit_radius = prng.random().float(f32) * 250 + 100;
        const x = SimulationParams.world_size / 2.0 + @cos(angle) * orbit_radius;
        const y = SimulationParams.world_size / 2.0 + @sin(angle) * orbit_radius;
        
        const orbital_speed = @sqrt(SimulationParams.gravity_constant * SimulationParams.central_mass * SimulationParams.central_force_multiplier / orbit_radius) * 0.8;
        const vel_x = -@sin(angle) * orbital_speed + (prng.random().float(f32) - 0.5) * 20;
        const vel_y = @cos(angle) * orbital_speed + (prng.random().float(f32) - 0.5) * 20;
        const mass = prng.random().float(f32) * 50 + 10;
        const body_radius = prng.random().float(f32) * 8 + 2;
        const color = Color.random(&prng);
        const force = vec2.zero();
        const body = Body{ .pos = vec2{ .x = x, .y = y }, .vel = vec2{ .x = vel_x, .y = vel_y }, .mass = mass, .radius = body_radius, .color = color, .force = force };
        bodies.append(body) catch break;
    }

    quadtree = QuadTree{ 
        .boundary = Rect{ .x = 0, .y = 0, .width = SimulationParams.world_size, .height = SimulationParams.world_size }, 
        .depth = 0, 
        .bodies = bodies, 
        .centerOfMass = vec2.zero(), 
        .totalMass = 0.0, 
        .divided = false, 
        .nw = null, 
        .ne = null, 
        .sw = null, 
        .se = null 
    };

    for (bodies.items) |body| {
        _ = quadtree.insert(body) catch continue;
    }
}

export fn frame() void {
    sgl.defaults();
    sgl.matrixModeProjection();
    sgl.ortho(-1.0, 1.0, 1.0, -1.0, -1.0, 1.0);

    updatePhysics() catch {};

    drawCircle(0.0, 0.0, 20.0 / (SimulationParams.world_size / 2.0), 0.8, 0.4, 1.0, 0.1, 3.0);
    drawCircle(0.0, 0.0, 20.0 / (SimulationParams.world_size / 2.0), 1.0, 0.6, 1.0, 0.9, 1.0);
    
    if (quadtree.bodies.items.len > 0) {
        for (quadtree.bodies.items) |body| {
            const norm_x = (body.pos.x / (SimulationParams.world_size / 2.0)) - 1.0;
            const norm_y = -((body.pos.y / (SimulationParams.world_size / 2.0)) - 1.0);
            const color = body.color.toNormalized();
            const radius_norm = body.radius / (SimulationParams.world_size / 2.0);
            
            drawCircle(norm_x, norm_y, radius_norm, color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.2, 2.0);
            drawCircle(norm_x, norm_y, radius_norm, color.r, color.g, color.b, 1.0, 1.0);
        }
    }

    sg.beginPass(.{ .action = pass_action, .swapchain = sglue.swapchain() });
    sgl.draw();
    sg.endPass();
    sg.commit();
}

fn drawCircle(cx: f32, cy: f32, radius: f32, r: f32, g: f32, b: f32, a: f32, scale: f32) void {
    sgl.beginTriangles();
    sgl.c4f(r, g, b, a);
    const segments = 32;
    var i: u32 = 0;
    while (i < segments) : (i += 1) {
        const a1 = @as(f32, @floatFromInt(i)) * 2.0 * std.math.pi / @as(f32, segments);
        const a2 = @as(f32, @floatFromInt(i + 1)) * 2.0 * std.math.pi / @as(f32, segments);
        
        sgl.v2f(cx, cy);
        sgl.v2f(cx + @cos(a1) * radius * scale, cy + @sin(a1) * radius * scale);
        sgl.v2f(cx + @cos(a2) * radius * scale, cy + @sin(a2) * radius * scale);
    }
    sgl.end();
}

export fn cleanup() void {
    sgl.shutdown();
    sg.shutdown();
}

fn updatePhysics() !void {
    const center = vec2{ .x = SimulationParams.world_size / 2.0, .y = SimulationParams.world_size / 2.0 };
    
    for (quadtree.bodies.items) |*body| {
        var force = vec2.zero();
        quadtree.calculateForce(body, &force);
        
        const r = center.sub(body.pos);
        const dist = @sqrt(r.lengthSquared());
        
        if (dist > 0.1) {
            if (dist < SimulationParams.repulsion_radius) {
                const repulsion = SimulationParams.repulsion_strength * body.mass / (dist * dist + 10.0);
                force = force.sub(r.normalize().scale(repulsion));
            } else {
                const dist_sq = dist * dist;
                const central_force = SimulationParams.gravity_constant * SimulationParams.central_force_multiplier * body.mass * SimulationParams.central_mass / (dist_sq + SimulationParams.softening);
                force = force.add(r.normalize().scale(central_force));
            }
        }
        
        body.force = force;
    }

    for (quadtree.bodies.items) |*body| {
        const acceleration = body.force.scale(1.0 / body.mass);
        body.vel = body.vel.add(acceleration.scale(SimulationParams.dt)).scale(SimulationParams.damping);
        body.pos = body.pos.add(body.vel.scale(SimulationParams.dt));
        
        if (body.pos.x < 0 or body.pos.x > SimulationParams.world_size) {
            body.vel.x = -body.vel.x * 0.8;
            body.pos.x = @max(0, @min(SimulationParams.world_size, body.pos.x));
        }
        if (body.pos.y < 0 or body.pos.y > SimulationParams.world_size) {
            body.vel.y = -body.vel.y * 0.8;
            body.pos.y = @max(0, @min(SimulationParams.world_size, body.pos.y));
        }
    }
}

pub fn main() void {
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