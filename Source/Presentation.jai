presentation :: () {
  ui_window_begin("Flying Rat - Immediate-mode UI", null, 60, 40, 960, 620, .NO_CLOSE, initial_dock = .FULL);
  slides_begin("flying_rat", *current_slide);
    if slide("Title")                                         slide_title();
    if slide("Topics")                                        slide_topics();

    // Part 1: What and why
    if slide("Retained vs immediate")                         slide_retained_vs_immediate();
    if slide("Immediate is the API")                          slide_api_not_implementation();
    if slide("Where this comes from")                         slide_prior_art();

    // Part 2: The frame
    if slide("One frame")                                     slide_one_frame();
    if slide("UI_Context")                                    slide_context();
    if slide("Input from the app")                            slide_input();
    if slide("What the app must provide")                     slide_app_provides();

    // Part 3: Building the tree
    if slide("A node is a rectangle")                         slide_anatomy();
    if slide("UI_Node")                                       slide_node();
    if slide("Where nodes live")                              slide_memory();
    if slide("The tree is intrusive")                         slide_intrusive();
    if slide("The root is the screen")                        slide_root();
    if slide("Building the tree")                             slide_tree();
    if slide("Keys")                                          slide_keys();

    // Part 4: From tree to screen
    if slide("Layout")                                        slide_layout();
    if slide("Single-pass layout and its cost")               slide_single_pass();
    if slide("Behaviour from flags")                          slide_flags();
    if slide("Style: params per node")                        slide_style();
    if slide("Depth instead of sorting")                      slide_depth();
    if slide("Signals")                                       slide_signals();
    if slide("Rendering")                                     slide_rendering();

    // Part 5: State across frames
    if slide("Why keep state between frames?")                slide_why_state();
    if slide("The cache")                                     slide_cache();
    if slide("Who owns the state?")                           slide_state_ownership();
    if slide("Animation")                                     slide_animation();
    if slide("Animated layout")                               slide_animated_layout();
    if slide("Windows and z-order")                           slide_windows();
    if slide("The one-frame delay")                           slide_delay();

    // Part 6: Building on it
    if slide("Widgets are small")                             slide_composition();
    if slide("Custom widgets")                                slide_custom_widgets();
    if slide("What user code looks like")                     slide_live_demo();

    // Part 7: Wrap-up
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
  title("Building an immediate mode UI from scratch... Presented in itself!");
  ui_spacing(ui.metrics.line_height * 2.0);
  point("Francisco Zacarias, 1st December 2026");
}

slide_topics :: () {
  title("Topics");
  ui_spacing(ui.metrics.line_height * 2.0);

  heading("1. What and why");
  sub("What is an immediate-mode UI, and where does this design come from?");
  ui_spacing();

  heading("2. The frame");
  sub("What happens each frame, and what does the UI work with?");
  ui_spacing();

  heading("3. Building the tree");
  sub("What is a node, and how does one frame's tree get built?");
  ui_spacing();

  heading("4. From tree to screen");
  sub("What happens to each node as it is created, and at the end of the frame?");
  ui_spacing();

  heading("5. State across frames");
  sub("The tree is thrown away every frame: what has to survive, and how?");
  ui_spacing();

  heading("6. Building on it");
  sub("What is it like to write and use widgets?");
  ui_spacing();

  heading("7. Wrap-up");
  sub("Performance, source, demo, summary");
}

// ---------------------------------------------------------------------------
// Part 1: What and why
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
  point("It's about API design, not about keeping data between frames");
  point("Cost: the UI is rebuilt every frame, and some state has to persist anyway");
}


slide_api_not_implementation :: () {
  title("Immediate is the API, not the implementation");
  point("Immediate vs retained is not about whether the UI keeps state");
  point("It is about who owns the data, and who keeps it in sync");
  sub("Retained: widgets hold a copy of your data, and you keep both copies in sync");
  sub("Immediate: your data is the only copy, and the UI reads it every frame");
  ui_spacing();
  point("The library can still keep its own state between frames");
  sub("only what the UI itself cares about: scroll, open / closed, animation");
  sub("our UI throws the node tree away every frame, but keeps a small per-widget cache");
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
// Part 2: The frame
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
    heading("In: what the app gives the UI (after the context)");
    point("input: mouse, keys, typed text, time since last frame");
    point("metrics: the font, and how to measure text");
    ui_spacing();
    heading("Out: what the UI gives back");
    point("a list of quads to draw  (how: part 4, Rendering)");
    point("signals: what was hovered, clicked, dragged...");
    ui_spacing();
    heading("Live");
    value("frame", tprint("frame               %", ui.frame));
    value("nodes", tprint("nodes last frame    %", ui.stats.nodes));
    value("quads", tprint("quads last frame    %", ui.stats.quads));
  split_end();
}

ctx_text: UI_Text_Buffer(64);

