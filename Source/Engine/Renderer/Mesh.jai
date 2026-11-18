Mesh_Vertex :: struct {
  position: Vector3;
  normal:   Vector3;
  uv:       Vector2;
}

Mesh_Instance :: struct {
  model: Matrix4;
  tint:  u32;
  texture_unit_index: s32;
}

Mesh_Draw :: struct {
  mesh:     *Mesh;
  instance: Mesh_Instance;

  is_transparent: bool;
  depth:          float; // Normalized device depth of the instance origin: what the depth test orders by. Only set for transparent draws.
  sequence:       u32;   // Submission order, the tie-breaker because quick_sort isn't stable
}

Mesh :: struct {
  label:         string;
  vao, vbo, ibo: u32;
  index_count:   u32;

  position_min: Vector3;
  position_max: Vector3;
}

r_create_mesh :: (renderer: *Renderer, label: string, vertices: [] Mesh_Vertex, indices: [] u32) -> *Mesh {
  mesh := New(Mesh);
  mesh.label = copy_string(label);

  glCreateVertexArrays(1, *mesh.vao);
  glCreateBuffers(1, *mesh.vbo);
  glCreateBuffers(1, *mesh.ibo);
  glNamedBufferData(mesh.vbo, vertices.count * size_of(Mesh_Vertex), vertices.data, GL_STATIC_DRAW);
  glNamedBufferData(mesh.ibo, indices.count  * size_of(u32),         indices.data,  GL_STATIC_DRAW);
  mesh.index_count = xx indices.count;
  mesh_setup_vao(renderer, mesh);

  array_add(*renderer.meshes, mesh);
  return mesh;
}

r_create_cube_mesh :: (renderer: *Renderer, side_length: float = 1) -> *Mesh {
  UNIT_CUBE_VERTICES :: Mesh_Vertex.[
    // +Z
    .{ .{ -0.5, -0.5,  0.5 }, .{  0,  0,  1 }, .{ 0, 0 } },
    .{ .{  0.5, -0.5,  0.5 }, .{  0,  0,  1 }, .{ 1, 0 } },
    .{ .{  0.5,  0.5,  0.5 }, .{  0,  0,  1 }, .{ 1, 1 } },
    .{ .{ -0.5,  0.5,  0.5 }, .{  0,  0,  1 }, .{ 0, 1 } },
    // -Z
    .{ .{  0.5, -0.5, -0.5 }, .{  0,  0, -1 }, .{ 0, 0 } },
    .{ .{ -0.5, -0.5, -0.5 }, .{  0,  0, -1 }, .{ 1, 0 } },
    .{ .{ -0.5,  0.5, -0.5 }, .{  0,  0, -1 }, .{ 1, 1 } },
    .{ .{  0.5,  0.5, -0.5 }, .{  0,  0, -1 }, .{ 0, 1 } },
    // +X
    .{ .{  0.5, -0.5,  0.5 }, .{  1,  0,  0 }, .{ 0, 0 } },
    .{ .{  0.5, -0.5, -0.5 }, .{  1,  0,  0 }, .{ 1, 0 } },
    .{ .{  0.5,  0.5, -0.5 }, .{  1,  0,  0 }, .{ 1, 1 } },
    .{ .{  0.5,  0.5,  0.5 }, .{  1,  0,  0 }, .{ 0, 1 } },
    // -X
    .{ .{ -0.5, -0.5, -0.5 }, .{ -1,  0,  0 }, .{ 0, 0 } },
    .{ .{ -0.5, -0.5,  0.5 }, .{ -1,  0,  0 }, .{ 1, 0 } },
    .{ .{ -0.5,  0.5,  0.5 }, .{ -1,  0,  0 }, .{ 1, 1 } },
    .{ .{ -0.5,  0.5, -0.5 }, .{ -1,  0,  0 }, .{ 0, 1 } },
    // +Y
    .{ .{ -0.5,  0.5,  0.5 }, .{  0,  1,  0 }, .{ 0, 0 } },
    .{ .{  0.5,  0.5,  0.5 }, .{  0,  1,  0 }, .{ 1, 0 } },
    .{ .{  0.5,  0.5, -0.5 }, .{  0,  1,  0 }, .{ 1, 1 } },
    .{ .{ -0.5,  0.5, -0.5 }, .{  0,  1,  0 }, .{ 0, 1 } },
    // -Y
    .{ .{ -0.5, -0.5, -0.5 }, .{  0, -1,  0 }, .{ 0, 0 } },
    .{ .{  0.5, -0.5, -0.5 }, .{  0, -1,  0 }, .{ 1, 0 } },
    .{ .{  0.5, -0.5,  0.5 }, .{  0, -1,  0 }, .{ 1, 1 } },
    .{ .{ -0.5, -0.5,  0.5 }, .{  0, -1,  0 }, .{ 0, 1 } },
  ];

  UNIT_CUBE_INDICES :: u32.[
     0,  1,  2,   0,  2,  3,
     4,  5,  6,   4,  6,  7,
     8,  9, 10,   8, 10, 11,
    12, 13, 14,  12, 14, 15,
    16, 17, 18,  16, 18, 19,
    20, 21, 22,  20, 22, 23,
  ];

  vertices := UNIT_CUBE_VERTICES;
  min := vertices[0].position;  
  max := vertices[0].position;

  for * vertices {
    it.position *= side_length;

    if min.x > it.position.x && min.y > it.position.y && min.z > it.position.z {
      min = it.position;
    }
    if max.x < it.position.x && max.y < it.position.y && max.z < it.position.z {
      max = it.position;
    }
  }
  mesh := r_create_mesh(renderer, "Cube", vertices, UNIT_CUBE_INDICES);
  mesh.position_max = max;
  mesh.position_min = min;
  return mesh;
}

