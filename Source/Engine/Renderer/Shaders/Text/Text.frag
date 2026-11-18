#version 460 core

// Text screen-space pipeline.
// The glyph atlas stores coverage in the alpha channel (white RGB + alpha mask).

in vec2       v_uv;
in vec4       v_tint;
flat in int   v_texture_unit;
flat in vec2  v_clip_lo;
flat in vec2  v_clip_hi;
flat in float v_clip_enabled;

uniform sampler2D u_textures[MAX_TEXTURES];

out vec4 out_color;

float sample_coverage(int idx, vec2 uv) {
  for (int i = 0; i < MAX_TEXTURES; ++i) {
    if (i == idx) return texture(u_textures[i], uv).a;
  }
  return 0.0;
}

void main() {
  if (v_clip_enabled > 0.5) {
    if (gl_FragCoord.x <  v_clip_lo.x || gl_FragCoord.x >= v_clip_hi.x ||
        gl_FragCoord.y <  v_clip_lo.y || gl_FragCoord.y >= v_clip_hi.y) discard;
  }

  float coverage = sample_coverage(v_texture_unit, v_uv);
  if (coverage <= 0.0) discard;
  out_color = vec4(v_tint.rgb, v_tint.a * coverage);
}
