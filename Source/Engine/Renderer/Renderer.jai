MAX_BATCH_TEXTURES :: 16; // NOTE(fz): This is injected into the shaders.

Quad_Vertex :: struct {
  position: Vector2;
}

Screen_Quad_Instance :: struct {
  top_left: Vector2;
  size:     Vector2;
  uv_min:   Vector2;
  uv_max:   Vector2;
  tint:     u32;
  texture_unit_index: s32;
  border_thickness:   float;
  border_color:       u32;
  rotation:           float; // radians, CCW
  clip_min: Vector2; // top left
  clip_max: Vector2; // bot right
  corner_radii: Vector4; // per corner rounding TL, TR, BR, BL

  sort_key: float;
  _seq:     u32;
}

Text_Quad_Instance :: struct {
  top_left: Vector2;
  size:     Vector2;
  uv_min:   Vector2;
  uv_max:   Vector2;
  tint:     u32;
  texture_unit_index: s32;
  clip_min: Vector2;
  clip_max: Vector2;

  sort_key: float;
  _seq:     u32;
}

Quad_Batch :: struct {
  label: string;

  vao:          u32;
  vbo:          u32;
  ibo:          u32;
  instance_vbo: u32;

  indices_count: u32;
}

Texture :: struct {
  label: string;

  handle: u32;
  width:  u32;
  height: u32;
  texture_unit_index: s32;
  has_transparency:   bool; // Any texel with alpha below 1; makes a mesh drawn with it sort as transparent
}

Renderer_Pipeline :: struct {
  label: string;

  handle:    u32;
  vs_handle: u32;
  fs_handle: u32;
}

Render_Target :: struct {
  Render_Target_Format :: enum {
    RGBA8;
    RGBA16F;
    RGBA32F;
  }

  label:  string;

  fbo:          u32;
  color:        *Texture; // always single-sampled; what every pass/quad samples from
  depth_handle: u32;      // depth24/stencil8 renderbuffer, 0 if none

  width:     s32;
  height:    s32;
  format:    Render_Target_Format;
  has_depth: bool;

  samples:           s32 = 1;
  msaa_fbo:          u32;
  msaa_color_handle: u32;
  msaa_depth_handle: u32;
}

Render_Pass :: struct {
  Pass_Clear :: struct {
    color:       bool = true;
    color_value: Vector4 = .{0, 0, 0, 1};
    depth:       bool = false;
  }

  Blend_Mode :: enum {
    NONE;
    ALPHA;
    PREMULTIPLIED;
    ADDITIVE;
    MULTIPLY;
  }

  Cull_Mode :: enum {
    NONE;
    BACK;
    FRONT;
  }

  // size <= 0 on either axis disables it; glClear respects it too.
  Scissor_Rect :: struct {
    x: s32; y: s32;
    w: s32; h: s32;
  }

  label:  string;
  target: *Render_Target; // null => the backbuffer

  clear:   Pass_Clear;
  scissor: Scissor_Rect;

  view:       Matrix4 = Matrix4_Identity;
  projection: Matrix4 = Matrix4_Identity;

  draw_meshes:   bool = true;
  draw_lines_3d: bool = true;
  draw_screen:   bool = true;
  draw_text:     bool = true;

  depth_test:  bool = false;
  depth_write: bool = true; // only matters while depth_test is on
  cull:        Cull_Mode = .NONE;
  wireframe:   bool = false;

  blend: Blend_Mode = .ALPHA;
}

#if DEBUG {
  Render_Stats :: struct {
    // GPU timing is read back two frames late so it never stalls the CPU.
    cpu_frame_ms: float64;
    gpu_frame_ms: float64;

    passes:           int;
    draw_calls:       int;
    fullscreen_draws: int;
    sorts:            int;

    quads_submitted: int;
    screen_quads:    int;
    text_quads:      int;
    mesh_draws:      int;
    mesh_triangles:  int;
    lines_3d:        int;
    triangles:       int;
    vertices:        int;

    instance_bytes: int;

    // Resident GPU resources, snapshotted at r_end_frame, not per-frame counters.
    textures:            int;
    render_targets:      int;
    texture_bytes:       int;
    stream_buffer_bytes: int;
    texture_units_used:  int;
    texture_units_max:   int;
  }
}


Renderer :: struct {
  Clip_Rect :: struct {
    min: Vector2;
    max: Vector2;
  }

  pool: Flat_Pool;

  screen_pipeline: Renderer_Pipeline;
  text_pipeline:   Renderer_Pipeline;
  mesh_pipeline:   Renderer_Pipeline;
  line3d_pipeline: Renderer_Pipeline;

  screen_batch: Quad_Batch;
  text_batch:   Quad_Batch;

  immediate_screen_quads: [..]Screen_Quad_Instance;
  immediate_text_quads:   [..]Text_Quad_Instance;

  meshes:            [..]*Mesh;
  mesh_draws:        [..]Mesh_Draw;
  mesh_instances:    [..]Mesh_Instance; // mesh_draws in final draw order, as uploaded to mesh_instance_vbo
  mesh_instance_vbo: u32;

  lines_3d:      [..]Line3d_Vertex;
  line3d_vao:    u32;
  line3d_vbo:    u32;

  textures:       [..]Texture;
  white_texture:  *Texture;
  texture_unit_count: s32;

  ft_library: FT_Library;
  fonts:      [..]*Font;

  fullscreen_vao:  u32;
  active_pass:     *Render_Pass;
  backbuffer_size: Vector2;

  frame_seq:         u32; // painter's-order tiebreaker, set per submission
  screen_needs_sort: bool;
  text_needs_sort:   bool;

  clip_stack: [..]Clip_Rect;

  #if DEBUG {
    stats:      Render_Stats;
    stats_prev: Render_Stats;

    cpu_frame_start: Apollo_Time;
    gpu_timer_query:  [3] u32; // ring of GL_TIME_ELAPSED queries
    gpu_timer_ready:  [3] bool;
    frame_index:      u64;
  }

  gpu_vendor:   string;
  gpu_renderer: string;
  gl_version:   string;

  view:        Matrix4;
  projection:  Matrix4;
  screen_size: Vector2;

  screen_u_screen_size: s32;
  text_u_screen_size:   s32;
  mesh_u_view:          s32;
  mesh_u_projection:    s32;
  line3d_u_view_proj:   s32;

  render_targets: [..]*Render_Target;

  max_texture_size: s32;
  max_texture_image_units: s32;
  max_combined_texture_image_units: s32;
  max_anisotropy: float;
}

