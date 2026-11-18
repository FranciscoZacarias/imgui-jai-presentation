UI_Node_Flags :: enum_flags u32 {
  CLICKABLE;
  DRAGGABLE_PANEL;  // moves when a descendant DRAGGABLE is dragged
  DRAGGABLE;
  HOVERABLE;
  RESIZABLE;
  DRAW_TEXT;
  DRAW_LINES;
  TEXT_CENTER_X;
  TEXT_CENTER_Y;
  FLOATING;         // out of the layout flow, at parent origin + offset
  SCROLL_Y;
  OVERLAY;          // clipped only to the screen, drawn after every window
  INPUT_SINK;       // claims hover and press with no visual state
  DISABLED;
}

UI_Axis :: enum u8 { Y; X; }

UI_Dock :: enum u8 {
  NONE; FULL;
  LEFT;      RIGHT;      TOP;      BOTTOM;
  LEFT_EDGE; RIGHT_EDGE; TOP_EDGE; BOTTOM_EDGE;
}

UI_Window_Flags :: enum_flags u32 {
  NO_MOVE;
  NO_RESIZE;
  NO_CLOSE;
  NO_COLLAPSE;
  NO_DOCK;
}
UI_Size_Kind :: enum u8 {
  NONE;
  PIXELS;
  PARENT_FRACTION;  // of the space still free in the parent
  PARENT_RATIO;     // of the parent's whole content size
  TEXT;             // text size + value
}

UI_Size :: struct {
  kind:  UI_Size_Kind;
  value: float;
  min:   float;
}

UI_Box_Size :: struct {
  width:  UI_Size;
  height: UI_Size;
}

UI_Visual_State :: enum u8 { NORMAL; HOVER; ACTIVE; }

UI_Color_Set :: struct {
  normal: Vector4;
  hover:  Vector4;
  active: Vector4;
}

UI_Params :: struct {
  size:      UI_Box_Size;
  axis:      UI_Axis = .Y;
  offset:    Vector2;
  padding:   float;
  pad_right: float;
  spacing:   float;
  text:      string;
  name:      string; // widget or part name, for debugging tools

  background: UI_Color_Set;
  border:     UI_Color_Set;
  foreground: UI_Color_Set;
  border_thickness: float;
  corner_radius:    float;
  corners:          u8 = R_CORNERS_ALL;

  texture: *Texture;
  uv_min:  Vector2;
  uv_max:  Vector2 = .{ 1, 1 };

  points:     [] Vector2;
  line_width: float;

  animate:    bool = true;
  render:     bool = true;
  depth_base: float;  // starts this subtree's depth band (window z-order)
  depth_band: float;  // size of that band; nested windows split its front half
  opacity:    float = 1.0;
  shadow:     float;
  disabled:   bool = false;
}

UI_Rect :: struct {
  pos:  Vector2;
  size: Vector2;
}

ui_default_atlas: *Texture;

ui_debug_node_borders := UI_DEBUG_NODE_BORDERS; // runtime toggle, starts at the compile-time default

UI_Node :: struct {
  key: u64;

  parent: *UI_Node;
  first:  *UI_Node;
  last:   *UI_Node;
  next:   *UI_Node;
  prev:   *UI_Node;

  label: string;
  text:  string;
  flags: UI_Node_Flags;
  params: UI_Params;

  rect:       UI_Rect;
  clip:       UI_Rect;
  inner:      UI_Rect;
  child_clip: UI_Rect;
  cursor:     Vector2;
  text_size:  Vector2;
  depth:      float;  // smaller = in front
  panel:      u64;    // key of the nearest enclosing window, 0 = none

  background: UI_Color_Set;
  border:     UI_Color_Set;
  foreground: UI_Color_Set;
  opacity:    float;
}

UI_Signal :: struct {
  node:     *UI_Node;
  hovered:  bool;
  held:     bool;
  pressed:  bool;
  clicked:  bool;  // press or release, per UI_ACTIVATE_ON_PRESS
  released: bool;  // pressed and released on this node
  dragging: bool;
  resizing: bool;
  close:    bool;

  focused:   bool;
  docked:    bool;
  minimized: bool;

  changed:   bool;
  submitted: bool;
}

UI_Measure_Proc :: #type (text: string) -> (width: float, height: float);

UI_Metrics :: struct {
  font:         *Font;
  line_height:  float = 16.0;
  measure_text: UI_Measure_Proc;

  get_clipboard: #type () -> string;
  set_clipboard: #type (text: string);
}

UI_KEY_COUNT :: 15;
UI_Key :: enum u8 {
  BACKSPACE :: 0;
  DELETE;
  LEFT;
  RIGHT;
  UP;
  DOWN;
  HOME;
  END;
  ENTER;
  ESCAPE;
  TAB;
  A; // the letter keys are read with Ctrl held
  C;
  V;
  X;
}

UI_Input :: struct {
  screen_size:   Vector2;
  mouse_pos:     Vector2;
  mouse_delta:   Vector2;

  // 0 = left, 1 = right, 2 = middle
  mouse_down:     [3] bool;
  mouse_pressed:  [3] bool;
  mouse_released: [3] bool;

  dock_modifier:  bool;
  scroll:         float; // notches, positive = down
  dt: float;

  text:  string;
  keys:  [UI_KEY_COUNT] bool;
  ctrl:  bool;
  shift: bool;
}

ui_utf8_encode :: (codepoint: u32, out: [] u8) -> int {
  if codepoint < 0x80 {
    out[0] = cast(u8) codepoint;
    return 1;
  }
  if codepoint < 0x800 {
    out[0] = cast(u8) (0xC0 | (codepoint >> 6));
    out[1] = cast(u8) (0x80 | (codepoint & 0x3F));
    return 2;
  }
  if codepoint < 0x10000 {
    out[0] = cast(u8) (0xE0 | (codepoint >> 12));
    out[1] = cast(u8) (0x80 | ((codepoint >> 6) & 0x3F));
    out[2] = cast(u8) (0x80 | (codepoint & 0x3F));
    return 3;
  }
  out[0] = cast(u8) (0xF0 | (codepoint >> 18));
  out[1] = cast(u8) (0x80 | ((codepoint >> 12) & 0x3F));
  out[2] = cast(u8) (0x80 | ((codepoint >> 6) & 0x3F));
  out[3] = cast(u8) (0x80 | (codepoint & 0x3F));
  return 4;
}

UI_Quad :: struct {
  rect: UI_Rect;
  clip: UI_Rect;

  color:            Vector4;
  border_color:     Vector4;
  border_thickness: float;
  corner_radius:    float;
  corner_mask:      u8 = R_CORNERS_ALL;
  rotation:         float;

  texture: *Texture;
  uv_min:  Vector2;
  uv_max:  Vector2 = .{ 1, 1 };
}

UI_Theme :: struct {
  window_background: UI_Color_Set;
  window_border:     UI_Color_Set;
  title_bar:         UI_Color_Set;
  button:            UI_Color_Set;
  button_border:     UI_Color_Set;
  danger:            UI_Color_Set;
  text:              UI_Color_Set;
  slider_track:      UI_Color_Set;
  slider_fill:       UI_Color_Set;
  group_background:  UI_Color_Set;
  handle:            Vector4;
  dock_hint:         Vector4;
  scroll_track:      Vector4;
  scroll_thumb:      UI_Color_Set;
  accent:            Vector4;
  window_shadow:     float;
  corner_radius:     float = 3.0;
  border_thickness:  float = 1.0;
  unfocused_dim:     float;
  transition_speed:  float;
}

