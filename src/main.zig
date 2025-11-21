const std = @import("std");
const sokol = @import("sokol");
const ig = @import("cimgui");

const math = @import("lib/math.zig");
const shader = @import("shader/cube.glsl.zig");

const gfx = sokol.gfx;
const app = sokol.app;
const sfx = sokol.audio;
const gui = sokol.imgui;

const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

const Vertex = extern struct {
    pos: [3]f32,
    col: [4]f32,
};

pub const World = struct {
    blocks: [4096]bool = [_]bool{false} ** 4096,
    vertices: [32768]Vertex = undefined,
    indices: [49152]u16 = undefined,

    fn get(w: *const World, x: i32, y: i32, z: i32) bool {
        if (x < 0 or x >= 16 or y < 0 or y >= 16 or z < 0 or z >= 16) return false;

        const idx = @as(usize, @intCast(x)) + @as(usize, @intCast(y)) * 16 + @as(usize, @intCast(z)) * 256;

        return w.blocks[idx];
    }

    fn collision(w: *const World, min: Vec3, max: Vec3) bool {
        const min_x = @max(0, @as(i32, @intFromFloat(@floor(min.data[0]))));
        const min_y = @max(0, @as(i32, @intFromFloat(@floor(min.data[1]))));
        const min_z = @max(0, @as(i32, @intFromFloat(@floor(min.data[2]))));

        const max_x = @min(16, @as(i32, @intFromFloat(@floor(max.data[0]))) + 1);
        const max_y = @min(16, @as(i32, @intFromFloat(@floor(max.data[1]))) + 1);
        const max_z = @min(16, @as(i32, @intFromFloat(@floor(max.data[2]))) + 1);

        for (@intCast(min_x)..@intCast(max_x)) |x| {
            for (@intCast(min_y)..@intCast(max_y)) |y| {
                for (@intCast(min_z)..@intCast(max_z)) |z| {
                    if (w.get(@intCast(x), @intCast(y), @intCast(z))) return true;
                }
            }
        }

        return false;
    }

    fn mesh(w: *World) u32 {
        var vertices: usize = 0;
        var indices: usize = 0;

        const dirs = [_]@Vector(3, i32){
            .{ 1, 0, 0 },
            .{ -1, 0, 0 },
            .{ 0, 1, 0 },
            .{ 0, -1, 0 },
            .{ 0, 0, 1 },
            .{ 0, 0, -1 },
        };
        const quads = [_][4]@Vector(3, f32){
            .{ .{ 1, 0, 0 }, .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 1, 1, 0 } },
            .{ .{ 0, 0, 1 }, .{ 0, 0, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 1 } },
            .{ .{ 0, 1, 0 }, .{ 1, 1, 0 }, .{ 1, 1, 1 }, .{ 0, 1, 1 } },
            .{ .{ 0, 0, 1 }, .{ 1, 0, 1 }, .{ 1, 0, 0 }, .{ 0, 0, 0 } },
            .{ .{ 1, 0, 1 }, .{ 0, 0, 1 }, .{ 0, 1, 1 }, .{ 1, 1, 1 } },
            .{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 1, 0 }, .{ 0, 1, 0 } },
        };
        const colors = [_][4]f32{
            .{ 1.0, 1.0, 1.0, 1.0 },
            .{ 1.0, 1.0, 1.0, 1.0 },
            .{ 1.0, 1.0, 1.0, 1.0 },
            .{ 1.0, 1.0, 1.0, 1.0 },
            .{ 1.0, 1.0, 1.0, 1.0 },
            .{ 1.0, 1.0, 1.0, 1.0 },
        };

        for (0..16) |x| for (0..16) |y| for (0..16) |z| {
            const idx = x + y * 16 + z * 256;

            if (!w.blocks[idx]) continue;

            const pos = @Vector(3, f32){
                @floatFromInt(x),
                @floatFromInt(y),
                @floatFromInt(z),
            };

            for (dirs, quads, colors) |dir, quad, color| {
                const neighbor = @Vector(3, i32){
                    @intCast(x),
                    @intCast(y),
                    @intCast(z),
                } + dir;

                if (!w.get(neighbor[0], neighbor[1], neighbor[2])) {
                    if (vertices + 4 > w.vertices.len or indices + 6 > w.indices.len) break;

                    const bi = @as(u16, @intCast(vertices));

                    for (quad) |v| {
                        w.vertices[vertices] = .{
                            .pos = .{
                                (pos + v)[0],
                                (pos + v)[1],
                                (pos + v)[2],
                            },
                            .col = color,
                        };

                        vertices += 1;
                    }

                    for ([_]u16{ 0, 1, 2, 0, 2, 3 }) |i| {
                        w.indices[indices] = bi + i;

                        indices += 1;
                    }
                }
            }
        };

        return @intCast(indices);
    }
};