r_init :: (renderer: *Renderer) {
  init(*renderer.pool);
  push_allocator(flat_pool_allocator_proc, *renderer.pool);

  // These go on the heap (not pool) so that on resize they don't fill the pool unecessairly.
  renderer.immediate_screen_quads.allocator = context.default_allocator;
  array_reserve(*renderer.immediate_screen_quads, 16384);
  renderer.immediate_text_quads.allocator = context.default_allocator;
  array_reserve(*renderer.immediate_text_quads, 16384);
  renderer.meshes.allocator = context.default_allocator;
  array_reserve(*renderer.meshes, 32);
  renderer.mesh_draws.allocator = context.default_allocator;
  array_reserve(*renderer.mesh_draws, 1024);
  renderer.mesh_instances.allocator = context.default_allocator;
  array_reserve(*renderer.mesh_instances, 1024);
  renderer.lines_3d.allocator = context.default_allocator;
  array_reserve(*renderer.lines_3d, 4096);
  renderer.clip_stack.allocator = context.default_allocator;
  array_reserve(*renderer.clip_stack, 32);
  renderer.fonts.allocator = context.default_allocator;
  renderer.render_targets.allocator = context.default_allocator;

  // Reserve texture array
  array_reserve(*renderer.textures, 64);

  glGetIntegerv(GL_MAX_TEXTURE_SIZE, *renderer.max_texture_size);
  glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, *renderer.max_texture_image_units);
  glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, *renderer.max_combined_texture_image_units);
  glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY, *renderer.max_anisotropy);

  gl_string :: (name: GLenum) -> string {
    raw := glGetString(name);
    return ifx raw then copy_string(to_string(raw)) else "";
  }
  renderer.gpu_vendor   = gl_string(GL_VENDOR);
  renderer.gpu_renderer = gl_string(GL_RENDERER);
  renderer.gl_version   = gl_string(GL_VERSION);

  #if DEBUG {
    glGenQueries(renderer.gpu_timer_query.count, renderer.gpu_timer_query.data);
  }

  // Screen pipeline
  renderer.screen_pipeline = create_pipeline_from_sources("Screen Space Pipeline", SCREEN_VS_SOURCE, SCREEN_FS_SOURCE);
  renderer.screen_u_screen_size = glGetUniformLocation(renderer.screen_pipeline.vs_handle, "u_screen_size");
  bind_pipeline_samplers(*renderer.screen_pipeline, MAX_BATCH_TEXTURES);

  // Text screen pipeline
  renderer.text_pipeline = create_pipeline_from_sources("Text Screen Space Pipeline", TEXT_VS_SOURCE, TEXT_FS_SOURCE);
  renderer.text_u_screen_size = glGetUniformLocation(renderer.text_pipeline.vs_handle, "u_screen_size");
  bind_pipeline_samplers(*renderer.text_pipeline, MAX_BATCH_TEXTURES);

  // Mesh pipeline
  renderer.mesh_pipeline = create_pipeline_from_sources("Mesh Pipeline", MESH_VS_SOURCE, MESH_FS_SOURCE);
  renderer.mesh_u_view       = glGetUniformLocation(renderer.mesh_pipeline.vs_handle, "u_view");
  renderer.mesh_u_projection = glGetUniformLocation(renderer.mesh_pipeline.vs_handle, "u_projection");
  glCreateBuffers(1, *renderer.mesh_instance_vbo);
  glNamedBufferData(renderer.mesh_instance_vbo, 0, null, GL_STREAM_DRAW);
  bind_pipeline_samplers(*renderer.mesh_pipeline, MAX_BATCH_TEXTURES);

  // 3D line pipeline
  renderer.line3d_pipeline = create_pipeline_from_sources("Line3D Pipeline", LINE3D_VS_SOURCE, LINE3D_FS_SOURCE);
  renderer.line3d_u_view_proj = glGetUniformLocation(renderer.line3d_pipeline.vs_handle, "u_view_proj");
  setup_line3d_buffers(renderer);

  renderer.screen_batch.label = "Screen Quad Batch";
  renderer.text_batch.label = "Text Quad Batch";
  setup_screen_batch(renderer);
  setup_text_batch(renderer);

  glCreateVertexArrays(1, *renderer.fullscreen_vao); // gl_VertexID-driven triangle, no attributes needed

  r_init_freetype(renderer);

  white_pixel := u8.[ 255, 255, 255, 255 ];
  renderer.white_texture = r_create_texture_from_pixels(renderer, "White Texture", 1, 1, white_pixel);
}