ui_theme: UI_Theme;

ui_set_theme :: (theme: UI_Theme) {
  ui_theme = theme;
}

ui_persistent_allocator :: () -> Allocator {
  return .{ flat_pool_allocator_proc, *ui.persistent };
}

ui_frame_allocator :: () -> Allocator {
  return .{ flat_pool_allocator_proc, *ui.frame_pool };
}

ui_init :: () {
  init(*ui.frame_pool);
  init(*ui.persistent);
  pool := ui_persistent_allocator();

  ui.parent_stack.allocator     = pool;
  ui.caches.allocator           = pool;
  ui.quads.allocator             = pool;
  ui.overlay_nodes.allocator     = pool;
  ui.overlay_quads.allocator     = pool;
  ui.window_order.allocator      = pool;
  ui.popup_stack.allocator       = pool;
  ui.collapse_stack.allocator    = pool;
  ui.tree_stack.allocator        = pool;
  ui.plot_stack.allocator        = pool;
  ui.columns_stack.allocator     = pool;
  ui.table_stack.allocator       = pool;
  ui.id_stack.allocator          = pool;
  ui.disabled_stack.allocator    = pool;
  #if UI_DEBUG  ui.debug_keys.allocator = pool;

  // Reserved up front: growing inside a Flat_Pool abandons the old buffer.
  table_resize(*ui.caches, 4096);
  #if UI_DEBUG  table_resize(*ui.debug_keys, 4096);

  array_reserve(*ui.parent_stack,   128);
  array_reserve(*ui.quads,        16384);
  array_reserve(*ui.overlay_nodes,     16);
  array_reserve(*ui.overlay_quads,     256);
  array_reserve(*ui.window_order,    64);
  array_reserve(*ui.popup_stack,      16);
  array_reserve(*ui.collapse_stack,   16);
  array_reserve(*ui.tree_stack,       32);
  array_reserve(*ui.plot_stack,        8);
  array_reserve(*ui.columns_stack,     8);
  array_reserve(*ui.table_stack,       8);
  array_reserve(*ui.id_stack,         32);
  array_reserve(*ui.disabled_stack,   16);

  ui_set_theme(ui_theme_from_palette(ui_palettes[0]));
}

ui_deinit :: () {
  fini(*ui.frame_pool);
  fini(*ui.persistent);
  ui = .{};
}

ui_begin :: (input: UI_Input, metrics: UI_Metrics) {
  ui.frame  += 1;
  reset(*ui.frame_pool);

  ui.input   = input;
  ui.metrics = metrics;

  #if UI_DEBUG {
    assert(metrics.measure_text != null, "Imgui: UI_Metrics.measure_text is null. Text sizing falls back to a crude fixed-width guess and every layout will be wrong - wire a real measure proc from the host.");
    assert(metrics.font != null, "Imgui: UI_Metrics.font is null, so no text can be drawn.");
  }

  array_reset_keeping_memory(*ui.quads);
  array_reset_keeping_memory(*ui.overlay_nodes);
  array_reset_keeping_memory(*ui.overlay_quads);
  ui.parent_stack.count   = 0;
  ui.popup_stack.count    = 0;
  ui.collapse_stack.count = 0;
  ui.tree_stack.count     = 0;
  ui.plot_stack.count     = 0;
  ui.columns_stack.count  = 0;
  ui.table_stack.count    = 0;
  ui.id_stack.count       = 0;
  ui.disabled_stack.count = 0;
  #if UI_DEBUG {
    table_reset_keeping_memory(*ui.debug_keys); // table_reset would free the buffer
    ui.frame_node_count = 0;
  }

  if ui.hot_key != 0 && ui.hot_key == ui.hover_key {
    ui.hover_t += input.dt;
  } else {
    ui.hover_key = ui.hot_key;
    ui.hover_t   = 0.0;
  }
  ui.tooltip_active = false;

  // Latches drop only once the mouse is idle, so the release frame still reports `clicked`.
  if !input.mouse_down[0] && !input.mouse_released[0] {
    ui.active_key       = 0;
    ui.drag_panel_key   = 0;
    ui.resizing_key     = 0;
    ui.table_resize_key = 0;
  }

  if ui.drag_panel_key != 0 {
    cache := ui_cache_get(ui.drag_panel_key);
    cache.drag_offset = cache.grab_drag_offset + (input.mouse_pos - cache.grab_mouse);
  }
  if ui.resizing_key != 0 {
    cache := ui_cache_get(ui.resizing_key);
    delta := input.mouse_pos - cache.grab_mouse;
    edge  := cache.resize_edge;
    if (edge & UI_EDGE_R) != 0  cache.resize_offset.x = cache.grab_resize_offset.x + delta.x;
    if (edge & UI_EDGE_L) != 0 { cache.resize_offset.x = cache.grab_resize_offset.x - delta.x; cache.drag_offset.x = cache.grab_drag_offset.x + delta.x; }
    if (edge & UI_EDGE_B) != 0  cache.resize_offset.y = cache.grab_resize_offset.y + delta.y;
    if (edge & UI_EDGE_T) != 0 { cache.resize_offset.y = cache.grab_resize_offset.y - delta.y; cache.drag_offset.y = cache.grab_drag_offset.y + delta.y; }
  }

  ui.hot_key             = 0;
  ui.hot_depth           = 1.0e30;
  ui.mouse_panel_next     = 0;
  ui.mouse_panel_depth    = 1.0e30;
  ui.active_press_depth  = 1.0e30;
  ui.resize_cand_key     = 0;
  ui.resize_cand_depth   = 1.0e30;
  ui.resize_cand_edge    = 0;
  ui.scroll_cand         = null;
  ui.scroll_cand_depth   = 1.0e30;
  ui.next_depth          = 1.0;
  ui.last_node           = null;

  root := ui_allocate_node();
  root.key        = UI_ROOT_KEY;
  root.rect       = .{ .{0, 0}, input.screen_size };
  root.clip       = root.rect;
  root.inner      = root.rect;
  root.child_clip = root.rect;
  root.cursor     = .{0, 0};
  root.depth      = 1.0;
  root.opacity    = 1.0;
  root.params.axis = .Y;
  root.params.name = "root";
  ui.root = root;

  ui.parent_stack.count = 0;
  ui_push_parent(root);
}