slide_context :: () {
  title("UI_Context: everything in one place");
  split_begin("ctx", 0.45);
    code(CODE_CONTEXT);
    point("The library's internal state: one global");
    point("ui_begin / ui_end work on it, every widget function uses it");
    point("Each part gets its own slide:");
    sub("nodes, the root, the parent stack (part 3), the cache (part 5)");
  split_next();
    heading("Live: what it holds right now");
    items: [..] Tree_Item;
    items.allocator = temp;
    array_add(*items, .{ label = "UI_Context  ui", parent = -1, depth = 0, highlight = true });
    array_add(*items, .{ label = "frame_pool: frame arena",                                          parent = 0, depth = 1 });
    array_add(*items, .{ label = tprint("% nodes this frame", ui.stats.nodes),                       parent = 1, depth = 2 });
    array_add(*items, .{ label = "root: the screen node",                                            parent = 0, depth = 1 });
    array_add(*items, .{ label = tprint("parent_stack: % deep, right here", ui.parent_stack.count),  parent = 0, depth = 1 });
    array_add(*items, .{ label = "persistent: arena",                                                parent = 0, depth = 1 });
    array_add(*items, .{ label = tprint("caches: % entries (hash table)", ui.caches.count),          parent = 5, depth = 2 });
    array_add(*items, .{ label = tprint("window_order: % windows", ui.window_order.count),           parent = 5, depth = 2 });
    array_add(*items, .{ label = tprint("hot key:    %", hex(ui.hover_key)),                         parent = 0, depth = 1 });
    array_add(*items, .{ label = tprint("active key: %", hex(ui.active_key)),                        parent = 0, depth = 1 });
    array_add(*items, .{ label = tprint("focus key:  %", hex(ui.keyboard_focus_key)),                parent = 0, depth = 1 });
    array_add(*items, .{ label = tprint("quads: % (output)", ui.stats.quads),                        parent = 0, depth = 1 });
    tree_diagram("ctx_map", items);
    ui_spacing();
    sub("interact to change the keys:");
    ui_text_input("ctx_text", *ctx_text, "click here to take keyboard focus");
    if ui_button("Hold me").held {
      ui_label("'active' is this button while held");
    }
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

// ---------------------------------------------------------------------------
// Part 3: Building the tree
// ---------------------------------------------------------------------------

RECT_COLOR   :: Vector4.{ 1.0,  0.35, 0.35, 1.0 };
INNER_COLOR  :: Vector4.{ 0.35, 0.65, 1.0,  1.0 };
CLIP_COLOR   :: Vector4.{ 0.35, 1.0,  0.45, 1.0 };
CURSOR_COLOR :: Vector4.{ 1.0,  0.85, 0.2,  1.0 };

show_rect   := false;
show_inner  := false;
show_clip   := false;
show_cursor := false;

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

slide_memory :: () {
  title("Where nodes live: two arenas");
  point("An arena is a bump allocator: allocating moves a pointer, freeing resets it");
  ui_spacing();
  split_begin("memory", 0.5);
    heading("Frame arena: reset at every ui_begin");
    point("every UI_Node");
    point("the text copied into nodes (label, text)");
    point("scratch: line points, tooltip text, sort lists");
    sub("anything that only has to live until the frame is drawn");
    code(CODE_ALLOC);
  split_next();
    heading("Persistent arena: lives as long as the UI");
    point("the cache: per-widget state kept between frames (part 5)");
    point("the window order");
    point("arrays reused every frame: the stacks, the quads");
    sub("reserved once, emptied every frame, never reallocated");
    code(CODE_INIT);
  split_end();

  ui_spacing();
  heading("Why two?");
  point("The frame arena is wiped every frame: state that must survive can't live there");
  point("Reusing persistent arrays means no allocation at all during a frame");
  ui_spacing();

  split_begin("memory_live", 0.5);
    heading("Does the size matter?");
    point("A debug UI has hundreds to a few thousand nodes");
    point("That is kilobytes, rebuilt every frame");
    point("At this size, simple code beats a clever memory layout");
  split_next();
    nodes      := ui.stats.nodes;
    node_bytes := size_of(UI_Node);
    heading("Live: this frame");
    value("node_size",  tprint("size_of(UI_Node)         % bytes", node_bytes));
    value("link_size",  tprint("  of which the 5 links   % bytes", 5 * size_of(*UI_Node)));
    value("node_count", tprint("nodes last frame         %", nodes));
    value("node_total", tprint("nodes x size             % KB", (nodes * node_bytes) / 1024));
    value("frame_used", tprint("frame arena used         % KB  (nodes + text + ...)", ui.stats.frame_bytes / 1024));
    value("cache_size", tprint("size_of(UI_Node_Cache)   % bytes, % entries", size_of(UI_Node_Cache), ui.caches.count));
    ui_spacing();
    heading("The two arenas  (hover the bars)");
    ui_flat_pool("frame arena", *ui.frame_pool);
    ui_flat_pool("persistent arena", *ui.persistent);
  split_end();
}

PARENT_COLOR :: Vector4.{ 1.0,  0.40, 0.40, 1.0 };
FIRST_COLOR  :: Vector4.{ 0.40, 1.0,  0.50, 1.0 };
LAST_COLOR   :: Vector4.{ 0.40, 0.70, 1.0,  1.0 };
PREV_COLOR   :: Vector4.{ 0.85, 0.50, 1.0,  1.0 };
NEXT_COLOR   :: Vector4.{ 1.0,  0.85, 0.30, 1.0 };

slide_intrusive :: () {
  title("The tree is intrusive");
  split_begin("intrusive", 0.48);
    point("The links live inside the node itself");
    sub("no child arrays, no separate tree container");
    code(CODE_NODE_LINKS);
    heading("Every node, seen from the middle");
    star_diagram();
    point("Adding a child: O(1), through parent.last");
    point("No allocation per child, nothing to grow or free");
    point("Walking the tree needs no extra memory");
  split_next();
    heading("Live: hover any part of this panel");
    big := ui.metrics.line_height;
    mini := mini_settings_ui(width = big * 36.0, padding = big * 2.0, spacing = big * 2.0);

    // The node to show: the one under the mouse inside the panel, or the checkbox.
    shown: *UI_Node;
    pick_under_mouse(mini, *shown);
    if !shown && rect_contains(mini.clip, ui.input.mouse_pos)  shown = mini;
    if !shown  shown = mini.first.next.next;

    ui_overlay_rect(shown.rect, .{ 1, 1, 1, 0.08 }, .{ 1, 1, 1, 1 }, 2.0, 0.0);
    pointer_arrow(shown, shown.parent, "parent", PARENT_COLOR);
    if shown.first && shown.first == shown.last {
      pointer_arrow(shown, shown.first, "first, last", FIRST_COLOR);   // one child: both point at it
    } else {
      pointer_arrow(shown, shown.first, "first", FIRST_COLOR);
      pointer_arrow(shown, shown.last,  "last",  LAST_COLOR);
    }
    pointer_arrow(shown, shown.prev,   "prev",   PREV_COLOR);
    pointer_arrow(shown, shown.next,   "next",   NEXT_COLOR);

    ui_spacing();
    heading(tprint("this node: %", tree_label(shown)));
    pointer_line("parent", shown.parent, PARENT_COLOR);
    pointer_line("first",  shown.first,  FIRST_COLOR);
    pointer_line("last",   shown.last,   LAST_COLOR);
    pointer_line("prev",   shown.prev,   PREV_COLOR);
    pointer_line("next",   shown.next,   NEXT_COLOR);
    ui_spacing();
    heading("Linking a new node in");
    code(CODE_INTRUSIVE);
    heading("Walking the children");
    code(CODE_WALK);
  split_end();
}

// A fixed diagram: one node in the middle and the five nodes its pointers reach.
star_diagram :: () {
  area_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  area_params.name        = "star";
  area_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  area_params.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height * 16.0 };
  area := ui_node("star_area", 0, area_params);
  ui_push_parent(area);
    size   := area.rect.size;
    box    := Vector2.{ floor(ui.metrics.line_height * 8.0), floor(ui_row_height() * 1.3) };
    center := Vector2.{ size.x * 0.5,  size.y * 0.5  };
    parent := Vector2.{ size.x * 0.5,  size.y * 0.12 };
    prev   := Vector2.{ size.x * 0.13, size.y * 0.5  };
    next   := Vector2.{ size.x * 0.87, size.y * 0.5  };
    first  := Vector2.{ size.x * 0.25, size.y * 0.88 };
    others := Vector2.{ size.x * 0.5,  size.y * 0.88 };
    last   := Vector2.{ size.x * 0.75, size.y * 0.88 };

    // Arrows first, so the boxes are drawn over their ends.
    star_arrow(0, area, center, parent, box, "parent", PARENT_COLOR);
    star_arrow(1, area, center, prev,   box, "prev",   PREV_COLOR);
    star_arrow(2, area, center, next,   box, "next",   NEXT_COLOR);
    star_arrow(3, area, center, first,  box, "first",  FIRST_COLOR);
    star_arrow(4, area, center, last,   box, "last",   LAST_COLOR);

    star_box(0, area, center, box, "node",          ui_theme.accent);
    star_box(1, area, parent, box, "its parent",    PARENT_COLOR);
    star_box(2, area, prev,   box, "prev sibling",  PREV_COLOR);
    star_box(3, area, next,   box, "next sibling",  NEXT_COLOR);
    star_box(4, area, first,  box, "first child",   FIRST_COLOR);
    star_box(5, area, others, box, "...",           ui_theme.window_border.normal);
    star_box(6, area, last,   box, "last child",    LAST_COLOR);
  ui_pop_parent();
}

star_box :: (index: int, area: *UI_Node, center: Vector2, box: Vector2, text: string, color: Vector4) {
  params := ui_box_params(ui_theme.button, .{ normal = color });
  params.text             = text;
  params.foreground       = ui_theme.text;
  params.border_thickness = 2.0;
  params.corner_radius    = 4.0;
  params.animate          = false;
  params.offset           = center - box * 0.5;
  params.size.width       = .{ kind = .PIXELS, value = box.x };
  params.size.height      = .{ kind = .PIXELS, value = box.y };
  ui_node("star_box", "b", index, .FLOATING | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, params);
}

