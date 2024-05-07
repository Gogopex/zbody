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
const mem = std.mem;
const Allocator = mem.Allocator;

const MAX_BODIES = 10;
const G = 6.67430e-11;
const SMALL_G = 6.67430e-4;
const damping = 0.99;

const QuadTreeError = error{
    OutOfMemory,
    PositionOutOfBounds,
};

const State = struct {
    var bindings: sg.Bindings = .{};
    var pipeline: sg.Pipeline = .{};
    var pass_action: sg.PassAction = .{};
};

const Body = struct {
    pos: vec2,
    vel: vec2,
    mass: f32,
    radius: f32,
    color: RGBA,
    force: vec2,

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

pub const RGBA = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn new() RGBA {
        return RGBA{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 };
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

    fn clear(this: *QuadTree) void {
        this.bodies.items = &[_]Body{};
        this.centerOfMass = vec2.zero();
        this.totalMass = 0.0;
        this.divided = false;
        if (this.nw) |nw| {
            nw.clear();
        }
        if (this.ne) |ne| {
            ne.clear();
        }
        if (this.sw) |sw| {
            sw.clear();
        }
        if (this.se) |se| {
            se.clear();
        }
        this.nw = null;
        this.ne = null;
        this.sw = null;
        this.se = null;
    }

    fn insert(this: *QuadTree, body: Body) Allocator.Error!bool {
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
        this.nw = QuadTree{ .boundary = Rect{ .x = x, .y = y, .width = w, .height = h }, .bodies = std.ArrayList(Body).init(Allocator), .divided = false, .nw = null, .ne = null, .sw = null, .se = null };
        this.ne = QuadTree{ .boundary = Rect{ .x = x + w, .y = y, .width = w, .height = h }, .bodies = std.ArrayList(Body).init(Allocator), .divided = false, .nw = null, .ne = null, .sw = null, .se = null };
        this.sw = QuadTree{ .boundary = Rect{ .x = x, .y = y + h, .width = w, .height = h }, .bodies = std.ArrayList(Body).init(Allocator), .divided = false, .nw = null, .ne = null, .sw = null, .se = null };
        this.se = QuadTree{ .boundary = Rect{ .x = x + w, .y = y + h, .width = w, .height = h }, .bodies = std.ArrayList(Body).init(Allocator), .divided = false, .nw = null, .ne = null, .sw = null, .se = null };
        this.divided = true;

        // Redistribute existing bodies into new quadrants
        for (this.bodies.items) |body| {
            _ = this.insert(body);
        }
        // Clear the original bodies list as they are now in the sub-quadrants
        this.bodies.deinit();
    }

    fn query(this: *QuadTree, range: Rect, found: *std.ArrayList(Body)) void {
        if (!this.boundary.intersects(range)) {
            return;
        }
        for (this.bodies.items) |body| {
            if (range.contains(body.pos)) {
                found.append(body);
            }
        }
    }

    fn shouldApproximate(this: *QuadTree, body: *Body) bool {
        const d = this.centerOfMass.sub(body.pos).length();
        return this.boundary.width / d < 0.5;
    }

    fn calculateApproximateForce(body: *Body, centerOfMass: vec2, totalMass: f32) vec2 {
        const r = centerOfMass.sub(body.pos);
        const distanceSquared = r.lengthSquared();
        if (distanceSquared > 0.00001) {
            const f = G * body.mass * totalMass / distanceSquared;
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

export fn init() void {
    std.debug.print("init", .{});
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

    const gpa = std.heap.page_allocator;
    bodies = std.ArrayList(Body).init(gpa);

    defer bodies.deinit();

    var prng = std.rand.DefaultPrng.init(42);
    for (0..MAX_BODIES) |_| {
        const x = prng.random().float(f32) * 100;
        const y = prng.random().float(f32) * 100;
        const vel_x = prng.random().float(f32) * 2 - 1;
        const vel_y = prng.random().float(f32) * 2 - 1;
        const mass = prng.random().float(f32) * 10 + 1;
        const radius = prng.random().float(f32) * 5 + 1;
        const color = RGBA.new();
        const force = vec2.zero();
        const body = Body{ .pos = vec2{ .x = x, .y = y }, .vel = vec2{ .x = vel_x, .y = vel_y }, .mass = mass, .radius = radius, .color = color, .force = force };
        const res = bodies.append(body) catch |err| {
            std.debug.print("Error appending body: {}\n", .{err});
            break;
        };
        _ = res;
    }

    //print bodies
    std.debug.print("bodies: {}", .{bodies});

    quadtree = QuadTree{ .boundary = Rect{ .x = 0, .y = 0, .width = 100, .height = 100 }, .depth = 0, .bodies = bodies, .centerOfMass = vec2.zero(), .totalMass = 0.0, .divided = false, .nw = null, .ne = null, .sw = null, .se = null };

    for (bodies.items) |body| {
        const success = quadtree.insert(body) catch |err| {
            std.debug.print("Insertion failed with error: {}\n", .{err});
            continue;
        };
        if (!success) {
            std.debug.print("Failed to insert body.\n", .{});
        }
    }
}

export fn frame() void {
    const frame_count = sapp.frameCount();
    std.debug.print("Frame count: {}\n", .{frame_count});

    sgl.defaults();
    sgl.beginPoints();

    updatePhysics() catch |err| {
        std.debug.print("Failed to update physics: {}\n", .{err});
    };

    std.debug.print("Quadtree: {}\n", .{quadtree});
    std.debug.print("Bodies: {}\n", .{quadtree.bodies.items.len});
    if (quadtree.bodies.items.len > 0) {
        for (0..quadtree.bodies.items.len) |i| {
            sgl.c3f(10.0, 0.0, 0.0);
            sgl.v2f(quadtree.bodies.items[i].pos.x, quadtree.bodies.items[i].pos.y);
            sgl.pointSize(quadtree.bodies.items[i].radius);
            std.debug.print("Body #{}: x: {}, y: {}\n", .{ i, quadtree.bodies.items[i].pos.x, quadtree.bodies.items[i].pos.y });
        }
    } else {
        std.debug.print("No bodies to render.\n", .{});
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

fn updatePhysics() QuadTreeError!void {
    quadtree.clear();

    for (quadtree.bodies.items) |body| {
        const success = quadtree.insert(body) catch |err| {
            std.debug.print("Insertion failed with error: {}\n", .{err});
            continue;
        };
        if (!success) {
            std.debug.print("Failed to insert body.\n", .{});
        }
    }

    for (quadtree.bodies.items) |*body| {
        var force = vec2.zero();
        quadtree.calculateForce(body, &force);
        body.force = force;
    }

    const dt: f32 = 0.1;
    for (quadtree.bodies.items) |*body| {
        const acceleration = body.force.scale(1.0 / body.mass);
        body.vel = body.vel.add(acceleration.scale(dt));
        body.pos = body.pos.add(body.vel.scale(dt));
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

fn calculateForce(body: Body, force: *vec2) void {
    if (quadtree.divided) {
        if (quadtree.boundary.contains(body.pos)) {
            for (0..quadtree.bodies.len) |i| {
                const other = quadtree.bodies.items[i];
                if (other != body) {
                    const f = body.updateForce(&other);
                    force.add(f);
                }
            }
        } else {
            if (quadtree.boundary.intersects(body.pos)) {
                if (quadtree.nw == null) {
                    quadtree.subdivide();
                }
                if (quadtree.nw) |nw| {
                    nw.calculateForce(body, force);
                }
                if (quadtree.ne) |ne| {
                    ne.calculateForce(body, force);
                }
                if (quadtree.sw) |sw| {
                    sw.calculateForce(body, force);
                }
                if (quadtree.se) |se| {
                    se.calculateForce(body, force);
                }
            }
        }
    }
}