ui_end :: () {
  ui_check(ui.parent_stack.count == 1, "Imgui: % begin/end pair(s) still open at ui_end - a ui_*_begin without its ui_*_end.", ui.parent_stack.count - 1);
  ui_check(ui.popup_stack.count == 0 && ui.collapse_stack.count == 0 && ui.tree_stack.count == 0 && ui.plot_stack.count == 0 && ui.columns_stack.count == 0 && ui.table_stack.count == 0, "Imgui: an unclosed dropdown / group / tree / plot / table / menu scope at ui_end.");
  ui_check(ui.id_stack.count == 0, "Imgui: % ui_push_id call(s) without a matching ui_pop_id.", ui.id_stack.count);
  ui_check(ui.disabled_stack.count == 0, "Imgui: % ui_disabled_begin call(s) without a matching ui_disabled_end.", ui.disabled_stack.count);

  ui_pop_parent();

  // A resize wins only if its window is at least as front as what the press hit.
  if ui.resize_cand_key != 0 && ui.resize_cand_depth <= ui.active_press_depth {
    ui.resizing_key   = ui.resize_cand_key;
    ui.active_key     = 0;
    ui.drag_panel_key = 0;
    cache := ui_cache_get(ui.resize_cand_key);
    cache.resize_edge        = ui.resize_cand_edge;
    cache.grab_mouse         = ui.input.mouse_pos;
    cache.grab_resize_offset = cache.resize_offset;
    cache.grab_drag_offset   = cache.drag_offset;
    ui.pressed_window_key = ui.resize_cand_key;
  }

  if ui.pressed_window_key != 0 {
    ui_window_raise_with_ancestors(ui.pressed_window_key);
    ui.pressed_window_key = 0;
  }

  ui.mouse_panel = ui.mouse_panel_next;

  if ui.scroll_cand && ui.input.scroll != 0.0 {
    scroll_cache := ui_cache_get(ui.scroll_cand.key);
    scroll_cache.scroll = clamp(scroll_cache.scroll + ui.input.scroll * UI_SCROLL_STEP, 0.0, scroll_cache.scroll_max);
  }

  // Painter's order: windows back to front, then popups, overlays and the tooltip.
  ui_emit_children(ui.root, 1.0, false);
  overlay_index := 0;
  while overlay_index < ui.overlay_nodes.count { // nested popups append as we walk
    ui_emit(ui.overlay_nodes[overlay_index]);
    overlay_index += 1;
  }
  for ui.overlay_quads  array_add(*ui.quads, it);

  if ui.tooltip_active  ui_emit_tooltip(ui.tooltip_text, ui.tooltip_anchor);

  if ui.frame % UI_CACHE_PURGE_INTERVAL == 0  ui_purge_caches();

  #if UI_DEBUG {
    ui.stats.nodes         = ui.frame_node_count;
    ui.stats.quads         = ui.quads.count;
    ui.stats.cache_entries = ui.caches.count;
    ui.stats.frame_bytes   = cast(int) (ui.frame_pool.current_point - ui.frame_pool.memory_base);
  }
}

ui_quads :: () -> [] UI_Quad {
  return ui.quads;
}

ui_node :: (id: string, flags: UI_Node_Flags, params: UI_Params, loc := #caller_location) -> *UI_Node {
  return ui_node_keyed(ui_scoped_key(id, loc), id, flags, params, loc);
}

ui_node :: (id: string, salt: string, flags: UI_Node_Flags, params: UI_Params, loc := #caller_location) -> *UI_Node {
  return ui_node_keyed(ui_child_key(id, salt, loc), id, flags, ui_params_named(params, salt), loc);
}
ui_node :: (id: string, salt: string, index: s64, flags: UI_Node_Flags, params: UI_Params, loc := #caller_location) -> *UI_Node {
  key := ui_mix_key(ui_mix_key(ui_scoped_key(id, loc), ui_hash(0, salt)), cast,no_check(u64) index);
  return ui_node_keyed(key, id, flags, ui_params_named(params, salt), loc);
}

ui_params_named :: (params: UI_Params, name: string) -> UI_Params {
  named := params;
  if !named.name  named.name = name;
  return named;
}

ui_node_keyed :: (key: u64, label: string, flags: UI_Node_Flags, params: UI_Params, loc: Source_Code_Location) -> *UI_Node {
  parent := ui_parent();

  disabled := params.disabled || ui_is_disabled();
  if disabled {
    flags &= ~(UI_Node_Flags.CLICKABLE | .HOVERABLE | .DRAGGABLE | .RESIZABLE | .SCROLL_Y);
    flags |= .DISABLED;
  }

  node := ui_allocate_node();
  node.key    = key;
  node.label  = ui_frame_copy_string(label);
  node.text   = ui_frame_copy_string(params.text);
  node.flags  = flags;
  node.params = params;

  #if UI_DEBUG {
    assert(table_find_pointer(*ui.debug_keys, node.key) == null,
           "Imgui: two widgets share a key under one parent (label \"%\" at %:%). Give one a \"text##unique\" suffix, a ui_node salt, or a per-iteration id inside a loop.",
           label, loc.fully_pathed_filename, loc.line_number);
    table_add(*ui.debug_keys, node.key, 1);
  }

  if params.depth_base != 0.0  ui.next_depth = params.depth_base;
  node.depth  = ui.next_depth;
  ui.next_depth -= UI_DEPTH_EPSILON;

  node.background = ui_resolve_color_set(params.background, derive = true);
  node.border     = ui_resolve_color_set(params.border,     derive = true);
  node.foreground = params.foreground;
  if node.foreground.normal.w == 0.0  node.foreground.normal = ui_theme.text.normal;
  node.foreground = ui_resolve_color_set(node.foreground, derive = false);
  node.opacity    = ifx params.opacity != 0.0 then params.opacity else 1.0;

  node.parent = parent;
  node.panel  = ifx flags & .DRAGGABLE_PANEL then key else parent.panel;
  if parent.last {
    parent.last.next = node;
    node.prev        = parent.last;
    parent.last      = node;
  } else {
    parent.first = node;
    parent.last  = node;
  }

  floating := flags & .FLOATING;

  consumed_x := max(0.0, parent.cursor.x - parent.inner.pos.x);
  consumed_y := max(0.0, parent.cursor.y - parent.inner.pos.y);
  available := Vector2.{
    max(0.0, parent.inner.size.x - consumed_x),
    max(0.0, parent.inner.size.y - consumed_y),
  };
  if floating  available = parent.rect.size;

  if flags & .DRAW_TEXT || params.size.width.kind == .TEXT || params.size.height.kind == .TEXT {
    w, h := ui_measure_display(node.text);
    node.text_size = .{ w, h };
  }

  total_size := ifx floating then parent.rect.size else parent.inner.size;
  w := ui_resolve_size(params.size.width, available.x, total_size.x, node.text_size.x);
  h := ui_resolve_size(params.size.height, available.y, total_size.y, node.text_size.y);

  node.rect.size = .{ w, h };

  if floating  node.rect.pos = parent.rect.pos + params.offset;
  else         node.rect.pos = parent.cursor  + params.offset;

  if flags & .DRAGGABLE_PANEL {
    // Whole pixels, so children land on integer edges.
    node.rect.pos  = ui_snap(node.rect.pos);
    node.rect.size = ui_snap(node.rect.size);
  }

  ui_node_set_rect(node);
  node.cursor = node.inner.pos;

  if flags & .SCROLL_Y  node.cursor.y -= ui_cache_get(node.key).scroll;

  if !floating {
    if parent.params.axis == .X  parent.cursor.x += node.rect.size.x + parent.params.spacing;
    else                         parent.cursor.y += node.rect.size.y + parent.params.spacing;
  }

  ui_interact(node);
  ui.last_node = node;
  return node;
}

ui_push_parent :: (node: *UI_Node) {
  array_add(*ui.parent_stack, node);
}

ui_pop_parent :: () -> *UI_Node {
  ui_check(ui.parent_stack.count > 0, "Imgui: ui_pop_parent with an empty stack - an extra ui_*_end, or ui_end called twice.");
  node := ui.parent_stack[ui.parent_stack.count - 1];
  ui.parent_stack.count -= 1;
  return node;
}