// An arrow between two box centres (relative to the area), stopping at the boxes' edges.
star_arrow :: (index: int, area: *UI_Node, from: Vector2, to: Vector2, box: Vector2, label: string, color: Vector4) {
  delta  := to - from;
  length := sqrt(delta.x * delta.x + delta.y * delta.y);
  if length < 1.0  return;
  dir := delta / length;

  // How far along the line the edge of a box is, from its centre.
  edge := min(ifx dir.x != 0.0 then box.x * 0.5 / abs(dir.x) else 1.0e9,
              ifx dir.y != 0.0 then box.y * 0.5 / abs(dir.y) else 1.0e9);
  origin := area.rect.pos;
  start  := origin + from + dir * (edge + 2.0);
  end    := origin + to   - dir * (edge + 4.0);
  side   := Vector2.{ -dir.y, dir.x };

  points := ui_frame_allocate(Vector2, 5);
  points[0] = start;
  points[1] = end;
  points[2] = end - dir * 12.0 + side * 6.0;
  points[3] = end;
  points[4] = end - dir * 12.0 - side * 6.0;

  line: UI_Params;
  line.size.width        = .{ kind = .PIXELS, value = area.rect.size.x };
  line.size.height       = .{ kind = .PIXELS, value = area.rect.size.y };
  line.foreground.normal = color;
  line.line_width        = 2.0;
  line.points            = points;
  line.animate           = false;
  ui_node("star_arrow", "a", index, .FLOATING | .DRAW_LINES, line);

  // The field name, beside the middle of the arrow.
  label_params: UI_Params;
  label_params.text        = label;
  label_params.foreground  = .{ normal = color };
  label_params.animate     = false;
  label_params.offset      = (from + to) * 0.5 + side * 14.0 - Vector2.{ 0, ui.metrics.line_height * 0.5 };
  label_params.size.width  = .{ kind = .TEXT, value = 0.0 };
  label_params.size.height = .{ kind = .TEXT, value = 0.0 };
  ui_node("star_label", "l", index, .FLOATING | .DRAW_TEXT, label_params);
}

// An arrow from one node to another, drawn on top of everything, labelled at its head.
pointer_arrow :: (from: *UI_Node, to: *UI_Node, label: string, color: Vector4) {
  if !to  return;
  screen := UI_Rect.{ .{ 0, 0 }, ui.input.screen_size };
  start  := from.rect.pos + from.rect.size * 0.5;
  end    := to.rect.pos + to.rect.size * 0.5;
  if to == from.parent  end = to.rect.pos + Vector2.{ 12, 12 };   // the parent contains us: point at its corner

  ui_overlay_rect(to.rect, .{ 0, 0, 0, 0 }, color, 1.5, 0.0);
  delta  := end - start;
  length := sqrt(delta.x * delta.x + delta.y * delta.y);
  if length > 1.0 {
    dir  := delta / length;
    side := Vector2.{ -dir.y, dir.x };
    ui_push_line(*ui.overlay_quads, start, end, 2.0, screen, color);
    ui_push_line(*ui.overlay_quads, end, end - dir * 10.0 + side * 5.0, 2.0, screen, color);
    ui_push_line(*ui.overlay_quads, end, end - dir * 10.0 - side * 5.0, 2.0, screen, color);
  }
  label_pos := end + Vector2.{ 10.0, -ui.metrics.line_height - 2.0 };   // just above and right of the head
  ui_push_text(*ui.overlay_quads, label, label_pos, screen, color);
}

// "parent  ->  Panel "Settings"" in the pointer's colour.
pointer_line :: (relation: string, node: *UI_Node, color: Vector4, loc := #caller_location) {
  target := ifx node then tree_label(node) else "null";
  text   := tprint("%  ->  %", relation, target);
  text_line(relation, text, .{ normal = color }, ui.metrics.line_height * 0.2, false, loc);
}

slide_root :: () {
  title("The root is the screen");
  split_begin("root", 0.5);
    point("Every frame starts with one node: the root");
    code(CODE_ROOT);
    point("Its rect is the app's screen");
    point("Otherwise it is an ordinary node:");
    sub("windows are its children, laid out and clipped like any other");
    point("Drawing walks the tree from the root down");
  split_next();
    root := ui.root;
    heading("Live: the screen, drawn small");
    screen_map(root);
    value("root_rect",   tprint("root.rect     % x %", root.rect.size.x, root.rect.size.y));
    value("screen_size", tprint("screen_size   % x %", ui.input.screen_size.x, ui.input.screen_size.y));
    ui_spacing();
    heading("...and the same nodes in the tree (top 3 levels)");
    canvas_params: UI_Params;
    canvas_params.name        = "Root canvas";
    canvas_params.spacing     = UI_STACK_SPACING;
    canvas_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    canvas_params.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height * 16.0 };
    ui_push_parent(ui_node("root_canvas_box", 0, canvas_params));
      ui_tree_canvas("root_tree", *root_canvas, root, live = true, levels = 3);
    ui_pop_parent();
    sub("the root is just the first node: a box the size of the screen");
  split_end();
}

root_canvas: Tree_Canvas;

// The screen at a small scale: the root's box, with its children and grandchildren
// drawn at their real positions inside it.
screen_map :: (root: *UI_Node) {
  map_width := floor(ui_parent().inner.size.x * 0.9);
  scale     := map_width / max(root.rect.size.x, 1.0);

  map_params := ui_box_params(ui_theme.window_background, .{ normal = ui_theme.accent });
  map_params.name             = "screen map";
  map_params.text             = tprint("root = the screen, % x %", cast(int) root.rect.size.x, cast(int) root.rect.size.y);
  map_params.foreground       = .{ normal = ui_theme.accent };
  map_params.border_thickness = 2.0;
  map_params.animate          = false;
  map_params.size.width       = .{ kind = .PIXELS, value = map_width };
  map_params.size.height      = .{ kind = .PIXELS, value = floor(root.rect.size.y * scale) };
  map := ui_node("screen_map", .DRAW_TEXT | .TEXT_CENTER_X, map_params);

  ui_push_parent(map);
    index := 0;
    child := root.first;
    while child {
      if child != map  map_rect(map, root, child, scale, 1, *index);
      grandchild := child.first;
      while grandchild {
        map_rect(map, root, grandchild, scale, 2, *index);
        grandchild = grandchild.next;
      }
      child = child.next;
    }
  ui_pop_parent();
}

map_rect :: (map: *UI_Node, root: *UI_Node, node: *UI_Node, scale: float, depth: int, index: *int) {
  color := ifx depth == 1 then ui_theme.text.normal else ui_theme.window_border.normal;
  params: UI_Params;
  params.border           = .{ normal = color };
  params.border_thickness = 1.0;
  params.animate          = false;
  params.offset           = (node.rect.pos - root.rect.pos) * scale;
  params.size.width       = .{ kind = .PIXELS, value = max(2.0, node.rect.size.x * scale) };
  params.size.height      = .{ kind = .PIXELS, value = max(2.0, node.rect.size.y * scale) };
  if depth == 1 {
    params.text       = tree_label(node);
    params.foreground = ui_theme.text;
  }
  ui_node("map_rect", "r", index.*, .FLOATING | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, params);
  index.* += 1;
}