r_deinit :: (renderer: *Renderer) {
  free_pipeline :: (pipeline: *Renderer_Pipeline) {
    if pipeline.handle     glDeleteProgramPipelines(1, *pipeline.handle);
    if pipeline.vs_handle  glDeleteProgram(pipeline.vs_handle);
    if pipeline.fs_handle  glDeleteProgram(pipeline.fs_handle);
  }
  free_pipeline(*renderer.screen_pipeline);
  free_pipeline(*renderer.text_pipeline);
  free_pipeline(*renderer.mesh_pipeline);
  free_pipeline(*renderer.line3d_pipeline);

  free_batch :: (batch: *Quad_Batch) {
    glDeleteVertexArrays(1, *batch.vao);
    buffers := u32.[ batch.vbo, batch.ibo, batch.instance_vbo ];
    glDeleteBuffers(buffers.count, buffers.data);
  }
  free_batch(*renderer.screen_batch);
  free_batch(*renderer.text_batch);

  glDeleteBuffers(1, *renderer.line3d_vbo);
  glDeleteVertexArrays(1, *renderer.line3d_vao);

  while renderer.meshes.count > 0  r_destroy_mesh(renderer, renderer.meshes[renderer.meshes.count - 1]);
  array_free(renderer.meshes);
  array_free(renderer.mesh_draws);
  array_free(renderer.mesh_instances);
  glDeleteBuffers(1, *renderer.mesh_instance_vbo);

  glDeleteVertexArrays(1, *renderer.fullscreen_vao);
  #if DEBUG  glDeleteQueries(renderer.gpu_timer_query.count, renderer.gpu_timer_query.data);

  for renderer.render_targets  render_target_deinit_gl(it);
  for renderer.textures  glDeleteTextures(1, *it.handle);

  for font: renderer.fonts {
    if font.face  FT_Done_Face(font.face);
    free(font.ttf_bytes.data);
    array_free(font.glyphs);
    free(font.label);
    free(font);
  }
  r_deinit_freetype(renderer);

  array_free(renderer.immediate_screen_quads);
  array_free(renderer.immediate_text_quads);
  array_free(renderer.lines_3d);
  array_free(renderer.clip_stack);
  array_free(renderer.textures);
  array_free(renderer.fonts);
  array_free(renderer.render_targets);

  fini(*renderer.pool);
  renderer.* = .{};
}

r_begin_frame :: (renderer: *Renderer, window_width: s64, window_height: s64) {
  renderer.backbuffer_size = Vector2.{xx window_width, xx window_height};
  renderer.screen_size     = renderer.backbuffer_size;
  renderer.clip_stack.count = 0;

  #if DEBUG {
    renderer.stats = .{};
    renderer.cpu_frame_start = current_time_monotonic();
    glBeginQuery(GL_TIME_ELAPSED, renderer.gpu_timer_query[renderer.frame_index % 3]);
  }
}

r_end_frame :: (renderer: *Renderer) {
  #if DEBUG {
    slot := renderer.frame_index % 3;
    glEndQuery(GL_TIME_ELAPSED);
    renderer.gpu_timer_ready[slot] = true;

    // The GPU is done with a query from two frames ago, so reading it back
    // here never blocks.
    read_slot := (renderer.frame_index + 1) % 3;
    if renderer.gpu_timer_ready[read_slot] {
      elapsed_ns: u64;
      glGetQueryObjectui64v(renderer.gpu_timer_query[read_slot], GL_QUERY_RESULT, *elapsed_ns);
      renderer.stats.gpu_frame_ms = cast(float64) elapsed_ns / 1_000_000.0;
    }

    cpu_seconds, ok := to_float64_seconds(current_time_monotonic() - renderer.cpu_frame_start);
    if ok  renderer.stats.cpu_frame_ms = cpu_seconds * 1000.0;

    renderer.stats.triangles = renderer.stats.quads_submitted * 2 + renderer.stats.fullscreen_draws + renderer.stats.mesh_triangles;
    renderer.stats.vertices  = renderer.stats.triangles * 3;

    texture_bytes := 0;
    for renderer.textures  texture_bytes += cast(int) it.width * cast(int) it.height * 4;
    renderer.stats.textures       = renderer.textures.count;
    renderer.stats.render_targets = renderer.render_targets.count;
    renderer.stats.texture_bytes  = texture_bytes;

    renderer.stats.stream_buffer_bytes =
        renderer.immediate_screen_quads.allocated * size_of(Screen_Quad_Instance)
      + renderer.immediate_text_quads.allocated   * size_of(Text_Quad_Instance)
      + renderer.lines_3d.allocated               * size_of(Line3d_Vertex)
      + renderer.mesh_instances.allocated         * size_of(Mesh_Instance);
    renderer.stats.texture_units_used = renderer.texture_unit_count;
    renderer.stats.texture_units_max  = renderer.max_combined_texture_image_units;

    renderer.stats_prev = renderer.stats;
    renderer.frame_index += 1;
  }
}

#if DEBUG {
  r_get_stats :: (renderer: *Renderer) -> Render_Stats {
    return renderer.stats_prev;
  }
}

r_gpu_info :: (renderer: *Renderer) -> vendor: string, renderer_name: string, gl_version: string {
  return renderer.gpu_vendor, renderer.gpu_renderer, renderer.gl_version;
}

// Screen/text only; world quads are unaffected. Nested pushes are intersected.
r_push_clip_rect :: (renderer: *Renderer, top_left: Vector2, size: Vector2) {
  rect := Renderer.Clip_Rect.{ min = top_left, max = top_left + size };
  if renderer.clip_stack.count > 0 {
    cur := renderer.clip_stack[renderer.clip_stack.count - 1];
    rect.min.x = max(rect.min.x, cur.min.x);
    rect.min.y = max(rect.min.y, cur.min.y);
    rect.max.x = min(rect.max.x, cur.max.x);
    rect.max.y = min(rect.max.y, cur.max.y);
  }
  array_add(*renderer.clip_stack, rect);
}

r_pop_clip_rect :: (renderer: *Renderer) {
  if renderer.clip_stack.count > 0  renderer.clip_stack.count -= 1;
}