ui_parent :: () -> *UI_Node {
  ui_check(ui.parent_stack.count > 0, "Imgui: no current parent - a widget built before ui_begin, or after ui_end.");
  return ui.parent_stack[ui.parent_stack.count - 1];
}

// Salts the keys of widgets in a repeated scope (a loop body, a reusable proc).
ui_push_id :: (salt: string) {
  seed := ifx ui.id_stack.count > 0 then ui.id_stack[ui.id_stack.count - 1] else UI_FNV_OFFSET;
  array_add(*ui.id_stack, ui_hash(seed, salt));
}
ui_push_id :: (salt: s64) {
  seed := ifx ui.id_stack.count > 0 then ui.id_stack[ui.id_stack.count - 1] else UI_FNV_OFFSET;
  array_add(*ui.id_stack, ui_mix_key(seed, cast,no_check(u64) salt));
}
ui_push_id :: (salt: *void) {
  ui_push_id(cast,no_check(s64) salt);
}
ui_pop_id :: () {
  ui_check(ui.id_stack.count > 0, "Imgui: ui_pop_id with no matching ui_push_id.");
  ui.id_stack.count -= 1;
}

ui_disabled_begin :: (disabled := true) {
  array_add(*ui.disabled_stack, disabled || ui_is_disabled());
}
ui_disabled_end :: () {
  ui_check(ui.disabled_stack.count > 0, "Imgui: ui_disabled_end without a matching ui_disabled_begin.");
  ui.disabled_stack.count -= 1;
}
ui_is_disabled :: () -> bool {
  return ui.disabled_stack.count > 0 && ui.disabled_stack[ui.disabled_stack.count - 1];
}

ui_scoped_key :: (id: string, loc: Source_Code_Location) -> u64 {
  scope := ui_parent().key;
  if ui.id_stack.count > 0  scope = ui_mix_key(scope, ui.id_stack[ui.id_stack.count - 1]);
  return ui_key(scope, id, loc);
}

ui_child_key :: (id: string, salt: string, loc: Source_Code_Location) -> u64 {
  return ui_mix_key(ui_scoped_key(id, loc), ui_hash(0, salt));
}

ui_cache_for :: (id: string, loc := #caller_location) -> *UI_Node_Cache {
  return ui_cache_get(ui_scoped_key(id, loc));
}

ui_signal_from_node :: (node: *UI_Node) -> UI_Signal {
  signal: UI_Signal;
  signal.node     = node;
  signal.hovered  = (ui.hot_key == node.key);
  signal.held     = (ui.active_key == node.key) && ui.input.mouse_down[0];
  signal.pressed  = (ui.active_key == node.key) && ui.input.mouse_pressed[0];
  signal.released = (ui.active_key == node.key) && ui.input.mouse_released[0] && signal.hovered;
  signal.clicked  = ifx UI_ACTIVATE_ON_PRESS then signal.pressed else signal.released;
  signal.dragging = (ui.drag_panel_key != 0) && (ui.active_key == node.key);
  signal.resizing = (ui.resizing_key == node.key);
  return signal;
}

ui_wants_keyboard :: () -> bool {
  return ui.keyboard_focus_key != 0;
}

ui_wants_mouse :: () -> bool {
  return ui.hot_key != 0 || ui.active_key != 0 || ui.drag_panel_key != 0 || ui.resizing_key != 0;
}

ui_last_node :: () -> *UI_Node {
  return ui.last_node;
}

UI_EDGE_L :: 1;
UI_EDGE_R :: 2;
UI_EDGE_T :: 4;
UI_EDGE_B :: 8;

UI_FNV_OFFSET : u64 : 0xcbf29ce484222325;
UI_FNV_PRIME  : u64 : 0x100000001b3;
UI_ROOT_KEY   : u64 : 0x9e3779b97f4a7c15;

UI_Node_Cache :: struct {
  last_touched: u64;
  free_next:    *UI_Node_Cache;

  drag_offset:   Vector2;
  resize_offset: Vector2;
  minimized:     bool;
  minimize_t:    float;
  expanded:      bool;
  popup_height:  float;

  dock:        UI_Dock;
  dock_t:      float;
  dock_seeded: bool;

  resize_edge: u32;

  menu_anchor: Vector2;

  options:          UI_Window_Flags;
  saved_next_depth: float;
  last_seen_frame:  u64;
  open_t:          float;
  closing:         bool;
  close_t:         float;

  grab_mouse:         Vector2;
  grab_drag_offset:   Vector2;
  grab_resize_offset: Vector2;

  disclosure_ready:  bool;
  disclosure_t:      float;
  disclosure_height: float;

  drag_accumulator: float;

  table_widths: [UI_TABLE_MAX_COLUMNS] float;
  table_ready:  bool;

  caret:       s64;
  selection:   s64; // anchor; == caret when nothing is selected
  text_scroll: float;
  blink_t:     float;

  scroll:                float;
  scroll_max:            float;
  scroll_grab:           float;
  scroll_grab_mouse:     float;

  animated_background: Vector4;
  animated_border:     Vector4;
  animated_foreground: Vector4;
  animated_ready:      bool;
}

Popup_Frame :: struct {
  open:             bool;
  owner:            *UI_Node_Cache;
  anchor:           UI_Rect;
  saved_next_depth: float;
  max_height:       float;
}

Collapse_Frame :: struct {
  open:  bool;
  body:  *UI_Node;
  owner: *UI_Node_Cache;
}

Tree_Frame :: struct {
  open:      bool;
  container: *UI_Node;
}

Plot_Frame :: struct {
  box:          *UI_Node;
  area:         UI_Rect;
  hovered:      bool;
  mouse_x:      float;
  series_index: int;

  hover_count:  int;
  hover_texts:  [8] string;
  hover_colors: [8] Vector4;
}

Columns_Frame :: struct {
  row:        *UI_Node;
  cell_width: float;
  count:      int;
  current:    int;
}

UI_TABLE_MAX_COLUMNS :: 16;

UI_Table_Column :: struct {
  name:  string;
  width: float; // fraction of the inner width; 0 shares what is left
}

Window_Order_Entry :: struct {
  key:    u64;
  parent: u64;
}

Table_Frame :: struct {
  panel:   *UI_Node;
  widths:  [UI_TABLE_MAX_COLUMNS] float;
  count:   int;
  row:     *UI_Node;
  row_seq: int;
  cell:    int;
}

UI_Stats :: struct {
  nodes:         int;
  quads:         int;
  cache_entries: int;
  frame_bytes:   int;
}

ui_cache_key_hash :: (key: u64) -> u32 { return cast,no_check(u32) (key ^ (key >> 32)); }

