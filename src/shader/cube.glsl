@header const math = @import("../lib/math.zig")
@ctype mat4 math.Mat4

@vs vs
layout(binding = 0) uniform vs_params { 
  mat4 mvp; 
};

in vec4 position;
in vec4 color0;

out vec4 color;
out vec3 world_pos;

void main() {
    gl_Position = mvp * position;
    world_pos = position.xyz;
    color = color0;
}
@end

@fs fs
in vec4 color;
in vec3 world_pos;
out vec4 frag_color;

void main() {
    // Compute face normal
    vec3 n = normalize(cross(dFdx(world_pos), dFdy(world_pos)));

    // Face-based UV
    vec2 uv = (abs(n.x) > 0.5) ? world_pos.yz
             : (abs(n.y) > 0.5) ? world_pos.xz
             : world_pos.xy;

    // Grid for voxel outlines
    vec2 grid = fract(uv * 4);

    // Smooth outline
    float outline = min(min(grid.x, 1.0 - grid.x), min(grid.y, 1.0 - grid.y));
    float edge = 1.0 - smoothstep(0.05, 0.08, outline);

    // Face tint based on normal with complementary colors
    vec3 face_tint;
    
    if (abs(n.x) > 0.5) {
        face_tint = vec3(1.0, 0.4, 0.0); // #FF6600
    } else if (abs(n.y) > 0.5) {
        face_tint = vec3(0.0, 1.0, 1.0); // #00FFFF
    } else {
        face_tint = vec3(0.0, 0.8, 0.66); // #00CCAA
    }

    // Lighten lighting: less directional shadow, more ambient
    float light = dot(n, normalize(vec3(0.0, -1.0, -1.0))) * 0.3 + 0.7;

    // clamp to avoid overbright
    light = clamp(light, 0.0, 1.0);

    // Optional procedural variation per voxel for slight color variation
    float variation = fract(sin(dot(floor(world_pos.xy), vec2(12.9898,78.233))) * 43758.5453);

    face_tint *= 0.85 + 0.15 * variation;

    frag_color = vec4(face_tint * edge * light, color.a);
}
@end

@program cube vs fs