current_clip :: (renderer: *Renderer) -> Renderer.Clip_Rect {
  if renderer.clip_stack.count > 0  return renderer.clip_stack[renderer.clip_stack.count - 1];
  return .{ .{0, 0}, .{0, 0} };
}

// The shaders read a rect with no width as "no clipping", so draws under an empty clip must be dropped here.
current_clip_is_empty :: (renderer: *Renderer) -> bool {
  if renderer.clip_stack.count == 0  return false;
  clip := renderer.clip_stack[renderer.clip_stack.count - 1];
  return clip.max.x <= clip.min.x || clip.max.y <= clip.min.y;
}

r_create_render_target :: (renderer: *Renderer, label: string, width: s32, height: s32,
                           format := Render_Target.Render_Target_Format.RGBA8, with_depth := false, samples := 1) -> *Render_Target {
  push_allocator(flat_pool_allocator_proc, *renderer.pool);

  render_target := New(Render_Target);
  render_target.label     = copy_string(label);
  render_target.width     = max(width, 1);
  render_target.height    = max(height, 1);
  render_target.format    = format;
  render_target.has_depth = with_depth;
  render_target.samples   = xx max(samples, 1);

  render_target_init_gl(renderer, render_target, reuse_color = false);
  array_add(*renderer.render_targets, render_target);
  return render_target;
}

// The colour *Texture keeps its identity and texture unit, so held pointers
// stay valid across a resize.
r_resize_render_target :: (renderer: *Renderer, render_target: *Render_Target, width: s32, height: s32) {
  width  = max(width, 1);
  height = max(height, 1);
  if render_target.fbo != 0 && render_target.width == width && render_target.height == height  return;

  render_target_deinit_gl(render_target);
  render_target.width  = width;
  render_target.height = height;
  render_target_init_gl(renderer, render_target, reuse_color = true);
}

r_begin_pass :: (renderer: *Renderer, pass: *Render_Pass) {
  if renderer.active_pass {
    log_error("r_begin_pass('%') while pass '%' is still active", pass.label, renderer.active_pass.label);
  }
  renderer.active_pass = pass;
  #if DEBUG  renderer.stats.passes += 1;

  array_reset_keeping_memory(*renderer.immediate_screen_quads);
  array_reset_keeping_memory(*renderer.immediate_text_quads);
  array_reset_keeping_memory(*renderer.lines_3d);
  array_reset_keeping_memory(*renderer.mesh_draws);

  renderer.frame_seq         = 0;
  renderer.screen_needs_sort = false;
  renderer.text_needs_sort   = false;

  renderer.view       = pass.view;
  renderer.projection = pass.projection;

  fbo: u32 = 0;
  w := cast(s32) renderer.backbuffer_size.x;
  h := cast(s32) renderer.backbuffer_size.y;
  if pass.target {
    fbo = ifx pass.target.samples > 1 then pass.target.msaa_fbo else pass.target.fbo;
    w   = pass.target.width;
    h   = pass.target.height;
  }
  renderer.screen_size = Vector2.{xx w, xx h};

  glBindFramebuffer(GL_FRAMEBUFFER, fbo);
  glViewport(0, 0, xx w, xx h);

  if #complete pass.cull == {
    case .NONE;  glDisable(GL_CULL_FACE);
    case .BACK;  glEnable(GL_CULL_FACE); glCullFace(GL_BACK);
    case .FRONT; glEnable(GL_CULL_FACE); glCullFace(GL_FRONT);
  }
  glFrontFace(GL_CCW);

  polygon_mode: GLenum = GL_FILL;
  if pass.wireframe  polygon_mode = GL_LINE;
  glPolygonMode(GL_FRONT_AND_BACK, polygon_mode);

  apply_blend_mode(pass.blend);

  if pass.scissor.w > 0 && pass.scissor.h > 0 {
    glEnable(GL_SCISSOR_TEST);
    gl_y := h - (pass.scissor.y + pass.scissor.h); // top-left rect -> GL's bottom-left origin
    glScissor(pass.scissor.x, gl_y, xx pass.scissor.w, xx pass.scissor.h);
  } else {
    glDisable(GL_SCISSOR_TEST);
  }

  mask: GLbitfield = 0;
  if pass.clear.color {
    c := pass.clear.color_value;
    glClearColor(c.x, c.y, c.z, c.w);
    mask |= GL_COLOR_BUFFER_BIT;
  }
  if pass.clear.depth  mask |= GL_DEPTH_BUFFER_BIT;
  glDepthMask(GL_TRUE); // glClear only clears depth while depth writes are on
  if mask  glClear(mask);

  if pass.depth_test {
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glDepthMask(ifx pass.depth_write then GL_TRUE else GL_FALSE);
  } else {
    glDisable(GL_DEPTH_TEST);
  }
}

// Draws immediately: on top of the meshes submitted so far, behind the lines and quads this pass flushes.
r_draw_fullscreen :: (renderer: *Renderer, pipeline: *Renderer_Pipeline, input: *Texture) {
  if !renderer.active_pass {
    log_error("r_draw_fullscreen called outside of a pass");
    return;
  }
  if renderer.active_pass.draw_meshes  flush_meshes(renderer);

  if input {
    loc := glGetUniformLocation(pipeline.fs_handle, "u_input");
    if loc != -1  glProgramUniform1i(pipeline.fs_handle, loc, input.texture_unit_index);

    texel_loc := glGetUniformLocation(pipeline.fs_handle, "u_texel_size");
    if texel_loc != -1 {
      texel := Vector2.{1.0 / cast(float) input.width, 1.0 / cast(float) input.height};
      glProgramUniform2fv(pipeline.fs_handle, texel_loc, 1, cast(*float) *texel);
    }
  }

  glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, xx pipeline.label.count, pipeline.label.data);
  defer glPopDebugGroup();

  glBindProgramPipeline(pipeline.handle);
  defer glBindProgramPipeline(0);

  glBindVertexArray(renderer.fullscreen_vao);
  defer glBindVertexArray(0);

  glDrawArrays(GL_TRIANGLES, 0, 3);

  #if DEBUG {
    renderer.stats.fullscreen_draws += 1;
    renderer.stats.draw_calls       += 1;
  }
}