pub const Player = struct {
    pos: Vec3 = .new(2.4743795, 1.8003182, 3.4313726),
    vel: Vec3 = .zero(),
    yaw: f32 = -28.86793,
    pitch: f32 = -0.0359997,
    mouse_dx: f32 = 0,
    mouse_dy: f32 = 0,
    keys: packed struct {
        w: bool = false,
        a: bool = false,
        s: bool = false,
        d: bool = false,
        space: bool = false,
    } = .{},
    mouse_locked: bool = false,

    fn update(p: *Player, w: *const World, dt: f32, jump_time: *f32) void {
        p.yaw += p.mouse_dx * 0.002;
        p.pitch = std.math.clamp(
            p.pitch + p.mouse_dy * 0.002,
            -1.5,
            1.5,
        );
        p.mouse_dx = 0;
        p.mouse_dy = 0;

        const sin_yaw, const cos_yaw = .{
            @sin(p.yaw),
            @cos(p.yaw),
        };

        const forward: f32 = if (p.keys.w) 1.0 else if (p.keys.s) -1.0 else 0.0;
        const strafe: f32 = if (p.keys.d) 1.0 else if (p.keys.a) -1.0 else 0.0;

        p.vel = Vec3.new(
            (sin_yaw * forward + cos_yaw * strafe) * 6.0,
            p.vel.data[1] - 15.0 * dt,
            (-cos_yaw * forward + sin_yaw * strafe) * 6.0,
        );

        const old = p.pos;
        const old_y_vel = p.vel.data[1];

        const hull: Vec3 = .new(0.4, 0.8, 0.4);

        inline for (.{ 0, 2, 1 }) |axis| {
            p.pos.data[axis] += p.vel.data[axis] * dt;

            if (w.collision(.sub(p.pos, hull), .add(p.pos, hull))) {
                p.pos.data[axis] = old.data[axis];

                if (axis == 1) {
                    if (p.keys.space and old_y_vel <= 0) {
                        p.vel.data[1] = 8.0;
                        jump_time.* = 0.15;
                    } else {
                        p.vel.data[1] = 0;
                    }
                }
            }
        }
    }

    fn view(p: *const Player) Mat4 {
        const cy, const sy, const cp, const sp = .{
            @cos(p.yaw),
            @sin(p.yaw),
            @cos(p.pitch),
            @sin(p.pitch),
        };

        return .{
            .data = .{
                cy,
                sy * sp,
                -sy * cp,
                0,
                0,
                cp,
                sp,
                0,
                sy,
                -cy * sp,
                cy * cp,
                0,
                -p.pos.data[0] * cy - p.pos.data[2] * sy,
                -p.pos.data[0] * sy * sp - p.pos.data[1] * cp + p.pos.data[2] * cy * sp,
                p.pos.data[0] * sy * cp - p.pos.data[1] * sp - p.pos.data[2] * cy * cp,
                1,
            },
        };
    }
};