r_destroy_mesh :: (renderer: *Renderer, mesh: *Mesh) {
  if !mesh  return;

  array_ordered_remove_by_value(*renderer.meshes, mesh);

  kept_draw_count := 0;
  for renderer.mesh_draws {
    if it.mesh == mesh  continue;
    renderer.mesh_draws[kept_draw_count] = it;
    kept_draw_count += 1;
  }
  renderer.mesh_draws.count = kept_draw_count;

  glDeleteVertexArrays(1, *mesh.vao);
  buffers := u32.[ mesh.vbo, mesh.ibo ];
  glDeleteBuffers(buffers.count, buffers.data);
  if mesh.label.data  free(mesh.label);
  free(mesh);
}

#scope_module

MESH_VS_SOURCE :: #run read_bundled_shader("Mesh", "Mesh.vert");
MESH_FS_SOURCE :: #run read_bundled_shader("Mesh", "Mesh.frag");


mesh_setup_vao :: (renderer: *Renderer, mesh: *Mesh) {
  vao := mesh.vao;
  glVertexArrayVertexBuffer(vao, 0, mesh.vbo, 0, size_of(Mesh_Vertex));
  glVertexArrayElementBuffer(vao, mesh.ibo);

  glEnableVertexArrayAttrib(vao, 0);
  glVertexArrayAttribFormat(vao, 0, 3, GL_FLOAT, GL_FALSE, xx offset_of(Mesh_Vertex, "position"));
  glVertexArrayAttribBinding(vao, 0, 0);
  glEnableVertexArrayAttrib(vao, 1);
  glVertexArrayAttribFormat(vao, 1, 3, GL_FLOAT, GL_FALSE, xx offset_of(Mesh_Vertex, "normal"));
  glVertexArrayAttribBinding(vao, 1, 0);
  glEnableVertexArrayAttrib(vao, 2);
  glVertexArrayAttribFormat(vao, 2, 2, GL_FLOAT, GL_FALSE, xx offset_of(Mesh_Vertex, "uv"));
  glVertexArrayAttribBinding(vao, 2, 0);

  glVertexArrayVertexBuffer(vao, 1, renderer.mesh_instance_vbo, 0, size_of(Mesh_Instance));
  glVertexArrayBindingDivisor(vao, 1, 1);

  // A mat4 attribute occupies four consecutive locations, one vec4 each.
  for row: 0..3 {
    location: u32 = xx (3 + row);
    glEnableVertexArrayAttrib(vao, location);
    glVertexArrayAttribFormat(vao, location, 4, GL_FLOAT, GL_FALSE, xx (offset_of(Mesh_Instance, "model") + row * size_of(Vector4)));
    glVertexArrayAttribBinding(vao, location, 1);
  }
  glEnableVertexArrayAttrib(vao, 7);
  glVertexArrayAttribIFormat(vao, 7, 1, GL_UNSIGNED_INT, xx offset_of(Mesh_Instance, "tint"));
  glVertexArrayAttribBinding(vao, 7, 1);
  glEnableVertexArrayAttrib(vao, 8);
  glVertexArrayAttribIFormat(vao, 8, 1, GL_INT, xx offset_of(Mesh_Instance, "texture_unit_index"));
  glVertexArrayAttribBinding(vao, 8, 1);
}