UI_Context :: struct {
  frame_pool:      Flat_Pool;
  persistent:      Flat_Pool;
  cache_free_list: *UI_Node_Cache;

  frame:   u64;
  input:   UI_Input;
  metrics: UI_Metrics;

  root:         *UI_Node;
  parent_stack: [..] *UI_Node;

  caches: Table(u64, *UI_Node_Cache, ui_cache_key_hash);
  quads:  [..] UI_Quad;

  hot_key:            u64;
  hot_depth:          float;
  active_key:         u64;
  active_press_depth: float;
  drag_panel_key:     u64;
  resizing_key:       u64;

  resize_cand_key:   u64;
  resize_cand_depth: float;
  resize_cand_edge:  u32;

  // The window that owns the mouse: last frame's front-most hit, so a window built
  // later in the frame can't lose a press an earlier one already reported.
  mouse_panel:       u64;
  mouse_panel_next:  u64;
  mouse_panel_depth: float;
  scroll_cand:       *UI_Node;
  scroll_cand_depth: float;

  window_order:       [..] Window_Order_Entry; // back (0) to front among siblings
  pressed_window_key: u64;

  popup_stack:      [..] Popup_Frame;
  collapse_stack:   [..] Collapse_Frame;
  tree_stack:       [..] Tree_Frame;
  plot_stack:       [..] Plot_Frame;
  columns_stack:    [..] Columns_Frame;
  table_stack:      [..] Table_Frame;

  table_resize_key:        u64;
  table_resize_col:        int;
  table_resize_grab_mouse: float;
  table_resize_grab_a:     float;
  table_resize_grab_b:     float;

  id_stack:       [..] u64;
  disabled_stack: [..] bool;

  debug_keys:       Table(u64, u8, ui_cache_key_hash);
  frame_node_count: int;
  stats:            UI_Stats;

  next_depth:    float;
  overlay_nodes: [..] *UI_Node;
  overlay_quads: [..] UI_Quad;

  keyboard_focus_key: u64;
  last_node:          *UI_Node;

  hover_key: u64;
  hover_t:   float;

  tooltip_active: bool;
  tooltip_text:   string;
  tooltip_anchor: Vector2;
}

ui: UI_Context;

ui_focused :: (key: u64) -> bool { return ui.keyboard_focus_key == key; }
ui_focus   :: (key: u64)         { ui.keyboard_focus_key = key; }
ui_blur    :: (key: u64)         { if ui.keyboard_focus_key == key  ui.keyboard_focus_key = 0; }

ui_key_pressed :: inline (key: UI_Key) -> bool {
  return ui.input.keys[cast(int) key];
}

ui_allocate_node :: () -> *UI_Node {
  node := cast(*UI_Node) get(*ui.frame_pool, size_of(UI_Node));
  node.* = .{};
  #if UI_DEBUG  ui.frame_node_count += 1;
  return node;
}

ui_frame_allocate :: ($T: Type, count: int) -> [] T {
  if count <= 0  return .{};
  buffer := get(*ui.frame_pool, count * size_of(T));
  return .{ count, cast(*T) buffer };
}

ui_frame_copy_string :: (text: string) -> string {
  if text.count == 0  return "";
  out := ui_frame_allocate(u8, text.count);
  memcpy(out.data, text.data, text.count);
  return .{ out.count, out.data };
}

// Unlike assert, stays live in release builds.
ui_check :: (condition: bool, message: string, args: .. Any, loc := #caller_location) #expand {
  if !condition && assert_helper(message, ..args, loc)  debug_break();
}

ui_row_height     :: inline () -> float { return floor(ui.metrics.line_height * UI_ROW_HEIGHT_FACTOR);   }
ui_compact_height :: inline () -> float { return floor(ui.metrics.line_height * UI_COMPACT_ROW_FACTOR);  }
ui_title_height   :: inline () -> float { return floor(ui.metrics.line_height * UI_TITLE_HEIGHT_FACTOR); }
ui_separator_height :: inline () -> float { return max(3.0, floor(ui.metrics.line_height * UI_SEPARATOR_FACTOR)); }
ui_menu_width       :: inline () -> float { return max(160.0, floor(ui.metrics.line_height * UI_MENU_WIDTH_FACTOR)); }

ui_smooth :: inline (t: float) -> float {
  clamped := clamp(t, 0.0, 1.0);
  return clamped * clamped * (3.0 - 2.0 * clamped);
}

ui_hash :: (seed: u64, text: string) -> u64 {
  hash := ifx seed != 0 then seed else UI_FNV_OFFSET;
  for 0..text.count-1 {
    hash ^= text[it];
    hash *= UI_FNV_PRIME;
  }
  return hash;
}

ui_mix_key :: inline (a: u64, b: u64) -> u64 {
  a ^= b;
  a *= UI_FNV_PRIME;
  return a;
}

// Parent + id + call site. The file path is a constant, so its address is hashed.
ui_key :: (parent_key: u64, id: string, loc: Source_Code_Location) -> u64 {
  key := ui_hash(parent_key, id);
  key = ui_mix_key(key, cast,no_check(u64) loc.fully_pathed_filename.data);
  key ^= cast,no_check(u64) loc.line_number;      key *= UI_FNV_PRIME;
  key ^= cast,no_check(u64) loc.character_number;  key *= UI_FNV_PRIME;
  return key;
}

ui_cache_get :: (key: u64) -> *UI_Node_Cache {
  found := table_find_pointer(*ui.caches, key);
  if found {
    found.*.last_touched = ui.frame;
    return found.*;
  }

  cache: *UI_Node_Cache;
  if ui.cache_free_list {
    cache = ui.cache_free_list;
    ui.cache_free_list = cache.free_next;
  } else {
    cache = New(UI_Node_Cache,, ui_persistent_allocator());
  }
  cache.* = .{};
  cache.last_touched = ui.frame;
  table_add(*ui.caches, key, cache);
  return cache;
}

ui_purge_caches :: () {
  for cache, key: ui.caches {
    if ui.frame - cache.last_touched > UI_CACHE_TTL_FRAMES {
      cache.free_next   = ui.cache_free_list;
      ui.cache_free_list = cache;
      remove;
    }
  }

  if ui.keyboard_focus_key != 0 && !table_contains(*ui.caches, ui.keyboard_focus_key) {
    ui.keyboard_focus_key = 0;
  }

  kept := 0;
  for ui.window_order {
    if table_contains(*ui.caches, it.key) {
      if kept != it_index  ui.window_order[kept] = it;
      kept += 1;
    }
  }
  ui.window_order.count = kept;
}

ui_window_parent :: (key: u64) -> u64 {
  for ui.window_order  if it.key == key  return it.parent;
  return UI_ROOT_KEY;
}

ui_window_raise :: (key: u64) {
  for ui.window_order {
    if it.key == key {
      entry := it;
      array_ordered_remove_by_index(*ui.window_order, it_index);
      array_add(*ui.window_order, entry);
      return;
    }
  }
}

ui_window_raise_with_ancestors :: (key: u64) {
  while key != UI_ROOT_KEY {
    parent := ui_window_parent(key);
    ui_window_raise(key);
    key = parent;
  }
}

ui_window_rank :: (key: u64) -> rank: int, sibling_count: int {
  parent := ui_window_parent(key);
  rank := -1;
  sibling_count := 0;
  for ui.window_order {
    if it.parent != parent  continue;
    if it.key == key  rank = sibling_count;
    sibling_count += 1;
  }
  return rank, sibling_count;
}

ui_window_is_front :: (key: u64) -> bool {
  parent := ui_window_parent(key);
  front: u64;
  for ui.window_order  if it.parent == parent  front = it.key;
  return front == key;
}

ui_window_is_focused :: (key: u64) -> bool {
  while key != UI_ROOT_KEY {
    if !ui_window_is_front(key)  return false;
    key = ui_window_parent(key);
  }
  return true;
}