const Render = struct {
    vertices: u32 = undefined,
    pipeline: gfx.Pipeline = undefined,
    bindings: gfx.Bindings = undefined,
    pass_action: gfx.PassAction = undefined,
    proj: Mat4 = undefined,

    fn init(r: *Render, w: *const World, indices: u32) void {
        var layout = gfx.VertexLayoutState{};

        layout.attrs[0].format = .FLOAT3;
        layout.attrs[1].format = .FLOAT4;

        r.pipeline = gfx.makePipeline(.{
            .shader = gfx.makeShader(
                shader.cubeShaderDesc(gfx.queryBackend()),
            ),
            .layout = layout,
            .index_type = .UINT16,
            .depth = .{
                .compare = .LESS_EQUAL,
                .write_enabled = true,
            },
            .cull_mode = .BACK,
        });

        r.bindings = .{
            .vertex_buffers = .{
                gfx.makeBuffer(.{
                    .data = gfx.asRange(w.vertices[0 .. indices / 6 * 4]),
                }),
                .{},
                .{},
                .{},
                .{},
                .{},
                .{},
                .{},
            },
            .index_buffer = gfx.makeBuffer(.{
                .usage = .{ .index_buffer = true },
                .data = gfx.asRange(w.indices[0..indices]),
            }),
        };

        const sky: gfx.Color = .{
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        };

        r.pass_action = .{
            .colors = .{
                .{
                    .load_action = .CLEAR,
                    .clear_value = sky,
                },
                .{},
                .{},
                .{},
                .{},
                .{},
                .{},
                .{},
            },
        };

        r.vertices = indices;

        r.proj = math.perspective(90, 1.33, 0.1, 100);
    }

    fn draw(r: *const Render, view_mat: Mat4) void {
        const mvp: Mat4 = .mul(r.proj, view_mat);

        gfx.beginPass(.{
            .action = r.pass_action,
            .swapchain = sokol.glue.swapchain(),
        });

        gfx.applyPipeline(r.pipeline);
        gfx.applyBindings(r.bindings);

        gfx.applyUniforms(0, gfx.asRange(&mvp));

        gfx.draw(0, r.vertices, 1);
    }

    fn drawCrosshair(_: *const Render, cx: f32, cy: f32, len: f32, thickness: f32, col: ig.ImU32) void {
        const draw_list = ig.igGetWindowDrawList();

        ig.ImDrawList_AddLineEx(
            draw_list,
            .{ .x = cx - len, .y = cy },
            .{ .x = cx + len, .y = cy },
            col,
            thickness,
        );

        ig.ImDrawList_AddLineEx(
            draw_list,
            .{ .x = cx, .y = cy - len },
            .{ .x = cx, .y = cy + len },
            col,
            thickness,
        );
    }

    fn crosshair(r: *const Render) void {
        ig.igSetNextWindowPos(
            .{ .x = 0, .y = 0 },
            ig.ImGuiCond_Always,
        );

        ig.igSetNextWindowSize(.{
            .x = @floatFromInt(app.width()),
            .y = @floatFromInt(app.height()),
        }, ig.ImGuiCond_Always);

        _ = ig.igBegin(
            "##crosshair",
            null,
            ig.ImGuiWindowFlags_NoTitleBar | ig.ImGuiWindowFlags_NoResize | ig.ImGuiWindowFlags_NoMove | ig.ImGuiWindowFlags_NoBackground | ig.ImGuiWindowFlags_NoInputs,
        );

        const cx, const cy = .{
            @as(f32, @floatFromInt(app.width())) * 0.5,
            @as(f32, @floatFromInt(app.height())) * 0.5,
        };

        r.drawCrosshair(cx, cy, 30, 5, 0xFF00FF00);

        ig.igEnd();
    }
};

var Engine = struct {
    world: World = World{},
    player: Player = Player{},
    render: Render = Render{},
    jump_time: f32 = 0,
}{};

fn audio(buf: [*c]f32, frames: i32, channels: i32) callconv(.c) void {
    for (0..@intCast(frames)) |i| {
        const sample: f32 = if (Engine.jump_time > 0) blk: {
            const t = 1.0 - Engine.jump_time / 0.15;

            Engine.jump_time -= 1.0 / 44100.0;

            break :blk @sin(
                (0.15 - Engine.jump_time) * (220.0 + 220.0 * t) * 2.0 * std.math.pi,
            ) * @exp(-t * 8.0) * 0.3;
        } else 0;

        for (0..@as(usize, @intCast(channels))) |ch|
            buf[i * @as(usize, @intCast(channels)) + ch] = sample;
    }
}

