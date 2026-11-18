presentation :: () {
  ui_window_begin("Flying Rat - Immediate-mode UI", null, 60, 40, 960, 620, .NO_CLOSE, initial_dock = .FULL);
  slides_begin("flying_rat", *current_slide);
    if slide("Title")                                         slide_title();
    if slide("Topics")                                        slide_topics();

    if slide("Retained vs immediate")  slide_retained_vs_immediate();
    if slide("Immediate is the API")                          slide_api_not_implementation();
    if slide("Where this comes from")                         slide_prior_art();

    if slide("One frame")  slide_one_frame();
    if slide("Input from the app")  slide_input();
    if slide("What the app must provide")  slide_app_provides();
    if slide("UI_Context")                                    slide_context();
    if slide("UI_Node")                                       slide_node();
    if slide("The UI tree")                                   slide_tree();
    if slide("Keys")                                          slide_keys();
    if slide("A node is a rectangle")                         slide_anatomy();
    if slide("Layout")                                        slide_layout();
    if slide("Signals")                                       slide_signals();
    if slide("Behaviour from flags")                          slide_flags();
    if slide("Widgets are small")                             slide_composition();
    if slide("Custom widgets")                                slide_custom_widgets();
    if slide("What user code looks like")                     slide_live_demo();

    if slide("The cache")  slide_cache();
    if slide("Who owns the state?")                           slide_state_ownership();
    if slide("Animation")                                     slide_animation();
    if slide("Animated layout")                               slide_animated_layout();
    if slide("Windows and z-order")                           slide_windows();

    if slide("Rendering")  slide_rendering();
    if slide("Performance")                                   slide_performance();
    if slide("Source code")                                   slide_source_code();
    if slide("Demo")                                          slide_demo();
    if slide("TL;DR")                                         slide_tldr();
    if slide("Questions")                                     slide_questions();
  slides_end();
  inspector();
  themes_window();
  ui_window_end();
}

#scope_file

// ---------------------------------------------------------------------------
// Slide system: a custom widget built on ui_node, no library changes.
// ---------------------------------------------------------------------------

Slides :: struct {
  id:       string;
  loc:      Source_Code_Location;
  selected: *int;
  body:     *UI_Node;
  count:    int;
}

slides: Slides;
current_slide := 0;
shown_slide   := -1;
theme_index   := 0;


slide_gap :: () -> float { return floor(ui.metrics.line_height * 0.6); }

slides_begin :: (id: string, selected: *int, loc := #caller_location) {
  bar_height := ui_row_height();

  params: UI_Params;
  params.name        = "Slides";
  params.spacing     = UI_STACK_SPACING;
  params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  container := ui_node(id, 0, params, loc);
  ui_push_parent(container);

  body_key   := ui_child_key(id, "slide", loc);
  body_cache := ui_cache_get(body_key);
  if shown_slide != selected.* {
    body_cache.scroll = 0;
    shown_slide = selected.*;
  }

  body_params := ui_box_params(ui_theme.group_background, ui_theme.window_border);
  body_params.padding     = floor(ui.metrics.line_height * 1.4);
  body_params.spacing     = slide_gap();
  body_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  body_params.size.height = .{ kind = .PIXELS, value = max(0.0, container.inner.size.y - bar_height - UI_STACK_SPACING) };
  if body_cache.scroll_max > 0.5  body_params.pad_right = UI_SCROLLBAR_W + 4.0;
  body := ui_node(id, "slide", .SCROLL_Y, body_params, loc);
  ui_push_parent(body);

  slides = .{ id = id, loc = loc, selected = selected, body = body };
}

slide :: (title: string) -> bool {
  index := slides.count;
  slides.count += 1;
  return index == slides.selected.*;
}

slides_end :: () {
  ui_pop_parent();
  body_cache := ui_cache_get(slides.body.key);
  ui_scrollbar(slides.body, body_cache);

  last := max(slides.count - 1, 0);

  if !ui_wants_keyboard() {
    if ui_key_pressed(.RIGHT)  slides.selected.* += 1;
    if ui_key_pressed(.LEFT)   slides.selected.* -= 1;
  }
  slides.selected.* = clamp(slides.selected.*, 0, last);

  bar_params: UI_Params;
  bar_params.name        = "nav";
  bar_params.axis        = .X;
  bar_params.spacing     = UI_STACK_SPACING;
  bar_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  bar_params.size.height = .{ kind = .PIXELS, value = ui_row_height() };
  bar := ui_node(slides.id, "nav", 0, bar_params, slides.loc);
  ui_push_parent(bar);
    gap       := UI_STACK_SPACING;
    nav_width := 80.0;

    jump_width := ui_row_height();  // square
    if bar_button("first", "<<", jump_width, slides.selected.* == 0)  slides.selected.* = 0;
    if bar_button("prev",  "<-", nav_width,  slides.selected.* == 0)  slides.selected.* -= 1;

    font := renderer.fonts[0];
    size := cast(int) font.height;
    if bar_button("font_minus", "A-", 0.0, size <= 8)   r_resize_font(*renderer, font, xx (size - 1));
    bar_label("font_size", tprint("% px", size), 0.0);
    if bar_button("font_plus",  "A+", 0.0, size >= 48)  r_resize_font(*renderer, font, xx (size + 1));

    if bar_button("theme", tprint("Theme: %", ui_palettes[theme_index].name), 0.0, false) {
      themes_open = !themes_open;
    }

    fps_params: UI_Params;
    fps_params.name        = "FPS cap";
    fps_params.size.width  = .{ kind = .PIXELS, value = floor(ui.metrics.line_height * 14.0) };
    fps_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
    fps_box := ui_node(slides.id, "fps_box", 0, fps_params, slides.loc);
    ui_push_parent(fps_box);
      track := ui_slider_track_node("fps_cap", false, slides.loc);
      if ui_signal_from_node(track).held {
        frame_cap = cast(int) floor(1.0 + ui_slider_cursor_t(track) * cast(float) (FRAME_CAP_UNLIMITED - 1) + 0.5);
      }
      fps_t := cast(float) (frame_cap - 1) / cast(float) (FRAME_CAP_UNLIMITED - 1);
      ui_slider_decorate(track, "fps_cap", fps_t, ifx frame_cap >= FRAME_CAP_UNLIMITED then "FPS cap: unlimited" else tprint("FPS cap: %", frame_cap));
    ui_pop_parent();

    checkbox_width :: (text: string) -> float {
      w, _ := ui_measure_display(text);
      return ui_compact_height() + UI_GAP + w + 4.0;
    }
    right_width := checkbox_width("Inspector") + checkbox_width("Borders") + nav_width + jump_width + 4.0 * gap;
    middle      := max(0.0, bar.inner.pos.x + bar.inner.size.x - bar.cursor.x - right_width - gap);
    bar_label("where", tprint("% / %", slides.selected.* + 1, slides.count), middle);

    ui_checkbox("Inspector", *inspector_open);
    ui_checkbox("Borders",   *ui_debug_node_borders);

    if bar_button("next", "->", nav_width,  slides.selected.* >= last)  slides.selected.* += 1;
    if bar_button("last", ">>", jump_width, slides.selected.* >= last)  slides.selected.* = last;
  ui_pop_parent();

  ui_pop_parent();
}

themes_open := false;

themes_window :: () {
  if !themes_open  return;
  region := ui_parent().inner;
  ui_window_begin("Themes", *themes_open, 20, max(0.0, region.size.y - 440.0), 280, 420);
    for palette, index: ui_palettes {
      ui_push_id(index);
      ui_row_begin("theme_row");
        swatch: UI_Params;
        swatch.background       = .{ normal = .{ palette.accent.x, palette.accent.y, palette.accent.z, 1.0 } };
        swatch.border           = .{ normal = .{ palette.base.x, palette.base.y, palette.base.z, 1.0 } };
        swatch.border_thickness = 3.0;
        swatch.corner_radius    = 3.0;
        swatch.size.width       = .{ kind = .PIXELS, value = ui_compact_height() };
        swatch.size.height      = .{ kind = .PIXELS, value = ui_compact_height() };
        ui_node("swatch", 0, swatch);

        selected := index == theme_index;
        if ui_selectable(palette.name, *selected) {
          theme_index = index;
          ui_set_theme(ui_theme_from_palette(palette));
        }
      ui_row_end();
      ui_pop_id();
    }
  ui_window_end();
}

// width 0 = fit the text
bar_button :: (salt: string, text: string, width: float, disabled: bool) -> bool {
  params := ui_box_params(ui_theme.button, ui_theme.button_border);
  params.name        = "Button";
  params.text        = text;
  params.foreground  = ui_theme.text;
  params.disabled    = disabled;
  params.size.width  = ifx width > 0.0 then UI_Size.{ kind = .PIXELS, value = width } else .{ kind = .TEXT, value = ui.metrics.line_height };
  params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  node := ui_node(slides.id, salt, .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y | .CLICKABLE | .HOVERABLE, params, slides.loc);
  return ui_signal_from_node(node).clicked;
}

bar_label :: (salt: string, text: string, width: float) {
  params: UI_Params;
  params.text        = text;
  params.foreground  = ui_theme.text;
  params.animate     = false;
  params.size.width  = ifx width > 0.0 then UI_Size.{ kind = .PIXELS, value = width } else .{ kind = .TEXT, value = ui.metrics.line_height * 0.5 };
  params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  ui_node(slides.id, salt, .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, params, slides.loc);
}

// ---------------------------------------------------------------------------
// Two-column layout for slides, with the slide's vertical spacing.
// ---------------------------------------------------------------------------

Split :: struct {
  row:    *UI_Node;
  widths: [2] float;
  id:     string;
  loc:    Source_Code_Location;
  index:  int;
}
split_state: Split;

split_begin :: (id: string, left := 0.5, loc := #caller_location) {
  gap := floor(ui.metrics.line_height * 2.0);
  params: UI_Params;
  params.name        = "Split";
  params.axis        = .X;
  params.spacing     = gap;
  params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(ui_parent()) };
  row := ui_node(id, "split", 0, params, loc);
  ui_push_parent(row);

  usable := max(2.0, row.inner.size.x - gap);
  split_state = .{ row = row, widths = .[ floor(usable * left), usable - floor(usable * left) ], id = id, loc = loc };
  split_cell();
}

split_next :: () {
  ui_shrink_panel_to_content(ui_pop_parent());
  split_state.index += 1;
  split_state.row.cursor.y = split_state.row.inner.pos.y;
  split_cell();
}

split_end :: () {
  ui_shrink_panel_to_content(ui_pop_parent());
  ui_shrink_row_to_content(ui_pop_parent());
}

split_cell :: () {
  params: UI_Params;
  params.name        = "Column";
  params.axis        = .Y;
  params.spacing     = slide_gap();
  params.size.width  = .{ kind = .PIXELS, value = max(1.0, split_state.widths[split_state.index]) };
  params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(split_state.row) };
  cell := ui_node(split_state.id, "cell", split_state.index, 0, params, split_state.loc);
  ui_push_parent(cell);
}

// ---------------------------------------------------------------------------
// Node inspector: click a node to select it, hover shows what a click would pick.
// ---------------------------------------------------------------------------

inspector_open       := false;
inspector_selected   : u64;
inspector_hovered    : u64;
inspector_window_key : u64;

