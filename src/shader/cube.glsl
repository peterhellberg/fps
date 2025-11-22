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
  vec3 n = cross(dFdx(world_pos), dFdy(world_pos));

  float len = length(n);
  if (len > 0.0) {
      n /= len;
  } else {
      n = vec3(0.0, 1.0, 0.0); // fallback
  }

  vec3 absN = abs(n);
  
  // Select UV plane based on face normal
  vec2 uv;
  
  if (absN.x >= absN.y && absN.x >= absN.z) {
      uv = world_pos.yz; // X is dominant
  } else if (absN.y >= absN.z) {
      uv = world_pos.xz; // Y is dominant
  } else {
      uv = world_pos.xy; // Z is dominant
  }
  
  float scaleX = 1.0;
  float scaleY = 1.0;

  // Apply scaling to maintain square voxels
  uv *= vec2(scaleX, scaleY);

  // Voxel grid
  vec2 grid = fract(uv*2.0);

  // Smooth outline
  float outline = min(min(grid.x, 1.0 - grid.x), min(grid.y, 1.0 - grid.y));

  float outlineWidth = 0.15;
  float bloomStart   = outlineWidth;
  float bloomEnd     = 0.30;  // controls bloom size

  // Hard outline
  float outlineEdge = 1.0 - step(outlineWidth, outline);

  // Soft bloom halo
  float bloom = 1.0 - smoothstep(bloomStart, bloomEnd, outline);

  // Combine (bloom adds brightness)
  float edge = outlineEdge + bloom * 0.8;

  // Face tint based on normal
  vec3 face_tint;

  if (abs(n.x) > 0.5) {
    face_tint = vec3(1.0, 0.4, 0.0);
  } else if (abs(n.z) > 0.0) {
    face_tint = vec3(0.1, 0.1, 0.1);
  } else {
    face_tint = vec3(0.3, 0.3, 0.3);
  }

  float light = 0.75 + 0.25 * abs(n.y) + 0.1 * sin(world_pos.y * 5.0);
  light = clamp(light, 0.0, 1.0);

  float variation = 0.85 + 0.15 * fract(sin(dot(floor(world_pos.xy), vec2(12.9898, 78.233))) * 43758.5453);
  face_tint *= 0.85 + 0.15 * variation;
  frag_color = vec4(face_tint * edge * light, color.a * 0.6);
}
@end

@program cube vs fs