tree_volume    := 0.6;
tree_mute      := false;
tree_full_open := false;
mini_canvas: Tree_Canvas;

// The parent stack as it was at one line of mini_settings_ui, saved for the slide.
stack_snapshot:       [32] string;
stack_snapshot_count: int;

capture_parent_stack :: () {
  stack_snapshot_count = min(ui.parent_stack.count, stack_snapshot.count);
  for i: 0..stack_snapshot_count - 1  stack_snapshot[i] = tree_label(ui.parent_stack[i]);
}

slide_tree :: () {
  title("Building the tree");
  split_begin("tree", 0.42);
    point("A stack of parents: an array of node pointers");
    sub("push to go in, pop to come out");
    sub("a new node's parent is the top of the stack");
    code(CODE_MINI_UI);
    code(CODE_STACK);
    ui_spacing();
    if ui_button("Show the full UI tree of this frame").clicked {
      tree_full_open = true;
    }
  split_next();
    heading("Live: that code, running");
    mini := mini_settings_ui();
    ui_spacing();
    heading("The parent stack at the marked line (top first)");
    for < i: stack_snapshot_count - 1..0 {
      ui_push_id(i);
        value("entry", tprint("[%]  %", i, stack_snapshot[i]));
      ui_pop_id();
    }
    ui_spacing();
    heading("...and the tree it builds  (drag, wheel to zoom, click Mute)");
    canvas_params: UI_Params;
    canvas_params.name        = "Tree canvas";
    canvas_params.spacing     = UI_STACK_SPACING;
    canvas_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    canvas_params.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height * 18.0 };
    ui_push_parent(ui_node("mini_canvas_box", 0, canvas_params));
      ui_tree_canvas("mini", *mini_canvas, mini, live = true);
    ui_pop_parent();
  split_end();

  ui_spacing(ui.metrics.line_height * 2.0);
  heading("Good to know: make the pop automatic");
  point("Every push needs its pop. Tie them together so one can't be forgotten");
  split_begin("tree_defer", 0.5);
    heading("Jai: defer, at the end of the scope");
    code(CODE_DEFER);
    ui_checkbox("show more (no early return)", *defer_show_more);
    defer_panel();
    sub("the early return still pops: ui_end would assert otherwise");
  split_next();
    heading("C: a one-iteration for loop (fzac)");
    code(CODE_DEFER_LOOP);
    sub("begin runs before the block, end runs after it");
  split_end();

  if tree_full_open {
    ui_window_begin("Full UI tree", *tree_full_open, 0, 0, 420, 400, initial_dock = .RIGHT);
      demo_canvas_body();
    ui_window_end();
  }
}

defer_show_more := false;

// Must match CODE_DEFER: pushes a parent and pops it with defer.
defer_panel :: () {
  panel_params := ui_box_params(ui_theme.window_background, ui_theme.window_border);
  panel_params.padding     = UI_PANEL_PADDING;
  panel_params.spacing     = UI_STACK_SPACING;
  panel_params.size.width  = .{ kind = .PIXELS, value = 300.0 };
  panel_params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(ui_parent()) };
  panel: *UI_Node = ui_node("Defer panel", 0, panel_params);
  ui_push_parent(panel);
  defer {
    ui_pop_parent();
    ui_shrink_panel_to_content(panel);
  }

  ui_label("Always shown");
  if !defer_show_more  return;  // the defer above still runs
  ui_button("Only with 'show more'");
}

// Must match CODE_MINI_UI. width / padding / spacing only make it bigger on
// the "tree is intrusive" slide, so the pointer arrows are easy to follow.
mini_settings_ui :: (width := 340.0, padding := UI_PANEL_PADDING, spacing := UI_STACK_SPACING) -> *UI_Node {
  panel_params := ui_box_params(ui_theme.window_background, ui_theme.window_border);
  panel_params.name        = "Panel";
  panel_params.padding     = padding;
  panel_params.spacing     = spacing;
  panel_params.size.width  = .{ kind = .PIXELS, value = width };
  panel_params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(ui_parent()) };

  panel: *UI_Node = ui_node("Settings", 0, panel_params);
  ui_push_parent(panel);
      ui_label("Audio");
      ui_slider("Volume", *tree_volume, 0.0, 1.0);
      ui_checkbox("Mute", *tree_mute);
      ui_row_begin("buttons");
          ui_button("Apply");
          capture_parent_stack();  // for the "Building the tree" slide
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
    point("Same widget, same key, every frame. Both later parts need that:");
    sub("input: the button pressed last frame is still held (part 4)");
    sub("state: a widget finds what it kept from last frame (part 5)");
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

// ---------------------------------------------------------------------------
// Part 4: From tree to screen
// ---------------------------------------------------------------------------

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
    point("Panels that fit their content: a problem for one pass (next slide)");
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

sp_items := 3;

slide_single_pass :: () {
  title("Single-pass layout and its cost");
  split_begin("single_pass", 0.5);
    point("Layout happens once, as each node is created: no second pass");
    point("Problem: a panel that fits its content can't know its height");
    sub("its children don't exist yet when it is created");
    point("Solution: give it a provisional height, the space that is left;");
    sub("build the children, then shrink it to where the cursor ended");
    code(CODE_SHRINK);
    heading("The trade-off");
    point("+ every rect is final the moment it exists: input is checked right away");
    point("- sizes that depend on children need this provisional trick");
    sub("a second layout pass could solve them, but rects would come a frame late");
  split_next();
    heading("Live: a group that fits its content");
    ui_slider("items in the group", *sp_items, 1, 8);
    colored_checkbox("provisional height (when it was created)", RECT_COLOR,  *sp_show_provisional);
    colored_checkbox("final height (after ui_group_end)",        CLIP_COLOR,  *sp_show_final);
    ui_spacing();

    ui_group_begin("A group");
      group: *UI_Node = ui_parent();
      provisional: UI_Rect = group.rect;   // copied before any child exists
      for 0..sp_items - 1  ui_label(tprint("item %", it));
    ui_group_end();
    final: UI_Rect = group.rect;

    if sp_show_provisional {
      fill := RECT_COLOR;  fill.w = 0.08;
      ui_overlay_rect(provisional, fill, RECT_COLOR, 2.0, 0.0);
    }
    if sp_show_final {
      ui_overlay_rect(final, .{ 0, 0, 0, 0 }, CLIP_COLOR, 2.0, 0.0);
    }
    value("sp_heights", tprint("provisional %  ->  final %", cast(int) provisional.size.y, cast(int) final.size.y));
    sub("everything below the group moved up when it shrank");
  split_end();
}

sp_show_provisional := true;
sp_show_final       := true;

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

style_color        := Vector4.{ 0.85, 0.35, 0.25, 1.0 };
style_radius       := 12.0;
style_window_open  := false;
style_theme        := 1;
style_slider       := 0.5;

