#version 460 core

// Instanced 3D mesh pipeline: consecutive r_draw_mesh calls of one mesh are
// instances of a single draw call. No culling or lighting yet.

layout(location = 0) in vec3 a_position;
layout(location = 1) in vec3 a_normal;
layout(location = 2) in vec2 a_uv;

layout(location = 3) in mat4 i_model_row_major; // locations 3..6; unlike a uniform, an attribute can't be transposed on upload
layout(location = 7) in uint i_tint;
layout(location = 8) in int  i_texture_unit;

uniform mat4 u_view;
uniform mat4 u_projection;

out vec3      v_normal;
out vec2      v_uv;
flat out vec4 v_tint;
flat out int  v_texture_unit;

out gl_PerVertex { vec4 gl_Position; };

vec4 unpack_rgba(uint c) {
  return vec4(float( c        & 0xFFu),
             float((c >>  8u) & 0xFFu),
             float((c >> 16u) & 0xFFu),
             float((c >> 24u) & 0xFFu)) / 255.0;
}

void main() {
  mat4 model = transpose(i_model_row_major);

  v_normal       = mat3(model) * a_normal;
  v_uv           = a_uv;
  v_tint         = unpack_rgba(i_tint);
  v_texture_unit = i_texture_unit;
  gl_Position    = u_projection * u_view * model * vec4(a_position, 1.0);
}