ui_window_dim :: (color: Vector4) -> Vector4 {
  body   := ui_theme.window_background.normal;
  amount := ui_theme.unfocused_dim;
  return .{ color.x + (body.x - color.x) * amount, color.y + (body.y - color.y) * amount, color.z + (body.z - color.z) * amount, color.w };
}

ui_resolve_size :: (size: UI_Size, available: float, total: float, text_size: float) -> float {
  value: float;
  if size.kind == {
    case .PIXELS;          value = size.value;
    case .PARENT_FRACTION; value = clamp(size.value, 0.0, 1.0) * available;
    case .PARENT_RATIO;    value = clamp(size.value, 0.0, 1.0) * total;
    case .TEXT;            value = text_size + size.value;
    case;                  value = size.value;
  }
  return max(value, size.min);
}

ui_display_label :: (label: string) -> string {
  if label.count >= 2 {
    for 0..label.count-2 {
      if label[it] == #char "#" && label[it + 1] == #char "#"  return .{ it, label.data };
    }
  }
  return label;
}

ui_measure_display :: (text: string) -> (width: float, height: float) {
  display := ui_display_label(text);
  if ui.metrics.measure_text {
    width, height := ui.metrics.measure_text(display);
    return width, height;
  }
  return cast(float) display.count * (ui.metrics.line_height * 0.5), ui.metrics.line_height;
}

ui_snap :: (v: Vector2) -> Vector2 {
  return .{ floor(v.x + 0.5), floor(v.y + 0.5) };
}

ui_lerp2 :: (a: Vector2, b: Vector2, t: float) -> Vector2 {
  return .{ a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t };
}

ui_emit_tooltip :: (text: string, anchor: Vector2) {
  if text.count == 0  return;

  padding := 6.0;
  text_width, text_height := ui_measure_display(text);
  width  := text_width + padding * 2.0;
  height := text_height + padding * 2.0;
  screen := ui.input.screen_size;

  pos := anchor + Vector2.{ 14.0, 20.0 };
  if pos.x + width  > screen.x  pos.x = max(0.0, screen.x - width);
  if pos.y + height > screen.y  pos.y = max(0.0, anchor.y - height - 6.0);

  clip := UI_Rect.{ .{ 0, 0 }, screen };

  background: UI_Quad;
  background.rect             = .{ pos, .{ width, height } };
  background.clip             = clip;
  background.color            = ui_theme.window_background.normal;
  background.border_color     = ui_theme.window_border.normal;
  background.border_thickness = ui_theme.border_thickness;
  background.corner_radius    = ui_theme.corner_radius;
  array_add(*ui.quads, background);

  ui_push_text(*ui.quads, text, .{ pos.x + padding, pos.y + padding }, clip, ui_theme.text.normal);
}

ui_overlay_rect :: (rect: UI_Rect, background: Vector4, border: Vector4, thickness: float, radius: float) {
  quad: UI_Quad;
  quad.rect             = rect;
  quad.clip             = .{ .{ 0, 0 }, ui.input.screen_size };
  quad.color            = background;
  quad.border_color     = border;
  quad.border_thickness = thickness;
  quad.corner_radius    = radius;
  array_add(*ui.overlay_quads, quad);
}

ui_push_text :: (quads: *[..] UI_Quad, text: string, top_left: Vector2, clip: UI_Rect, color: Vector4) {
  font := ui.metrics.font;
  if !font  return;

  pen_x := top_left.x;
  pen_y := top_left.y + font.ascent;

  index := 0;
  while index < text.count {
    codepoint, size := utf8_decode(text, index);
    index += size;

    if codepoint == #char "\n" {
      pen_x = top_left.x;
      pen_y += font.line_height;
      continue;
    }
    if codepoint < font.first_codepoint || codepoint >= font.first_codepoint + font.num_glyphs  continue;

    glyph := font.glyphs[codepoint - font.first_codepoint];
    if glyph.size.x > 0 && glyph.size.y > 0 {
      quad: UI_Quad;
      quad.rect    = .{ .{ pen_x + glyph.bearing.x, pen_y - glyph.bearing.y }, glyph.size };
      quad.clip    = clip;
      quad.color   = color;
      quad.texture = font.atlas;
      quad.uv_min  = glyph.uv_min;
      quad.uv_max  = glyph.uv_max;
      array_add(quads, quad);
    }
    pen_x += glyph.advance;
  }
}

ui_push_line :: (quads: *[..] UI_Quad, start: Vector2, end: Vector2, width: float, clip: UI_Rect, color: Vector4) {
  delta  := end - start;
  length := sqrt(delta.x * delta.x + delta.y * delta.y);
  if length <= 0.0  return;

  thickness := max(width, 1.0);
  quad: UI_Quad;
  quad.rect     = .{ (start + end) * 0.5 - Vector2.{ length, thickness } * 0.5, .{ length, thickness } };
  quad.clip     = clip;
  quad.color    = color;
  quad.rotation = atan2(delta.y, delta.x);
  array_add(quads, quad);
}

ui_dock_rect :: (dock: UI_Dock, region: UI_Rect) -> UI_Rect {
  origin := region.pos;
  size   := region.size;
  half_w := size.x * 0.5;
  half_h := size.y * 0.5;
  edge_w := size.x * UI_DOCK_EDGE_FRACTION;
  edge_h := size.y * UI_DOCK_EDGE_FRACTION;
  if dock == {
    case .LEFT;      return .{ origin,                              .{ half_w, size.y } };
    case .RIGHT;     return .{ .{ origin.x + half_w, origin.y },     .{ half_w, size.y } };
    case .TOP;       return .{ origin,                              .{ size.x, half_h } };
    case .BOTTOM;    return .{ .{ origin.x, origin.y + half_h },     .{ size.x, half_h } };
    case .LEFT_EDGE;   return .{ origin,                              .{ edge_w, size.y } };
    case .RIGHT_EDGE;  return .{ .{ origin.x + size.x - edge_w, origin.y }, .{ edge_w, size.y } };
    case .TOP_EDGE;    return .{ origin,                              .{ size.x, edge_h } };
    case .BOTTOM_EDGE; return .{ .{ origin.x, origin.y + size.y - edge_h }, .{ size.x, edge_h } };
    case;           return region;
  }
}

ui_mix :: (a: Vector4, b: Vector4, t: float) -> Vector4 {
  return .{
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.z + (b.z - a.z) * t,
    a.w + (b.w - a.w) * t,
  };
}

// Derives hover / active from normal when they are left at alpha 0.
ui_resolve_color_set :: (set: UI_Color_Set, derive: bool) -> UI_Color_Set {
  resolved := set;
  if resolved.normal.w == 0.0  return resolved;

  if resolved.hover.w == 0.0 {
    resolved.hover = ifx derive then ui_mix(resolved.normal, .{ 1, 1, 1, resolved.normal.w }, UI_HOVER_LIFT) else resolved.normal;
  }
  if resolved.active.w == 0.0 {
    resolved.active = ifx derive then ui_mix(resolved.normal, .{ 0, 0, 0, resolved.normal.w }, UI_ACTIVE_PRESS) else resolved.normal;
  }
  return resolved;
}

ui_state_color :: (set: UI_Color_Set, state: UI_Visual_State) -> Vector4 {
  if state == .ACTIVE  return set.active;
  if state == .HOVER   return set.hover;
  return set.normal;
}