slide_style :: () {
  title("Style: params per node");
  split_begin("style", 0.5);
    point("Flags say what a node does; UI_Params say how it looks");
    point("Every node keeps its own copy of the params it was built with");
    sub("there is no global style to push and pop while drawing");
    code(CODE_PARAMS);
    point("So style can change at three levels:");
    code(CODE_STYLE);
  split_next();
    heading("1. One node: set its params");
    ui_color_edit("background", *style_color);
    ui_slider("corner radius", *style_radius, 0.0, 30.0);
    params := ui_box_params(ui_theme.button, ui_theme.button_border);
    params.text          = "a styled node";
    params.foreground    = ui_theme.text;
    params.background    = .{ normal = style_color };
    params.corner_radius = style_radius;
    params.size.width    = .{ kind = .PARENT_RATIO, value = 0.6 };
    params.size.height   = .{ kind = .PIXELS, value = ui_row_height() * 2.0 };
    flags: UI_Node_Flags = .HOVERABLE | .CLICKABLE | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y;
    ui_node("styled node", flags, params);
    ui_spacing();

    heading("2. One window: swap the theme while building it");
    ui_slider("its theme", *style_theme, 0, ui_palettes.count - 1);
    value("style_theme_name", tprint("   %", ui_palettes[style_theme].name));
    ui_checkbox("Show the window", *style_window_open);
    ui_spacing();

    heading("3. Everything: the Theme button in the bottom bar");
    sub("sets the theme for the whole frame, so every node copies it");
  split_end();

  if style_window_open {
    region := ui_parent().inner;
    saved: UI_Theme = ui_theme;
    ui_theme = ui_theme_from_palette(ui_palettes[style_theme]);
    ui_window_begin("Another theme", *style_window_open, max(0.0, region.size.x - 420.0), 120, 380, 240);
      ui_label("Every node in here copied");
      ui_label("its colours from this theme.");
      ui_button("A button");
      ui_slider("A slider", *style_slider, 0.0, 1.0);
    ui_window_end();
    ui_theme = saved;
  }
}

depth_reverse := false;

slide_depth :: () {
  title("Depth instead of sorting");
  split_begin("depth", 0.5);
    point("Every node gets a depth when it is created: smaller = in front");
    point("Built later = in front, so children are in front of their parent");
    code(CODE_DEPTH);
    point("Two uses, and no node is ever sorted:");
    sub("input: of the nodes under the mouse, the smallest depth wins (next slide)");
    sub("drawing: back to front (Rendering)");
  split_next();
    heading("Live: three overlapping nodes - hover where they overlap");
    ui_checkbox("build them in reverse order", *depth_reverse);
    area_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
    area_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    area_params.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height * 12.0 };
    area := ui_node("depth_area", 0, area_params);
    ui_push_parent(area);
      a, b, c: *UI_Node;
      if depth_reverse {
        c = depth_box("C", 2, .{ 180, 90 });
        b = depth_box("B", 1, .{ 100, 50 });
        a = depth_box("A", 0, .{ 20,  10 });
      } else {
        a = depth_box("A", 0, .{ 20,  10 });
        b = depth_box("B", 1, .{ 100, 50 });
        c = depth_box("C", 2, .{ 180, 90 });
      }
    ui_pop_parent();
    value("depth_a", tprint("A  depth %", formatFloat(a.depth, trailing_width = 6)));
    value("depth_b", tprint("B  depth %", formatFloat(b.depth, trailing_width = 6)));
    value("depth_c", tprint("C  depth %", formatFloat(c.depth, trailing_width = 6)));
    hovered := "none";
    if ui.hover_key == a.key  hovered = "A";
    if ui.hover_key == b.key  hovered = "B";
    if ui.hover_key == c.key  hovered = "C";
    value("depth_hot", tprint("under the mouse, front-most: %", hovered));
  split_end();
}

// One of the overlapping boxes on the depth slide.
depth_box :: (name: string, color: int, offset: Vector2) -> *UI_Node {
  params := ui_box_params(.{ normal = ui_plot_series_color(color) }, ui_theme.button_border);
  params.text             = name;
  params.foreground       = ui_theme.text;
  params.border_thickness = 2.0;
  params.corner_radius    = 4.0;
  params.offset           = offset;
  params.size.width       = .{ kind = .PIXELS, value = 220.0 };
  params.size.height      = .{ kind = .PIXELS, value = ui_row_height() * 3.0 };
  flags: UI_Node_Flags = .FLOATING | .HOVERABLE | .CLICKABLE | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y;
  return ui_node("depth_box", name, flags, params);
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
    point("The front-most node under the mouse wins (depth)");
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

// ---------------------------------------------------------------------------
// Part 5: State across frames
// ---------------------------------------------------------------------------

why_pick := 4;

slide_why_state :: () {
  title("Why keep state between frames?");
  split_begin("why_state", 0.5);
    point("Every frame the whole tree is rebuilt");
    sub("last frame's nodes are gone: the frame arena was reset");
    ui_spacing();
    point("But some things must outlive a frame:");
    sub("how far a list is scrolled, whether a header is open");
    sub("where the text cursor is, where a window was dragged");
    sub("the colour a hover fade has reached: animation needs the last value");
    ui_spacing();
    point("The app shouldn't have to own any of that");
    point("So each widget gets a small piece of state, kept by the UI");
    sub("found again next frame by its key (part 3),");
    sub("stored in the cache (next slide)");
  split_next();
    heading("Without a remembered value, a hover can only jump");
    ui_row_begin("why_boxes", spacing = 12.0);
      anim_box("why_off", "no memory", false);
      anim_box("why_on",  "remembers its colour", true);
    ui_row_end();
    sub("hover both: only the right one can fade");
    ui_spacing();
    heading("Open or closed? Nothing in our code stores it");
    if ui_collapsing_header("Click me") {
      ui_label("The UI remembered this was open.");
    }
    ui_collapsing_end();
    ui_spacing();
    heading("Scroll it, change slides, come back: still scrolled");
    ui_list_box("Fruits##why", *why_pick, own_items, 4);
  split_end();
}

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
  point("Everything so far, together: a window is a node with a key");
  point("Its position, size and dock live in its cache");
  point("The context keeps a list of windows, back to front, kept across frames");
  sub("press inside a window: it and its parents move to the front");
  point("Each window gets its own band of depths from its place in that list");
  sub("so the front window's nodes win hit-testing and are drawn last");
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

delay_presses: [2] int;
delay_names:   [2] Window_Name;

slide_delay :: () {
  title("The one-frame delay");
  split_begin("delay", 0.5);
    point("Hit-testing happens while the tree is being built");
    point("Problem: a node can't know a later node will cover it");
    sub("it may already have told your code 'pressed'");
    sub("inside one window nodes rarely overlap; windows overlap all the time");
    point("So: which window owns the mouse is decided from last frame");
    code(CODE_DELAY);
    point("Only that window's nodes can be hovered or pressed this frame");
    point("Everything else is this frame's: layout is already done");
    sub("a layout solved at the end of the frame would make all input a frame late");
  split_next();
    heading("Live: two overlapping windows - press where they overlap");
    owner := "another window";
    if ui.mouse_panel == delay_names[0].key  owner = delay_names[0].name;
    if ui.mouse_panel == delay_names[1].key  owner = delay_names[1].name;
    value("delay_owner",  tprint("owner of the mouse (from last frame): %", owner));
    value("delay_counts", tprint("presses:  first %   second %", delay_presses[0], delay_presses[1]));
    sub("only the front window's button counts, whichever was built first");
  split_end();

  region := ui_parent().inner;
  x := max(0.0, region.size.x * 0.55);
  first := ui_window_begin("Built first", null, x, 260, 340, 200, .NO_CLOSE);
    delay_names[0] = .{ first.node.key, "Built first" };
    if delay_button("press me##first").pressed  delay_presses[0] += 1;
  ui_window_end();
  second := ui_window_begin("Built second", null, x + 120, 320, 340, 200, .NO_CLOSE);
    delay_names[1] = .{ second.node.key, "Built second" };
    if delay_button("press me##second").pressed  delay_presses[1] += 1;
  ui_window_end();
}

// A button that fills the window body, so the windows overlap on buttons.
delay_button :: (text: string, loc := #caller_location) -> UI_Signal {
  params := ui_box_params(ui_theme.button, ui_theme.button_border);
  params.text        = text;
  params.foreground  = ui_theme.text;
  params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  flags: UI_Node_Flags = .HOVERABLE | .CLICKABLE | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y;
  return ui_signal_from_node(ui_node(text, flags, params, loc));
}

// ---------------------------------------------------------------------------
// Part 6: Building on it
// ---------------------------------------------------------------------------

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
// Part 7: Wrap-up
// ---------------------------------------------------------------------------

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
  point("The node is the only primitive: a rect, optional text, flags that assign behaviour");
  ui_spacing();
  point("Nodes form an intrusive tree (parent / first / last / next / prev), rooted at the screen");
  ui_spacing();
  point("Rebuilt every frame from a frame arena, through a parent stack, then thrown away");
  ui_spacing();
  point("Keys give nodes an identity; a per-key cache keeps animation and cross-frame state");
  ui_spacing();
  point("Layout and hit-testing happen as each node is created; widgets get a signal back");
  ui_spacing();
  point("Output is a flat list of quads, for any renderer");
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
  heading("Source code of the UI and this presentation:");
  point("https://github.com/FranciscoZacarias/imgui-jai-presentation");
  ui_spacing();

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
// each snippet says where the real code is.
//
// Line numbers are found by the compiler: src() runs at compile time and turns
// every [[File.jai|some text]] into File.jai:line, the first line of that file
// containing the text. If the text is not found the build stops, so a slide
// can never point at the wrong line.
// ---------------------------------------------------------------------------

src :: (body: string) -> string {
  builder: String_Builder;
  rest := body;
  while true {
    start := find_index_from_left(rest, "[[");
    if start < 0 {
      append(*builder, rest);
      break;
    }
    append(*builder, slice(rest, 0, start));
    rest = advance(rest, start + 2);

    end := find_index_from_left(rest, "]]");
    assert(end >= 0, "src: a [[ without its ]]");
    token := slice(rest, 0, end);
    rest = advance(rest, end + 2);

    bar := find_index_from_left(token, #char "|");
    assert(bar >= 0, "src: [[%]] needs File.jai|text", token);
    file := slice(token, 0, bar);
    text := advance(token, bar + 1);
    append(*builder, tprint("%:%", file, source_line(file, text)));
  }
  return builder_to_string(*builder);
}

// The first line of `file` containing `text`, counting from 1.
source_line :: (file: string, text: string) -> int {
  path := ifx file == "Main.jai" || file == "Imgui_Backend.jai" || file == "Presentation.jai"
          then tprint("%/%", SOURCE_DIR, file)
          else tprint("%/Engine/Imgui/%", SOURCE_DIR, file);
  contents, ok := read_entire_file(path);
  assert(ok, "src: can't read %", path);

  line := 1;
  rest := contents;
  while rest {
    end := find_index_from_left(rest, #char "\n");
    if end < 0  end = rest.count;
    this_line := string.{ end, rest.data };
    // Lines with [[ are the references themselves (or this code): never match those.
    if !contains(this_line, "[[") && contains(this_line, text)  return line;
    line += 1;
    rest = advance(rest, min(end + 1, rest.count));
  }
  assert(false, "src: \"%\" not found in %", text, file);
  return 0;
}

// Retained vs immediate

CODE_RETAINED :: #run src(#string DONE
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
DONE);

CODE_IMMEDIATE :: #run src(#string DONE
// [[Presentation.jai|ui_checkbox("document dirty", *rvi_dirty);]], slide_retained_vs_immediate
ui_checkbox("document dirty", *dirty);

if ui_button("Save", disabled = !dirty).clicked {
  save_document();
}
DONE);

// One frame

CODE_MAIN_LOOP :: #run src(#string DONE
// [[Main.jai|while !app.should_quit {]]
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
DONE);