inspector :: () {
  inspector_hovered = 0;
  if !inspector_open  return;

  over_inspector := inspector_window_key != 0 && ui.mouse_panel == inspector_window_key;
  if !over_inspector {
    best: *UI_Node;
    pick_under_mouse(ui.root, *best);
    if best  inspector_hovered = best.key;
    if ui.input.mouse_pressed[0]  inspector_selected = inspector_hovered;
  }

  hovered  := find_node(ui.root, inspector_hovered);
  selected := find_node(ui.root, inspector_selected);
  if hovered && hovered != selected {
    fill   := ui_theme.accent;  fill.w   = 0.05;
    border := ui_theme.accent;  border.w = 0.45;
    ui_overlay_rect(hovered.rect, fill, border, 1.0, 0.0);
  }
  if selected {
    fill := ui_theme.accent;  fill.w = 0.15;
    ui_overlay_rect(selected.rect, fill, ui_theme.accent, 2.0, 0.0);
  }

  region := ui_parent().inner;
  signal := ui_window_begin("Node inspector", *inspector_open, max(0.0, region.size.x - 400.0), 20, 380, 560);
  inspector_window_key = signal.node.key;

    if !selected {
      ui_label("Click any node to select it.");
      ui_label("Hovering outlines what a click picks.");
    } else {
      path: String_Builder;
      path.allocator = temp;
      chain: [32] *UI_Node;
      depth := 0;
      walk := selected;
      while walk && depth < chain.count { chain[depth] = walk; depth += 1; walk = walk.parent; }
      for < i: depth-1..0 {
        for 1..depth - 1 - i  append(*path, "  ");
        append(*path, tree_label(chain[i]));
        if i > 0  append(*path, "\n");
      }
      heading("Path from the root");
      value("path", builder_to_string(*path,, temp));

      heading("Family, by key  (click one to select it)");
      family_row("key",    selected);
      family_row("parent", selected.parent);
      family_row("first",  selected.first);
      family_row("last",   selected.last);
      family_row("prev",   selected.prev);
      family_row("next",   selected.next);

      heading("UI_Node (this frame)");
      ui_inspect("UI_Node", selected.*);

      heading("UI_Node_Cache (kept between frames)");
      found := table_find_pointer(*ui.caches, selected.key);
      if found  ui_inspect("UI_Node_Cache", found.*.*);
      else      ui_label("no cache entry for this key");
    }
  ui_window_end();
}

