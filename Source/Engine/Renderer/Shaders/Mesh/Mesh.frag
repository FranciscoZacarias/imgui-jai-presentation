#version 460 core

// Minimal 3D mesh pipeline: unlit, tinted, single texture. No lighting model
// yet - sample_texture/v_uv is the whole shading story until one is added.

in vec3      v_normal; // unused today; carried through so the pipeline stays fully wired for shading
in vec2      v_uv;
flat in vec4 v_tint;
flat in int  v_texture_unit;

uniform sampler2D u_textures[MAX_TEXTURES];

out vec4 out_color;

vec4 sample_texture(int idx, vec2 uv) {
  for (int i = 0; i < MAX_TEXTURES; ++i) {
    if (i == idx) return texture(u_textures[i], uv);
  }
  return vec4(1.0);
}

void main() {
  out_color = sample_texture(v_texture_unit, v_uv) * v_tint;
}