// UI_Context

CODE_CONTEXT :: #run src(#string DONE
// [[Core.jai|UI_Context :: struct {]] (simplified)
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
DONE);

// Input from the app

CODE_INPUT :: #run src(#string DONE
// [[Imgui_Backend.jai|ui_frame_begin :: () {]], ui_frame_begin (simplified)
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
DONE);

// What the app must provide

CODE_APP_PROVIDES :: #run src(#string DONE
// [[Imgui_Backend.jai|ui_measure_text :: (text: string) -> (width: float, height: float) {]]
ui_measure_text :: (text: string) -> (width: float, height: float) {
  width, height: s32 = r_measure_text(ui_font, text);
  return cast(float) width, cast(float) height;
}

// [[Imgui_Backend.jai|ui_frame_begin :: () {]], every frame
metrics: UI_Metrics;
metrics.font          = ui_font;
metrics.measure_text  = ui_measure_text;
metrics.get_clipboard = ui_get_clipboard;  // optional
metrics.set_clipboard = ui_set_clipboard;  // optional
DONE);

// A node is a rectangle

CODE_ANATOMY :: #run src(#string DONE
// [[Core.jai|UI_Node :: struct {]] (only the layout part)
UI_Node :: struct {
  rect:   UI_Rect;        // position and size, on screen
  text:   string;         // optional
  flags:  UI_Node_Flags;  // behaviour

  inner:  UI_Rect;        // rect minus padding
  clip:   UI_Rect;        // the visible part of rect
  cursor: Vector2;        // where the next child goes
}
DONE);

// UI_Node

CODE_NODE :: #run src(#string DONE
// [[Core.jai|UI_Node :: struct {]] (simplified)
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
DONE);

// Where nodes live

CODE_ALLOC :: #run src(#string DONE
// [[Core.jai|ui_allocate_node :: () -> *UI_Node {]]
ui_allocate_node :: () -> *UI_Node {
  node: *UI_Node = get(*ui.frame_pool, size_of(UI_Node));
  node.* = .{};
  return node;
}

// [[Core.jai|reset(*ui.frame_pool);]], ui_begin: last frame's nodes, all freed at once
reset(*ui.frame_pool);
DONE);

CODE_INIT :: #run src(#string DONE
// [[Core.jai|ui_init :: ()]] (simplified)
init(*ui.frame_pool);
init(*ui.persistent);

persistent: Allocator = ui_persistent_allocator();
ui.caches.allocator       = persistent;
ui.window_order.allocator = persistent;
ui.parent_stack.allocator = persistent;
ui.quads.allocator        = persistent;

// reserved up front, reused every frame
table_resize(*ui.caches, 4096);
array_reserve(*ui.parent_stack, 128);
array_reserve(*ui.quads, 16384);
DONE);

// The tree is intrusive

CODE_NODE_LINKS :: #run src(#string DONE
// [[Core.jai|UI_Node :: struct {]] (the tree part)
UI_Node :: struct {
  key: u64;

  parent: *UI_Node;   // the node that contains me
  first:  *UI_Node;   // my first child
  last:   *UI_Node;   // my last child
  next:   *UI_Node;   // my next sibling
  prev:   *UI_Node;   // my previous sibling

  ...                 // text, flags, params, rects
}
DONE);

CODE_INTRUSIVE :: #run src(#string DONE
// [[Core.jai|node.parent = parent;]], ui_node_keyed: link the new node in
node.parent = parent;
if parent.last {
  parent.last.next = node;
  node.prev        = parent.last;
  parent.last      = node;
} else {
  parent.first = node;
  parent.last  = node;
}
DONE);