r_end_pass :: (renderer: *Renderer) {
  pass := renderer.active_pass;
  if !pass {
    log_error("r_end_pass called with no active pass");
    return;
  }

  if pass.draw_screen && renderer.screen_needs_sort { sort_quad_batch(*renderer.immediate_screen_quads); #if DEBUG renderer.stats.sorts += 1; }
  if pass.draw_text   && renderer.text_needs_sort   { sort_quad_batch(*renderer.immediate_text_quads);   #if DEBUG renderer.stats.sorts += 1; }

  if pass.draw_meshes    flush_meshes(renderer);
  if pass.draw_lines_3d  flush_line3d(renderer);
  flush_quad_batches(renderer, pass.draw_screen, pass.draw_text);

  if pass.target && pass.target.samples > 1  resolve_msaa_render_target(pass.target);

  renderer.active_pass = null;
}

// A multisample texture can't be bound to a plain sampler2D, so resolving the
// MSAA draw down to render_target.color (what everything else samples) isn't optional.
resolve_msaa_render_target :: (render_target: *Render_Target) {
  glBlitNamedFramebuffer(render_target.msaa_fbo, render_target.fbo, 0, 0, xx render_target.width, xx render_target.height, 0, 0, xx render_target.width, xx render_target.height,
                          GL_COLOR_BUFFER_BIT, GL_NEAREST);
}

// The fullscreen shader may declare u_input and u_texel_size, which get filled in.
r_create_post_pipeline :: (label: string, fs_path: string) -> Renderer_Pipeline {
  vs := compile_shader_from_source(tprint("% VS", label), FULLSCREEN_VS_SOURCE, GL_VERTEX_SHADER);
  fs := compile_shader_from_file(tprint("% FS", label), fs_path, GL_FRAGMENT_SHADER);

  pipeline := create_renderer_pipeline(label);
  add_or_replace_pipeline_stage(*pipeline, GL_VERTEX_SHADER_BIT,   vs);
  add_or_replace_pipeline_stage(*pipeline, GL_FRAGMENT_SHADER_BIT, fs);
  return pipeline;
}

r_load_texture_from_path :: (renderer: *Renderer, label: string, path: string, filter_param: s32 = GL_NEAREST, wrap_param: s32 = GL_CLAMP_TO_EDGE, generate_mipmaps := false) -> *Texture {
  stbi_set_flip_vertically_on_load(1);
  width, height, channels: s32;
  data := stbi_load(temp_c_string(path), *width, *height, *channels, 4);
  if !data {
    log_error("Failed to load texture: % from %", label, path);
    assert(false);
  }
  defer stbi_image_free(data);

  mip_levels := ifx generate_mipmaps then mip_level_count_for_size(width, height) else 1;
  texture := register_texture_2d(renderer, label, width, height, GL_RGBA8, filter_param, wrap_param, mip_levels);
  glTextureSubImage2D(texture.handle, 0, 0, 0, xx width, xx height, GL_RGBA, GL_UNSIGNED_BYTE, data);
  texture.has_transparency = rgba_pixels_have_transparency(data, width * height);
  if generate_mipmaps  glGenerateTextureMipmap(texture.handle);
  return texture;
}

r_create_texture_from_pixels :: (renderer: *Renderer, label: string, width: s32, height: s32, pixels: [] u8, filter_param: s32 = GL_LINEAR, wrap_param: s32 = GL_CLAMP_TO_EDGE, generate_mipmaps := false) -> *Texture {
  if !(pixels.count == width * height * 4) {
    log_error("Expected RGBA packing in r_create_texture_from_pixels");
    assert(false);
  }

  mip_levels := ifx generate_mipmaps then mip_level_count_for_size(width, height) else 1;
  texture := register_texture_2d(renderer, label, width, height, GL_RGBA8, filter_param, wrap_param, mip_levels);
  glTextureSubImage2D(texture.handle, 0, 0, 0, xx width, xx height, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data);
  texture.has_transparency = rgba_pixels_have_transparency(pixels.data, width * height);
  if generate_mipmaps  glGenerateTextureMipmap(texture.handle);
  return texture;
}

#scope_module

SCREEN_VS_SOURCE     :: #run read_bundled_shader("Screen", "Screen.vert");
SCREEN_FS_SOURCE     :: #run read_bundled_shader("Screen", "Screen.frag");
TEXT_VS_SOURCE       :: #run read_bundled_shader("Text", "Text.vert");
TEXT_FS_SOURCE       :: #run read_bundled_shader("Text", "Text.frag");
LINE3D_VS_SOURCE     :: #run read_bundled_shader("Line3D", "Line3D.vert");
LINE3D_FS_SOURCE     :: #run read_bundled_shader("Line3D", "Line3D.frag");
FULLSCREEN_VS_SOURCE :: #run read_bundled_shader("Fullscreen", "Fullscreen.vert");

read_bundled_shader :: (folder: string, name: string) -> string {
  path := tprint("%Shaders/%/%", #filepath, folder, name);
  source, ok := read_entire_file(path);
  assert(ok, tprint("Renderer: cannot read shader %", path));

  // Injected right after #version, so every shader stays in lock step with
  // MAX_BATCH_TEXTURES.
  line_end := 0;
  while line_end < source.count && source[line_end] != #char "\n"  line_end += 1;
  line_end += 1;
  head: string = .{ line_end, source.data };
  tail: string = .{ source.count - line_end, source.data + line_end };
  return tprint("%#define MAX_TEXTURES %\n%", head, MAX_BATCH_TEXTURES, tail);
}

next_texture_unit :: (renderer: *Renderer) -> s32 {
  unit := renderer.texture_unit_count;
  assert(unit < MAX_BATCH_TEXTURES,
         "Renderer: out of texture units (MAX_BATCH_TEXTURES = %). Every texture, font atlas and render target takes one.",
         MAX_BATCH_TEXTURES);
  renderer.texture_unit_count += 1;
  return unit;
}

// Callers upload pixels afterwards through the returned handle, and must call
// glGenerateTextureMipmap themselves when mip_levels > 1.
register_texture_2d :: (renderer: *Renderer, label: string, width: s32, height: s32, internal_format: GLenum, filter: s32, wrap: s32 = GL_CLAMP_TO_EDGE, mip_levels: s32 = 1) -> *Texture {
  push_allocator(flat_pool_allocator_proc, *renderer.pool);

  result: Texture;
  result.label  = copy_string(label);
  result.width  = xx width;
  result.height = xx height;

  glCreateTextures(GL_TEXTURE_2D, 1, *result.handle);
  glTextureStorage2D(result.handle, xx mip_levels, internal_format, xx width, xx height);
  glTextureParameteri(result.handle, GL_TEXTURE_MIN_FILTER, filter);
  glTextureParameteri(result.handle, GL_TEXTURE_MAG_FILTER, filter);
  glTextureParameteri(result.handle, GL_TEXTURE_WRAP_S, wrap);
  glTextureParameteri(result.handle, GL_TEXTURE_WRAP_T, wrap);
  if mip_levels > 1  glTextureParameterf(result.handle, GL_TEXTURE_MAX_ANISOTROPY, renderer.max_anisotropy);

  result.texture_unit_index = next_texture_unit(renderer);
  glBindTextureUnit(xx result.texture_unit_index, result.handle);

  array_add(*renderer.textures, result);
  return *renderer.textures[renderer.textures.count - 1];
}

rgba_pixels_have_transparency :: (pixels: *u8, pixel_count: s64) -> bool {
  for pixel_index: 0..pixel_count-1 {
    if pixels[pixel_index * 4 + 3] != 255  return true;
  }
  return false;
}

mip_level_count_for_size :: (width: s32, height: s32) -> s32 {
  levels: s32 = 1;
  size := max(width, height);
  while size > 1 {
    size /= 2;
    levels += 1;
  }
  return levels;
}

draw_quad_batch :: (renderer: *Renderer, pipeline: *Renderer_Pipeline, batch: *Quad_Batch, instances: *void, count: s64, stride: s64) {
  if count <= 0  return;

  glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, xx pipeline.label.count, pipeline.label.data);
  defer glPopDebugGroup();

  glBindProgramPipeline(pipeline.handle);
  defer glBindProgramPipeline(0);

  glNamedBufferData(batch.instance_vbo, count * stride, instances, GL_STREAM_DRAW);

  glBindVertexArray(batch.vao);
  defer glBindVertexArray(0);

  glDrawElementsInstanced(GL_TRIANGLES, xx batch.indices_count, GL_UNSIGNED_INT, null, xx count);

  #if DEBUG {
    renderer.stats.draw_calls     += 1;
    renderer.stats.instance_bytes += count * stride;
  }
}

apply_blend_mode :: (mode: Render_Pass.Blend_Mode) {
  if mode == .NONE {
    glDisable(GL_BLEND);
    return;
  }
  glEnable(GL_BLEND);
  glBlendEquation(GL_FUNC_ADD);
  // Separate RGB/alpha so a render target's own alpha channel stays sensible
  // when later composited or fed to a post pass.
  if #complete mode == {
    case .NONE;
    case .ALPHA;         glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE,       GL_ONE_MINUS_SRC_ALPHA);
    case .PREMULTIPLIED; glBlendFuncSeparate(GL_ONE,       GL_ONE_MINUS_SRC_ALPHA, GL_ONE,       GL_ONE_MINUS_SRC_ALPHA);
    case .ADDITIVE;      glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE,                 GL_ONE,       GL_ONE);
    case .MULTIPLY;      glBlendFuncSeparate(GL_DST_COLOR, GL_ZERO,                GL_DST_ALPHA, GL_ZERO);
  }
}