// One relative of the selected node, shown by its key (the same hash the node
// itself has), as a button that selects it.
family_row :: (relation: string, node: *UI_Node) {
  ui_push_id(relation);
  ui_row_begin("family");
    padded := alloc_string(7,, temp);
    memset(padded.data, #char " ", padded.count);
    memcpy(padded.data, relation.data, min(relation.count, padded.count));
    value("relation", padded);
    if node {
      params := ui_box_params(ui_theme.button, ui_theme.button_border);
      params.text        = tprint("%  %", hex(node.key), tree_label(node));
      params.foreground  = ui_theme.text;
      params.size.width  = .{ kind = .TEXT, value = ui.metrics.line_height };
      params.size.height = .{ kind = .PIXELS, value = ui_compact_height() };
      jump := ui_node("jump", .CLICKABLE | .HOVERABLE | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, params);
      if ui_signal_from_node(jump).clicked  inspector_selected = node.key;
    } else {
      value("none", "-");
    }
  ui_row_end();
  ui_pop_id();
}

pick_under_mouse :: (node: *UI_Node, best: **UI_Node) {
  mouse := ui.input.mouse_pos;
  child := node.first;
  while child {
    visible := child.clip.size.x > 0.0 && child.clip.size.y > 0.0;
    if visible && rect_contains(child.clip, mouse) {
      if !best.* || child.depth <= best.*.depth  best.* = child;
    }
    pick_under_mouse(child, best);
    child = child.next;
  }
}

find_node :: (node: *UI_Node, key: u64) -> *UI_Node {
  if key == 0         return null;
  if node.key == key  return node;
  child := node.first;
  while child {
    found := find_node(child, key);
    if found  return found;
    child = child.next;
  }
  return null;
}

tree_label :: (node: *UI_Node) -> string {
  name  := node.params.name;
  label := ui_display_label(node.label);
  if node.parent && node.parent.label == node.label  label = "";  // a part of its parent's widget
  if name && label && name != label  return tprint("% \"%\"", name, label);
  if name                            return name;
  if label                           return tprint("\"%\"", label);
  return "node";
}

// ---------------------------------------------------------------------------
// Tree diagram: draws any parent-linked list (pre-order) with nodes and lines.
// ---------------------------------------------------------------------------

Tree_Item :: struct {
  label:     string;
  parent:    int;
  depth:     int;
  highlight: bool;
}

tree_diagram :: (id: string, items: [] Tree_Item, loc := #caller_location) {
  count := items.count;
  if count == 0  return;

  has_child := NewArray(count, bool,,  temp);
  y         := NewArray(count, float,, temp);
  low       := NewArray(count, float,, temp);
  high      := NewArray(count, float,, temp);
  for items  if it.parent >= 0  has_child[it.parent] = true;

  leaves    := 0;
  max_depth := 0;
  max_label := 0.0;
  for items {
    low[it_index]  =  1.0e9;
    high[it_index] = -1.0e9;
    if !has_child[it_index] { y[it_index] = cast(float) leaves; leaves += 1; }
    max_depth = max(max_depth, it.depth);
    w, _ := ui_measure_display(it.label);
    max_label = max(max_label, w);
  }
  for < i: count-1..0 {
    if has_child[i]  y[i] = (low[i] + high[i]) * 0.5;
    p := items[i].parent;
    if p >= 0 { low[p] = min(low[p], y[i]); high[p] = max(high[p], y[i]); }
  }

  pad   := 10.0;
  box_h := ui_row_height();
  row_h := box_h + 8.0;
  box_w := max_label + ui.metrics.line_height * 1.5;
  link  := 28.0;
  col_w := box_w + link;

  panel_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  panel_params.name        = "Tree diagram";
  panel_params.size.width  = .{ kind = .PIXELS, value = (max_depth + 1) * col_w - link + 2.0 * pad };
  panel_params.size.height = .{ kind = .PIXELS, value = leaves * row_h - 8.0 + 2.0 * pad };
  panel := ui_node(id, "tree", 0, panel_params, loc);
  ui_push_parent(panel);
    origin := panel.rect.pos + Vector2.{ pad, pad };
    box_pos :: (i: int) -> Vector2 #expand {
      return `origin + Vector2.{ `items[i].depth * `col_w, `y[i] * `row_h };
    }

    for items {
      if it.parent < 0  continue;
      from := box_pos(it.parent) + Vector2.{ box_w, box_h * 0.5 };
      to   := box_pos(it_index)  + Vector2.{ 0.0,   box_h * 0.5 };
      points := ui_frame_allocate(Vector2, 4);
      points[0] = from;
      points[1] = .{ from.x + link * 0.5, from.y };
      points[2] = .{ from.x + link * 0.5, to.y };
      points[3] = to;

      line_params: UI_Params;
      line_params.size.width        = .{ kind = .PIXELS, value = panel.rect.size.x };
      line_params.size.height       = .{ kind = .PIXELS, value = panel.rect.size.y };
      line_params.foreground.normal = ui_theme.text.normal;
      line_params.foreground.normal.w = 0.4;
      line_params.line_width        = 1.0;
      line_params.points            = points;
      line_params.animate           = false;
      ui_node(id, "edge", it_index, .FLOATING | .DRAW_LINES, line_params, loc);
    }

    for items {
      box_params := ui_box_params(ifx it.highlight then UI_Color_Set.{ normal = ui_theme.accent } else ui_theme.button, ui_theme.button_border);
      box_params.text          = it.label;
      box_params.foreground    = ui_theme.text;
      box_params.offset        = box_pos(it_index) - panel.rect.pos;
      box_params.size.width    = .{ kind = .PIXELS, value = box_w };
      box_params.size.height   = .{ kind = .PIXELS, value = box_h };
      box_params.animate       = false;
      ui_node(id, "box", it_index, .FLOATING | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, box_params, loc);
    }
  ui_pop_parent();
}

subtree_items :: (root: *UI_Node) -> [] Tree_Item {
  items: [..] Tree_Item;
  items.allocator = temp;
  collect :: (node: *UI_Node, parent: int, depth: int, items: *[..] Tree_Item) {
    index := items.count;
    array_add(items, .{ label = tree_label(node), parent = parent, depth = depth });
    child := node.first;
    while child { collect(child, index, depth + 1, items); child = child.next; }
  }
  if root  collect(root, -1, 0, *items);
  return items;
}

count_nodes :: (node: *UI_Node) -> int {
  if !node  return 0;
  total := 1;
  child := node.first;
  while child { total += count_nodes(child); child = child.next; }
  return total;
}

// ---------------------------------------------------------------------------
// Plots sampled at a fixed rate, so they read the same at any frame rate.
// ---------------------------------------------------------------------------

Sampler :: struct {
  buffer: UI_Plot_Buffer;
  timer:  float;
}

sample :: (sampler: *Sampler, v: float, hz: float) {
  sampler.timer += ui.input.dt;
  if sampler.timer >= 1.0 / hz {
    sampler.timer = min(sampler.timer - 1.0 / hz, 1.0 / hz);
    ui_plot_push(*sampler.buffer, v);
  }
}

// ---------------------------------------------------------------------------
// Title and agenda
// ---------------------------------------------------------------------------

slide_title :: () {
  ui_spacing(ui.metrics.line_height * 6.0);
  title("Immediate-mode UI");
  point("The architecture of Imgui, our UI - presented in itself");
  ui_spacing(ui.metrics.line_height * 2.0);
  point("Flying Rat  -  <presenter>  -  <date>");
  ui_spacing(ui.metrics.line_height * 4.0);
  sub("Arrow keys or the bottom bar to navigate");
  sub("Bottom bar: font size, theme, node inspector, node borders - on every slide");
}

slide_topics :: () {
  title("Topics");
  ui_spacing(ui.metrics.line_height * 2.0);

  heading("1. What immediate mode is");
  sub("Immediate vs retained mode, and where this design comes from");
  ui_spacing(ui.metrics.line_height * 1.5);

  heading("2. The core");
  sub("The context, nodes, the tree, keys, layout, signals and widgets");
  ui_spacing(ui.metrics.line_height * 1.5);

  heading("3. State across frames");
  sub("The cache, who owns state, animation and windows");
  ui_spacing(ui.metrics.line_height * 1.5);

  heading("4. Output and wrap-up");
  sub("Rendering, performance, a demo and a summary");
}

// ---------------------------------------------------------------------------
// Part 1: framing
// ---------------------------------------------------------------------------

rvi_dirty := true;
rvi_saves := 0;

slide_retained_vs_immediate :: () {
  title("Retained vs immediate");
  point("Retained: create widget objects, keep them in sync with your data, react in callbacks");
  point("Immediate: the UI is a function of your data, called every frame");
  ui_spacing();
  split_begin("rvi");
    heading("Retained (a typical toolkit)");
    code(CODE_RETAINED);
  split_next();
    heading("Immediate (ours)");
    code(CODE_IMMEDIATE);
    heading("Live - that exact code:");
    ui_checkbox("document dirty", *rvi_dirty);
    if ui_button("Save", disabled = !rvi_dirty).clicked {
      rvi_dirty = false;
      rvi_saves += 1;
    }
    value("saves", tprint("saved % time(s)", rvi_saves));
  split_end();
  ui_spacing();
  point("No widget lifetime to manage and nothing to keep in sync: the code is the UI");
  point("Cost: the UI is rebuilt every frame, and some state has to persist anyway");
}

slide_api_not_implementation :: () {
  title("Immediate is the API, not the implementation");
  point("Immediate vs retained is about *not* about retaining state.");
  sub("It is instead about who manages and keeps the data syncronized.");
  point("It does *not* mean the library keeps nothing between frames.");
  sub("a library can cache whatever it wants internally, as we will see.");
  ui_spacing();
  point("This ImGUi throws the whole node tree away every frame...");
  point("...and keeps a small per-widget cache for what must survive.");
  ui_spacing();
  heading("Live");
  value("nodes",  tprint("nodes built last frame    %   (all thrown away)", ui.stats.nodes));
  value("caches", tprint("cache entries             %   (kept between frames)", ui.caches.count));
  value("frame",  tprint("frame                     %", ui.frame));
}

slide_prior_art :: () {
  title("Where this comes from");
  heading("2005  Casey Muratori");
  point("A widget is a function call: draw + input, every frame, no objects");
  ui_spacing();
  heading("2014  Dear ImGui");
  point("One function per widget type, returns a bool");
  ui_spacing();
  heading("2024  RAD Debugger");
  point("One generic box + flags, widgets return a signal, state cached by key");
  ui_spacing();
  heading("Ours");
  point("RAD's architecture, with layout done as nodes are created");
}

// ---------------------------------------------------------------------------
// Part 2: the core
// ---------------------------------------------------------------------------

slide_one_frame :: () {
  title("One frame");
  split_begin("frame");
    code(CODE_MAIN_LOOP);
    point("ui_begin: clear last frame's nodes, take input, new root");
    point("build: each node is placed and hit-tested right away");
    point("ui_end: finish resize / scroll / raise, output quads");
    point("The library never touches the GPU, the OS or the user code");
  split_next();
    heading("In: what the app gives the UI (next slide)");
    point("input: mouse, keys, typed text, time since last frame");
    point("metrics: the font, and how to measure text");
    ui_spacing();
    heading("Out: what the UI gives back");
    point("a list of quads to draw");
    point("signals: what was hovered, clicked, dragged...");
    ui_spacing();
    heading("Live");
    value("frame", tprint("frame               %", ui.frame));
    value("nodes", tprint("nodes last frame    %", ui.stats.nodes));
    value("quads", tprint("quads last frame    %", ui.stats.quads));
  split_end();
}

input_presses  := 0;
input_releases := 0;
input_typed: UI_Text_Buffer(48);

slide_input :: () {
  title("Input from the app");
  split_begin("input", 0.55);
    point("The UI never talks to the OS, the window or the font system");
    point("Every frame, the app hands it a snapshot:");
    code(CODE_INPUT);
    point("down = held right now; pressed / released = changed this frame");
    point("dt: animations move by time, not by frame count");
    point("What the app must implement itself: next slide");
  split_next();
    heading("Live: this frame's UI_Input");
    if ui.input.mouse_pressed[0] {
      input_presses += 1;
    }
    if ui.input.mouse_released[0] {
      input_releases += 1;
    }
    if ui.input.text {
      if input_typed.count + ui.input.text.count > input_typed.data.count {
        input_typed.count = 0;
      }
      memcpy(input_typed.data.data + input_typed.count, ui.input.text.data, ui.input.text.count);
      input_typed.count += ui.input.text.count;
    }

    value("screen",   tprint("screen_size        %", ui.input.screen_size));
    value("mouse",    tprint("mouse_pos          %", ui.input.mouse_pos));
    value("delta",    tprint("mouse_delta        %", ui.input.mouse_delta));
    value("down",     tprint("mouse_down         left %  right %  middle %", ui.input.mouse_down[0], ui.input.mouse_down[1], ui.input.mouse_down[2]));
    value("pressed",  tprint("mouse_pressed      % times so far  (true for one frame)", input_presses));
    value("released", tprint("mouse_released     % times so far  (true for one frame)", input_releases));
    value("scroll",   tprint("scroll             %", ui.input.scroll));
    value("mods",     tprint("ctrl %   shift %", ui.input.ctrl, ui.input.shift));
    value("text",     tprint("text (typed)       \"%\"", ui_text(*input_typed)));
    ui_spacing();
    value("dt",       tprint("dt                 % ms", formatFloat(ui.input.dt * 1000.0, trailing_width = 2)));
    value("fps",      tprint("                   (% frames per second)", cast(int) (1.0 / max(ui.input.dt, 0.0001))));
    sub("try the FPS cap in the bottom bar: dt changes, animations don't");
    ui_spacing();
    sub("click, scroll, hold ctrl / shift, type something");
    ui_spacing();

    heading("Live: this frame's UI_Metrics");
    value("m_font",    tprint("font               %", ifx ui.metrics.font then tprint("%, % px", ui.metrics.font.label, ui.metrics.font.height) else "(none)"));
    value("m_line",    tprint("line_height        %", ui.metrics.line_height));
    value("m_measure", tprint("measure_text(\"Hello\") -> %", measure_hello()));
    sub("change the font size in the bottom bar: these change too");
  split_end();
}

measure_hello :: () -> string {
  w, h := ui.metrics.measure_text("Hello");
  return tprint("% x %", cast(int) w, cast(int) h);
}

break_measure     := false;
real_measure_text : UI_Measure_Proc;
measure_sample    : UI_Text_Buffer(48);

// A wrong measure_text, for the demo: says every string is half as wide as it is.
half_measure_text :: (text: string) -> (width: float, height: float) {
  width, height := real_measure_text(text);
  return width * 0.5, height;
}

slide_app_provides :: () {
  title("What the app must provide");
  point("The library can't measure text: the app does it, or nothing lays out right");
  split_begin("provides", 0.55);
    code(CODE_APP_PROVIDES);
    point("measure_text, font: required");
    point("clipboard: optional");
  split_next();
    heading("Live: what measure_text does");
    if !measure_sample.count  ui_text_set(*measure_sample, "Hello, Flying Rat!");
    ui_text_input("measure_sample", *measure_sample, "type something");
    width, height := ui.metrics.measure_text(ui_text(*measure_sample));
    value("measured", tprint("measure_text -> width %, height %", cast(int) width, cast(int) height));
    ui_spacing();
  split_end();
}

ctx_text: UI_Text_Buffer(64);

slide_context :: () {
  title("UI_Context: one global context");
  split_begin("ctx");
    code(CODE_CONTEXT);
    point("Every widget function reads and writes this one global");
  split_next();
    heading("Live - interact with anything");
    stack_depth := ui.parent_stack.count;
    value("frame",   tprint("frame               %", ui.frame));
    value("mouse",   tprint("mouse               %", ui.input.mouse_pos));
    value("hot",     tprint("hovered (last frame) %", hex(ui.hover_key)));
    value("hover_t", tprint("hovered for         % s", formatFloat(ui.hover_t, trailing_width = 2)));
    value("active",  tprint("active (pressed)    %", hex(ui.active_key)));
    value("focus",   tprint("keyboard focus      %", hex(ui.keyboard_focus_key)));
    value("panel",   tprint("window under mouse  %", hex(ui.mouse_panel)));
    value("stack",   tprint("parent stack depth  % (right here)", stack_depth));
    value("caches",  tprint("cache entries       %", ui.caches.count));
    value("quads",   tprint("quads last frame    %", ui.stats.quads));
    ui_spacing();
    ui_text_input("ctx_text", *ctx_text, "click here to take keyboard focus");
    if ui_button("Hold me").held {
      ui_label("'active' is this button while held");
    }
  split_end();
}

slide_node :: () {
  title("UI_Node: one generic node");
  split_begin("node");
    code(CODE_NODE);
  split_next();
    point("There is no Button, Slider or Window type");
    point("A widget is a function that creates nodes");
    point("Nodes only live for one frame");
    ui_spacing();
    heading("Try it");
    point("Turn on 'Inspector' in the bottom bar");
    sub("hover: outlines the node under the mouse");
    sub("click: selects it - its node and its cache");
    if !inspector_open && ui_button("Turn the inspector on").clicked {
      inspector_open = true;
    }
  split_end();
}

tree_volume    := 0.6;
tree_mute      := false;
tree_full_open := false;
mini_canvas: Tree_Canvas;

slide_tree :: () {
  title("The UI tree");
  split_begin("tree", 0.42);
    code(CODE_MINI_UI);
    point("A stack of parents: push to go in, pop to come out");
    point("Siblings are a linked list");
    ui_spacing();
    if ui_button("Show the full UI tree of this frame").clicked {
      tree_full_open = true;
    }
  split_next();
    heading("Live: that code, running");
    mini := mini_settings_ui();
    ui_spacing();
    heading("...and its tree  (drag, wheel to zoom, click Mute)");
    canvas_params: UI_Params;
    canvas_params.name        = "Tree canvas";
    canvas_params.spacing     = UI_STACK_SPACING;
    canvas_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    canvas_params.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height * 24.0 };
    ui_push_parent(ui_node("mini_canvas_box", 0, canvas_params));
      ui_tree_canvas("mini", *mini_canvas, mini, live = true);
    ui_pop_parent();
  split_end();

  if tree_full_open {
    ui_window_begin("Full UI tree", *tree_full_open, 0, 0, 420, 400, initial_dock = .RIGHT);
      demo_canvas_body();
    ui_window_end();
  }
}

// Must match CODE_MINI_UI.
mini_settings_ui :: () -> *UI_Node {
  panel_params := ui_box_params(ui_theme.window_background, ui_theme.window_border);
  panel_params.name        = "Panel";
  panel_params.padding     = UI_PANEL_PADDING;
  panel_params.spacing     = UI_STACK_SPACING;
  panel_params.size.width  = .{ kind = .PIXELS, value = 340.0 };
  panel_params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(ui_parent()) };

  panel: *UI_Node = ui_node("Settings", 0, panel_params);
  ui_push_parent(panel);
      ui_label("Audio");
      ui_slider("Volume", *tree_volume, 0.0, 1.0);
      ui_checkbox("Mute", *tree_mute);
      ui_row_begin("buttons");
          ui_button("Apply");
          ui_button("Cancel");
      ui_row_end();
  ui_pop_parent();
  ui_shrink_panel_to_content(panel);
  return panel;
}

slide_keys :: () {
  title("Keys");
  split_begin("keys");
    point("Every node needs an identity that is the same every frame");
    point("key = hash( parent's key, text, call site )");
    sub("call site = file, line and column of the call,");
    sub("passed in automatically by the compiler");
    ui_spacing();
    code(CODE_KEY_SAME_TEXT);
    point("Same text, different lines: different keys");
    ui_spacing();
    code(CODE_KEY_LOOP);
    point("A loop calls from the same line: add the index");
    ui_spacing();
    point("The key is how a node finds its state from last frame");
  split_next();
    heading("Live: the code on the left");
    ui_row_begin("row");
      first:  UI_Signal = ui_button("Save");
      second: UI_Signal = ui_button("Save");
    ui_row_end();
    value("k_first",  tprint("first.node.key    %", hex(first.node.key)));
    value("k_second", tprint("second.node.key   %", hex(second.node.key)));
    ui_spacing(ui.metrics.line_height * 3.0);
    keys: [3] u64;
    ui_row_begin("loop");
      for i: 0..2 {
        ui_push_id(i);
        item: UI_Signal = ui_button("Item");
        ui_pop_id();
        keys[i] = item.node.key;
      }
    ui_row_end();
    value("k_item_0", tprint("item 0 key        %", hex(keys[0])));
    value("k_item_1", tprint("item 1 key        %", hex(keys[1])));
    value("k_item_2", tprint("item 2 key        %", hex(keys[2])));
  split_end();
}

RECT_COLOR   :: Vector4.{ 1.0,  0.35, 0.35, 1.0 };
INNER_COLOR  :: Vector4.{ 0.35, 0.65, 1.0,  1.0 };
CLIP_COLOR   :: Vector4.{ 0.35, 1.0,  0.45, 1.0 };
CURSOR_COLOR :: Vector4.{ 1.0,  0.85, 0.2,  1.0 };

show_rect   := true;
show_inner  := true;
show_clip   := true;
show_cursor := true;

anatomy_padding  := 14.0;
anatomy_children := 3;
anatomy_width    := 260.0;

slide_anatomy :: () {
  title("A node is a rectangle");
  split_begin("anatomy", 0.45);
    point("A node is a rectangle, maybe some text,");
    point("and flags that say how it behaves");
    code(CODE_ANATOMY);
    point("Everything is relative to the parent:");
    sub("a child is placed at the parent's cursor");
    sub("inside the parent's inner rect");
    sub("its clip is its rect, cut by the parent's clip");
    sub("so nothing ever draws outside its parent");
  split_next();
    heading("Live: one parent, a few children");
    ui_slider("padding",      *anatomy_padding,  0.0, 40.0);
    ui_slider("children",     *anatomy_children, 1, 8);
    ui_slider("child width",  *anatomy_width,    40.0, 900.0);
    colored_checkbox("rect:   position and size",         RECT_COLOR,   *show_rect);
    colored_checkbox("inner:  rect minus padding",        INNER_COLOR,  *show_inner);
    colored_checkbox("clip:   the visible part",          CLIP_COLOR,   *show_clip);
    colored_checkbox("cursor: where the next child goes", CURSOR_COLOR, *show_cursor);
    ui_spacing();

    parent_params := ui_box_params(ui_theme.window_background, ui_theme.window_border);
    parent_params.name        = "parent";
    parent_params.padding     = anatomy_padding;
    parent_params.spacing     = 6.0;
    parent_params.size.width  = .{ kind = .PARENT_RATIO, value = 0.75 };
    parent_params.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height * 13.0 };
    parent := ui_node("anatomy_parent", 0, parent_params);
    ui_push_parent(parent);
      for 0..anatomy_children - 1 {
        child := ui_box_params(ui_theme.button, ui_theme.button_border);
        child.name        = "child";
        child.text        = tprint("child %", it);
        child.foreground  = ui_theme.text;
        child.size.width  = .{ kind = .PIXELS, value = anatomy_width };
        child.size.height = .{ kind = .PIXELS, value = ui_row_height() };
        ui_node("anatomy_child", "c", it, .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, child);
      }
    ui_pop_parent();

    none      := Vector4.{ 0, 0, 0, 0 };
    clip_fill := Vector4.{ CLIP_COLOR.x, CLIP_COLOR.y, CLIP_COLOR.z, 0.25 };
    child_node := parent.first;
    while child_node {
      if show_clip {
        ui_overlay_rect(child_node.clip, clip_fill, CLIP_COLOR, 1.0, 0.0);
      }
      if show_rect {
        ui_overlay_rect(child_node.rect, none, RECT_COLOR, 1.0, 0.0);
      }
      child_node = child_node.next;
    }
    if show_rect {
      ui_overlay_rect(parent.rect, none, RECT_COLOR, 2.0, 0.0);
    }
    if show_inner {
      ui_overlay_rect(parent.inner, none, INNER_COLOR, 1.0, 0.0);
    }
    if show_cursor {
      ui_overlay_rect(.{ parent.cursor - Vector2.{ 6, 1 }, .{ 12, 3 } }, CURSOR_COLOR, CURSOR_COLOR, 0.0, 0.0);
      ui_overlay_rect(.{ parent.cursor - Vector2.{ 1, 6 }, .{ 3, 12 } }, CURSOR_COLOR, CURSOR_COLOR, 0.0, 0.0);
    }
    sub("make the children wider than the parent: the clip stops at the parent's inner rect");
  split_end();
}

// A colour swatch followed by a checkbox.
colored_checkbox :: (text: string, color: Vector4, value: *bool, loc := #caller_location) {
  ui_row_begin(text, loc = loc);
    swatch: UI_Params;
    swatch.background    = .{ normal = color };
    swatch.corner_radius = 2.0;
    swatch.size.width    = .{ kind = .PIXELS, value = ui_compact_height() };
    swatch.size.height   = .{ kind = .PIXELS, value = ui_compact_height() };
    ui_node("swatch", 0, swatch, loc);
    ui_checkbox(text, value, loc = loc);
  ui_row_end();
}

lay_width    := 520.0;
lay_axis_x   := true;
lay_fraction := 1.0;
lay_ratio    := 0.25;

slide_layout :: () {
  title("Layout: one pass, as nodes are created");
  split_begin("lay");
    point("Each parent has a cursor: where its next child goes");
    point("A node's size and position are known the moment it is created");
    sub("so it can be hit-tested right away");
    code(CODE_SIZES);
    point("Panels that fit their content: start tall, shrink at the end");
    point("FLOATING nodes skip the cursor: popups, overlays, scrollbars");
  split_next();
    heading("What ui_node does with every new node");
    code(CODE_PLACE);
  split_end();

  heading("Playground");
  split_begin("lay_controls");
    ui_slider("container width", *lay_width, 120.0, 900.0);
    ui_checkbox("axis = X (a row)", *lay_axis_x);
  split_next();
    ui_slider("PARENT_RATIO",    *lay_ratio,    0.0, 1.0);
    ui_slider("PARENT_FRACTION", *lay_fraction, 0.0, 1.0);
  split_end();

  row := ui_row_height();
  box := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  box.name        = "container";
  box.axis        = ifx lay_axis_x then UI_Axis.X else .Y;
  box.padding     = 4.0;
  box.spacing     = 4.0;
  box.size.width  = .{ kind = .PIXELS, value = lay_width };
  box.size.height = .{ kind = .PIXELS, value = ifx lay_axis_x then row * 1.6 else row * 4.0 + 20.0 };
  container := ui_node("lay_box", 0, box);
  ui_push_parent(container);
    lay_child :: (salt: string, index: int, text: string, size: UI_Size) #expand {
      params: UI_Params;
      params.name          = salt;
      params.text          = text;
      params.foreground    = ui_theme.text;
      params.background    = .{ normal = ui_plot_series_color(index) };
      params.background.normal.w = 0.55;
      params.corner_radius = 3.0;
      params.animate       = false;
      full := UI_Size.{ kind = .PARENT_FRACTION, value = 1.0 };
      if lay_axis_x { params.size.width = size;  params.size.height = full; }
      else          { params.size.width = full; params.size.height = size; }
      ui_node("lay_child", salt, .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, params);
    }
    lay_child("px",    0, "PIXELS 90", .{ kind = .PIXELS, value = 90.0 });
    lay_child("text",  1, "TEXT",      .{ kind = .TEXT,   value = 16.0 });
    lay_child("ratio", 2, tprint("RATIO %",    formatFloat(lay_ratio,    trailing_width = 2)), .{ kind = .PARENT_RATIO,    value = lay_ratio });
    lay_child("frac",  3, tprint("FRACTION %", formatFloat(lay_fraction, trailing_width = 2)), .{ kind = .PARENT_FRACTION, value = lay_fraction });
  ui_pop_parent();
  sub("FRACTION takes a share of what is still free after the earlier siblings");
}

Sig_Counts :: struct { pressed: int; clicked: int; released: int; }
sig_counts: Sig_Counts;

card_pos    := Vector2.{ 30, 30 };
card_clicks := 0;

slide_signals :: () {
  title("Signals");
  split_begin("sig");
    heading("Dear ImGui (C++): a bool, then ask about the 'last item'");
    code(CODE_SIGNAL_CLASSIC);
    heading("Ours: every widget returns a signal");
    code(CODE_SIGNAL_OURS);
    point("ui_node tests the mouse as the node is created");
    point("The front-most node under the mouse wins");
    ui_spacing();
    heading("Signals are for your code, not just for hover effects");
    code(CODE_SIGNAL_REACT);
  split_next();
    signal_box_demo();
    ui_spacing(ui.metrics.line_height * 2.0);
    heading("Live: the code at the bottom left");
    card_demo();
  split_end();
}

card_demo :: () {
  area_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  area_params.name        = "card area";
  area_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  area_params.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height * 12.0 };
  area := ui_node("card_area", 0, area_params);
  ui_push_parent(area);
    params := ui_box_params(ui_theme.button, .{ normal = ui_theme.accent });
    params.name             = "card";
    params.text             = tprint("drag me  (clicked %)", card_clicks);
    params.foreground       = ui_theme.text;
    params.border_thickness = 2.0;
    params.corner_radius    = 6.0;
    params.offset           = card_pos;
    params.size.width       = .{ kind = .TEXT,   value = ui.metrics.line_height * 2.0 };
    params.size.height      = .{ kind = .PIXELS, value = ui_row_height() * 2.0 };
    flags: UI_Node_Flags = .FLOATING | .CLICKABLE | .HOVERABLE | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y;
    card: *UI_Node = ui_node("card", flags, params);
    signal: UI_Signal = ui_signal_from_node(card);

    if signal.hovered {
      ui_set_tooltip("Drag me around");
    }
    if signal.held {
      card_pos += ui.input.mouse_delta;
    }
    if signal.clicked {
      card_clicks += 1;
    }
    card_pos.x = clamp(card_pos.x, 0.0, max(0.0, area.rect.size.x - card.rect.size.x));
    card_pos.y = clamp(card_pos.y, 0.0, max(0.0, area.rect.size.y - card.rect.size.y));
  ui_pop_parent();
}

signal_box_demo :: () {
    heading("Live: hover, press, hold, release");
    params := ui_box_params(ui_theme.button, ui_theme.button_border);
    params.name        = "signal box";
    params.text        = "press me";
    params.foreground  = ui_theme.text;
    params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    params.size.height = .{ kind = .PIXELS, value = ui_row_height() * 3.0 };
    node := ui_node("sigbox", .CLICKABLE | .HOVERABLE | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, params);
    s := ui_signal_from_node(node);
    if s.pressed   sig_counts.pressed  += 1;
    if s.clicked   sig_counts.clicked  += 1;
    if s.released  sig_counts.released += 1;

    value("hovered",  tprint("hovered    %", s.hovered));
    value("held",     tprint("held       %", s.held));
    value("pressed",  tprint("pressed    % times  (true for one frame)", sig_counts.pressed));
    value("clicked",  tprint("clicked    % times", sig_counts.clicked));
    value("released", tprint("released   % times  (only if released on the box)", sig_counts.released));
    point("Press, move off, release: no 'released'");
    point("Press here, release elsewhere: 'held' stays true");
}

pg_clickable     := true;
pg_hoverable     := true;
pg_floating      := false;
pg_draw_text     := true;
pg_text_center_x := true;
pg_text_center_y := true;
pg_disabled      := false;

slide_flags :: () {
  title("Behaviour = flags on a node");
  split_begin("flags");
    code(CODE_FLAGS);
    point("Each flag is implemented once, in the core");
    point("Widgets just pick flags");
  split_next();
    heading("Live: one node, change its flags");
    ui_checkbox("CLICKABLE",     *pg_clickable);
    ui_checkbox("HOVERABLE",     *pg_hoverable);
    ui_checkbox("FLOATING",      *pg_floating);
    ui_checkbox("DRAW_TEXT",     *pg_draw_text);
    ui_checkbox("TEXT_CENTER_X", *pg_text_center_x);
    ui_checkbox("TEXT_CENTER_Y", *pg_text_center_y);
    ui_checkbox("disabled",      *pg_disabled);
    ui_spacing();

    flags: UI_Node_Flags;
    if pg_clickable      flags |= .CLICKABLE;
    if pg_hoverable      flags |= .HOVERABLE;
    if pg_floating       flags |= .FLOATING;
    if pg_draw_text      flags |= .DRAW_TEXT;
    if pg_text_center_x  flags |= .TEXT_CENTER_X;
    if pg_text_center_y  flags |= .TEXT_CENTER_Y;

    params := ui_box_params(ui_theme.button, ui_theme.button_border);
    params.name          = "playground node";
    params.text          = "one UI_Node";
    params.foreground    = ui_theme.text;
    params.disabled      = pg_disabled;
    params.corner_radius = 6.0;
    params.offset        = ifx flags & .FLOATING then Vector2.{ 120, 40 } else .{};
    params.size.width    = .{ kind = .PARENT_RATIO, value = 0.7 };
    params.size.height   = .{ kind = .PIXELS, value = ui_row_height() * 2.0 };
    node := ui_node("pg_node", flags, params);
    s := ui_signal_from_node(node);

    value("pg_sig", tprint("hovered %   held %", s.hovered, s.held));
    sub("FLOATING: leaves the layout, placed at an offset");
  split_end();
}

comp_tab     := 0;
comp_check   := true;
comp_slider  := 0.4;
comp_outline := true;
comp_clicks  := 0;

slide_composition :: () {
  title("Widgets are small");
  point("The core (layout, input, cache, drawing) is the hard part - written once");
  point("A widget is a short function you can read top to bottom");
  ui_spacing();
  split_begin("comp", 0.58);
    ui_tab_group_begin("comp_tabs");
      ui_tab("Button",   *comp_tab, 0);
      ui_tab("Checkbox", *comp_tab, 1);
      ui_tab("Slider",   *comp_tab, 2);
    ui_tab_group_end();
    if comp_tab == 0  code(CODE_BUTTON);
    if comp_tab == 1  code(CODE_CHECKBOX);
    if comp_tab == 2  code(CODE_SLIDER);
  split_next();
    heading("Live: the real widget");
    widget: *UI_Node;
    if comp_tab == 0 {
      s := ui_button("Click me");
      if s.clicked  comp_clicks += 1;
      widget = s.node;
      value("comp_clicks", tprint("clicked % times", comp_clicks));
    }
    if comp_tab == 1 {
      ui_checkbox("A checkbox", *comp_check);
      widget = ui.last_node.parent;   // the last node built is its label; the parent is the widget
    }
    if comp_tab == 2 {
      ui_slider("A slider", *comp_slider, 0.0, 1.0);
      widget = ui.last_node.parent;
    }
    ui_spacing();
    ui_checkbox("Outline its nodes", *comp_outline);
    if comp_outline  outline_subtree(widget);
    value("comp_nodes", tprint("% node(s)", count_nodes(widget)));
    ui_spacing();
    heading("Its tree");
    tree_diagram("comp_tree", subtree_items(widget));
  split_end();
}

outline_subtree :: (node: *UI_Node) {
  if !node  return;
  ui_overlay_rect(node.rect, .{ 0, 0, 0, 0 }, .{ 1, 0, 1, 1 }, 1.0, 0.0);
  child := node.first;
  while child { outline_subtree(child); child = child.next; }
}

slide_custom_widgets :: () {
  title("Custom widgets");
  point("Anything built from nodes is a real widget - the library doesn't need to know");
  ui_spacing();
  heading("Example: a widget for our memory pool type  (hover the bars)");
  ui_flat_pool("UI frame memory", *ui.frame_pool);
  ui_flat_pool("UI persistent memory", *ui.persistent);
  ui_spacing();
  split_begin("custom", 0.62);
    code(CODE_POOL_WIDGET);
  split_next();
    point("Written for one of our own types");
    point("A label and two bars");
    point("Each bar: a track node with 3 coloured nodes");
    point("Each coloured node has its own tooltip");
    point("About 40 lines, outside the library");
    ui_spacing();
    point("These slides are a custom widget too");
  split_end();
}

live_clicks  := 0;
live_value   := 0.5;
live_toggle  := true;
live_pick    := 1;
live_color   := Vector4.{ 0.30, 0.55, 0.95, 1.0 };
live_count   := 7;
live_name:     UI_Text_Buffer(64);

slide_live_demo :: () {
  title("What user code looks like");
  split_begin("live");
    code(CODE_USER);
    point("Your data is the state: the UI reads and writes it");
    point("No widget objects, no callbacks, no bindings");
  split_next();
    heading("Live - the code on the left");
    if ui_button("Click me").clicked {
      live_clicks += 1;
    }
    value("clicks", tprint("clicked % times", live_clicks));
    ui_slider("Value", *live_value, 0.0, 1.0);
    ui_toggle("Toggle", *live_toggle);
    ui_progress_bar(live_value);
    ui_combo("Quality", *live_pick, string.[ "Low", "Medium", "High", "Ultra" ]);
    ui_drag_number("Count", *live_count, 0.2, 0, 100);
    ui_text_input("Name", *live_name, "type a name");
    ui_color_edit("Colour", *live_color);
    if live_toggle {
      ui_label("Hello, Sailor!");
    }
  split_end();
}

// ---------------------------------------------------------------------------
// Part 3: across frames
// ---------------------------------------------------------------------------

cache_spawn := false;
cache_plot: Sampler;

slide_cache :: () {
  title("The cache: what survives between frames");
  split_begin("cache");
    code(CODE_CACHE);
    point("A node asks for its cache with its key");
    point("Created the first time a key asks");
    point("Not asked for in a while: freed");
  split_next();
    heading("Live: cache entries over the last ~17 s");
    sample(*cache_plot, cast(float) ui.caches.count, 15.0);
    ui_plot_begin("cache_plot", height = ui.metrics.line_height * 7.0);
      ui_plot_line(ui_plot_values(*cache_plot.buffer));
    ui_plot_end();
    value("entries", tprint("entries now   %", ui.caches.count));

    ui_spacing();
    heading("Try it");
    ui_checkbox("Build 120 extra buttons", *cache_spawn);
    ttl_seconds := cast(float) UI_CACHE_TTL_FRAMES * ui.input.dt;
    point("1. Turn it on: 120 buttons appear, each makes a cache entry");
    point("2. Turn it off: the buttons are gone, their entries are not");
    point(tprint("3. After % frames unused, a purge frees them", UI_CACHE_TTL_FRAMES));
    value("ttl", tprint("      (at this frame rate: about % s)", formatFloat(ttl_seconds, trailing_width = 2)));
    if cache_spawn {
      for row: 0..11 {
        ui_push_id(row);
        ui_row_begin("spawn_row", spacing = 2.0);
          for col: 0..9  ui_button(tprint("%", row * 10 + col));
        ui_row_end();
        ui_pop_id();
      }
    }
  split_end();
}

own_mute := false;
own_pick := 2;
own_items := string.[ "Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape", "Honeydew", "Kiwi", "Lemon", "Mango" ];

slide_state_ownership :: () {
  title("Who owns the state?");
  split_begin("own");
    code(CODE_OWN_USER);
    heading("Your data: you own it");
    point("the widget gets a pointer");
    heading("UI details: the library owns them, per key");
    point("open / closed, scroll, caret, window position");
    heading("Interaction: the context owns it");
    point("hovered, pressed, focused");
  split_next();
    heading("Live");
    ui_checkbox("Mute", *own_mute);
    value("own_mute", tprint("your variable: mute = %", own_mute));
    ui_spacing();
    if ui_collapsing_header("Open / close me") {
      ui_label("Nothing in our code stores");
      ui_label("whether this is open.");
    }
    ui_collapsing_end();
    ui_spacing();
    ui_list_box("Fruits", *own_pick, own_items, 4);
    sub("the selection is ours, the scroll position is the library's");
  split_end();
}

anim_toggle := false;
anim_plot: Sampler;

slide_animation :: () {
  title("Animation");
  split_begin("anim");
    code(CODE_ANIMATION);
    point("Move a fraction of the way to the target, every frame");
    sub("fast at first, slows down, never overshoots");
    sub("the same speed at any frame rate");
    point("Every node's colours fade like this, via its cache");
    sub("hover effects everywhere, for free");
  split_next();
    heading("Hover both boxes");
    ui_row_begin("anim_boxes", spacing = 12.0);
      anim_box("off", "animate = false", false);
      anim_box("on",  "animate = true",  true);
    ui_row_end();
    ui_slider("transition speed", *ui_theme.transition_speed, 1.0, 60.0);
    sub("lower it to make the fade easier to see");
    ui_spacing();
    heading("A toggle, and its cached value over time");
    anim_toggle_and_plot();
  split_end();
}

anim_box :: (salt: string, text: string, animate: bool) {
  params := ui_box_params(ui_theme.button, ui_theme.button_border);
  params.text        = text;
  params.foreground  = ui_theme.text;
  params.animate     = animate;
  params.size.width  = .{ kind = .TEXT, value = ui.metrics.line_height * 3.0 };
  params.size.height = .{ kind = .PIXELS, value = ui_row_height() * 3.0 };
  ui_node("anim_box", salt, .HOVERABLE | .CLICKABLE | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, params);
}

anim_toggle_and_plot :: (loc := #caller_location) {
  cache := ui_cache_for("Click me", loc);
  ui_toggle("Click me", *anim_toggle, loc = loc);
  sample(*anim_plot, cache.disclosure_t, 60.0);
  ui_plot_begin("anim_plot", overlay = "the toggle's knob position (0..1)");
    ui_plot_line(ui_plot_values(*anim_plot.buffer), y_range = .{ 0, 1 });
  ui_plot_end();
}

al_window := false;
al_plot: Sampler;

slide_animated_layout :: () {
  title("Animated layout");
  point("Layout is one pass: the body's full height isn't known until its children are built");
  point("So it uses the height measured last frame");
  split_begin("al");
    code(CODE_DISCLOSURE);
    heading("Every frame");
    point("1. body height = last frame's full height x open_t");
    point("2. children are laid out inside it, the rest is clipped");
    point("3. measure how tall the children really were");
    point("4. store it: that is next frame's full height");
  split_next();
    heading("Live");
    al_header();
    ui_spacing();
    ui_checkbox("Show a window (then close it with its X)", *al_window);
    sub("it fades and grows in, and plays out its close");
  split_end();

  if al_window {
    ui_window_begin("Animated window", *al_window, 60, 300, 300, 200);
      ui_label("Minimise me, or close me.");
      ui_label("Shift-drag me to dock me.");
    ui_window_end();
  }
}

al_header :: (loc := #caller_location) {
  cache := ui_cache_for("Click to animate", loc);
  sample(*al_plot, cache.disclosure_t * cache.disclosure_height, 60.0);
  if ui_collapsing_header("Click to animate", loc = loc) {
    ui_label("Line one");
    ui_label("Line two");
    ui_label("Line three");
    ui_button("A button in here");
  }
  ui_collapsing_end();
  value("al_values", tprint("open_t %   x   full height %   =   body height %", formatFloat(cache.disclosure_t, trailing_width = 2), cast(int) cache.disclosure_height, cast(int) (cache.disclosure_t * cache.disclosure_height)));
  ui_plot_begin("al_plot", height = ui.metrics.line_height * 5.0, overlay = "the body's height, over time");
    ui_plot_line(ui_plot_values(*al_plot.buffer));
  ui_plot_end();
}

win_tree_open := false;
Window_Name :: struct { key: u64; name: string; }
win_names: [8] Window_Name;

slide_windows :: () {
  title("Windows and z-order");
  point("A window is a node too: its key is its identity in the z-order");
  point("The context keeps a list of windows, back to front, with their parent");
  sub("press inside a window: it and its parents move to the front");
  point("A window's depth comes from its place in that list");
  sub("hit-testing and drawing order both use depth");
  point("Windows can contain windows: they are clipped to their parent");
  ui_spacing();
  if ui_button("Show the window tree").clicked {
    win_tree_open = true;
  }
  sub("then click the windows and watch the order change");

  region := ui_parent().inner;
  x := max(0.0, region.size.x - 620.0);
  win_names[0] = .{ ui_parent().panel, "Presentation" };
  win_names[1] = .{ inspector_window_key, "Node inspector" };

  a := ui_window_begin("Window A", null, x, 160, 250, 170, .NO_CLOSE);
    win_names[2] = .{ a.node.key, "A" };
    ui_label("Click me to raise me.");
  ui_window_end();

  b := ui_window_begin("Window B", null, x + 190, 230, 420, 330, .NO_CLOSE);
    win_names[3] = .{ b.node.key, "B" };
    ui_label("I hold two windows.");
    c := ui_window_begin("Window C", null, 10, 40, 190, 120, .NO_CLOSE);
      win_names[4] = .{ c.node.key, "C" };
      ui_label("Inside B");
    ui_window_end();
    d := ui_window_begin("Window D", null, 170, 90, 230, 200, .NO_CLOSE);
      win_names[5] = .{ d.node.key, "D" };
      ui_label("Inside B");
      e := ui_window_begin("Window E", null, 10, 50, 170, 100, .NO_CLOSE);
        win_names[6] = .{ e.node.key, "E" };
        ui_label("Inside D");
      ui_window_end();
    ui_window_end();
  ui_window_end();

  if win_tree_open {
    t := ui_window_begin("Window tree", *win_tree_open, 20, region.size.y - 340, 520, 320);
      win_names[7] = .{ t.node.key, "Window tree" };
      ui_label("Back to front, top to bottom. Highlighted = focused.");
      items: [..] Tree_Item;
      items.allocator = temp;
      array_add(*items, .{ label = "screen", parent = -1, depth = 0 });
      collect_windows(UI_ROOT_KEY, 0, 1, *items);
      tree_diagram("win_tree", items);
    ui_window_end();
  }
}

collect_windows :: (parent_key: u64, parent_index: int, depth: int, items: *[..] Tree_Item) {
  for ui.window_order {
    if it.parent != parent_key  continue;
    name := hex(it.key);
    for n: win_names  if n.key == it.key && n.name  name = n.name;
    index := items.count;
    array_add(items, .{ label = name, parent = parent_index, depth = depth, highlight = ui_window_is_focused(it.key) });
    collect_windows(it.key, index, depth + 1, items);
  }
}

// ---------------------------------------------------------------------------
// Part 4: output and wrap-up
// ---------------------------------------------------------------------------

rend_radius  := 8.0;
rend_border  := 2.0;
rend_shadow  := 8.0;
rend_opacity := 1.0;
rend_line    := 2.0;
rend_time    := 0.0;

slide_rendering :: () {
  title("Rendering: the UI outputs quads, your renderer draws them");
  split_begin("rend");
    point("The UI makes no GPU calls: ui_end outputs an array of quads");
    code(CODE_QUAD);
    code(CODE_DRAW);
    point("Text: one quad per letter, from a font texture");
    point("Rounded corners, borders, soft edges: the renderer's shader");
  split_next();
    heading("Live: one node's parameters");
    ui_slider("corner_radius",    *rend_radius,  0.0, 40.0);
    ui_slider("border_thickness", *rend_border,  0.0, 8.0);
    ui_slider("shadow",           *rend_shadow,  0.0, 24.0);
    ui_slider("opacity",          *rend_opacity, 0.0, 1.0);
    ui_spacing();

    params := ui_box_params(ui_theme.button, .{ normal = ui_theme.accent });
    params.name             = "render sample";
    params.text             = "params -> quads";
    params.foreground       = ui_theme.text;
    params.corner_radius    = rend_radius;
    params.border_thickness = rend_border;
    params.shadow           = rend_shadow;
    params.opacity          = max(rend_opacity, 0.001);
    params.size.width       = .{ kind = .PARENT_RATIO, value = 0.8 };
    params.size.height      = .{ kind = .PIXELS, value = ui_row_height() * 3.0 };
    ui_node("rend_box", .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, params);
    sub("a shadow is 4 extra see-through quads");
    ui_spacing();

    heading("Lines (plots, graphs) are quads too");
    code(CODE_LINE);
    point("Each segment: one quad, rotated to the segment's angle");
    point("The shader fades every quad's edge over one pixel");
    sub("so rotated quads still look smooth");
    ui_slider("line_width", *rend_line, 1.0, 8.0);
    rend_time += ui.input.dt;
    line_params: UI_Params;
    line_params.name              = "sine";
    line_params.size.width        = .{ kind = .PARENT_RATIO, value = 0.8 };
    line_params.size.height       = .{ kind = .PIXELS, value = 80.0 };
    line_params.foreground.normal = ui_theme.accent;
    line_params.border            = ui_theme.window_border;
    line_params.border_thickness  = 1.0;
    line_params.line_width        = rend_line;
    line := ui_node("rend_line", .DRAW_LINES, line_params);
    points := ui_frame_allocate(Vector2, 48);
    for * points {
      t := cast(float) it_index / cast(float) (points.count - 1);
      it.* = .{ line.rect.pos.x + t * line.rect.size.x, line.rect.pos.y + line.rect.size.y * (0.5 + 0.4 * sin(t * 12.0 + rend_time * 1.5)) };
    }
    line.params.points = points;
    sub("47 segments = 47 rotated quads");
  split_end();
}

stress_open    := false;
stress_count   := 2000;
stress_animate := false;
stress_text    := false;

slide_performance :: () {
  title("Performance");
  point("It depends on the renderer and the implementation, of course");
  point("Not claiming to be the fastest or the best - but it handles a lot of nodes");
  point("Our renderer batches the quads: the whole UI is one draw call");
  ui_checkbox("Open the stress test", *stress_open);
  ui_spacing();
  split_begin("perf");
    heading("Frame");
    stat("fps", cast(int) (1.0 / max(ui.input.dt, 0.0001)));
    #if DEBUG {
      render := r_get_stats(*renderer);
      stat("cpu ms", formatFloat(render.cpu_frame_ms, trailing_width = 2));
      stat("gpu ms", formatFloat(render.gpu_frame_ms, trailing_width = 2));
      ui_spacing();
      heading("Renderer");
      stat("draw calls",       render.draw_calls);
      stat("quads",            render.quads_submitted);
      stat("  screen / text",  tprint("% / %", render.screen_quads, render.text_quads));
      stat("passes",           render.passes);
      stat("vertices",         render.vertices);
      stat("instance data",    kilobytes(render.instance_bytes));
      stat("textures",         tprint("%  (%)", render.textures, kilobytes(render.texture_bytes)));
    } else {
      point("Renderer stats need a DEBUG build");
    }
  split_next();
    heading("UI");
    #if UI_DEBUG {
      stat("nodes",          ui.stats.nodes);
      stat("quads",          ui.stats.quads);
      stat("cache entries",  ui.stats.cache_entries);
      stat("frame memory",   kilobytes(ui.stats.frame_bytes));
    } else {
      point("UI stats need UI_DEBUG");
    }
    ui_spacing();
    heading("Memory");
    ui_flat_pool("ui.persistent", *ui.persistent);
    ui_flat_pool("ui.frame_pool", *ui.frame_pool);
  split_end();

  if stress_open {
    stress_window();
  }
}

// A window full of small nodes, to see how far it goes.
stress_window :: () {
  ui_window_begin("Stress test", *stress_open, 40, 40, 640, 520);
    ui_slider("nodes", *stress_count, 100, 20000);
    ui_checkbox("animated (each node gets a cache entry)", *stress_animate);
    ui_checkbox("text (one quad per digit)", *stress_text);
    value("stress_stats", tprint("nodes %   quads %   frame % ms", ui.stats.nodes, ui.stats.quads, formatFloat(ui.input.dt * 1000.0, trailing_width = 2)));
    ui_separator();

    cell     := 18.0;
    width    := max(cell, ui_parent().inner.size.x - UI_SCROLLBAR_W - 8.0);
    per_row  := max(1, cast(int) (width / (cell + 2.0)));
    rows     := (stress_count + per_row - 1) / per_row;

    row_params: UI_Params;
    row_params.axis        = .X;
    row_params.spacing     = 2.0;
    row_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    row_params.size.height = .{ kind = .PIXELS, value = cell };
    row_params.animate     = false;

    cell_flags: UI_Node_Flags = .HOVERABLE;
    if stress_text  cell_flags |= .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y;

    for row: 0..rows - 1 {
      row_node := ui_node("stress_row", "r", row, 0, row_params);
      ui_push_parent(row_node);
        first := row * per_row;
        last  := min(first + per_row, stress_count) - 1;
        for i: first..last {
          params: UI_Params;
          params.background    = .{ normal = ui_plot_series_color(i % 8) };
          params.background.normal.w = 0.6;
          params.foreground    = ui_theme.text;
          params.corner_radius = 3.0;
          params.animate       = stress_animate;
          if stress_text  params.text = tprint("%", i % 10);
          params.size.width    = .{ kind = .PIXELS, value = cell };
          params.size.height   = .{ kind = .PIXELS, value = cell };
          ui_node("stress_cell", "c", i, cell_flags, params);
        }
      ui_pop_parent();
    }
  ui_window_end();
}

slide_source_code :: () {
  if !source.loaded  source_load();

  title("Source code");

  row_params: UI_Params;
  row_params.name        = "Row";
  row_params.axis        = .X;
  row_params.spacing     = UI_STACK_SPACING;
  row_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  ui_push_parent(ui_node("source", 0, row_params));
    files_panel := source_panel("files", .{ kind = .PARENT_RATIO, value = 0.2 });
      source_tree();
    ui_pop_parent();
    ui_scrollbar(files_panel, ui_cache_get(files_panel.key));

    column_params: UI_Params;
    column_params.name        = "Column";
    column_params.spacing     = UI_TIGHT_SPACING;
    column_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    column_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
    ui_push_parent(ui_node("source", "column", 0, column_params));
      ui_label(ifx source.selected >= 0 then source.files[source.selected] else "Select a file on the left.");
      text_panel := source_panel("text", .{ kind = .PARENT_FRACTION, value = 1.0 });
        source_text(text_panel);
      ui_pop_parent();
      ui_scrollbar(text_panel, ui_cache_get(text_panel.key));
    ui_pop_parent();
  ui_pop_parent();
}

demo_widgets_open := true;
demo_ui_tree_open := true;
demo_full_open    := false;

slide_demo :: () {
  title("Demo");
  ui_row_begin("demo_buttons");
    if !demo_widgets_open || !demo_ui_tree_open {
      if ui_button("Reopen windows").clicked {
        demo_widgets_open = true;
        demo_ui_tree_open = true;
      }
    }
    if ui_button("Open the full widget demo").clicked {
      demo_full_open = true;
    }
  ui_row_end();

  if demo_widgets_open {
    ui_window_begin("Widgets", *demo_widgets_open, 20, 100, 380, 520);
      demo_controls_body();
    ui_window_end();
  }
  if demo_ui_tree_open {
    ui_window_begin("UI tree", *demo_ui_tree_open, 420, 100, 760, 520);
      demo_canvas_body();
    ui_window_end();
  }
  ui_demo_window(*demo_full_open);
}

slide_tldr :: () {
  title("TL;DR");
  ui_spacing(ui.metrics.line_height * 2.0);
  point("The UI is code that runs every frame; your data is the state");
  ui_spacing();
  point("One kind of node: flags for behaviour, a signal back to your code");
  ui_spacing();
  point("Keys give nodes an identity, so the UI can keep its own state between frames");
  ui_spacing();
  point("Widgets are small functions that build nodes");
  ui_spacing();
  point("Output is a list of quads, for any renderer");
}

// Questions slide: floating words that bounce off the slide's edges. A new one
// appears every few seconds (or on a click), up to BOUNCER_MAX.
Bouncer :: struct { id: int; pos: Vector2; vel: Vector2; color: int; text: string; }
BOUNCER_MAX :: 64;
bouncers:        [BOUNCER_MAX] Bouncer;
bouncer_count   := 0;
bouncer_next_id := 0;
bouncer_timer   := 0.0;
bouncer_seed    : u32 = 12345;

BOUNCER_TEXTS :: string.[
  "?", "Rats!", "UI_Node", "hot", "active", "one draw call", "cache hit", "immediate!",
  "signal", "key", "quad", "60 fps", "layout", "clip", "cursor", "ui_end()", "?!", "hot & active",
];

slide_questions :: () {
  ui_spacing(ui.metrics.line_height * 8.0);
  title("Questions?");
  if ui_button("Reset").clicked {
    bouncer_count = 0;
    bouncer_timer = 0.0;
  }

  body := slides.body;
  area := body.inner.size;
  if bouncer_count == 0  bouncer_add(area, "Questions?");

  bouncer_timer += ui.input.dt;
  if bouncer_timer > 4.0 {
    bouncer_timer = 0.0;
    bouncer_add(area, BOUNCER_TEXTS[bouncer_random() % BOUNCER_TEXTS.count]);
  }

  for * b: bouncers {
    if it_index >= bouncer_count  break;
    w, h := ui_measure_display(b.text);
    size := Vector2.{ w + 24.0, h + 14.0 };

    b.pos += b.vel * ui.input.dt;
    bounced := false;
    if b.pos.x < 0.0             { b.pos.x = 0.0;                       b.vel.x =  abs(b.vel.x); bounced = true; }
    if b.pos.x > area.x - size.x { b.pos.x = max(0.0, area.x - size.x); b.vel.x = -abs(b.vel.x); bounced = true; }
    if b.pos.y < 0.0             { b.pos.y = 0.0;                       b.vel.y =  abs(b.vel.y); bounced = true; }
    if b.pos.y > area.y - size.y { b.pos.y = max(0.0, area.y - size.y); b.vel.y = -abs(b.vel.y); bounced = true; }
    if bounced {
      b.color += 1;
      b.vel = bouncer_wobble(b.vel);
    }

    params: UI_Params;
    params.name          = "bouncer";
    params.text          = b.text;
    params.foreground    = ui_theme.text;
    params.background    = .{ normal = ui_plot_series_color(b.color) };
    params.corner_radius = size.y * 0.5;
    params.offset        = (body.inner.pos - body.rect.pos) + b.pos;
    params.size.width    = .{ kind = .PIXELS, value = size.x };
    params.size.height   = .{ kind = .PIXELS, value = size.y };
    ui_push_id(b.id);
      node := ui_node("bouncer", .FLOATING | .CLICKABLE | .HOVERABLE | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, params);
    ui_pop_id();
    if ui_signal_from_node(node).clicked  bouncer_add(area, BOUNCER_TEXTS[bouncer_random() % BOUNCER_TEXTS.count]);
  }
}

bouncer_random :: () -> u32 {
  bouncer_seed = bouncer_seed * 1664525 + 1013904223;
  return bouncer_seed >> 8;
}

bouncer_random_float :: (low: float, high: float) -> float {
  return low + (high - low) * cast(float) (bouncer_random() % 10000) / 10000.0;
}

// After a bounce: turn a little and change speed a little, so no two paths repeat.
bouncer_wobble :: (vel: Vector2) -> Vector2 {
  angle := bouncer_random_float(-0.35, 0.35);
  c, s  := cos(angle), sin(angle);
  turned := Vector2.{ vel.x * c - vel.y * s, vel.x * s + vel.y * c };
  speed  := sqrt(turned.x * turned.x + turned.y * turned.y);
  target := clamp(speed * bouncer_random_float(0.85, 1.15), 50.0, 140.0);
  return turned * (target / max(speed, 0.001));
}

bouncer_add :: (area: Vector2, text: string) {
  if bouncer_count >= BOUNCER_MAX  return;
  angle := bouncer_random_float(0.0, 6.283);
  speed := bouncer_random_float(50.0, 120.0);
  bouncers[bouncer_count] = .{
    id    = bouncer_next_id,
    pos   = .{ bouncer_random_float(0.0, max(1.0, area.x * 0.7)), bouncer_random_float(0.0, max(1.0, area.y * 0.7)) },
    vel   = .{ cos(angle) * speed, sin(angle) * speed },
    color = cast(int) (bouncer_random() % 8),
    text  = text,
  };
  bouncer_count   += 1;
  bouncer_next_id += 1;
}

// ---------------------------------------------------------------------------
// Slide content helpers
// ---------------------------------------------------------------------------

text_line :: (id: string, text: string, color: UI_Color_Set, extra: float, animate: bool, loc: Source_Code_Location) {
  params: UI_Params;
  params.name        = "Text";
  params.text        = text;
  params.foreground  = color;
  params.animate     = animate;
  params.size.width  = .{ kind = .TEXT, value = 0.0 };
  params.size.height = .{ kind = .TEXT, value = extra };
  ui_node(id, .DRAW_TEXT | .TEXT_CENTER_Y, params, loc);
}

title :: (text: string, loc := #caller_location) {
  ui_label(text, loc);
  ui_separator(loc);
  ui_spacing(ui.metrics.line_height * 0.5, loc = loc);
}

heading :: (text: string, loc := #caller_location) {
  text_line(text, text, .{ normal = ui_theme.accent }, ui.metrics.line_height * 0.5, true, loc);
}

point :: (text: string, loc := #caller_location) {
  shown := tprint("-  %", text);
  text_line(shown, shown, ui_theme.text, ui.metrics.line_height * 0.2, true, loc);
}

sub :: (text: string, loc := #caller_location) {
  shown := tprint("   %", text);
  text_line(shown, shown, ui_theme.text, 0.0, true, loc);
}

// A label with a stable id, for text that changes every frame. A label is keyed
// by its text, so live text would make a new key (and cache entry) every frame.
value :: (id: string, text: string, loc := #caller_location) {
  text_line(id, text, ui_theme.text, ui.metrics.line_height * 0.2, false, loc);
}

code :: (text: string, loc := #caller_location) {
  clean := talloc_string(text.count);
  count := 0;
  for 0..text.count - 1 {
    if text[it] == #char "\r"  continue;
    clean[count] = text[it];
    count += 1;
  }
  while count > 0 && clean[count - 1] == #char "\n"  count -= 1;
  clean.count = count;

  params := ui_box_params(ui_theme.window_background, ui_theme.window_border);
  params.name        = "Code";
  params.padding     = floor(ui.metrics.line_height * 0.8);
  params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(ui_parent()) };
  panel := ui_node("code", 0, params, loc);
  ui_push_parent(panel);
    rest  := clean;
    index := 0;
    while true {
      end := find_index_from_left(rest, #char "\n");
      if end < 0  end = rest.count;
      code_line(string.{ end, rest.data }, index, loc);
      index += 1;
      if end >= rest.count  break;
      rest = advance(rest, end + 1);
    }
  ui_pop_parent();
  ui_shrink_panel_to_content(panel);
}

// One line of a code block: the code, then its // comment in the comment colour.
code_line :: (line: string, index: int, loc: Source_Code_Location) {
  comment := comment_start(line);

  row: UI_Params;
  row.name        = "Code line";
  row.axis        = .X;
  row.animate     = false;
  row.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height };
  ui_push_parent(ui_node("code_line", "l", index, 0, row, loc));
    code_part := ifx comment >= 0 then string.{ comment, line.data } else line;
    if code_part {
      text: UI_Params;
      text.text        = code_part;
      text.foreground  = ui_theme.text;
      text.animate     = false;
      text.size.width  = .{ kind = .TEXT, value = 0.0 };
      text.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
      ui_node("code_text", "t", index, .DRAW_TEXT | .TEXT_CENTER_Y, text, loc);
    }
    if comment >= 0 {
      note: UI_Params;
      note.text        = advance(line, comment);
      note.foreground  = .{ normal = comment_color() };
      note.animate     = false;
      note.size.width  = .{ kind = .TEXT, value = 0.0 };
      note.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
      ui_node("code_comment", "c", index, .DRAW_TEXT | .TEXT_CENTER_Y, note, loc);
    }
  ui_pop_parent();
}

// Where a // comment starts in a line, ignoring // inside "strings". -1 if none.
comment_start :: (line: string) -> int {
  in_string := false;
  i := 0;
  while i < line.count - 1 {
    c := line[i];
    if c == #char "\\" && in_string {
      i += 2;  // skip the escaped character
      continue;
    }
    if c == #char "\""  in_string = !in_string;
    if !in_string && c == #char "/" && line[i + 1] == #char "/"  return i;
    i += 1;
  }
  return -1;
}

// Comments take the theme's accent, toned down toward the text colour.
comment_color :: () -> Vector4 {
  color := ui_mix(ui_theme.accent, ui_theme.text.normal, 0.35);
  color.w = 0.9;
  return color;
}

stat :: (name: string, data: Any, loc := #caller_location) {
  padded := alloc_string(18,, temp);
  memset(padded.data, #char " ", padded.count);
  memcpy(padded.data, name.data, min(name.count, padded.count));
  value(name, tprint("   %  %", padded, data), loc);
}

hex :: (v: u64) -> string {
  return tprint("0x%", formatInt(v, base = 16, minimum_digits = 16));
}

kilobytes :: (bytes: int) -> string {
  return tprint("% KB", bytes / 1024);
}

// ---------------------------------------------------------------------------
// Code shown on slides, in slide order. Types are written out on purpose: this
// is about the UI architecture, not about the language. The first comment of
// each snippet says where the real code is (line numbers as of writing).
// ---------------------------------------------------------------------------

// Retained vs immediate

CODE_RETAINED :: #string DONE
// a typical retained toolkit
save: *Button = new Button("Save");
save.on_click = () {
  save_document();
};
panel.add(save);

// whenever the document changes:
save.set_enabled(document.dirty);

// when the panel goes away:
panel.remove(save);
delete save;
DONE

CODE_IMMEDIATE :: #string DONE
ui_checkbox("document dirty", *dirty);

if ui_button("Save", disabled = !dirty).clicked {
  save_document();
}
DONE

// One frame

CODE_MAIN_LOOP :: #string DONE
// Main.jai:44
while !app.should_quit {
  input: UI_Input;
  input.mouse_pos = mouse_position;
  input.dt        = seconds_since_last_frame;

  ui_begin(input, metrics);

  presentation();

  ui_end();

  quads: [] UI_Quad = ui_quads();
  for quad: quads {
    r_draw_screen_quad(quad.rect, quad.color);
  }
}
DONE

// Input from the app

CODE_INPUT :: #string DONE
// Imgui_Backend.jai:16, ui_frame_begin (simplified)
input: UI_Input;
input.mouse_pos = mouse_position;
input.dt        = seconds_since_last_frame;

input.mouse_down[0]    = is_key_down(.MOUSE_BUTTON_LEFT);
input.mouse_pressed[0] = is_key_clicked(.MOUSE_BUTTON_LEFT);

input.scroll = wheel_notches;
input.text   = characters_typed_this_frame;

metrics: UI_Metrics;
metrics.font         = ui_font;
metrics.line_height  = ui_font.line_height;
metrics.measure_text = ui_measure_text;

ui_begin(input, metrics);
DONE

// What the app must provide

CODE_APP_PROVIDES :: #string DONE
// Imgui_Backend.jai:98
ui_measure_text :: (text: string) -> (width: float, height: float) {
  width, height: s32 = r_measure_text(ui_font, text);
  return cast(float) width, cast(float) height;
}

// Imgui_Backend.jai:16, every frame
metrics: UI_Metrics;
metrics.font          = ui_font;
metrics.measure_text  = ui_measure_text;
metrics.get_clipboard = ui_get_clipboard;  // optional
metrics.set_clipboard = ui_set_clipboard;  // optional
DONE

// UI_Context

CODE_CONTEXT :: #string DONE
// Core.jai:794 (simplified)
UI_Context :: struct {
  frame_memory:      Arena;    // reset every frame
  persistent_memory: Arena;
  input:   UI_Input;

  root:         *UI_Node;      // this frame's tree
  parent_stack: [..] *UI_Node;

  caches: Table(u64, *UI_Node_Cache);  // kept between frames

  hot_key:    u64;             // hovered
  active_key: u64;             // pressed

  quads: [..] UI_Quad;         // output
}
DONE

// UI_Node

CODE_NODE :: #string DONE
// Core.jai:102 (simplified)
UI_Node :: struct {
  key: u64;
  parent, first, last, next, prev: *UI_Node;

  text:   string;
  flags:  UI_Node_Flags;  // behaviour
  params: UI_Params;      // size, axis, colours...

  rect:   UI_Rect;        // position and size
  clip:   UI_Rect;        // visible part
  inner:  UI_Rect;        // rect minus padding
  cursor: Vector2;        // where the next child goes
  depth:  float;          // smaller = in front
}
DONE

// The UI tree

CODE_MINI_UI :: #string DONE
// Presentation.jai, mini_settings_ui
panel: *UI_Node = ui_node("Settings", 0, panel_params);
ui_push_parent(panel);
  ui_label("Audio");
  ui_slider("Volume", *volume, 0.0, 1.0);
  ui_checkbox("Mute", *mute);
  ui_row_begin("buttons");
    ui_button("Apply");
    ui_button("Cancel");
  ui_row_end();
ui_pop_parent();
DONE

// Keys

CODE_KEY_SAME_TEXT :: #string DONE
// Presentation.jai, slide_keys
ui_row_begin("row");
  first:  UI_Signal = ui_button("Save");
  second: UI_Signal = ui_button("Save");
ui_row_end();
DONE

CODE_KEY_LOOP :: #string DONE
for i: 0..2 {
  ui_push_id(i);
  item: UI_Signal = ui_button("Item");
  ui_pop_id();
}
DONE

// A node is a rectangle

CODE_ANATOMY :: #string DONE
// Core.jai:102 (only the layout part)
UI_Node :: struct {
  rect:   UI_Rect;        // position and size, on screen
  text:   string;         // optional
  flags:  UI_Node_Flags;  // behaviour

  inner:  UI_Rect;        // rect minus padding
  clip:   UI_Rect;        // the visible part of rect
  cursor: Vector2;        // where the next child goes
}
DONE

// Layout

CODE_SIZES :: #string DONE
// Core.jai:33
UI_Size_Kind :: enum {
  PIXELS;           // fixed
  PARENT_FRACTION;  // share of the space still free
  PARENT_RATIO;     // share of the parent's whole size
  TEXT;             // text size + some padding
}
DONE

CODE_PLACE :: #string DONE
// Core.jai:489, ui_node_keyed (simplified)
parent: *UI_Node = ui_parent();

// 1. size: from params, the free space and the text
node.rect.size = resolve(params.size, free_space, text_size);

// 2. position: the parent's cursor
node.rect.pos = parent.cursor;

// 3. move the cursor past the new node
if parent.params.axis == .X {
  parent.cursor.x += node.rect.size.x + spacing;
} else {
  parent.cursor.y += node.rect.size.y + spacing;
}

// 4. the rect is final: test the mouse now
ui_interact(node);
DONE

// Signals

CODE_SIGNAL_CLASSIC :: #string DONE
// Dear ImGui (C++)
if (ImGui::Button("Save")) {
  save();
}
if (ImGui::IsItemHovered()) {
  ImGui::SetTooltip("Writes to disk");
}
DONE

CODE_SIGNAL_OURS :: #string DONE
signal: UI_Signal = ui_button("Save");
if signal.clicked {
  save();
}
if signal.hovered {
  ui_set_tooltip("Writes to disk");
}
DONE

CODE_SIGNAL_REACT :: #string DONE
// Presentation.jai, card_demo
card: *UI_Node = ui_node("card", flags, params);
signal: UI_Signal = ui_signal_from_node(card);

if signal.hovered {
  ui_set_tooltip("Drag me around");
}
if signal.held {
  card_position += ui.input.mouse_delta;
}
DONE

// Behaviour from flags

CODE_FLAGS :: #string DONE
// Core.jai:1
UI_Node_Flags :: enum_flags {
  CLICKABLE;  HOVERABLE;  DRAGGABLE;
  RESIZABLE;  SCROLL_Y;   FLOATING;
  DRAW_TEXT;  DRAW_LINES;
  TEXT_CENTER_X;  TEXT_CENTER_Y;  ...
}
DONE

// Widgets are small

CODE_BUTTON :: #string DONE
// Widgets.jai:27 (simplified)
ui_button :: (text: string) -> UI_Signal {
  params: UI_Params = ui_box_params(ui_theme.button, ui_theme.button_border);
  params.text        = text;
  params.size.width  = .{ kind = .TEXT, value = 16 };
  params.size.height = .{ kind = .TEXT, value = 8 };

  flags: UI_Node_Flags = .DRAW_TEXT | .TEXT_CENTER_Y | .HOVERABLE | .CLICKABLE;
  node: *UI_Node = ui_node(text, flags, params);
  return ui_signal_from_node(node);
}
DONE

CODE_CHECKBOX :: #string DONE
// Widgets.jai:487 (simplified)
ui_checkbox :: (text: string, value: *bool) -> bool {
  row_flags: UI_Node_Flags = .CLICKABLE | .HOVERABLE;
  row: *UI_Node = ui_node(text, row_flags, row_params);
  signal: UI_Signal = ui_signal_from_node(row);
  if signal.clicked {
    value.* = !value.*;
  }

  ui_push_parent(row);
    box: *UI_Node = ui_node(text, "box", 0, box_params);
    if value.* {
      ui_push_parent(box);
        ui_icon_node(text, "tick", tick_params, .CHECK);
      ui_pop_parent();
    }
    ui_node(text, "label", .DRAW_TEXT, label_params);
  ui_pop_parent();

  return signal.clicked;
}
DONE

CODE_SLIDER :: #string DONE
// Widgets.jai:382 (simplified)
ui_slider :: (text: string, value: *float, low: float, high: float) {
  track_flags: UI_Node_Flags = .CLICKABLE | .HOVERABLE;
  track: *UI_Node = ui_node(text, track_flags, track_params);
  signal: UI_Signal = ui_signal_from_node(track);

  if signal.held {
    t: float = (mouse.x - track.rect.pos.x) / track.rect.size.x;
    value.* = clamp(low + t * (high - low), low, high);
  }

  ui_push_parent(track);
    fraction: float = (value.* - low) / (high - low);
    fill_params.size.width = .{ kind = .PIXELS, value = track.rect.size.x * fraction };
    ui_node(text, "fill", .FLOATING, fill_params);

    text_flags: UI_Node_Flags = .FLOATING | .DRAW_TEXT;
    ui_node(text, "value", text_flags, text_params);
  ui_pop_parent();
}
DONE

// Custom widgets

CODE_POOL_WIDGET :: #string DONE
// Custom_Widgets.jai:1 (simplified)
ui_flat_pool :: (name: string, pool: *Flat_Pool) {
  panel: *UI_Node = ui_node(name, "panel", 0, bordered_params);
  ui_push_parent(panel);
    ui_label(tprint("%: used %, committed %, reserved %", ...));
    pool_bar(name, "reserve",   used, committed, reserved);
    pool_bar(name, "committed", used, committed, committed);
  ui_pop_parent();
}

// Custom_Widgets.jai:47 (simplified)
pool_bar :: (name: string, salt: string, used: int, committed: int, total: int) {
  track: *UI_Node = ui_node(name, salt, 0, track_params);
  ui_push_parent(track);
    segment(0, 0.0,         used_x,      used_color,  "used");
    segment(1, used_x,      committed_x, free_color,  "committed, free");
    segment(2, committed_x, width,       empty_color, "reserved only");
  ui_pop_parent();
}
DONE

// What user code looks like

CODE_USER :: #string DONE
if ui_button("Click me").clicked {
  clicks += 1;
}
ui_label(tprint("clicked % times", clicks));

ui_slider("Value", *value, 0.0, 1.0);
ui_toggle("Toggle", *toggle);
ui_progress_bar(value);
ui_combo("Quality", *quality, qualities);
ui_drag_number("Count", *count, 0.2, 0, 100);
ui_text_input("Name", *name, "type a name");
ui_color_edit("Colour", *colour);

if toggle {
  ui_label("Hello, Sailor!");
}
DONE

// The cache

CODE_CACHE :: #string DONE
// Core.jai:936
ui_cache_get :: (key: u64) -> *UI_Node_Cache {
  found: **UI_Node_Cache = table_find_pointer(*ui.caches, key);
  if found {
    found.*.last_touched = ui.frame;
    return found.*;
  }

  cache: *UI_Node_Cache = New(UI_Node_Cache);
  cache.last_touched = ui.frame;
  table_add(*ui.caches, key, cache);
  return cache;
}

// Core.jai:956, every 60 frames:
// free every entry not touched in the last 240 frames
DONE

// Who owns the state?

CODE_OWN_USER :: #string DONE
mute: bool = false;            // your variable
ui_checkbox("Mute", *mute);    // reads and writes it

if ui_collapsing_header("Open / close me") {
  // open or closed? the library remembers, by key
}

ui_list_box("Fruits", *picked, fruits, 4);
// picked is yours, the scroll position is the library's
DONE

// Animation

CODE_ANIMATION :: #string DONE
// Core.jai:1209
t: float = 1.0 - exp(-dt * speed);   // fraction to move this frame

// Core.jai:1339, ui_emit: every node's colour, in its cache
target: Vector4 = ifx hovered then hover_color else normal_color;
cache.background += (target - cache.background) * t;
DONE

// Animated layout

CODE_DISCLOSURE :: #string DONE
// Widgets.jai:746, ui_collapsing_header (simplified)
target: float = ifx cache.expanded then 1.0 else 0.0;
cache.open_t += (target - cache.open_t) * t;

body_height: float = cache.full_height * cache.open_t;

// Widgets.jai:814, ui_collapsing_end
cache.full_height = height_of_contents;  // for next frame
DONE

// Rendering

CODE_QUAD :: #string DONE
// Core.jai:223 (simplified)
UI_Quad :: struct {
  rect:  UI_Rect;    // where
  clip:  UI_Rect;    // what part is visible
  color: Vector4;
  border_thickness: float;
  corner_radius:    float;
  rotation:         float;
  texture: *Texture;  // font texture for letters
}
DONE

CODE_DRAW :: #string DONE
// Imgui_Backend.jai:86 (simplified)
ui_draw :: () {
  quads: [] UI_Quad = ui_quads();
  for quad: quads {
    r_push_clip_rect(quad.clip);
    r_draw_screen_quad(quad.rect, quad.color, quad.texture,
                       quad.corner_radius, quad.rotation);
    r_pop_clip_rect();
  }
}
DONE

CODE_LINE :: #string DONE
// Core.jai:1146, ui_push_line (simplified)
delta:  Vector2 = end - start;
length: float   = sqrt(delta.x * delta.x + delta.y * delta.y);

quad: UI_Quad;
quad.rect.size = .{ length, line_width };
quad.rect.pos  = (start + end) * 0.5 - quad.rect.size * 0.5;
quad.rotation  = atan2(delta.y, delta.x);
DONE

// ---------------------------------------------------------------------------
// Source browser
// ---------------------------------------------------------------------------

#import "File_Utilities";
#import "String";

SOURCE_DIR :: #run -> string { path := #filepath; return string.{ path.count - 1, path.data }; };

Source_Entry :: struct {
  name:  string;
  depth: int;
  file:  int; // index into source.files, -1 for a folder
}

source: struct {
  loaded:   bool;
  pool:     Flat_Pool;
  files:    [..] string;   // relative to SOURCE_DIR
  entries:  [..] Source_Entry;
  selected: int = -1;
  text:     string;
  lines:    [..] string;
}

source_load :: () {
  source.loaded = true;
  push_allocator(flat_pool_allocator_proc, *source.pool);

  for file_list(SOURCE_DIR, recursive = true) {
    path := copy_string(it);
    for 0..path.count - 1  if path[it] == #char "\\"  path[it] = #char "/";
    relative := advance(path, SOURCE_DIR.count + 1);
    if contains(relative, ".build/")  continue;
    if !ends_with(relative, ".jai") && !ends_with(relative, ".vert") && !ends_with(relative, ".frag")  continue;
    array_add(*source.files, relative);
  }
  quick_sort(source.files, compare_strings);

  previous: [] string;
  for file, file_index: source.files {
    parts := split(file, "/");
    shared := 0;
    while shared < previous.count - 1 && shared < parts.count - 1 && previous[shared] == parts[shared]  shared += 1;
    for depth: shared..parts.count - 2  array_add(*source.entries, .{ name = parts[depth], depth = depth, file = -1 });
    array_add(*source.entries, .{ name = parts[parts.count - 1], depth = parts.count - 1, file = file_index });
    previous = parts;
  }
}

source_select :: (file: int) {
  if file == source.selected  return;
  free(source.text);
  array_reset(*source.lines);

  source.selected = file;
  source.text     = read_entire_file(tprint("%/%", SOURCE_DIR, source.files[file]));
  rest := source.text;
  while rest {
    end := find_index_from_left(rest, #char "\n");
    if end < 0  end = rest.count;
    line := string.{ end, rest.data };
    if line && line[line.count - 1] == #char "\r"  line.count -= 1;
    array_add(*source.lines, line);
    rest = advance(rest, min(end + 1, rest.count));
  }
}

source_panel :: (salt: string, width: UI_Size, loc := #caller_location) -> *UI_Node {
  key := ui_child_key("source", salt, loc);
  params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  params.name        = "Panel";
  params.padding     = UI_CONTROL_PADDING;
  params.size.width  = width;
  params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  if ui_cache_get(key).scroll_max > 0.5  params.pad_right = UI_SCROLLBAR_W + 4.0;
  panel := ui_node("source", salt, .SCROLL_Y, params, loc);
  ui_push_parent(panel);
  return panel;
}

source_tree :: () {
  open_depth := 0;
  skip_below := -1;
  for entry: source.entries {
    if skip_below >= 0 && entry.depth > skip_below  continue;
    skip_below = -1;
    while open_depth > entry.depth { ui_tree_pop(); open_depth -= 1; }

    ui_push_id(it_index);
    if entry.file < 0 {
      if ui_tree_node(entry.name, default_open = entry.depth == 0) {
        open_depth += 1;
      } else {
        ui_tree_pop();
        skip_below = entry.depth;
      }
    } else {
      selected := entry.file == source.selected;
      if ui_selectable(entry.name, *selected)  source_select(entry.file);
      ui_set_tooltip(entry.name);
    }
    ui_pop_id();
  }
  while open_depth > 0 { ui_tree_pop(); open_depth -= 1; }
}

source_text :: (panel: *UI_Node) {
  line_height := ui.metrics.line_height;
  scroll  := ui_cache_get(panel.key).scroll;
  first   := clamp(cast(int) (scroll / line_height), 0, source.lines.count);
  visible := cast(int) (panel.inner.size.y / line_height) + 2;
  last    := min(first + visible, source.lines.count);

  spacer :: (lines: int, salt: string) #expand {
    if lines <= 0  return;
    params: UI_Params;
    params.render      = false;
    params.size.width  = .{ kind = .PIXELS, value = 1.0 };
    params.size.height = .{ kind = .PIXELS, value = lines * `line_height };
    ui_node("source", salt, 0, params);
  }

  spacer(first, "above");
  for index: first..last - 1 {
    params: UI_Params;
    params.text        = tprint("%  %", formatInt(index + 1, minimum_digits = 4, padding = #char " "), source.lines[index]);
    params.foreground  = ui_theme.text;
    params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    params.size.height = .{ kind = .PIXELS, value = line_height };
    ui_node("source", "line", index, .DRAW_TEXT, params);
  }
  spacer(source.lines.count - last, "below");
}