CODE_WALK :: #run src(#string DONE
// [[Core.jai|ui_emit_children :: (node: *UI_Node, alpha: float, disabled: bool) {]], ui_emit_children
child: *UI_Node = node.first;
while child {
  ui_emit(child);
  child = child.next;
}
DONE);

// The root is the screen

CODE_ROOT :: #run src(#string DONE
// [[Core.jai|root := ui_allocate_node();]], ui_begin
root: *UI_Node = ui_allocate_node();
root.key  = UI_ROOT_KEY;
root.rect = .{ .{ 0, 0 }, input.screen_size };
root.clip = root.rect;
ui.root = root;

ui_push_parent(root);  // everything built this frame goes under it
DONE);

// Building the tree

CODE_MINI_UI :: #run src(#string DONE
// [[Presentation.jai|mini_settings_ui :: (]], mini_settings_ui
panel: *UI_Node = ui_node("Settings", 0, panel_params);
ui_push_parent(panel);
  ui_label("Audio");
  ui_slider("Volume", *volume, 0.0, 1.0);
  ui_checkbox("Mute", *mute);
  ui_row_begin("buttons");
    ui_button("Apply");   // <- the stack on the right is from here
    ui_button("Cancel");
  ui_row_end();
ui_pop_parent();
DONE);

CODE_STACK :: #run src(#string DONE
// [[Core.jai|ui_push_parent :: (node: *UI_Node) {]] (simplified)
ui_push_parent :: (node: *UI_Node) {
  array_add(*ui.parent_stack, node);
}
ui_pop_parent :: () -> *UI_Node {
  node: *UI_Node = ui.parent_stack[ui.parent_stack.count - 1];
  ui.parent_stack.count -= 1;
  return node;
}
DONE);

CODE_DEFER :: #run src(#string DONE
// [[Presentation.jai|defer_panel :: ()]] (simplified)
defer_panel :: () {
  panel: *UI_Node = ui_node("Defer panel", 0, panel_params);
  ui_push_parent(panel);
  defer ui_pop_parent();   // runs when this scope ends

  ui_label("Always shown");
  if !show_more {
    return;                // still popped
  }
  ui_button("Only with 'show more'");
}
DONE);

CODE_DEFER_LOOP :: #run src(#string DONE
// fzac, base/Core.h (simplified)
#define defer_loop(begin, end) \
  for (u32 _i_ = ((begin), 0); !_i_; _i_ += 1, (end))

// fzac, modules/UI/UI_Widgets.c
#define ui_window(text, x, y, w, h) \
  defer_loop(ui_window_begin((text), (x), (y), (w), (h)), ui_window_end())

ui_window("Settings", 20, 20, 300, 200) {
  ui_button("Apply");
}
DONE);

// Keys

CODE_KEY_SAME_TEXT :: #run src(#string DONE
// [[Presentation.jai|first:  UI_Signal = ui_button("Save");]], slide_keys
ui_row_begin("row");
  first:  UI_Signal = ui_button("Save");
  second: UI_Signal = ui_button("Save");
ui_row_end();
DONE);

CODE_KEY_LOOP :: #run src(#string DONE
// [[Presentation.jai|item: UI_Signal = ui_button("Item");]], slide_keys
for i: 0..2 {
  ui_push_id(i);
  item: UI_Signal = ui_button("Item");
  ui_pop_id();
}
DONE);

// Layout

CODE_SIZES :: #run src(#string DONE
// [[Core.jai|UI_Size_Kind :: enum u8 {]]
UI_Size_Kind :: enum {
  PIXELS;           // fixed
  PARENT_FRACTION;  // share of the space still free
  PARENT_RATIO;     // share of the parent's whole size
  TEXT;             // text size + some padding
}
DONE);

CODE_PLACE :: #run src(#string DONE
// [[Core.jai|ui_node_keyed :: (key: u64, label: string, flags: UI_Node_Flags, params: UI_Params, loc: Source_Code_Location) -> *UI_Node {]], ui_node_keyed (simplified)
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
DONE);

// Single-pass layout and its cost

CODE_SHRINK :: #run src(#string DONE
// [[Widgets.jai|ui_group_begin :: (]] (simplified)
ui_group_begin :: (title: string) {
  params.size.height = .{ kind = .PIXELS,
                          value = ui_provisional_panel_height(ui_parent()) };
  panel: *UI_Node = ui_node(title, "group", 0, params);
  ui_push_parent(panel);
}

// [[Widgets.jai|ui_group_end :: ()]]
ui_group_end :: () {
  ui_shrink_panel_to_content(ui_pop_parent());
}

// [[Widgets.jai|ui_shrink_panel_to_content :: (]] (simplified)
height: float = panel.cursor.y - panel.inner.pos.y + 2 * padding;
panel.parent.cursor.y += height - panel.rect.size.y;  // give the space back
panel.rect.size.y = height;
DONE);

// Behaviour from flags

CODE_FLAGS ::#run src(#string DONE
// [[Core.jai|UI_Node_Flags :: enum_flags u32 {]]
UI_Node_Flags :: enum_flags {
  CLICKABLE;  HOVERABLE;  DRAGGABLE;
  RESIZABLE;  SCROLL_Y;   FLOATING;
  DRAW_TEXT;  DRAW_LINES;
  TEXT_CENTER_X;  TEXT_CENTER_Y;  ...
}
DONE);

// Style: params per node

CODE_PARAMS :: #run src(#string DONE
// [[Core.jai|UI_Params :: struct {]] (simplified)
UI_Params :: struct {
  size:    UI_Box_Size;
  padding: float;
  text:    string;

  background: UI_Color_Set;   // normal, hover, active
  border:     UI_Color_Set;
  foreground: UI_Color_Set;
  border_thickness: float;
  corner_radius:    float;
  ...
}

// [[Core.jai|node.params = params;]], ui_node_keyed: a copy, per node
node.params = params;
DONE);

CODE_STYLE :: #run src(#string DONE
// [[Presentation.jai|params.background    = .{ normal = style_color };]], one node
params.background    = .{ normal = style_color };
params.corner_radius = style_radius;
ui_node("styled node", flags, params);

// [[Presentation.jai|saved: UI_Theme = ui_theme;]], one window
saved: UI_Theme = ui_theme;
ui_theme = other_theme;   // nodes built from here copy these colours
ui_window_begin("Another theme", ...);
  ui_button("A button");
ui_window_end();
ui_theme = saved;         // nodes already built keep theirs

// [[Presentation.jai|ui_set_theme(ui_theme_from_palette(palette));]], everything
ui_set_theme(ui_theme_from_palette(palette));
DONE);

// Depth instead of sorting

CODE_DEPTH :: #run src(#string DONE
// [[Core.jai|node.depth  = ui.next_depth;]], ui_node_keyed
node.depth = ui.next_depth;
ui.next_depth -= UI_DEPTH_EPSILON;   // the next node is a bit more in front

// [[Core.jai|if over && hoverable && node.depth <= ui.hot_depth {]], ui_interact
if over && hoverable && node.depth <= ui.hot_depth {
  ui.hot_key   = node.key;           // the front-most so far wins
  ui.hot_depth = node.depth;
}
DONE);

// Signals

CODE_SIGNAL_CLASSIC ::#run src(#string DONE
// Dear ImGui (C++)
if (ImGui::Button("Save")) {
  save();
}
if (ImGui::IsItemHovered()) {
  ImGui::SetTooltip("Writes to disk");
}
DONE);

