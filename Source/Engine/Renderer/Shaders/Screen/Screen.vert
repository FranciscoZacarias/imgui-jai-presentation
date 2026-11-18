#version 460 core

// Screen-space quad pipeline.
// Positions are in pixels with a top-left origin (+X right, +Y down).

layout(location = 0) in vec2  a_corner;            // unit quad corner, 0..1

layout(location = 1) in vec2  i_top_left;
layout(location = 2) in vec2  i_size;
layout(location = 3) in vec2  i_uv_min;
layout(location = 4) in vec2  i_uv_max;
layout(location = 5) in uint  i_tint;
layout(location = 6) in int   i_texture_unit;
layout(location = 7) in float i_border_thickness;
layout(location = 8) in uint  i_border_color;
layout(location = 9) in vec2  i_clip_min;   // top-left px; clip_max.x <= clip_min.x => no clip
layout(location = 10) in vec2 i_clip_max;
layout(location = 11) in float i_rotation;  // radians, about the quad centre (0 = axis-aligned)
layout(location = 12) in vec4  i_corner_radii;

uniform vec2 u_screen_size;

out vec2       v_uv;
out vec4       v_tint;
out vec2       v_local_px;        // fragment position inside the quad, pixels, origin = centre
flat out vec2  v_half_size_px;
flat out int   v_texture_unit;
flat out float v_border_thickness;
flat out vec4  v_border_color;
flat out vec2  v_clip_lo;         // clip rect in gl_FragCoord space (bottom-left origin)
flat out vec2  v_clip_hi;
flat out float v_clip_enabled;
flat out vec4  v_corner_radii;

out gl_PerVertex { vec4 gl_Position; };

vec4 unpack_rgba(uint c) {
  return vec4(float( c        & 0xFFu),
             float((c >>  8u) & 0xFFu),
             float((c >> 16u) & 0xFFu),
             float((c >> 24u) & 0xFFu)) / 255.0;
}

void main() {
  vec2  local = (a_corner - 0.5) * i_size;   // corner offset from the quad centre
  vec2  px;
  if (i_rotation != 0.0) {
    float s = sin(i_rotation), c = cos(i_rotation);
    vec2  rotated = vec2(local.x * c - local.y * s, local.x * s + local.y * c);
    px = i_top_left + i_size * 0.5 + rotated;
  } else {
    px = i_top_left + a_corner * i_size;
  }
  vec2 ndc = vec2((px.x / u_screen_size.x) * 2.0 - 1.0,
                  1.0 - (px.y / u_screen_size.y) * 2.0);
  gl_Position = vec4(ndc, 0.0, 1.0);

  v_uv   = mix(i_uv_min, i_uv_max, a_corner);
  v_tint = unpack_rgba(i_tint);

  v_half_size_px = i_size * 0.5;
  v_local_px     = local;

  v_texture_unit     = i_texture_unit;
  v_border_thickness = i_border_thickness;
  v_border_color     = unpack_rgba(i_border_color);
  v_corner_radii     = i_corner_radii;

  if (i_clip_max.x > i_clip_min.x) {
    v_clip_enabled = 1.0;
    v_clip_lo = vec2(i_clip_min.x, u_screen_size.y - i_clip_max.y);
    v_clip_hi = vec2(i_clip_max.x, u_screen_size.y - i_clip_min.y);
  } else {
    v_clip_enabled = 0.0;
    v_clip_lo = vec2(0.0);
    v_clip_hi = vec2(0.0);
  }
}
