#version 460 core

// Attribute-less fullscreen triangle. Draw with glDrawArrays(GL_TRIANGLES, 0, 3)
// and an empty VAO bound.

out vec2 v_uv;

out gl_PerVertex { vec4 gl_Position; };

void main() {
  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  v_uv = p;                          // 0..2, covers 0..1 across the visible area
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