// quick_sort isn't stable on its own, so _seq breaks ties by submission order.
sort_quad_batch :: (list: *[..]$T) {
  quick_sort(list.*, (a: T, b: T) -> int {
    if a.sort_key != b.sort_key  return ifx a.sort_key < b.sort_key then -1 else 1;
    return cast(int) (cast(s64) a._seq - cast(s64) b._seq);
  });
}

flush_quad_batches :: (renderer: *Renderer, draw_screen: bool, draw_text: bool) {
  // Screen-space quads ignore the pass's 3D state. Nothing is restored: this is the last draw of a pass and r_begin_pass sets all of it.
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_CULL_FACE);
  glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

  if draw_screen {
    glProgramUniform2fv(renderer.screen_pipeline.vs_handle, renderer.screen_u_screen_size, 1, cast(*float) *renderer.screen_size);
    draw_quad_batch(renderer, *renderer.screen_pipeline, *renderer.screen_batch,
                    renderer.immediate_screen_quads.data, renderer.immediate_screen_quads.count,
                    size_of(Screen_Quad_Instance));
  }
  if draw_text {
    glProgramUniform2fv(renderer.text_pipeline.vs_handle, renderer.text_u_screen_size, 1, cast(*float) *renderer.screen_size);
    draw_quad_batch(renderer, *renderer.text_pipeline, *renderer.text_batch,
                    renderer.immediate_text_quads.data, renderer.immediate_text_quads.count,
                    size_of(Text_Quad_Instance));
  }
}

