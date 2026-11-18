#version 460 core

// Copies the input texture straight through. The baseline post pass / composite.

in vec2 v_uv;

uniform sampler2D u_input;

out vec4 out_color;

void main() {
  out_color = texture(u_input, v_uv);
}
