#version 460 core

// 3D debug/grid line pipeline. Unlit, per-vertex colour, drawn as GL_LINES.

layout(location = 0) in vec3 a_position;
layout(location = 1) in uint a_color;

uniform mat4 u_view_proj;

out vec4 v_color;

out gl_PerVertex { vec4 gl_Position; };

vec4 unpack_rgba(uint c) {
  return vec4(float( c        & 0xFFu),
             float((c >>  8u) & 0xFFu),
             float((c >> 16u) & 0xFFu),
             float((c >> 24u) & 0xFFu)) / 255.0;
}

void main() {
  v_color     = unpack_rgba(a_color);
  gl_Position = u_view_proj * vec4(a_position, 1.0);
}
