#version 460 core

// Screen-space quad pipeline: a rounded rectangle, textured/tinted, with an
// optional border, evaluated in pixel space.

in vec2       v_uv;
in vec4       v_tint;
in vec2       v_local_px;
flat in vec2  v_half_size_px;
flat in int   v_texture_unit;
flat in float v_border_thickness;
flat in vec4  v_border_color;
flat in vec2  v_clip_lo;
flat in vec2  v_clip_hi;
flat in float v_clip_enabled;
flat in vec4  v_corner_radii;

uniform sampler2D u_textures[MAX_TEXTURES];

out vec4 out_color;

vec4 sample_texture(int idx, vec2 uv) {
  for (int i = 0; i < MAX_TEXTURES; ++i) {
    if (i == idx) return texture(u_textures[i], uv);
  }
  return vec4(1.0);
}

// The radius for the corner the fragment `p` sits in. rr = (TL, TR, BR, BL),
// screen space (+x right, +y down).
float corner_radius_at(vec2 p, vec4 rr) {
  float top = (p.x < 0.0) ? rr.x : rr.y;
  float bot = (p.x < 0.0) ? rr.w : rr.z;
  return (p.y < 0.0) ? top : bot;
}

void main() {
  if (v_clip_enabled > 0.5) {
    if (gl_FragCoord.x <  v_clip_lo.x || gl_FragCoord.x >= v_clip_hi.x ||
        gl_FragCoord.y <  v_clip_lo.y || gl_FragCoord.y >= v_clip_hi.y) discard;
  }

  vec4 base     = sample_texture(v_texture_unit, v_uv) * v_tint;
  bool bordered = v_border_thickness > 0.0;

  // Only a corner arc's outer silhouette is antialiased - straight edges and
  // the border's inner edge stay hard, so abutting panels don't seam and a
  // thin border doesn't darken on the curves.
  vec4  radii  = clamp(v_corner_radii, 0.0, min(v_half_size_px.x, v_half_size_px.y));
  float radius = corner_radius_at(v_local_px, radii);
  bool  rounded_any = any(greaterThan(radii, vec4(0.0)));
  if (!rounded_any && !bordered) { out_color = base; return; }

  vec2  q    = abs(v_local_px) - v_half_size_px + radius;
  bool  arc  = radius > 0.0 && q.x > 0.0 && q.y > 0.0;
  float dist = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;

  float outer_alpha = step(dist, 0.0);
  if (arc) {
    float aa = max(fwidth(dist), 1e-4);
    outer_alpha = 1.0 - smoothstep(-aa, aa, dist);
  }

  vec4 color = base;
  if (bordered) {
    float in_border = 1.0 - step(dist + v_border_thickness, 0.0); // hard, arc and straight alike
    color = mix(base, v_border_color, in_border);
  }
  color.a *= outer_alpha;
  if (color.a <= 0.0) discard;
  out_color = color;
}
