Line3d_Vertex :: struct {
  position: Vector3;
  color:    u32;
}

r_draw_line_3d :: (renderer: *Renderer, a: Vector3, b: Vector3, color := Vector4.{ 1, 1, 1, 1 }) {
  if !renderer.active_pass {
    log_error("r_draw_line_3d called outside of a pass");
    return;
  }

  packed := vector4_pack(color);
  array_add(*renderer.lines_3d, Line3d_Vertex.{ a, packed });
  array_add(*renderer.lines_3d, Line3d_Vertex.{ b, packed });
}

r_draw_wire_box :: (renderer: *Renderer, center: Vector3, size: Vector3, color: Vector4) {
  half := size * 0.5;
  corners: [8] Vector3;
  corners[0] = center + Vector3.{ -half.x, -half.y, -half.z };
  corners[1] = center + Vector3.{  half.x, -half.y, -half.z };
  corners[2] = center + Vector3.{  half.x, -half.y,  half.z };
  corners[3] = center + Vector3.{ -half.x, -half.y,  half.z };
  corners[4] = center + Vector3.{ -half.x,  half.y, -half.z };
  corners[5] = center + Vector3.{  half.x,  half.y, -half.z };
  corners[6] = center + Vector3.{  half.x,  half.y,  half.z };
  corners[7] = center + Vector3.{ -half.x,  half.y,  half.z };

  r_draw_line_3d(renderer, corners[0], corners[1], color);  r_draw_line_3d(renderer, corners[1], corners[2], color);
  r_draw_line_3d(renderer, corners[2], corners[3], color);  r_draw_line_3d(renderer, corners[3], corners[0], color);
  r_draw_line_3d(renderer, corners[4], corners[5], color);  r_draw_line_3d(renderer, corners[5], corners[6], color);
  r_draw_line_3d(renderer, corners[6], corners[7], color);  r_draw_line_3d(renderer, corners[7], corners[4], color);
  r_draw_line_3d(renderer, corners[0], corners[4], color);  r_draw_line_3d(renderer, corners[1], corners[5], color);
  r_draw_line_3d(renderer, corners[2], corners[6], color);  r_draw_line_3d(renderer, corners[3], corners[7], color);
}

// Queued, then drawn at r_end_pass (or before the next r_draw_fullscreen). No culling or lighting.
// In a pass that tests and writes depth: opaque draws first, then transparent ones back to front.
// In any other pass: strictly in submission order.
r_draw_mesh :: (renderer: *Renderer, mesh: *Mesh, transform: Matrix4, tint := Vector4.{ 1, 1, 1, 1 }, texture: *Texture = null) {
  if !renderer.active_pass {
    log_error("r_draw_mesh called outside of a pass");
    return;
  }
  if !mesh  return;
  if !texture  texture = renderer.white_texture;

  draw: Mesh_Draw;
  draw.mesh           = mesh;
  draw.instance       = Mesh_Instance.{ transform, vector4_pack(tint), texture.texture_unit_index };
  draw.is_transparent = renderer.active_pass.blend != .NONE && (tint.w < 1 || texture.has_transparency);
  draw.sequence       = xx renderer.mesh_draws.count;

  if draw.is_transparent {
    origin        := Vector4.{ transform._14, transform._24, transform._34, 1 };
    clip_position := renderer.projection * (renderer.view * origin);
    if clip_position.w != 0  draw.depth = clip_position.z / clip_position.w;
  }

  array_add(*renderer.mesh_draws, draw);
}

#scope_module

compare_mesh_draws :: (a: Mesh_Draw, b: Mesh_Draw) -> int {
  if a.is_transparent != b.is_transparent  return ifx a.is_transparent then 1 else -1;

  if a.is_transparent {
    if a.depth != b.depth  return ifx a.depth > b.depth then -1 else 1;
  } else {
    // Opaque order is irrelevant under a depth test, so group by mesh to get the longest instanced runs.
    if a.mesh != b.mesh  return ifx cast(u64) a.mesh < cast(u64) b.mesh then -1 else 1;
  }

  return cast(int) a.sequence - cast(int) b.sequence;
}