export fn init() void {
    gfx.setup(.{ .environment = sokol.glue.environment() });
    sfx.setup(.{ .stream_cb = audio });
    gui.setup(.{});

    for (0..16) |x| for (0..16) |y| for (0..16) |z| {
        if (y == 0 or x == 0 or x == 15 or z == 0 or z == 15 or (x % 4 == 0 and z % 4 == 0 and y < 3)) {
            const idx = x + y * 16 + z * 256;

            Engine.world.blocks[idx] = true;
        }
    };

    const ic = Engine.world.mesh();

    Engine.render.init(&Engine.world, ic);
}

export fn frame() void {
    Engine.player.update(&Engine.world, @floatCast(app.frameDuration()), &Engine.jump_time);

    gui.newFrame(.{
        .width = app.width(),
        .height = app.height(),
        .delta_time = app.frameDuration(),
    });

    Engine.render.draw(Engine.player.view());
    Engine.render.crosshair();

    gui.render();

    gfx.endPass();
    gfx.commit();
}

export fn cleanup() void {
    gui.shutdown();
    sfx.shutdown();
    gfx.shutdown();
}

export fn event(e: [*c]const app.Event) void {
    _ = gui.handleEvent(e.*);

    const key_state = e.*.type == .KEY_DOWN;
    switch (e.*.type) {
        .KEY_DOWN, .KEY_UP => switch (e.*.key_code) {
            .W => Engine.player.keys.w = key_state,
            .A => Engine.player.keys.a = key_state,
            .S => Engine.player.keys.s = key_state,
            .D => Engine.player.keys.d = key_state,
            .Q => app.requestQuit(),
            .P => std.debug.print("Player: {any}\n", .{Engine.player}),
            .SPACE => Engine.player.keys.space = key_state,
            .ESCAPE => if (key_state and Engine.player.mouse_locked) {
                Engine.player.mouse_locked = false;
                app.showMouse(true);
                app.lockMouse(false);
            },
            else => {},
        },
        .MOUSE_DOWN => if (e.*.mouse_button == .LEFT and !Engine.player.mouse_locked) {
            Engine.player.mouse_locked = true;
            app.showMouse(false);
            app.lockMouse(true);
        },
        .MOUSE_MOVE => if (Engine.player.mouse_locked) {
            Engine.player.mouse_dx += e.*.mouse_dx;
            Engine.player.mouse_dy += e.*.mouse_dy;
        },
        else => {},
    }
}

pub fn main() void {
    app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .window_title = "FPS",
        .fullscreen = true,
        .high_dpi = true,
    });
}

test "World.get basic block access" {
    var w = World{};

    const idx = 1 + 2 * 16 + 3 * 256;

    w.blocks[idx] = true;

    try std.testing.expect(w.get(1, 2, 3) == true);
    try std.testing.expect(w.get(0, 0, 0) == false);
}

test "World.get out of bounds returns false" {
    var w = World{};

    try std.testing.expect(!w.get(-1, 0, 0));
    try std.testing.expect(!w.get(16, 0, 0));
    try std.testing.expect(!w.get(0, -1, 0));
    try std.testing.expect(!w.get(0, 16, 0));
    try std.testing.expect(!w.get(0, 0, 16));
}

test "World.collision detects filled voxel" {
    var w = World{};

    const idx = 5 + 5 * 16 + 5 * 256;

    w.blocks[idx] = true;

    // Bounding box that overlaps the voxel at (5,5,5)
    const min = Vec3.new(4.8, 4.8, 4.8);
    const max = Vec3.new(5.2, 5.2, 5.2);

    try std.testing.expect(w.collision(min, max) == true);

    // Move bounding box away → no collision
    const min2 = Vec3.new(6.0, 6.0, 6.0);
    const max2 = Vec3.new(6.5, 6.5, 6.5);

    try std.testing.expect(w.collision(min2, max2) == false);
}

test "Player.update basic forward movement" {
    var w = World{};
    var p = Player{};

    p.keys.w = true;

    const old_pos = p.pos;

    var jt: f32 = 0;

    p.update(&w, 0.1, &jt);

    try std.testing.expect(p.pos.data[2] != old_pos.data[2]); // moved
}

test "Player.view returns matrix with correct w column" {
    var p = Player{};

    p.pos = Vec3.new(2, 3, 4);

    const m = p.view();

    try std.testing.expect(m.data[15] == 1);
}