gl_internal_format :: (format: Render_Target.Render_Target_Format) -> GLenum {
  if #complete format == {
    case .RGBA8;   return GL_RGBA8;
    case .RGBA16F; return GL_RGBA16F;
    case .RGBA32F; return GL_RGBA32F;
  }
}

create_render_target_texture :: (renderer: *Renderer, label: string, width: s32, height: s32, internal_format: GLenum) -> *Texture {
  return register_texture_2d(renderer, label, width, height, internal_format, GL_LINEAR);
}

render_target_init_gl :: (renderer: *Renderer, render_target: *Render_Target, reuse_color: bool) {
  internal_format := gl_internal_format(render_target.format);

  if reuse_color && render_target.color {
    texture := render_target.color; // keep its identity/texture unit; swap only the GL object
    glDeleteTextures(1, *texture.handle);
    glCreateTextures(GL_TEXTURE_2D, 1, *texture.handle);
    glTextureStorage2D(texture.handle, 1, internal_format, xx render_target.width, xx render_target.height);
    glTextureParameteri(texture.handle, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTextureParameteri(texture.handle, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTextureParameteri(texture.handle, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTextureParameteri(texture.handle, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    texture.width  = xx render_target.width;
    texture.height = xx render_target.height;
    glBindTextureUnit(xx texture.texture_unit_index, texture.handle);
  } else {
    render_target.color = create_render_target_texture(renderer, tprint("%_color", render_target.label), render_target.width, render_target.height, internal_format);
  }

  glCreateFramebuffers(1, *render_target.fbo);
  glNamedFramebufferTexture(render_target.fbo, GL_COLOR_ATTACHMENT0, render_target.color.handle, 0);

  if render_target.has_depth {
    glCreateRenderbuffers(1, *render_target.depth_handle);
    glNamedRenderbufferStorage(render_target.depth_handle, GL_DEPTH24_STENCIL8, xx render_target.width, xx render_target.height);
    glNamedFramebufferRenderbuffer(render_target.fbo, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, render_target.depth_handle);
  }

  draw_buffers: [1]GLenum = .[GL_COLOR_ATTACHMENT0];
  glNamedFramebufferDrawBuffers(render_target.fbo, 1, draw_buffers.data);

  status := glCheckNamedFramebufferStatus(render_target.fbo, GL_FRAMEBUFFER);
  if status != GL_FRAMEBUFFER_COMPLETE {
    log_error("Render target '%' is incomplete (status %)", render_target.label, formatInt(status, base = 16));
  }

  if render_target.samples > 1  render_target_init_msaa_gl(render_target, internal_format, draw_buffers);
}

render_target_init_msaa_gl :: (render_target: *Render_Target, internal_format: GLenum, draw_buffers: [1]GLenum) {
  glCreateFramebuffers(1, *render_target.msaa_fbo);

  glCreateRenderbuffers(1, *render_target.msaa_color_handle);
  glNamedRenderbufferStorageMultisample(render_target.msaa_color_handle, xx render_target.samples, internal_format, xx render_target.width, xx render_target.height);
  glNamedFramebufferRenderbuffer(render_target.msaa_fbo, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, render_target.msaa_color_handle);

  if render_target.has_depth {
    glCreateRenderbuffers(1, *render_target.msaa_depth_handle);
    glNamedRenderbufferStorageMultisample(render_target.msaa_depth_handle, xx render_target.samples, GL_DEPTH24_STENCIL8, xx render_target.width, xx render_target.height);
    glNamedFramebufferRenderbuffer(render_target.msaa_fbo, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, render_target.msaa_depth_handle);
  }

  glNamedFramebufferDrawBuffers(render_target.msaa_fbo, 1, draw_buffers.data);

  status := glCheckNamedFramebufferStatus(render_target.msaa_fbo, GL_FRAMEBUFFER);
  if status != GL_FRAMEBUFFER_COMPLETE {
    log_error("Render target '%''s MSAA framebuffer is incomplete (status %)", render_target.label, formatInt(status, base = 16));
  }
}

render_target_deinit_gl :: (render_target: *Render_Target) {
  if render_target.fbo               { glDeleteFramebuffers(1, *render_target.fbo);                render_target.fbo = 0; }
  if render_target.depth_handle      { glDeleteRenderbuffers(1, *render_target.depth_handle);      render_target.depth_handle = 0; }
  if render_target.msaa_fbo          { glDeleteFramebuffers(1, *render_target.msaa_fbo);           render_target.msaa_fbo = 0; }
  if render_target.msaa_color_handle { glDeleteRenderbuffers(1, *render_target.msaa_color_handle); render_target.msaa_color_handle = 0; }
  if render_target.msaa_depth_handle { glDeleteRenderbuffers(1, *render_target.msaa_depth_handle); render_target.msaa_depth_handle = 0; }
}

create_pipeline_from_sources :: (label: string, vs_source: string, fs_source: string) -> Renderer_Pipeline {
  vs := compile_shader_from_source(tprint("% VS", label), vs_source, GL_VERTEX_SHADER);
  fs := compile_shader_from_source(tprint("% FS", label), fs_source, GL_FRAGMENT_SHADER);

  pipeline := create_renderer_pipeline(label);
  add_or_replace_pipeline_stage(*pipeline, GL_VERTEX_SHADER_BIT,   vs);
  add_or_replace_pipeline_stage(*pipeline, GL_FRAGMENT_SHADER_BIT, fs);
  return pipeline;
}

bind_pipeline_samplers :: (pipeline: *Renderer_Pipeline, count: s32) {
  for i: 0..count-1 {
    name := tprint("u_textures[%]\0", i);
    location := glGetUniformLocation(pipeline.fs_handle, xx name.data);
    if location != -1  glProgramUniform1i(pipeline.fs_handle, location, i);
  }
}

setup_screen_batch :: (renderer: *Renderer) {
  batch := *renderer.screen_batch;
  create_quad_batch_base(batch, xx size_of(Screen_Quad_Instance));

  T :: Screen_Quad_Instance;
  quad_attrib_f(batch.vao, 1, 2, xx offset_of(T, "top_left"));
  quad_attrib_f(batch.vao, 2, 2, xx offset_of(T, "size"));
  quad_attrib_f(batch.vao, 3, 2, xx offset_of(T, "uv_min"));
  quad_attrib_f(batch.vao, 4, 2, xx offset_of(T, "uv_max"));
  quad_attrib_i(batch.vao, 5, GL_UNSIGNED_INT, xx offset_of(T, "tint"));
  quad_attrib_i(batch.vao, 6, GL_INT,          xx offset_of(T, "texture_unit_index"));
  quad_attrib_f(batch.vao, 7, 1, xx offset_of(T, "border_thickness"));
  quad_attrib_i(batch.vao, 8, GL_UNSIGNED_INT, xx offset_of(T, "border_color"));
  quad_attrib_f(batch.vao, 9, 2, xx offset_of(T, "clip_min"));
  quad_attrib_f(batch.vao, 10, 2, xx offset_of(T, "clip_max"));
  quad_attrib_f(batch.vao, 11, 1, xx offset_of(T, "rotation"));
  quad_attrib_f(batch.vao, 12, 4, xx offset_of(T, "corner_radii"));
}

setup_text_batch :: (renderer: *Renderer) {
  batch := *renderer.text_batch;
  create_quad_batch_base(batch, xx size_of(Text_Quad_Instance));

  T :: Text_Quad_Instance;
  quad_attrib_f(batch.vao, 1, 2, xx offset_of(T, "top_left"));
  quad_attrib_f(batch.vao, 2, 2, xx offset_of(T, "size"));
  quad_attrib_f(batch.vao, 3, 2, xx offset_of(T, "uv_min"));
  quad_attrib_f(batch.vao, 4, 2, xx offset_of(T, "uv_max"));
  quad_attrib_i(batch.vao, 5, GL_UNSIGNED_INT, xx offset_of(T, "tint"));
  quad_attrib_i(batch.vao, 6, GL_INT,          xx offset_of(T, "texture_unit_index"));
  quad_attrib_f(batch.vao, 7, 2, xx offset_of(T, "clip_min"));
  quad_attrib_f(batch.vao, 8, 2, xx offset_of(T, "clip_max"));
}

create_quad_batch_base :: (batch: *Quad_Batch, instance_stride: u32) {
  verts:   [4]Quad_Vertex = .[ .{.{0, 0}}, .{.{1, 0}}, .{.{1, 1}}, .{.{0, 1}} ];
  indices: [6]u32         = .[ 0, 1, 2,  2, 3, 0 ];

  glCreateVertexArrays(1, *batch.vao);
  glCreateBuffers(1, *batch.vbo);
  glCreateBuffers(1, *batch.ibo);
  glCreateBuffers(1, *batch.instance_vbo);

  glNamedBufferData(batch.vbo, verts.count   * size_of(Quad_Vertex), verts.data,   GL_STATIC_DRAW);
  glNamedBufferData(batch.ibo, indices.count * size_of(u32),         indices.data, GL_STATIC_DRAW);
  glNamedBufferData(batch.instance_vbo, 0, null, GL_STREAM_DRAW);

  glVertexArrayVertexBuffer(batch.vao, 0, batch.vbo, 0, size_of(Quad_Vertex));
  glVertexArrayElementBuffer(batch.vao, batch.ibo);

  glEnableVertexArrayAttrib(batch.vao,  0);
  glVertexArrayAttribFormat(batch.vao,  0, 2, GL_FLOAT, GL_FALSE, xx offset_of(Quad_Vertex, "position"));
  glVertexArrayAttribBinding(batch.vao, 0, 0);

  glVertexArrayVertexBuffer(batch.vao, 1, batch.instance_vbo, 0, instance_stride);
  glVertexArrayBindingDivisor(batch.vao, 1, 1);

  batch.indices_count = xx indices.count;
}

quad_attrib_f :: (vao: u32, location: u32, component_count: s32, offset: u32) {
  glEnableVertexArrayAttrib(vao,  location);
  glVertexArrayAttribFormat(vao,  location, component_count, GL_FLOAT, GL_FALSE, offset);
  glVertexArrayAttribBinding(vao, location, 1);
}

quad_attrib_i :: (vao: u32, location: u32, gl_type: GLenum, offset: u32) {
  glEnableVertexArrayAttrib(vao,  location);
  glVertexArrayAttribIFormat(vao, location, 1, gl_type, offset);
  glVertexArrayAttribBinding(vao, location, 1);
}

create_renderer_pipeline :: (label: string) -> Renderer_Pipeline {
  pipeline: Renderer_Pipeline;
  pipeline.label = label;
  glCreateProgramPipelines(1, *pipeline.handle);
  return pipeline;
}

add_or_replace_pipeline_stage :: (pipeline: *Renderer_Pipeline, stage: u32, shader_program: u32) {
  glUseProgramStages(pipeline.handle, stage, shader_program);
  if stage == {
    case GL_VERTEX_SHADER_BIT;   pipeline.vs_handle = shader_program;
    case GL_FRAGMENT_SHADER_BIT; pipeline.fs_handle = shader_program;
    case;                        log_error("Unhandled shader stage: %", stage);
  }
}