CODE_SIGNAL_OURS :: #run src(#string DONE
// [[Widgets.jai|ui_button :: (]], every widget returns a UI_Signal
signal: UI_Signal = ui_button("Save");
if signal.clicked {
  save();
}
if signal.hovered {
  ui_set_tooltip("Writes to disk");
}
DONE);

CODE_SIGNAL_REACT :: #run src(#string DONE
// [[Presentation.jai|card_demo :: ()]], card_demo
card: *UI_Node = ui_node("card", flags, params);
signal: UI_Signal = ui_signal_from_node(card);

if signal.hovered {
  ui_set_tooltip("Drag me around");
}
if signal.held {
  card_position += ui.input.mouse_delta;
}
DONE);

// Rendering

CODE_QUAD :: #run src(#string DONE
// [[Core.jai|UI_Quad :: struct {]] (simplified)
UI_Quad :: struct {
  rect:  UI_Rect;    // where
  clip:  UI_Rect;    // what part is visible
  color: Vector4;
  border_thickness: float;
  corner_radius:    float;
  rotation:         float;
  texture: *Texture;  // font texture for letters
}
DONE);

CODE_DRAW :: #run src(#string DONE
// [[Imgui_Backend.jai|ui_draw :: () {]] (simplified)
ui_draw :: () {
  quads: [] UI_Quad = ui_quads();
  for quad: quads {
    r_push_clip_rect(quad.clip);
    r_draw_screen_quad(quad.rect, quad.color, quad.texture,
                       quad.corner_radius, quad.rotation);
    r_pop_clip_rect();
  }
}
DONE);

CODE_LINE :: #run src(#string DONE
// [[Core.jai|ui_push_line :: (quads: *[..] UI_Quad, start: Vector2, end: Vector2, width: float, clip: UI_Rect, color: Vector4) {]], ui_push_line (simplified)
delta:  Vector2 = end - start;
length: float   = sqrt(delta.x * delta.x + delta.y * delta.y);

quad: UI_Quad;
quad.rect.size = .{ length, line_width };
quad.rect.pos  = (start + end) * 0.5 - quad.rect.size * 0.5;
quad.rotation  = atan2(delta.y, delta.x);
DONE);

// The cache

CODE_CACHE :: #run src(#string DONE
// [[Core.jai|ui_cache_get :: (key: u64)]]
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

// [[Core.jai|ui_purge_caches :: ()]], every 60 frames:
// free every entry not touched in the last 240 frames
DONE);

// Who owns the state?

CODE_OWN_USER :: #run src(#string DONE
// [[Presentation.jai|ui_checkbox("Mute", *own_mute);]], slide_state_ownership
mute: bool = false;            // your variable
ui_checkbox("Mute", *mute);    // reads and writes it

if ui_collapsing_header("Open / close me") {
  // open or closed? the library remembers, by key
}

ui_list_box("Fruits", *picked, fruits, 4);
// picked is yours, the scroll position is the library's
DONE);

// Animation

CODE_ANIMATION :: #run src(#string DONE
// [[Core.jai|ui_animation_t :: (dt: float) -> float {]]
t: float = 1.0 - exp(-dt * speed);   // fraction to move this frame

// [[Core.jai|ui_emit :: (node: *UI_Node, parent_alpha: float = 1.0, parent_disabled := false) {]], ui_emit: every node's colour, in its cache
target: Vector4 = ifx hovered then hover_color else normal_color;
cache.background += (target - cache.background) * t;
DONE);

// Animated layout

CODE_DISCLOSURE :: #run src(#string DONE
// [[Widgets.jai|ui_collapsing_header :: (id: string, default_open := true, disabled := false, loc := #caller_location) -> bool {]], ui_collapsing_header (simplified)
target: float = ifx cache.expanded then 1.0 else 0.0;
cache.open_t += (target - cache.open_t) * t;

body_height: float = cache.full_height * cache.open_t;

// [[Widgets.jai|ui_collapsing_end :: () {]], ui_collapsing_end
cache.full_height = height_of_contents;  // for next frame
DONE);

// The one-frame delay

CODE_DELAY :: #run src(#string DONE
// [[Core.jai|over := under && node.panel == ui.mouse_panel;]], ui_interact (simplified)
if under && node.depth < ui.mouse_panel_depth {
  ui.mouse_panel_next  = node.panel;   // front-most window under the mouse, this frame
  ui.mouse_panel_depth = node.depth;
}
over: bool = under && node.panel == ui.mouse_panel;   // decided last frame

// [[Core.jai|ui.mouse_panel = ui.mouse_panel_next;]], ui_end
ui.mouse_panel = ui.mouse_panel_next;   // ready for next frame
DONE);

// Widgets are small

CODE_BUTTON ::#run src(#string DONE
// [[Widgets.jai|ui_button :: (id: string, disabled := false, width_frac := 0.0, on_press := UI_ACTIVATE_ON_PRESS, loc := #caller_location) -> UI_Signal {]] (simplified)
ui_button :: (text: string) -> UI_Signal {
  params: UI_Params = ui_box_params(ui_theme.button, ui_theme.button_border);
  params.text        = text;
  params.size.width  = .{ kind = .TEXT, value = 16 };
  params.size.height = .{ kind = .TEXT, value = 8 };

  flags: UI_Node_Flags = .DRAW_TEXT | .TEXT_CENTER_Y | .HOVERABLE | .CLICKABLE;
  node: *UI_Node = ui_node(text, flags, params);
  return ui_signal_from_node(node);
}
DONE);

CODE_CHECKBOX :: #run src(#string DONE
// [[Widgets.jai|ui_checkbox :: (id: string, value: *bool, disabled := false, loc := #caller_location) -> bool {]] (simplified)
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
DONE);

CODE_SLIDER :: #run src(#string DONE
// [[Widgets.jai|ui_slider :: (id: string, value: *$T, min_value: T, max_value: T, disabled := false, loc := #caller_location) -> bool {]] (simplified)
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
DONE);

// Custom widgets

CODE_POOL_WIDGET :: #run src(#string DONE
// [[Custom_Widgets.jai|ui_flat_pool :: (id: string, pool: *Flat_Pool, loc := #caller_location) {]] (simplified)
ui_flat_pool :: (name: string, pool: *Flat_Pool) {
  panel: *UI_Node = ui_node(name, "panel", 0, bordered_params);
  ui_push_parent(panel);
    ui_label(tprint("%: used %, committed %, reserved %", ...));
    pool_bar(name, "reserve",   used, committed, reserved);
    pool_bar(name, "committed", used, committed, committed);
  ui_pop_parent();
}

// [[Custom_Widgets.jai|pool_bar ::(id: string, salt: string, used: s64, committed: s64, total: s64, overlay: string, used_tip: string, free_tip: string, uncommitted_tip: string, loc: Source_Code_Location) {]] (simplified)
pool_bar :: (name: string, salt: string, used: int, committed: int, total: int) {
  track: *UI_Node = ui_node(name, salt, 0, track_params);
  ui_push_parent(track);
    segment(0, 0.0,         used_x,      used_color,  "used");
    segment(1, used_x,      committed_x, free_color,  "committed, free");
    segment(2, committed_x, width,       empty_color, "reserved only");
  ui_pop_parent();
}
DONE);

// What user code looks like

CODE_USER :: #run src(#string DONE
// [[Presentation.jai|if ui_button("Click me").clicked {]], slide_live_demo
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
DONE);

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