ui_animation_t :: (dt: float) -> float {
  return clamp(1.0 - exp(-max(dt, 0.0) * ui_theme.transition_speed), 0.0, 1.0);
}

rect_intersect :: (a: UI_Rect, b: UI_Rect) -> UI_Rect {
  x0 := max(a.pos.x, b.pos.x);
  y0 := max(a.pos.y, b.pos.y);
  x1 := min(a.pos.x + a.size.x, b.pos.x + b.size.x);
  y1 := min(a.pos.y + a.size.y, b.pos.y + b.size.y);
  result: UI_Rect;
  result.pos  = .{ x0, y0 };
  result.size = .{ max(0.0, x1 - x0), max(0.0, y1 - y0) };
  return result;
}

rect_inset :: (rect: UI_Rect, margin: float) -> UI_Rect {
  clamped := min(margin, min(rect.size.x, rect.size.y) * 0.5);
  result: UI_Rect;
  result.pos  = .{ rect.pos.x + clamped, rect.pos.y + clamped };
  result.size = .{ max(0.0, rect.size.x - 2.0 * clamped), max(0.0, rect.size.y - 2.0 * clamped) };
  return result;
}

rect_contains :: (rect: UI_Rect, point: Vector2) -> bool {
  return point.x >= rect.pos.x && point.x < rect.pos.x + rect.size.x &&
         point.y >= rect.pos.y && point.y < rect.pos.y + rect.size.y;
}

// pad_right narrows inner (flow stops before the scrollbar gutter) but not
// child_clip, so the scrollbar in that gutter stays visible.
ui_node_set_rect :: (node: *UI_Node) {
  clip_bound := ifx node.flags & .OVERLAY then ui.root.rect else node.parent.child_clip;
  full_inner := rect_inset(node.rect, node.params.padding);
  node.clip       = rect_intersect(node.rect, clip_bound);
  node.inner      = full_inner;
  node.inner.size.x = max(0.0, full_inner.size.x - node.params.pad_right);
  node.child_clip = rect_intersect(full_inner, node.clip);
}

ui_resize_edge_at :: (rect: UI_Rect, point: Vector2) -> u32 {
  band := UI_RESIZE_EDGE;
  slop := 3.0;
  left := rect.pos.x;  right  := rect.pos.x + rect.size.x;
  top  := rect.pos.y;  bottom := rect.pos.y + rect.size.y;

  if point.x < left - slop || point.x > right + slop || point.y < top - slop || point.y > bottom + slop  return 0;

  edge: u32;
  if point.x <= left + band    edge |= UI_EDGE_L;
  if point.x >= right - band   edge |= UI_EDGE_R;
  if point.y <= top + band     edge |= UI_EDGE_T;
  if point.y >= bottom - band  edge |= UI_EDGE_B;

  grip := UI_RESIZE_HANDLE;
  if point.x >= right - grip && point.y >= bottom - grip  edge = UI_EDGE_R | UI_EDGE_B;

  return edge;
}

ui_interact :: (node: *UI_Node) {
  input := ui.input;

  visible := node.clip.size.x > 0.0 && node.clip.size.y > 0.0;
  under   := visible && rect_contains(node.clip, input.mouse_pos);

  hoverable := (node.flags & .HOVERABLE) || (node.flags & .INPUT_SINK);
  clickable := (node.flags & .CLICKABLE) || (node.flags & .INPUT_SINK);

  if under && (hoverable || clickable) && node.depth < ui.mouse_panel_depth {
    ui.mouse_panel_next  = node.panel;
    ui.mouse_panel_depth = node.depth;
  }
  over := under && node.panel == ui.mouse_panel;

  if over && hoverable && node.depth <= ui.hot_depth {
    ui.hot_key   = node.key;
    ui.hot_depth = node.depth;
  }

  if over && (node.flags & .SCROLL_Y) && input.scroll != 0.0 && node.depth < ui.scroll_cand_depth {
    ui.scroll_cand       = node;
    ui.scroll_cand_depth = node.depth;
  }

  if node.flags & .RESIZABLE && input.mouse_pressed[0] && node.depth < ui.resize_cand_depth {
    edge := ui_resize_edge_at(node.rect, input.mouse_pos);
    if edge != 0 {
      ui.resize_cand_key   = node.key;
      ui.resize_cand_depth = node.depth;
      ui.resize_cand_edge  = edge;
    }
  }

  if over && clickable && input.mouse_pressed[0] && node.depth <= ui.active_press_depth {
    if ui.resizing_key == 0 {
      ui.active_key         = node.key;
      ui.active_press_depth = node.depth;
      ui_note_press_window(node);

      ui.drag_panel_key = ifx node.flags & .DRAGGABLE then node.panel else 0;
      if ui.drag_panel_key {
        panel_cache := ui_cache_get(ui.drag_panel_key);
        panel_cache.grab_mouse       = input.mouse_pos;
        panel_cache.grab_drag_offset = panel_cache.drag_offset;
      }
    }
  }
}

ui_note_press_window :: (node: *UI_Node) {
  if node.panel  ui.pressed_window_key = node.panel;
}

ui_emit_children :: (node: *UI_Node, alpha: float, disabled: bool) {
  windows: [..] *UI_Node;
  windows.allocator = ui_frame_allocator();

  child := node.first;
  while child {
    if child.flags & .OVERLAY               array_add(*ui.overlay_nodes, child);
    else if child.flags & .DRAGGABLE_PANEL  array_add(*windows, child);
    else                                    ui_emit(child, alpha, disabled);
    child = child.next;
  }

  quick_sort(windows, (a: *UI_Node, b: *UI_Node) -> int { return ifx a.depth > b.depth then -1 else cast(int) (a.depth < b.depth); });
  for windows  ui_emit(it, alpha, disabled);
}