flush_meshes :: (renderer: *Renderer) {
  draws: [] Mesh_Draw = renderer.mesh_draws;
  if draws.count == 0  return;
  defer array_reset_keeping_memory(*renderer.mesh_draws);

  pass := renderer.active_pass;
  renderer_orders_draws := pass.depth_test && pass.depth_write;
  if renderer_orders_draws {
    quick_sort(draws, compare_mesh_draws);
    #if DEBUG  renderer.stats.sorts += 1;
  }

  array_reset_keeping_memory(*renderer.mesh_instances);
  for draws  array_add(*renderer.mesh_instances, it.instance);
  glNamedBufferData(renderer.mesh_instance_vbo, renderer.mesh_instances.count * size_of(Mesh_Instance), renderer.mesh_instances.data, GL_STREAM_DRAW);

  pipeline := *renderer.mesh_pipeline;
  glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, xx pipeline.label.count, pipeline.label.data);
  defer glPopDebugGroup();

  glProgramUniformMatrix4fv(pipeline.vs_handle, renderer.mesh_u_view,       1, GL_TRUE, cast(*float) *renderer.view);
  glProgramUniformMatrix4fv(pipeline.vs_handle, renderer.mesh_u_projection, 1, GL_TRUE, cast(*float) *renderer.projection);

  glBindProgramPipeline(pipeline.handle);
  defer glBindProgramPipeline(0);
  defer glBindVertexArray(0);
  defer if renderer_orders_draws  glDepthMask(GL_TRUE);

  // Consecutive draws of the same mesh become one instanced draw call.
  run_start := 0;
  while run_start < draws.count {
    mesh               := draws[run_start].mesh;
    run_is_transparent := draws[run_start].is_transparent;

    run_end := run_start + 1;
    while run_end < draws.count && draws[run_end].mesh == mesh && draws[run_end].is_transparent == run_is_transparent  run_end += 1;
    instance_count := run_end - run_start;

    // Transparent draws must not occlude what blends behind them later.
    if renderer_orders_draws  glDepthMask(ifx run_is_transparent then GL_FALSE else GL_TRUE);

    glBindVertexArray(mesh.vao);
    glDrawElementsInstancedBaseInstance(GL_TRIANGLES, xx mesh.index_count, GL_UNSIGNED_INT, null, xx instance_count, xx run_start);

    #if DEBUG {
      renderer.stats.draw_calls     += 1;
      renderer.stats.mesh_draws     += instance_count;
      renderer.stats.mesh_triangles += instance_count * cast(int) mesh.index_count / 3;
      renderer.stats.instance_bytes += instance_count * size_of(Mesh_Instance);
    }

    run_start = run_end;
  }
}

setup_line3d_buffers :: (renderer: *Renderer) {
  glCreateVertexArrays(1, *renderer.line3d_vao);
  glCreateBuffers(1, *renderer.line3d_vbo);
  glNamedBufferData(renderer.line3d_vbo, 0, null, GL_STREAM_DRAW);

  vao := renderer.line3d_vao;
  glVertexArrayVertexBuffer(vao, 0, renderer.line3d_vbo, 0, size_of(Line3d_Vertex));
  glEnableVertexArrayAttrib(vao, 0);
  glVertexArrayAttribFormat(vao, 0, 3, GL_FLOAT, GL_FALSE, xx offset_of(Line3d_Vertex, "position"));
  glVertexArrayAttribBinding(vao, 0, 0);
  glEnableVertexArrayAttrib(vao, 1);
  glVertexArrayAttribIFormat(vao, 1, 1, GL_UNSIGNED_INT, xx offset_of(Line3d_Vertex, "color"));
  glVertexArrayAttribBinding(vao, 1, 0);
}

flush_line3d :: (renderer: *Renderer) {
  vertex_count := renderer.lines_3d.count;
  if vertex_count == 0  return;

  pipeline        := *renderer.line3d_pipeline;
  view_projection := renderer.projection * renderer.view;
  glProgramUniformMatrix4fv(pipeline.vs_handle, renderer.line3d_u_view_proj, 1, GL_TRUE, cast(*float) *view_projection);

  glBindProgramPipeline(pipeline.handle);
  defer glBindProgramPipeline(0);

  glNamedBufferData(renderer.line3d_vbo, vertex_count * size_of(Line3d_Vertex), renderer.lines_3d.data, GL_STREAM_DRAW);
  glBindVertexArray(renderer.line3d_vao);
  glDrawArrays(GL_LINES, 0, xx vertex_count);
  glBindVertexArray(0);

  #if DEBUG {
    renderer.stats.draw_calls += 1;
    renderer.stats.lines_3d   += vertex_count / 2;
  }
}