// parent_disabled keeps the disabled fade from stacking in nested subtrees.
ui_emit :: (node: *UI_Node, parent_alpha: float = 1.0, parent_disabled := false) {
  alpha := parent_alpha * node.opacity;
  node_disabled := node.flags & .DISABLED;
  if node_disabled && !parent_disabled  alpha *= 0.4;

  state := UI_Visual_State.NORMAL;
  if !(node.flags & .INPUT_SINK) {
    if      ui.active_key == node.key  state = .ACTIVE;
    else if ui.hot_key    == node.key  state = .HOVER;
  }

  background := ui_state_color(node.background, state);
  border     := ui_state_color(node.border,     state);
  foreground := ui_state_color(node.foreground, state);

  if node.params.animate {
    cache := ui_cache_get(node.key);
    if !cache.animated_ready {
      cache.animated_background = background; cache.animated_border = border; cache.animated_foreground = foreground;
      cache.animated_ready = true;
    } else {
      t := ui_animation_t(ui.input.dt);
      cache.animated_background = ui_mix(cache.animated_background, background, t);
      cache.animated_border     = ui_mix(cache.animated_border,     border,     t);
      cache.animated_foreground = ui_mix(cache.animated_foreground, foreground, t);
    }
    background = cache.animated_background; border = cache.animated_border; foreground = cache.animated_foreground;
  }

  if alpha < 1.0 {
    background.w *= alpha;
    border.w     *= alpha;
    foreground.w *= alpha;
  }

  clipped := node.clip.size.x > 0.0 && node.clip.size.y > 0.0;

  // Drop shadow: fading rects grown down-right from the node's corner.
  if node.params.shadow > 0.0 && alpha > 0.01 {
    shadow_clip := ifx node.parent == ui.root
                   then UI_Rect.{ .{ 0, 0 }, ui.input.screen_size }
                   else node.parent.child_clip;
    for i: 1..4 {
      grow := node.params.shadow * (cast(float) i / 4.0);
      quad: UI_Quad;
      quad.rect          = .{ .{ node.rect.pos.x + 1.0, node.rect.pos.y + 1.0 },
                              .{ node.rect.size.x + grow, node.rect.size.y + grow } };
      quad.clip          = shadow_clip;
      quad.color         = .{ 0, 0, 0, 0.045 * alpha };
      quad.corner_radius = node.params.corner_radius + grow * 0.5;
      array_add(*ui.quads, quad);
    }
  }

  if node.params.render && clipped {
    has_fill   := background.w > 0.0;
    has_border := node.params.border_thickness > 0.0 && border.w > 0.0;

    if has_fill || has_border {
      quad: UI_Quad;
      quad.rect             = node.rect;
      quad.clip             = node.clip;
      quad.color            = background;
      quad.border_color     = ifx has_border then border else Vector4.{ 0, 0, 0, 0 };
      quad.border_thickness = ifx has_border then node.params.border_thickness else 0.0;
      quad.corner_radius    = node.params.corner_radius;
      quad.corner_mask      = node.params.corners;
      array_add(*ui.quads, quad);
    }
  }

  if node.params.texture && clipped {
    box := node.inner;
    if box.size.x > 0.0 && box.size.y > 0.0 {
      quad: UI_Quad;
      quad.rect    = box;
      quad.clip    = node.clip;
      quad.color   = foreground;
      quad.texture = node.params.texture;
      quad.uv_min  = node.params.uv_min;
      quad.uv_max  = node.params.uv_max;
      array_add(*ui.quads, quad);
    }
  }

  if node.flags & .DRAW_TEXT && node.text.count > 0 && clipped {
    text_width  := node.text_size.x;
    text_height := node.text_size.y;

    text_x := node.cursor.x;
    text_y := node.cursor.y;
    if node.flags & .TEXT_CENTER_X  text_x = node.rect.pos.x + (node.rect.size.x - text_width) * 0.5;
    if node.flags & .TEXT_CENTER_Y  text_y = node.rect.pos.y + (node.rect.size.y - text_height) * 0.5;

    ui_push_text(*ui.quads, ui_display_label(node.text), .{ text_x, text_y }, node.clip, foreground);
  }

  if node.flags & .DRAW_LINES && node.params.points.count >= 2 && clipped {
    width := ifx node.params.line_width > 0.0 then node.params.line_width else 1.0;
    for segment: 0..node.params.points.count-2 {
      ui_push_line(*ui.quads, node.params.points[segment], node.params.points[segment + 1], width, node.clip, foreground);
    }
  }

  ui_emit_children(node, alpha, parent_disabled || node_disabled);

  if ui_debug_node_borders {
    outline: UI_Quad;
    outline.rect            = node.rect;
    outline.clip             = .{ .{ 0, 0 }, ui.input.screen_size };
    outline.border_color     = UI_DEBUG_NODE_BORDER_COLOR;
    outline.border_thickness = 1.0;
    array_add(*ui.quads, outline);
  }
}

// Compile-time checks; a failure fails the build.
#if UI_DEBUG #run {
  ix := rect_intersect(.{ .{0,0}, .{10,10} }, .{ .{5,5}, .{10,10} });
  assert(ix.pos.x == 5.0 && ix.pos.y == 5.0 && ix.size.x == 5.0 && ix.size.y == 5.0);
  assert(rect_intersect(.{ .{0,0}, .{5,5} }, .{ .{10,10}, .{5,5} }).size.x == 0.0);

  clamped := rect_inset(.{ .{0,0}, .{4,20} }, 100.0);
  assert(clamped.size.x == 0.0 && clamped.pos.x == 2.0);

  hit := UI_Rect.{ .{0,0}, .{10,10} };
  assert(rect_contains(hit, .{0,0}) && rect_contains(hit, .{9.5,9.5}));
  assert(!rect_contains(hit, .{10,5}) && !rect_contains(hit, .{-1,5}));

  assert(ui_resolve_size(.{ kind = .PIXELS,          value = 42  }, 100, 999,   0) == 42.0);
  assert(ui_resolve_size(.{ kind = .PARENT_FRACTION, value = 0.5 }, 200, 999,   0) == 100.0);
  assert(ui_resolve_size(.{ kind = .PARENT_RATIO,    value = 0.25}, 999, 400,   0) == 100.0);
  assert(ui_resolve_size(.{ kind = .TEXT,            value = 4   },   0,   0,  20) == 24.0);
  assert(ui_resolve_size(.{ kind = .PIXELS, value = 3, min = 10  },   0,   0,   0) == 10.0);

  assert(ui_smooth(0.0) == 0.0 && ui_smooth(1.0) == 1.0);
  assert(ui_smooth(-1.0) == 0.0 && ui_smooth(2.0) == 1.0);

  assert(ui_display_label("Save##btn").count == 4);
  assert(ui_display_label("no marker").count == 9);

  loc_a := Source_Code_Location.{ "a.jai", 10, 1 };
  loc_b := Source_Code_Location.{ "a.jai", 11, 1 };
  assert(ui_key(1, "x", loc_a) == ui_key(1, "x", loc_a));
  assert(ui_key(1, "x", loc_a) != ui_key(1, "x", loc_b));
  assert(ui_key(1, "x", loc_a) != ui_key(2, "x", loc_a));

  assert(ui_hash(0, "hello") == ui_hash(0, "hello"));
  assert(ui_hash(0, "hello") != ui_hash(0, "olleh"));
  assert(ui_hash(1, "hello") != ui_hash(2, "hello"));
  assert(ui_mix_key(3, 5) == ui_mix_key(3, 5) && ui_mix_key(3, 5) != 0);

  {
    buffer: [4] u8;
    assert(ui_utf8_encode(#char "A", buffer) == 1 && buffer[0] == #char "A");
    assert(ui_utf8_encode(0xE9,       buffer) == 2);
    assert(ui_utf8_encode(0x20AC,     buffer) == 3);
    assert(ui_utf8_encode(0x1F600,    buffer) == 4);
    n := ui_utf8_encode(0x20AC, buffer);
    assert((buffer[0] & 0xF0) == 0xE0 && (buffer[1] & 0xC0) == 0x80 && (buffer[2] & 0xC0) == 0x80 && n == 3);
  }

  {
    derived := ui_resolve_color_set(.{ normal = .{ 0.5, 0.5, 0.5, 1.0 } }, derive = true);
    assert(derived.hover.x  > 0.5 && derived.active.x < 0.5 && derived.hover.w == 1.0);
    flat := ui_resolve_color_set(.{ normal = .{ 0.5, 0.5, 0.5, 1.0 } }, derive = false);
    assert(flat.hover.x == 0.5 && flat.active.x == 0.5);
    assert(ui_resolve_color_set(.{}, derive = true).normal.w == 0.0);
  }
}
