presentation :: () {
  ui_window_begin("Flying Rat - Immediate-mode UI", null, 60, 40, 960, 620, .NO_CLOSE, initial_dock = .FULL);
  slides_begin("flying_rat", *current_slide);
    if slide("Title")                                         slide_title();
    if slide("Topics")                                        slide_topics();

    // Part 1: What and why
    stop();
    if slide("Retained vs immediate")                         slide_retained_vs_immediate();

    // Part 2: The frame
    if slide("Part 1: One frame")                             slide_one_frame();
    if slide("UI_Context")                                    slide_context();
    stop();
    if slide("Part 2, as code")                               slide_recap_2();

    // Part 3: Building the tree
    if slide("The node")                                      slide_anatomy();
    if slide("Keys")                                          slide_keys();
    if slide("The tree is intrusive")                         slide_intrusive();
    if slide("Building the tree")                             slide_tree();
    stop();
    if slide("Part 3, as code")                               slide_recap_3();

    // Part 4: From tree to screen
    if slide("ui_node: where it all happens")                 slide_ui_node();
    if slide("Layout")                                        slide_layout();
    if slide("Depth instead of sorting")                      slide_depth();
    if slide("Signals")                                       slide_signals();
    if slide("Rendering")                                     slide_rendering();
    stop();
    if slide("Part 4, as code")                               slide_recap_4();

    // Part 5: State across frames
    if slide("Why keep state between frames?")                slide_why_state();
    if slide("The cache")                                     slide_cache();
    if slide("Animation")                                     slide_animation();
    if slide("Windows and z-order")                           slide_windows();
    stop();
    if slide("Part 5, as code")                               slide_recap_5();

    // Part 6: Building on it
    if slide("Widgets are small")                             slide_composition();
    if slide("Style: params per node")                        slide_style();
    stop();
    if slide("Part 6, as code")                               slide_recap_6();

    // Part 7: Wrap-up
    if slide("Demo and source")                               slide_demo();
    if slide("Build your own")                                slide_build_your_own();
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

  stops:      [16] int;   // slides << and >> jump to (the part recaps), filled by stop()
  stop_count: int;
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

// Marks the next slide as a stop for the << and >> buttons: the "Part N, as code" recaps.
stop :: () {
  if slides.stop_count < slides.stops.count {
    slides.stops[slides.stop_count] = slides.count;
    slides.stop_count += 1;
  }
}

// The slide << goes to: the closest stop before this slide, or the first slide.
previous_stop :: (current: int) -> int {
  target := 0;
  for i: 0..slides.stop_count - 1 {
    if slides.stops[i] < current  target = slides.stops[i];
  }
  return target;
}

// The slide >> goes to: the next stop after this slide, or the last slide.
next_stop :: (current: int, last: int) -> int {
  for i: 0..slides.stop_count - 1 {
    if slides.stops[i] > current  return slides.stops[i];
  }
  return last;
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
    if bar_button("first", "<<", jump_width, slides.selected.* == 0)  slides.selected.* = previous_stop(slides.selected.*);
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
    if bar_button("last", ">>", jump_width, slides.selected.* >= last)  slides.selected.* = next_stop(slides.selected.*, last);
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

// The height left in the current column, down to the bottom of the slide. For
// widgets that use all the space they get, like the tree canvases.
column_height_left :: () -> float {
  return max(ui.metrics.line_height * 12.0, ui_provisional_panel_height(ui_parent()) - slide_gap());
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
      for < i: 0..depth-1 {
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
  title("Building an immediate mode UI from scratch");
  ui_spacing(ui.metrics.line_height * 2.0);
  point("Francisco Zacarias, 1st December 2026");
}

slide_topics :: () {
  title("Topics");
  ui_spacing(ui.metrics.line_height * 2.0);

  heading("1. Immediate vs retained");
  ui_spacing();
  heading("2. The frame: input in, quads out");
  ui_spacing();
  heading("3. Nodes and the tree");
  ui_spacing();
  heading("4. From tree to screen: layout, input, drawing");
  ui_spacing();
  heading("5. State across frames");
  ui_spacing();
  heading("6. Widgets and style");
  ui_spacing();
  heading("7. Wrap-up");
}

// ---------------------------------------------------------------------------
// Part 1: What and why
// ---------------------------------------------------------------------------

Rvi_Settings :: struct {
  volume: float = 0.5;
  mute:   bool  = false;
}
rvi_settings: Rvi_Settings;

slide_retained_vs_immediate :: () {
  title("Retained vs immediate");
  point("Retained: widgets are objects that hold a copy of your data");
  point("Immediate: widgets are function calls on your data, every frame");
  ui_spacing();
  split_begin("rvi");
    heading("Retained (a typical toolkit)");
    code(CODE_RETAINED);
  split_next();
    heading("Immediate");
    code(CODE_IMMEDIATE);
    ui_spacing();
    heading("Live: the result, the same for both");
    ui_checkbox("Mute", *rvi_settings.mute);
    ui_slider("Volume", *rvi_settings.volume, 0.0, 1.0, disabled = rvi_settings.mute);
    if ui_button("Reset").clicked {
      rvi_settings = .{};
    }
  split_end();
}

// The data behind the real widgets on every "Part N, as code" slide.
recap_volume  := 0.5;
recap_mute    := false;
recap_applied := 0;

// ---------------------------------------------------------------------------
// Part 2: The frame
// ---------------------------------------------------------------------------

input_presses := 0;
input_typed: UI_Text_Buffer(48);

measure_sample: UI_Text_Buffer(48);

slide_one_frame :: () {
  title("Part 1: One frame");
  split_begin("frame", 0.55);
    code(CODE_MAIN_LOOP);
    point("ui_begin: take the input, start a new tree");
    point("ui_end: output quads for the app to draw");
    point("The UI never touches the GPU, the OS or the font system");
    ui_spacing();
    heading("The app gives the UI its letters");
    code(CODE_APP_PROVIDES);
    point("The UI measures text itself: it adds up the advances");
  split_next();
    heading("Live: this frame's UI_Input  (click, scroll, type)");
    if ui.input.mouse_pressed[0] {
      input_presses += 1;
    }
    if ui.input.text {
      if input_typed.count + ui.input.text.count > input_typed.data.count {
        input_typed.count = 0;
      }
      memcpy(input_typed.data.data + input_typed.count, ui.input.text.data, ui.input.text.count);
      input_typed.count += ui.input.text.count;
    }
    value("mouse",   tprint("mouse_pos       %", ui.input.mouse_pos));
    value("down",    tprint("mouse_down      %", ui.input.mouse_down[0]));
    value("pressed", tprint("mouse_pressed   % times so far", input_presses));
    value("scroll",  tprint("scroll          %", ui.input.scroll));
    value("text",    tprint("text            \"%\"", ui_text(*input_typed)));
    value("dt",      tprint("dt              % ms", formatFloat(ui.input.dt * 1000.0, trailing_width = 2)));
    ui_spacing();

    heading("Live: text measured by the UI  (try the font size in the bottom bar)");
    if !measure_sample.count  ui_text_set(*measure_sample, "Hello, Flying Rat!");
    ui_text_input("measure_sample", *measure_sample, "type something");
    width, height := ui_measure_text(ui_text(*measure_sample));
    value("measured", tprint("width %, height %", cast(int) width, cast(int) height));
  split_end();
}

ctx_text: UI_Text_Buffer(64);
ctx_canvas: Tree_Canvas;

// The context's fields as invisible, zero-size nodes, only so the tree canvas can draw them.
ctx_map :: () -> *UI_Node {
  ctx := ctx_field("UI_Context", "ui");
  ui_push_parent(ctx);
    frame := ctx_field("frame_pool", "frame memory");
    ui_push_parent(frame);
      ctx_field("nodes", tprint("% this frame", ui.stats.nodes));
    ui_pop_parent();
    ctx_field("root", "the screen node");
    ctx_field("parent_stack", tprint("% deep, right here", ui.parent_stack.count));
    persistent := ctx_field("persistent", "kept between frames");
    ui_push_parent(persistent);
      ctx_field("caches", tprint("% entries", ui.caches.count));
      ctx_field("window_order", tprint("% windows", ui.window_order.count));
    ui_pop_parent();
    ctx_field("hot_key",    hex(ui.hover_key));
    ctx_field("active_key", hex(ui.active_key));
    ctx_field("focus_key",  hex(ui.keyboard_focus_key));
    ctx_field("quads", tprint("% (output)", ui.stats.quads));
  ui_pop_parent();
  return ctx;
}

ctx_field :: (name: string, text: string, loc := #caller_location) -> *UI_Node {
  params: UI_Params;
  params.name        = name;
  params.text        = text;
  params.animate     = false;
  params.size.width  = .{ kind = .PIXELS, value = 0.0 };
  params.size.height = .{ kind = .PIXELS, value = 0.0 };
  return ui_node(name, 0, params, loc);
}

slide_context :: () {
  title("UI_Context: everything in one place");
  split_begin("ctx", 0.45);
    code(CODE_CONTEXT);
    point("The library's internal state: one global");
    point("ui_begin / ui_end work on it, every widget function uses it");
  split_next();
    heading("Change the keys");
    ui_text_input("ctx_text", *ctx_text, "click here to take keyboard focus");
    ui_button("Hold me");
    sub("while held, active_key is this button");
    ui_spacing();
    heading("Live: what it holds right now  (drag, wheel to zoom)");
    ctx_root := ctx_map();
    canvas_params: UI_Params;
    canvas_params.name        = "Context canvas";
    canvas_params.spacing     = UI_STACK_SPACING;
    canvas_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    canvas_params.size.height = .{ kind = .PIXELS, value = column_height_left() };
    ui_push_parent(ui_node("ctx_canvas_box", 0, canvas_params));
      ui_tree_canvas("ctx", *ctx_canvas, ctx_root, live = true);
    ui_pop_parent();
  split_end();
}

slide_recap_2 :: () {
  title("Part 2, as code: the frame");
  split_begin("recap_2", 0.6);
    heading("The library (mock)");
    code(MOCK_2, "A mock: the shape of it, not the real code");
  split_next();
    heading("The real widgets");
    ui_slider("Volume", *recap_volume, 0.0, 1.0);
    ui_checkbox("Mute", *recap_mute);
    if ui_button("Apply").clicked {
      recap_applied += 1;
    }
    value("recap_applied", tprint("applied % times", recap_applied));
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

first_clickable := true;
first_hoverable := true;
first_draw_text := true;
first_floating  := false;

slide_anatomy :: () {
  title("The node: one generic primitive");
  split_begin("anatomy", 0.45);
    point("There is no Button, Slider or Window type");
    point("A node is a rectangle, maybe some text, and flags for behaviour");
    sub("a widget is just a function that creates nodes");
    code(CODE_NODE);
    point("Each flag is implemented once, in the core; widgets just pick flags");
    code(CODE_FLAGS);
  split_next();
    heading("Live: one parent, a few children  (try children wider than it)");
    ui_slider("padding",      *anatomy_padding,  0.0, 40.0);
    ui_slider("children",     *anatomy_children, 1, 8);
    ui_slider("child width",  *anatomy_width,    40.0, 900.0);
    colored_checkbox("rect:   position and size",         RECT_COLOR,   *show_rect);
    colored_checkbox("inner:  rect minus padding",        INNER_COLOR,  *show_inner);
    colored_checkbox("clip:   the visible part",          CLIP_COLOR,   *show_clip);
    colored_checkbox("cursor: where the next child goes", CURSOR_COLOR, *show_cursor);
    ui_spacing();
    heading("Live: Behaviour and layout");
    ui_row_begin("first_child_flags", spacing = ui.metrics.line_height);
      ui_checkbox("CLICKABLE", *first_clickable);
      ui_checkbox("HOVERABLE", *first_hoverable);
      ui_checkbox("DRAW_TEXT", *first_draw_text);
      ui_checkbox("FLOATING",  *first_floating);
    ui_row_end();
    ui_spacing();

    parent_params := ui_box_params(ui_theme.window_background, ui_theme.window_border);
    parent_params.name        = "parent";
    parent_params.padding     = anatomy_padding;
    parent_params.spacing     = 6.0;
    parent_params.size.width  = .{ kind = .PARENT_RATIO, value = 0.75 };
    parent_params.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height * 13.0 };
    parent := ui_node("anatomy_parent", 0, parent_params);
    ui_push_parent(parent);
      first_child: *UI_Node;
      for 0..anatomy_children - 1 {
        child := ui_box_params(ui_theme.button, ui_theme.button_border);
        child.name        = "child";
        child.text        = tprint("child %", it);
        child.foreground  = ui_theme.text;
        child.size.width  = .{ kind = .PIXELS, value = anatomy_width };
        child.size.height = .{ kind = .PIXELS, value = ui_row_height() };

        flags: UI_Node_Flags = .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y;
        if it == 0 {
          flags = .TEXT_CENTER_X | .TEXT_CENTER_Y;
          if first_clickable {
            flags |= .CLICKABLE;
          }
          if first_hoverable {
            flags |= .HOVERABLE;
          }
          if first_draw_text {
            flags |= .DRAW_TEXT;
          }
          if first_floating {
            flags |= .FLOATING;
            child.offset = .{ anatomy_padding + 40.0, ui_row_height() * 4.0 };
          }
        }
        node := ui_node("anatomy_child", "c", it, flags, child);
        if it == 0  first_child = node;
      }
    ui_pop_parent();

    signal := ui_signal_from_node(first_child);
    value("first_signal", tprint("first child:  hovered %   held %", signal.hovered, signal.held));
    sub("FLOATING: leaves the layout, placed at an offset");

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

slide_keys :: () {
  title("Keys");
  split_begin("keys");
    point("Each node gets a key when it is created:");
    point("key = hash( parent's key, text, call site )");
    ui_spacing();
    heading("Same text, different lines: different keys");
    code(CODE_KEY_SAME_TEXT);
    ui_spacing();
    heading("Conflict: same text, same line, in a loop");
    point("Fix: push an id, so the index goes into the hash");
    code(CODE_KEY_LOOP);
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
    heading("One node and its five links");
    star_diagram();
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

tree_volume    := 0.6;
tree_mute      := false;
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
    point("The root: one node, the size of the screen");
    code(CODE_ROOT);
    point("A parent stack: a new node goes under the top one");
    code(CODE_MINI_UI);
  split_next();
    heading("Live: that code");
    mini := mini_settings_ui();
    ui_spacing();
    heading("The parent stack at the marked line (top first)");
    for < i: 0..stack_snapshot_count - 1 {
      ui_push_id(i);
        value("entry", tprint("[%]  %", i, stack_snapshot[i]));
      ui_pop_id();
    }
    ui_spacing();
    heading("The tree it builds  (drag, wheel to zoom)");
    canvas_params: UI_Params;
    canvas_params.name        = "Tree canvas";
    canvas_params.spacing     = UI_STACK_SPACING;
    canvas_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    canvas_params.size.height = .{ kind = .PIXELS, value = column_height_left() };
    ui_push_parent(ui_node("mini_canvas_box", 0, canvas_params));
      ui_tree_canvas("mini", *mini_canvas, mini, live = true);
    ui_pop_parent();
  split_end();
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

slide_recap_3 :: () {
  title("Part 3, as code: the tree");
  split_begin("recap_3", 0.6);
    heading("The library (mock)");
    code(MOCK_3, "A mock: the shape of it, not the real code");
  split_next();
    heading("The real widgets");
    ui_slider("Volume", *recap_volume, 0.0, 1.0);
    ui_checkbox("Mute", *recap_mute);
    if ui_button("Apply").clicked {
      recap_applied += 1;
    }
    value("recap_applied", tprint("applied % times", recap_applied));
  split_end();
}

// ---------------------------------------------------------------------------
// Part 4: From tree to screen
// ---------------------------------------------------------------------------

slide_ui_node :: () {
  title("ui_node: the core building function");
  point("Every node on screen went through this one function");
  split_begin("ui_node", 0.58);
    code(CODE_UI_NODE);
  split_next();
    heading("Each step, and where it is explained");
    point("1. key            Keys");
    point("2. parent         Building the tree");
    point("3. allocate       a new node every frame");
    point("4. copy params    Style");
    point("5. depth          Depth");
    point("6. link           The tree is intrusive");
    point("7. size, place    Layout");
    point("8. hit-test       Signals");
  split_end();
}

layout_ratio := 0.3;

slide_layout :: () {
  title("Layout: size kinds and axis");
  split_begin("lay", 0.5);
    point("Each node: a size kind per axis");
    code(CODE_SIZES);
    point("Each parent: an axis. Y stacks its children, X puts them side by side");
    point("Split, then split again:");
    code(CODE_LAYOUT_SPLIT);
  split_next();
    heading("Live: that code");
    ui_slider("left: PARENT_RATIO", *layout_ratio, 0.1, 0.8);
    ui_spacing();
    layout_split_demo();
  split_end();
}

// Must match CODE_LAYOUT_SPLIT: a row split in two, its right side split in two again.
layout_split_demo :: () {
  row: UI_Params = ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  row.name        = "row";
  row.axis        = .X;
  row.padding     = 6.0;
  row.spacing     = 6.0;
  row.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height * 16.0 };
  ui_push_parent(ui_node("row", 0, row));

    left: UI_Params = ui_box_params(ui_theme.button, ui_theme.button_border);
    left.name        = "left";
    left.text        = tprint("RATIO %", formatFloat(layout_ratio, trailing_width = 2));
    left.foreground  = ui_theme.text;
    left.size.width  = .{ kind = .PARENT_RATIO, value = layout_ratio };
    left.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
    ui_node("left", .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, left);

    column: UI_Params;
    column.name        = "column";
    column.axis        = .Y;
    column.spacing     = 6.0;
    column.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    column.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
    ui_push_parent(ui_node("column", 0, column));

      top: UI_Params = ui_box_params(ui_theme.button, ui_theme.button_border);
      top.name        = "top";
      top.text        = "FRACTION 0.5";
      top.foreground  = ui_theme.text;
      top.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
      top.size.height = .{ kind = .PARENT_FRACTION, value = 0.5 };
      ui_node("top", .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, top);

      bottom: UI_Params = ui_box_params(ui_theme.button, ui_theme.button_border);
      bottom.name        = "bottom";
      bottom.text        = "FRACTION 1.0  (the rest)";
      bottom.foreground  = ui_theme.text;
      bottom.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
      bottom.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
      ui_node("bottom", .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, bottom);

    ui_pop_parent();
  ui_pop_parent();
}

depth_reverse := false;

slide_depth :: () {
  title("Depth instead of sorting");
  split_begin("depth", 0.5);
    point("Every node gets a depth when it is created: smaller = in front");
    point("Built later = in front, so children are in front of their parent");
    code(CODE_DEPTH);
    point("Two uses, and no node is ever sorted:");
    sub("input: of the nodes under the mouse, the smallest depth wins");
    sub("drawing: back to front");
  split_next();
    heading("Live: hover where they overlap");
    ui_checkbox("build them in reverse order", *depth_reverse);
    area_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
    area_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    area_params.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height * 12.0 };
    area := ui_node("depth_area", 0, area_params);
    ui_push_parent(area);
      a, b, c: *UI_Node;
      if depth_reverse {
        a, b, c = depth_build_cba();
      } else {
        a, b, c = depth_build_abc();
      }
    ui_pop_parent();
    heading("The code that just ran");
    if depth_reverse {
      code(CODE_DEPTH_CBA);
    } else {
      code(CODE_DEPTH_ABC);
    }
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

// Must match CODE_DEPTH_ABC.
depth_build_abc :: () -> *UI_Node, *UI_Node, *UI_Node {
  a: *UI_Node = depth_box("A", 0, .{ 20,  10 });   // built first: at the back
  b: *UI_Node = depth_box("B", 1, .{ 100, 50 });
  c: *UI_Node = depth_box("C", 2, .{ 180, 90 });   // built last: in front
  return a, b, c;
}

// Must match CODE_DEPTH_CBA.
depth_build_cba :: () -> *UI_Node, *UI_Node, *UI_Node {
  c: *UI_Node = depth_box("C", 2, .{ 180, 90 });   // built first: at the back
  b: *UI_Node = depth_box("B", 1, .{ 100, 50 });
  a: *UI_Node = depth_box("A", 0, .{ 20,  10 });   // built last: in front
  return a, b, c;
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

sig_saves := 0;

slide_signals :: () {
  title("Signals");
  split_begin("sig");
    point("A signal: what happened to a node this frame");
    code(CODE_SIGNAL_STRUCT);
    ui_spacing();
    heading("Dear ImGui (C++): a bool, then ask about the 'last item'");
    code(CODE_SIGNAL_CLASSIC);
    ui_spacing();
    heading("Ours: every widget returns its signal");
    code(CODE_SIGNAL_OURS);
    point("ui_node hit-tests as the node is created; the front-most wins");
  split_next();
    heading("Live: that code");
    signal: UI_Signal = ui_button("Save");
    if signal.clicked {
      sig_saves += 1;
    }
    if signal.hovered {
      ui_set_tooltip("Writes to disk");
    }
    value("sig_saves", tprint("saved % time(s)", sig_saves));
    ui_spacing(ui.metrics.line_height * 2.0);
    signal_box_demo();
  split_end();
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

slide_rendering :: () {
  title("Rendering: the UI outputs quads, your renderer draws them");
  split_begin("rend");
    code(CODE_QUAD);
    code(CODE_DRAW);
    point("Text: one quad per letter, from a font texture");
    point("Fonts and textures are handles: the UI passes them through, the app casts them back");
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
  split_end();
}

slide_recap_4 :: () {
  title("Part 4, as code: from tree to screen");
  split_begin("recap_4", 0.6);
    heading("The library (mock)");
    code(MOCK_4, "A mock: the shape of it, not the real code");
  split_next();
    heading("The real widgets");
    ui_slider("Volume", *recap_volume, 0.0, 1.0);
    ui_checkbox("Mute", *recap_mute);
    if ui_button("Apply").clicked {
      recap_applied += 1;
    }
    value("recap_applied", tprint("applied % times", recap_applied));
  split_end();
}

// ---------------------------------------------------------------------------
// Part 5: State across frames
// ---------------------------------------------------------------------------

why_pick := 4;

slide_why_state :: () {
  title("Why keep state between frames?");
  split_begin("why_state", 0.5);
    point("The tree is rebuilt every frame: last frame's nodes are gone");
    point("Some state must survive: scroll, open / closed, text cursor, window position");
    ui_spacing();
    heading("Who keeps it");
    point("Your data: you pass it to the widget with a pointer");
    point("Widget state: the UI keeps it per widget, found by its key");
    point("Interaction: the context keeps it: hovered, pressed, focused");
    code(CODE_OWN_USER);
  split_next();
    heading("Open / closed: kept by the UI");
    if ui_collapsing_header("Click me") {
      ui_label("The UI remembered this was open.");
    }
    ui_collapsing_end();
    ui_spacing();
    heading("Selection: ours. Scroll: the UI's  (scroll, change slides, come back)");
    ui_list_box("Fruits##why", *why_pick, own_items, 4);
  split_end();
}

own_items := string.[ "Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape", "Honeydew", "Kiwi", "Lemon", "Mango" ];

cache_spawn := false;
cache_plot: Sampler;

slide_cache :: () {
  title("The cache");
  split_begin("cache");
    point("Why: nodes are rebuilt every frame, but some widget state must survive");
    point("Who gets an entry: a node with state to keep, found by its key");
    sub("a colour in transition, scroll, open / closed, windows, text fields");
    point("A node at rest has nothing to keep: no entry");
    point(tprint("Cleanup: entries unused for % frames are freed", UI_CACHE_TTL_FRAMES));
    code(CODE_CACHE);
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
    point("1. On: 120 buttons, no new entries");
    point("2. Sweep the mouse across them: an entry per button while its colour moves");
    point(tprint("3. Leave them: once settled, freed % frames later", UI_CACHE_TTL_FRAMES));
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

slide_animation :: () {
  title("Animation");
  split_begin("anim");
    point("Animation: state interpolated between frames, kept in the cache");
    point("Colours and sizes, the same way");
    point("The speed is one setting in the theme: change it at any time");
    code(CODE_ANIMATION);
  split_next();
    heading("A colour: hover both boxes");
    ui_row_begin("anim_boxes", spacing = 12.0);
      anim_box("off", "animate = false", false);
      anim_box("on",  "animate = true",  true);
    ui_row_end();
    ui_slider("transition_speed", *ui_theme.transition_speed, 1.0, 60.0);
    ui_spacing();
    heading("A size: open and close it");
    al_header();
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

al_plot: Sampler;

al_header :: (loc := #caller_location) {
  cache := ui_cache_for("Click to animate", loc);
  sample(*al_plot, cache.disclosure_t, 60.0);
  if ui_collapsing_header("Click to animate", loc = loc) {
    ui_label("Line one");
    ui_label("Line two");
    ui_label("Line three");
    ui_button("A button in here");
  }
  ui_collapsing_end();
  value("al_values", tprint("disclosure_t %", formatFloat(cache.disclosure_t, trailing_width = 2)));
  ui_plot_begin("al_plot", height = ui.metrics.line_height * 5.0, overlay = "disclosure_t, over time");
    ui_plot_line(ui_plot_values(*al_plot.buffer));
  ui_plot_end();
}

Window_Name :: struct { key: u64; name: string; }
win_names: [8] Window_Name;
draw_order_count := 0;

slide_windows :: () {
  title("Windows and z-order");
  split_begin("windows", 0.5);
    point("A window: a node with a key; position, size and dock in its cache");
    ui_spacing();
    heading("Windows are ordered, nodes are not");
    point("Nodes: built later = in front. Windows can't use that:");
    sub("the code builds them in the same order every frame");
    point("The context keeps a window order: a list, back to front");
    point("Pressing a window moves it, and its parents, to the end: the front");
    point("Each window gets a depth range from its place in the list");
    sub("its nodes count down inside it, as before");
    point("Windows inside a window share the front of their parent's range");
    ui_spacing();
    heading("The one-frame delay");
    point("Hit-testing happens during the build, so the mouse owner comes from last frame");
    code(CODE_DELAY);
  split_next();
    heading("Live: draw order, back to front  (click the windows)");
    draw_order_count = 0;
    draw_order_lines(UI_ROOT_KEY, 0);
    ui_spacing();
    heading("Press where A and B overlap: only the front one counts");
    owner := "another window";
    for win_names  if it.key && it.key == ui.mouse_panel  owner = it.name;
    value("win_owner",   tprint("owner of the mouse (from last frame): %", owner));
    value("win_presses", tprint("presses:  A %   B %", win_presses[0], win_presses[1]));
  split_end();

  region := ui_parent().inner;
  x := max(0.0, region.size.x - 620.0);
  win_names[0] = .{ ui_parent().panel, "Presentation" };
  win_names[1] = .{ inspector_window_key, "Node inspector" };

  a := ui_window_begin("Window A", null, x, 160, 250, 170, .NO_CLOSE);
    win_names[2] = .{ a.node.key, "A" };
    if delay_button("press me (A)").pressed  win_presses[0] += 1;
  ui_window_end();

  b := ui_window_begin("Window B", null, x + 190, 230, 420, 330, .NO_CLOSE);
    win_names[3] = .{ b.node.key, "B" };
    if delay_button("press me (B)").pressed  win_presses[1] += 1;
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
}

// One line per window, back to front: a window, then the windows inside it.
draw_order_lines :: (parent_key: u64, depth: int) {
  for ui.window_order {
    if it.parent != parent_key  continue;
    name := tprint("window %", hex(it.key));
    for n: win_names  if n.key == it.key && n.name  name = n.name;
    for 1..depth  name = tprint("     %", name);   // indented under its parent
    draw_order_count += 1;
    ui_push_id(it_index);
      value("draw_order", tprint("%.  %", draw_order_count, name));
    ui_pop_id();
    draw_order_lines(it.key, depth + 1);
  }
}

win_presses: [2] int;

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

slide_recap_5 :: () {
  title("Part 5, as code: state across frames");
  split_begin("recap_5", 0.6);
    heading("The library (mock)");
    code(MOCK_5, "A mock: the shape of it, not the real code");
  split_next();
    heading("The real widgets");
    ui_slider("Volume", *recap_volume, 0.0, 1.0);
    ui_checkbox("Mute", *recap_mute);
    if ui_button("Apply").clicked {
      recap_applied += 1;
    }
    value("recap_applied", tprint("applied % times", recap_applied));
  split_end();
}

// ---------------------------------------------------------------------------
// Part 6: Building on it
// ---------------------------------------------------------------------------

comp_tab     := 0;
comp_check   := true;
comp_slider  := 0.4;
comp_outline := true;
comp_clicks  := 0;

comp_canvas: Tree_Canvas;

slide_composition :: () {
  title("Widgets are small");
  point("The core (layout, input, cache, drawing) is written once");
  point("A widget is a short function that creates nodes");
  sub("your own widgets work the same way: the library doesn't know about them");
  ui_spacing();
  split_begin("comp", 0.58);
    ui_tab_group_begin("comp_tabs");
      ui_tab("Button",   *comp_tab, 0);
      ui_tab("Checkbox", *comp_tab, 1);
      ui_tab("Slider",   *comp_tab, 2);
      ui_tab("Custom (memory pool)", *comp_tab, 3);
    ui_tab_group_end();
    if comp_tab == 0  code(CODE_BUTTON);
    if comp_tab == 1  code(CODE_CHECKBOX);
    if comp_tab == 2  code(CODE_SLIDER);
    if comp_tab == 3  code(CODE_POOL_WIDGET);
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
      widget = ui_parent().last;   // the widget is the last node added here
    }
    if comp_tab == 2 {
      ui_slider("A slider", *comp_slider, 0.0, 1.0);
      widget = ui_parent().last;
    }
    if comp_tab == 3 {
      ui_flat_pool("UI frame memory", *ui.frame_pool);
      widget = ui_parent().last;
      sub("a widget for one of our own types  (hover the bars)");
    }
    ui_spacing();
    ui_checkbox("Outline its nodes", *comp_outline);
    if comp_outline  outline_subtree(widget);
    value("comp_nodes", tprint("% node(s)", count_nodes(widget)));
    ui_spacing();
    heading("Its tree  (drag, wheel to zoom, 'Fit' to see all)");
    canvas_params: UI_Params;
    canvas_params.name        = "Widget tree";
    canvas_params.spacing     = UI_STACK_SPACING;
    canvas_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    canvas_params.size.height = .{ kind = .PIXELS, value = column_height_left() };
    ui_push_parent(ui_node("comp_canvas_box", 0, canvas_params));
      ui_tree_canvas("comp", *comp_canvas, widget, live = true);
    ui_pop_parent();
  split_end();
}

outline_subtree :: (node: *UI_Node) {
  if !node  return;
  ui_overlay_rect(node.rect, .{ 0, 0, 0, 0 }, .{ 1, 0, 1, 1 }, 1.0, 0.0);
  child := node.first;
  while child { outline_subtree(child); child = child.next; }
}


style_color        := Vector4.{ 0.85, 0.35, 0.25, 1.0 };
style_radius       := 12.0;
style_windows_open := true;
style_slider       := 0.5;
style_check        := true;

slide_style :: () {
  title("Style: params per node");
  split_begin("style", 0.5);
    point("Flags: what a node does. UI_Params: how it looks");
    point("Each node copies the theme into its params when it is built");
    point("Children are built inside their parent: set the theme once, around the widget");
    code(CODE_PARAMS);
    code(CODE_STYLE);
  split_next();
    heading("1. One node: its own params");
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

    heading("2. A window: its own theme");
    ui_checkbox("Show the windows", *style_windows_open);
    ui_spacing();

    heading("3. Everything: the Theme button in the bottom bar");
    sub("the windows keep their own theme");
  split_end();

  if style_windows_open {
    region := ui_parent().inner;
    x := max(0.0, region.size.x - 380.0);
    themed_window("Green screen window", ui_palettes[4],  x - 60.0, 60.0);
    themed_window("Kanagawa window",     ui_palettes[8],  x - 30.0, 240.0);
    themed_window("Solarized window",    ui_palettes[11], x,        420.0);
  }
}

// Must match CODE_STYLE: one theme, set once around a whole window.
themed_window :: (title: string, palette: UI_Palette, x: float, y: float) {
  saved: UI_Theme = ui_theme;
  ui_theme = ui_theme_from_palette(palette);
  ui_window_begin(title, null, x, y, 340, 200, .NO_CLOSE);
    ui_label(tprint("Theme: %", palette.name));
    ui_button("A button");
    ui_slider("A slider", *style_slider, 0.0, 1.0);
    ui_checkbox("A checkbox", *style_check);
  ui_window_end();
  ui_theme = saved;
}

slide_recap_6 :: () {
  title("Part 6, as code: widgets on top");
  split_begin("recap_6", 0.6);
    heading("The library (mock)");
    code(MOCK_6, "A mock: the shape of it, not the real code");
  split_next();
    heading("The real widgets");
    ui_slider("Volume", *recap_volume, 0.0, 1.0);
    ui_checkbox("Mute", *recap_mute);
    if ui_button("Apply").clicked {
      recap_applied += 1;
    }
    value("recap_applied", tprint("applied % times", recap_applied));
    ui_spacing();
    heading("The API from the start now runs");
    sub("from the widget calls down to the quads the app draws");
  split_end();
}

// ---------------------------------------------------------------------------
// Part 7: Wrap-up
// ---------------------------------------------------------------------------

// The file tree and text viewer for the "Demo and source" slide.
source_browser :: () {
  if !source.loaded  source_load();

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

demo_full_open := true;

demo_tab := 0;

slide_demo :: () {
  title("Demo and source");
  ui_tab_group_begin("demo_tabs");
    ui_tab("Live demo",   *demo_tab, 0);
    ui_tab("Source code", *demo_tab, 1);
  ui_tab_group_end();
  if demo_tab == 1 {
    source_browser();
    return;
  }

  if !demo_full_open {
    if ui_button("Reopen the widget demo").clicked {
      demo_full_open = true;
    }
  }
  ui_demo_window(*demo_full_open);
}

slide_build_your_own :: () {
  title("Build your own, in this order");
  ui_spacing();
  heading("1. A context");
  point("one global: input, metrics, a parent stack, hot / active keys");
  ui_spacing();
  heading("2. A node");
  point("one struct for everything: rect, text, flags, params, key, tree links");
  ui_spacing();
  heading("3. ui_begin");
  point("free last frame's nodes, make the root, push it");
  ui_spacing();
  heading("4. ui_node");
  point("key, link, size, place, hit-test: all when the node is created");
  ui_spacing();
  heading("5. Signals");
  point("every widget returns one");
  ui_spacing();
  heading("6. ui_end");
  point("walk the tree, output quads");
  ui_spacing();
  heading("7. A cache");
  point("key -> state, freed when unused");
  ui_spacing();
  point("Then widgets: small functions that call ui_node");
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
  "?", "Rats!", "UI_Node", "hot", "active", "We are not your kind", "cache hit", "immediate!",
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

// A code panel. The snippet's leading "// File.jai:line ..." lines (see src())
// are where the code comes from: they are taken out of the code and shown in a
// footer, together with the optional description. No description and no
// source: no footer. footer_top puts the footer above the code instead.
code :: (text: string, description := "", footer_top := false, loc := #caller_location) {
  clean := talloc_string(text.count);
  count := 0;
  for 0..text.count - 1 {
    if text[it] == #char "\r"  continue;
    clean[count] = text[it];
    count += 1;
  }
  while count > 0 && clean[count - 1] == #char "\n"  count -= 1;
  clean.count = count;

  sources: [..] string;
  sources.allocator = temp;
  while true {
    end := find_index_from_left(clean, #char "\n");
    if end < 0  end = clean.count;
    first_line := string.{ end, clean.data };
    if !begins_with(first_line, "// ") || !contains(first_line, ".jai:")  break;
    array_add(*sources, advance(first_line, 3));
    clean = advance(clean, min(end + 1, clean.count));
  }

  pad: float = floor(ui.metrics.line_height * 0.8);
  has_footer: bool = description.count > 0 || sources.count > 0;

  params := ui_box_params(ui_theme.window_background, ui_theme.window_border);
  params.name        = "Code";
  params.padding     = ui_theme.border_thickness;  // the footer sits inside the border
  params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(ui_parent()) };
  panel := ui_node("code", 0, params, loc);
  ui_push_parent(panel);
    if has_footer && footer_top {
      code_footer(description, sources, pad, true, loc);
    }

    body_params: UI_Params;
    body_params.name        = "Code body";
    body_params.animate     = false;
    body_params.padding     = pad;
    body_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    body_params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(panel) };
    body := ui_node("code_body", 0, body_params, loc);
    ui_push_parent(body);
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
    ui_shrink_panel_to_content(body);

    if has_footer && !footer_top {
      code_footer(description, sources, pad, false, loc);
    }
  ui_pop_parent();
  ui_shrink_panel_to_content(panel);
}

// The strip under (or over) the code: a line, then the description on the left
// and where the code comes from on the right. All on one row when it fits;
// otherwise the description gets its own row, then the sources (one per row if
// they still don't fit).
code_footer :: (description: string, sources: [] string, pad: float, top: bool, loc: Source_Code_Location) {
  if !top  code_footer_line(loc);

  inset: float = floor(ui.metrics.line_height * 0.3);

  params: UI_Params;
  params.name              = "Code footer";
  params.animate           = false;
  params.padding           = inset;
  params.background.normal = ui_mix(ui_theme.window_background.normal, ui_theme.text.normal, 0.06);
  params.corner_radius     = max(0.0, ui_theme.corner_radius - ui_theme.border_thickness);
  params.corners           = ifx top then UI_CORNER_TL | UI_CORNER_TR else UI_CORNER_BL | UI_CORNER_BR;
  params.size.width        = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.size.height       = .{ kind = .PIXELS, value = ui_provisional_panel_height(ui_parent()) };
  footer := ui_node("code_footer", 0, params, loc);
  ui_push_parent(footer);
    gap: float = max(0.0, pad - inset);   // lines the footer text up with the code
    joined: string = join(..sources, separator = ", ");
    description_width := code_text_width(description);
    joined_width      := code_text_width(joined);
    width: float = footer.inner.size.x - 2.0 * gap;

    gap_between: float = 0.0;
    if description && joined  gap_between = gap;
    if description_width + gap_between + joined_width <= width {
      code_footer_row(0, description, joined, gap, loc);
    } else {
      row := 0;
      if description {
        code_footer_row(row, description, "", gap, loc);
        row += 1;
      }
      if joined_width <= width {
        code_footer_row(row, "", joined, gap, loc);
      } else {
        for sources {
          code_footer_row(row, "", it, gap, loc);
          row += 1;
        }
      }
    }
  ui_pop_parent();
  ui_shrink_panel_to_content(footer);

  if top  code_footer_line(loc);
}

// The footer text is drawn smaller than the code.
CODE_FOOTER_TEXT_SCALE :: 0.8;

code_text_width :: (text: string) -> float {
  if !text  return 0.0;
  width, height := ui_measure_text(text);
  return width * CODE_FOOTER_TEXT_SCALE;
}

code_footer_row :: (index: int, description: string, sources: string, gap: float, loc: Source_Code_Location) {
  row_params: UI_Params;
  row_params.name        = "Code footer row";
  row_params.axis        = .X;
  row_params.animate     = false;
  row_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height = .{ kind = .PIXELS, value = floor(ui.metrics.line_height * CODE_FOOTER_TEXT_SCALE * 1.15) };
  row := ui_node("code_footer_row", "r", index, 0, row_params, loc);
  ui_push_parent(row);
    space: UI_Params;
    space.animate     = false;
    space.size.width  = .{ kind = .PIXELS, value = gap };
    space.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
    ui_node("code_footer_gap", 0, space, loc);

    if description {
      text: UI_Params;
      text.text        = description;
      text.foreground  = ui_theme.text;
      text.animate     = false;
      text.text_scale  = CODE_FOOTER_TEXT_SCALE;
      text.size.width  = .{ kind = .TEXT, value = 0.0 };
      text.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
      ui_node("code_description", .DRAW_TEXT | .TEXT_CENTER_Y, text, loc);
    }

    if sources {
      // Push the sources to the right edge.
      right: float = row.inner.pos.x + row.inner.size.x - gap;
      space.size.width = .{ kind = .PIXELS, value = max(0.0, right - row.cursor.x - code_text_width(sources)) };
      ui_node("code_footer_push", 0, space, loc);

      text: UI_Params;
      text.text        = sources;
      text.foreground  = .{ normal = comment_color() };
      text.animate     = false;
      text.text_scale  = CODE_FOOTER_TEXT_SCALE;
      text.size.width  = .{ kind = .TEXT, value = 0.0 };
      text.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
      ui_node("code_sources", .DRAW_TEXT | .TEXT_CENTER_Y, text, loc);
    }
  ui_pop_parent();
}

// The line between the code and its footer.
code_footer_line :: (loc: Source_Code_Location) {
  line: UI_Params;
  line.name              = "Code footer line";
  line.animate           = false;
  line.background.normal = ui_theme.window_border.normal;
  line.size.width        = .{ kind = .PARENT_FRACTION, value = 1.0 };
  line.size.height       = .{ kind = .PIXELS, value = max(1.0, ui_theme.border_thickness) };
  ui_node("code_footer_line", 0, line, loc);
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

hex :: (v: u64) -> string {
  return tprint("0x%", formatInt(v, base = 16, minimum_digits = 16));
}

// ---------------------------------------------------------------------------
// Code shown on slides, in slide order. Types are written out on purpose: this
// is about the UI architecture, not about the language. The leading comment
// lines of each snippet say where the real code is; code() moves them into
// the panel's footer.
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
// built once
mute:   *Checkbox = new Checkbox("Mute");
volume: *Slider   = new Slider("Volume", 0.0, 1.0);
reset:  *Button   = new Button("Reset");

mute.set_checked(settings.mute);          // copy the data in
volume.set_value(settings.volume);

mute.on_change = (checked: bool) {        // copy changes back out
  settings.mute = checked;
  volume.set_enabled(!checked);
};
volume.on_change = (value: float) {
  settings.volume = value;
};
reset.on_click = () {
  settings = default_settings;
  mute.set_checked(settings.mute);        // and update every widget
  volume.set_value(settings.volume);
  volume.set_enabled(!settings.mute);
};

panel.add(mute);
panel.add(volume);
panel.add(reset);
DONE);

CODE_IMMEDIATE :: #run src(#string DONE
// [[Presentation.jai|ui_checkbox("Mute", *rvi_settings.mute);]], slide_retained_vs_immediate
// every frame
ui_checkbox("Mute", *settings.mute);
ui_slider("Volume", *settings.volume, 0.0, 1.0, disabled = settings.mute);

if ui_button("Reset").clicked {
  settings = default_settings;
}
DONE);

// One frame

CODE_MAIN_LOOP ::#run src(#string DONE
// [[Main.jai|while !app.should_quit {]] (simplified)
while !app.should_quit {
  input: UI_Input;
  input.mouse_pos     = mouse_position;
  input.mouse_down[0] = is_key_down(.MOUSE_BUTTON_LEFT);
  input.dt            = seconds_since_last_frame;

  metrics: UI_Metrics;
  metrics.font      = cast(UI_Font) font;
  metrics.get_glyph = ui_get_glyph;

  ui_begin(input, metrics);
  presentation();
  ui_end();

  for quad: ui_quads() {
    draw_quad(quad);
  }
}
DONE);

CODE_APP_PROVIDES :: #run src(#string DONE
// [[Imgui_Backend.jai|ui_get_glyph :: (]]
// [[Core.jai|UI_Glyph :: struct {]]
ui_get_glyph :: (font: UI_Font, codepoint: u32) -> (found: bool, glyph: UI_Glyph);

UI_Glyph :: struct {
  texture: UI_Texture;   // where the letter's pixels are
  uv_min:  Vector2;
  uv_max:  Vector2;
  size:    Vector2;
  bearing: Vector2;      // from the pen to the letter's top-left
  advance: float;        // how far the pen moves
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

// Part 2 recap

MOCK_2 :: #string DONE
// + part 2: the UI font type is an opaque pointer
UI_Font :: #type,distinct *void;

// + part 2: what the app saw this frame
UI_Input :: struct {
  screen_size:   Vector2;
  mouse_pos:     Vector2;
  mouse_pressed: bool;
  dt:            float;
}

// + part 2: the font, and its letters
UI_Metrics :: struct {
  font:      UI_Font;
  get_glyph: (font: UI_Font, codepoint: u32) -> UI_Glyph;   // the app's letters
}

// + part 2: the UI's own state
UI_Context :: struct {
  input:   UI_Input;
  metrics: UI_Metrics;
  quads:   [..] UI_Quad;
}
ui: UI_Context;

// + part 2
ui_begin :: (input: UI_Input, metrics: UI_Metrics) {
  ui.input       = input;
  ui.metrics     = metrics;
  ui.quads.count = 0;
}

// + part 2
ui_end :: () {

}
DONE

// The node

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

// Building the tree (the root)

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
  ui_push_id(i);                         // the index goes into the key
  item: UI_Signal = ui_button("Item");
  ui_pop_id();
}
DONE);

// Part 3 recap

MOCK_3 :: #string DONE
UI_Input :: struct {
  screen_size:   Vector2;
  mouse_pos:     Vector2;
  mouse_pressed: bool;
  dt:            float;
}

UI_Metrics :: struct {
  font:      UI_Font;
  get_glyph: (font: UI_Font, codepoint: u32) -> UI_Glyph;   // the app's letters
}

// + part 3: the node, the only primitive
UI_Node :: struct {
  key:   u64;
  rect:  UI_Rect;
  text:  string;
  flags: UI_Node_Flags;
  parent, first, last, next, prev: *UI_Node;  // the intrusive tree
}

UI_Context :: struct {
  input:        UI_Input;
  metrics:      UI_Metrics;
  frame_arena:  Arena;                        // + part 3: every node lives here
  root:         *UI_Node;                     // + part 3: the screen
  parent_stack: [..] *UI_Node;                // + part 3
  quads:        [..] UI_Quad;
}
ui: UI_Context;

ui_begin :: (input: UI_Input, metrics: UI_Metrics) {
  ui.input       = input;
  ui.metrics     = metrics;
  ui.quads.count = 0;

  // + part 3: last frame's tree is gone; the root is the screen
  reset(*ui.frame_arena);
  ui.root      = arena_new(*ui.frame_arena, UI_Node);
  ui.root.rect = .{ .{ 0, 0 }, input.screen_size };
  ui_push_parent(ui.root);
}

// + part 3
ui_node :: (id: string, flags: UI_Node_Flags) -> *UI_Node {
  parent: *UI_Node = ui.parent_stack[ui.parent_stack.count - 1];
  node:   *UI_Node = arena_new(*ui.frame_arena, UI_Node);
  node.key   = hash(parent.key, id, call_site);
  node.flags = flags;

  // linked in as the parent's last child
  node.parent = parent;
  if parent.last {
    parent.last.next = node;
    node.prev        = parent.last;
  } else {
    parent.first = node;
  }
  parent.last = node;
  return node;
}

// + part 3
ui_push_parent :: (node: *UI_Node) {
  array_add(*ui.parent_stack, node);
}

// + part 3
ui_pop_parent :: () {
  ui.parent_stack.count -= 1;
}

ui_end :: () {
  ui_pop_parent();                            // + part 3: back down to the root
  // turn this frame's tree into quads (part 4)
}
DONE

// ui_node: where it all happens

CODE_UI_NODE ::#run src(#string DONE
// [[Core.jai|ui_node :: (id: string, flags: UI_Node_Flags]]
// [[Core.jai|ui_node_keyed :: (]] (simplified)
ui_node :: (id: string, flags: UI_Node_Flags, params: UI_Params) -> *UI_Node {
  key: u64 = ui_scoped_key(id, call_site);    // 1. key
  return ui_node_keyed(key, flags, params);
}

ui_node_keyed :: (key: u64, flags: UI_Node_Flags, params: UI_Params) -> *UI_Node {
  parent: *UI_Node = ui_parent();             // 2. top of the parent stack

  node: *UI_Node = ui_allocate_node();        // 3. from the frame arena
  node.key    = key;
  node.flags  = flags;
  node.params = params;                       // 4. a copy: its style
  node.text   = ui_frame_copy_string(params.text);

  node.depth = ui.next_depth;                 // 5. later = in front
  ui.next_depth -= UI_DEPTH_EPSILON;

  // 6. linked in as the parent's last child
  node.parent = parent;
  if parent.last {
    parent.last.next = node;
    node.prev        = parent.last;
  } else {
    parent.first = node;
  }
  parent.last = node;

  // 7. layout: size from the params, position from the parent's cursor
  free_space: Vector2 = parent.inner.size - (parent.cursor - parent.inner.pos);
  text_w, text_h: float = ui_measure_display(node.text);
  node.rect.size.x = ui_resolve_size(params.size.width,  free_space.x, parent.inner.size.x, text_w);
  node.rect.size.y = ui_resolve_size(params.size.height, free_space.y, parent.inner.size.y, text_h);
  node.rect.pos    = parent.cursor;
  if parent.params.axis == .X {              // then move the cursor past it
    parent.cursor.x += node.rect.size.x + parent.params.spacing;
  } else {
    parent.cursor.y += node.rect.size.y + parent.params.spacing;
  }

  ui_interact(node);                          // 8. hit-test, right now
  return node;
}
DONE);

// Layout

CODE_SIZES ::#run src(#string DONE
// [[Core.jai|UI_Size_Kind :: enum u8 {]]
UI_Size_Kind :: enum {
  PIXELS;           // fixed
  PARENT_FRACTION;  // share of the space still free
  PARENT_RATIO;     // share of the parent's whole size
  TEXT;             // text size + some padding
}
DONE);


// Layout (split, then split again)

CODE_LAYOUT_SPLIT :: #run src(#string DONE
// [[Presentation.jai|layout_split_demo :: ()]] (simplified)
row.axis = .X;                                                    // side by side
ui_push_parent(ui_node("row", 0, row));

  left.size.width = .{ kind = .PARENT_RATIO, value = 0.3 };
  ui_node("left", flags, left);

  column.axis       = .Y;                                         // stacked
  column.size.width = .{ kind = .PARENT_FRACTION, value = 1.0 };  // the rest
  ui_push_parent(ui_node("column", 0, column));

    top.size.height = .{ kind = .PARENT_FRACTION, value = 0.5 };
    ui_node("top", flags, top);

    bottom.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
    ui_node("bottom", flags, bottom);

  ui_pop_parent();
ui_pop_parent();
DONE);

// Behaviour from flags

CODE_FLAGS ::#run src(#string DONE
// [[Core.jai|UI_Node_Flags :: enum_flags u32 {]]
UI_Node_Flags :: enum_flags {
  CLICKABLE;
  HOVERABLE;
  DRAGGABLE;
  RESIZABLE;
  SCROLL_Y;
  FLOATING;
  DRAW_TEXT;
  DRAW_LINES;
  TEXT_CENTER_X;
  TEXT_CENTER_Y;
  ...
}
DONE);

// Depth instead of sorting

CODE_DEPTH :: #run src(#string DONE
// [[Core.jai|node.depth  = ui.next_depth;]]
// [[Core.jai|if over && hoverable && node.depth <= ui.hot_depth {]]
// ui_node_keyed
node.depth = ui.next_depth;
ui.next_depth -= UI_DEPTH_EPSILON;   // the next node is a bit more in front

// ui_interact
if over && hoverable && node.depth <= ui.hot_depth {
  ui.hot_key   = node.key;           // the front-most so far wins
  ui.hot_depth = node.depth;
}
DONE);

CODE_DEPTH_ABC :: #run src(#string DONE
// [[Presentation.jai|depth_build_abc :: ()]]
a: *UI_Node = depth_box("A", ...);   // built first: at the back
b: *UI_Node = depth_box("B", ...);
c: *UI_Node = depth_box("C", ...);   // built last: in front
DONE);

CODE_DEPTH_CBA :: #run src(#string DONE
// [[Presentation.jai|depth_build_cba :: ()]]
c: *UI_Node = depth_box("C", ...);   // built first: at the back
b: *UI_Node = depth_box("B", ...);
a: *UI_Node = depth_box("A", ...);   // built last: in front
DONE);

// Signals

CODE_SIGNAL_STRUCT :: #run src(#string DONE
// [[Core.jai|UI_Signal :: struct {]] (simplified)
UI_Signal :: struct {
  node:     *UI_Node;
  hovered:  bool;
  pressed:  bool;    // only on the frame it happened
  held:     bool;
  clicked:  bool;
  released: bool;
  ...
}
DONE);

CODE_SIGNAL_CLASSIC ::#run src(#string DONE
if (ImGui::Button("Save")) {
  save();
}
if (ImGui::IsItemHovered()) {
  ImGui::SetTooltip("Writes to disk");
}
DONE);

CODE_SIGNAL_OURS :: #run src(#string DONE
// [[Presentation.jai|signal: UI_Signal = ui_button("Save");]], slide_signals
signal: UI_Signal = ui_button("Save");
if signal.clicked {
  save();
}
if signal.hovered {
  ui_set_tooltip("Writes to disk");
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
  texture: UI_Texture;  // a handle: the font texture for letters
}
DONE);

CODE_DRAW :: #run src(#string DONE
// [[Imgui_Backend.jai|ui_draw :: () {]]
ui_draw :: () {
  for quad: ui_quads() {
    texture := cast(*Texture) quad.texture;   // the handle we gave the UI, back again
    r_push_clip_rect(*renderer, quad.clip.pos, quad.clip.size);
    r_draw_screen_quad(*renderer, quad.rect.pos, quad.rect.size, tint = quad.color, texture = texture, 
                        uv_min = quad.uv_min, uv_max = quad.uv_max,
                        border_thickness = quad.border_thickness, border_color = quad.border_color, 
                        border_radius = quad.corner_radius,
                        rotation = quad.rotation, corners = quad.corner_mask);
    r_pop_clip_rect(*renderer);
  }
}
DONE);


// Part 4 recap

MOCK_4 :: #string DONE
UI_Input :: struct {
  screen_size:   Vector2;
  mouse_pos:     Vector2;
  mouse_pressed: bool;
  dt:            float;
}

UI_Metrics :: struct {
  font:      UI_Font;
  get_glyph: (font: UI_Font, codepoint: u32) -> UI_Glyph;   // the app's letters
}

UI_Node :: struct {
  key:    u64;
  rect:   UI_Rect;
  text:   string;
  flags:  UI_Node_Flags;
  params: UI_Params;                          // + part 4: size, colours
  cursor: Vector2;                            // + part 4: where the next child goes
  depth:  float;                              // + part 4: smaller = in front
  parent, first, last, next, prev: *UI_Node;  // the intrusive tree
}

UI_Context :: struct {
  input:        UI_Input;
  metrics:      UI_Metrics;
  frame_arena:  Arena;
  root:         *UI_Node;
  parent_stack: [..] *UI_Node;
  hot_key:      u64;                          // + part 4: under the mouse
  hot_depth:    float;                        // + part 4
  next_depth:   float;                        // + part 4
  quads:        [..] UI_Quad;
}
ui: UI_Context;

ui_begin :: (input: UI_Input, metrics: UI_Metrics) {
  ui.input       = input;
  ui.metrics     = metrics;
  ui.quads.count = 0;
  ui.hot_key     = 0;                         // + part 4
  ui.hot_depth   = 1.0e30;                    // + part 4
  ui.next_depth  = 1.0;                       // + part 4

  reset(*ui.frame_arena);
  ui.root      = arena_new(*ui.frame_arena, UI_Node);
  ui.root.rect = .{ .{ 0, 0 }, input.screen_size };
  ui_push_parent(ui.root);
}

ui_node :: (id: string, flags: UI_Node_Flags, params: UI_Params) -> *UI_Node {
  parent: *UI_Node = ui.parent_stack[ui.parent_stack.count - 1];
  node:   *UI_Node = arena_new(*ui.frame_arena, UI_Node);
  node.key    = hash(parent.key, id, call_site);
  node.flags  = flags;
  node.params = params;                       // + part 4

  node.parent = parent;
  if parent.last {
    parent.last.next = node;
    node.prev        = parent.last;
  } else {
    parent.first = node;
  }
  parent.last = node;

  // + part 4: depth - later is in front
  node.depth = ui.next_depth;
  ui.next_depth -= 0.0001;

  // + part 4: layout - at the parent's cursor (simplified: sizes in pixels)
  node.rect.pos  = parent.cursor;
  node.rect.size = params.size;
  node.cursor    = node.rect.pos;
  parent.cursor.y += node.rect.size.y;

  // + part 4: hit-test, right now - the front-most hoverable node wins
  under: bool = contains(node.rect, ui.input.mouse_pos);
  if under && (flags & .HOVERABLE) && node.depth < ui.hot_depth {
    ui.hot_key   = node.key;
    ui.hot_depth = node.depth;
  }
  return node;
}

ui_push_parent :: (node: *UI_Node) {
  array_add(*ui.parent_stack, node);
}

ui_pop_parent :: () {
  ui.parent_stack.count -= 1;
}

// + part 4
ui_signal :: (node: *UI_Node) -> UI_Signal {
  signal: UI_Signal;
  signal.hovered = ui.hot_key == node.key;
  signal.clicked = signal.hovered && ui.input.mouse_pressed;
  return signal;
}

ui_end :: () {
  ui_pop_parent();
  emit(ui.root);                              // + part 4: the tree becomes quads
}

// + part 4: parents first = back to front
emit :: (node: *UI_Node) {
  quad: UI_Quad;
  quad.rect  = node.rect;
  quad.color = ifx ui.hot_key == node.key then node.params.hover else node.params.background;
  array_add(*ui.quads, quad);

  child: *UI_Node = node.first;
  while child {
    emit(child);
    child = child.next;
  }
}

// + part 4: a widget, using its signal
ui_button :: (text: string) -> UI_Signal {
  flags: UI_Node_Flags = .CLICKABLE | .HOVERABLE | .DRAW_TEXT;
  params: UI_Params;
  params.text       = text;
  params.size       = .{ 120, 30 };
  params.background = .{ 0.30, 0.30, 0.30, 1 };
  params.hover      = .{ 0.45, 0.45, 0.45, 1 };
  node: *UI_Node = ui_node(text, flags, params);
  return ui_signal(node);
}
DONE

// Why keep state between frames, and whose is it?

CODE_OWN_USER ::#run src(#string DONE
// [[Presentation.jai|if ui_collapsing_header("Click me") {]], slide_why_state
mute: bool = false;            // your variable
ui_checkbox("Mute", *mute);    // reads and writes it

if ui_collapsing_header("Open / close me") {
  // open or closed? the library remembers, by key
}

ui_list_box("Fruits", *picked, fruits, 4);
// picked is yours, the scroll position is the library's
DONE);

// The cache

CODE_CACHE ::#run src(#string DONE
// [[Core.jai|caches: Table(u64, *UI_Node_Cache]]
// [[Core.jai|UI_Node_Cache :: struct {]] (simplified)
// UI_Context
caches: Table(u64, *UI_Node_Cache);   // key -> state

UI_Node_Cache :: struct {
  last_touched: u64;      // the last frame it was used
  scroll:       float;
  expanded:     bool;     // open / closed
  animated_background: Vector4;
  ...
}
DONE);


// Animation

CODE_ANIMATION :: #run src(#string DONE
// [[Core.jai|ui_animation_t :: (dt: float) -> float {]]
// [[Core.jai|cache.animated_background = ui_mix(cache.animated_background, background, t);]]
// [[Widgets.jai|cache.disclosure_t += (target - cache.disclosure_t) * dt;]]
// ui_animation_t
speed: float = ui_theme.transition_speed;
t: float = 1.0 - exp(-dt * speed);   // the fraction to move this frame

// ui_emit
target: Vector4 = node.background.normal;
if hovered {
  target = node.background.hover;
}
cache.animated_background += (target - cache.animated_background) * t;

// ui_collapsing_header
target_open: float = 0.0;
if cache.expanded {
  target_open = 1.0;
}
cache.disclosure_t += (target_open - cache.disclosure_t) * t;
body_height: float = cache.disclosure_height * cache.disclosure_t;
DONE);

// Windows and z-order (the one-frame delay)

CODE_DELAY :: #run src(#string DONE
// [[Core.jai|over := under && node.panel == ui.mouse_panel;]] (simplified)
// [[Core.jai|ui.mouse_panel = ui.mouse_panel_next;]]
// ui_interact
if under && node.depth < ui.mouse_panel_depth {
  ui.mouse_panel_next  = node.panel;   // front-most window under the mouse, this frame
  ui.mouse_panel_depth = node.depth;
}
over: bool = under && node.panel == ui.mouse_panel;   // decided last frame

// ui_end
ui.mouse_panel = ui.mouse_panel_next;   // ready for next frame
DONE);

// Part 5 recap

MOCK_5 :: #string DONE
UI_Input :: struct {
  screen_size:   Vector2;
  mouse_pos:     Vector2;
  mouse_pressed: bool;
  dt:            float;
}

UI_Metrics :: struct {
  font:      UI_Font;
  get_glyph: (font: UI_Font, codepoint: u32) -> UI_Glyph;   // the app's letters
}

UI_Node :: struct {
  key:    u64;
  rect:   UI_Rect;
  text:   string;
  flags:  UI_Node_Flags;
  params: UI_Params;
  cursor: Vector2;
  depth:  float;
  window: u64;                                // + part 5: the window it is in
  parent, first, last, next, prev: *UI_Node;
}

// + part 5: what survives a frame, per key
UI_Node_Cache :: struct {
  last_touched: u64;
  scroll:       float;
  open:         bool;
  color:        Vector4;                      // how far the hover fade got
}

UI_Context :: struct {
  input:             UI_Input;
  metrics:           UI_Metrics;
  frame:             u64;                     // + part 5
  frame_arena:       Arena;
  persistent_arena:  Arena;                   // + part 5
  caches:            Table(u64, *UI_Node_Cache);  // + part 5: key -> state
  window_order:      [..] u64;                // + part 5: back to front, raised on press
  mouse_window:      u64;                     // + part 5: owns the mouse, from last frame
  next_mouse_window: u64;                     // + part 5: found during this frame
  next_window_depth: float;                   // + part 5
  root:              *UI_Node;
  parent_stack:      [..] *UI_Node;
  hot_key:           u64;
  hot_depth:         float;
  next_depth:        float;
  quads:             [..] UI_Quad;
}
ui: UI_Context;

ui_begin :: (input: UI_Input, metrics: UI_Metrics) {
  ui.frame      += 1;                         // + part 5
  ui.input       = input;
  ui.metrics     = metrics;
  ui.quads.count = 0;
  ui.hot_key     = 0;
  ui.hot_depth   = 1.0e30;
  ui.next_depth  = 1.0;
  ui.next_window_depth = 1.0e30;              // + part 5

  reset(*ui.frame_arena);
  ui.root      = arena_new(*ui.frame_arena, UI_Node);
  ui.root.rect = .{ .{ 0, 0 }, input.screen_size };
  ui_push_parent(ui.root);
}

ui_node :: (id: string, flags: UI_Node_Flags, params: UI_Params) -> *UI_Node {
  parent: *UI_Node = ui.parent_stack[ui.parent_stack.count - 1];
  node:   *UI_Node = arena_new(*ui.frame_arena, UI_Node);
  node.key    = hash(parent.key, id, call_site);
  node.flags  = flags;
  node.params = params;
  node.window = ifx flags & .WINDOW then node.key else parent.window;   // + part 5

  node.parent = parent;
  if parent.last {
    parent.last.next = node;
    node.prev        = parent.last;
  } else {
    parent.first = node;
  }
  parent.last = node;

  node.depth = ui.next_depth;
  ui.next_depth -= 0.0001;

  node.rect.pos  = parent.cursor;
  node.rect.size = params.size;
  node.cursor    = node.rect.pos;
  parent.cursor.y += node.rect.size.y;

  under: bool = contains(node.rect, ui.input.mouse_pos);

  // + part 5: remember the front-most window under the mouse, for next frame
  if under && node.depth < ui.next_window_depth {
    ui.next_mouse_window = node.window;
    ui.next_window_depth = node.depth;
  }

  in_owner: bool = node.window == ui.mouse_window;   // + part 5: last frame's owner
  if under && in_owner && (flags & .HOVERABLE) && node.depth < ui.hot_depth {
    ui.hot_key   = node.key;
    ui.hot_depth = node.depth;
  }
  return node;
}

ui_push_parent :: (node: *UI_Node) {
  array_add(*ui.parent_stack, node);
}

ui_pop_parent :: () {
  ui.parent_stack.count -= 1;
}

ui_signal :: (node: *UI_Node) -> UI_Signal {
  signal: UI_Signal;
  signal.hovered = ui.hot_key == node.key;
  signal.clicked = signal.hovered && ui.input.mouse_pressed;
  return signal;
}

// + part 5
ui_cache_get :: (key: u64) -> *UI_Node_Cache {
  cache: *UI_Node_Cache = table_find(*ui.caches, key);
  if !cache {
    cache = arena_new(*ui.persistent_arena, UI_Node_Cache);
    table_add(*ui.caches, key, cache);
  }
  cache.last_touched = ui.frame;
  return cache;
}

ui_end :: () {
  ui_pop_parent();
  emit(ui.root);

  // + part 5: forget the state of widgets not built for a while
  for cache, key: ui.caches {
    if ui.frame - cache.last_touched > 240 {
      remove;
    }
  }

  ui.mouse_window = ui.next_mouse_window;     // + part 5: next frame's owner
}

emit :: (node: *UI_Node) {
  // + part 5: animation - the colour moves toward its target, a bit each frame
  cache:  *UI_Node_Cache = ui_cache_get(node.key);
  target: Vector4 = ifx ui.hot_key == node.key then node.params.hover else node.params.background;
  t:      float   = 1.0 - exp(-ui.input.dt * 10.0);
  cache.color += (target - cache.color) * t;

  quad: UI_Quad;
  quad.rect  = node.rect;
  quad.color = cache.color;                   // + part 5
  array_add(*ui.quads, quad);

  child: *UI_Node = node.first;
  while child {
    emit(child);
    child = child.next;
  }
}

ui_button :: (text: string) -> UI_Signal {
  flags: UI_Node_Flags = .CLICKABLE | .HOVERABLE | .DRAW_TEXT;
  params: UI_Params;
  params.text       = text;
  params.size       = .{ 120, 30 };
  params.background = .{ 0.30, 0.30, 0.30, 1 };
  params.hover      = .{ 0.45, 0.45, 0.45, 1 };
  node: *UI_Node = ui_node(text, flags, params);
  return ui_signal(node);
}
DONE

// Widgets are small

CODE_BUTTON :: #run src(#string DONE
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

// Widgets are small (custom)

CODE_POOL_WIDGET :: #run src(#string DONE
// [[Custom_Widgets.jai|ui_flat_pool :: (id: string, pool: *Flat_Pool, loc := #caller_location) {]] (simplified)
// [[Custom_Widgets.jai|pool_bar ::(id: string, salt: string, used: s64, committed: s64, total: s64, overlay: string, used_tip: string, free_tip: string, uncommitted_tip: string, loc: Source_Code_Location) {]]
ui_flat_pool :: (name: string, pool: *Flat_Pool) {
  panel: *UI_Node = ui_node(name, "panel", 0, bordered_params);
  ui_push_parent(panel);
    ui_label(tprint("%: used %, committed %, reserved %", ...));
    pool_bar(name, "reserve",   used, committed, reserved);
    pool_bar(name, "committed", used, committed, committed);
  ui_pop_parent();
}

pool_bar :: (name: string, salt: string, used: int, committed: int, total: int) {
  track: *UI_Node = ui_node(name, salt, 0, track_params);
  ui_push_parent(track);
    segment(0, 0.0,         used_x,      used_color,  "used");
    segment(1, used_x,      committed_x, free_color,  "committed, free");
    segment(2, committed_x, width,       empty_color, "reserved only");
  ui_pop_parent();
}
DONE);

// Style: params per node

CODE_PARAMS :: #run src(#string DONE
// [[Core.jai|UI_Params :: struct {]] (simplified)
// [[Core.jai|node.params = params;]]
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

// ui_node_keyed: a copy, per node
node.params = params;
DONE);

CODE_STYLE :: #run src(#string DONE
// [[Presentation.jai|params.background    = .{ normal = style_color };]]
// [[Presentation.jai|themed_window :: (]]
// [[Presentation.jai|ui_set_theme(ui_theme_from_palette(palette));]]
// one node
params.background    = .{ normal = style_color };
params.corner_radius = style_radius;
ui_node("styled node", flags, params);

// one window
saved: UI_Theme = ui_theme;
ui_theme = ui_theme_from_palette(palette);   // once, before the window
ui_window_begin(title, ...);
  ui_button("A button");                     // its children get it too
ui_window_end();
ui_theme = saved;

// everything
ui_set_theme(ui_theme_from_palette(palette));
DONE);

// Part 6 recap

MOCK_6 :: #string DONE
UI_Input :: struct {
  screen_size:   Vector2;
  mouse_pos:     Vector2;
  mouse_pressed: bool;
  dt:            float;
}

UI_Metrics :: struct {
  font:      UI_Font;
  get_glyph: (font: UI_Font, codepoint: u32) -> UI_Glyph;   // the app's letters
}

UI_Node :: struct {
  key:    u64;
  rect:   UI_Rect;
  text:   string;
  flags:  UI_Node_Flags;
  params: UI_Params;
  cursor: Vector2;
  depth:  float;
  window: u64;
  parent, first, last, next, prev: *UI_Node;
}

UI_Node_Cache :: struct {
  last_touched: u64;
  scroll:       float;
  open:         bool;
  color:        Vector4;
}

// + part 6: the colours widgets copy into their params when they are built
UI_Theme :: struct {
  button:       Vector4;
  button_hover: Vector4;
  accent:       Vector4;
}

UI_Context :: struct {
  input:             UI_Input;
  metrics:           UI_Metrics;
  frame:             u64;
  frame_arena:       Arena;
  persistent_arena:  Arena;
  caches:            Table(u64, *UI_Node_Cache);
  window_order:      [..] u64;
  mouse_window:      u64;
  next_mouse_window: u64;
  next_window_depth: float;
  root:              *UI_Node;
  parent_stack:      [..] *UI_Node;
  hot_key:           u64;
  hot_depth:         float;
  next_depth:        float;
  theme:             UI_Theme;                // + part 6: the theme in use right now
  quads:             [..] UI_Quad;
}
ui: UI_Context;

ui_begin :: (input: UI_Input, metrics: UI_Metrics) {
  ui.frame      += 1;
  ui.input       = input;
  ui.metrics     = metrics;
  ui.quads.count = 0;
  ui.hot_key     = 0;
  ui.hot_depth   = 1.0e30;
  ui.next_depth  = 1.0;
  ui.next_window_depth = 1.0e30;

  reset(*ui.frame_arena);
  ui.root      = arena_new(*ui.frame_arena, UI_Node);
  ui.root.rect = .{ .{ 0, 0 }, input.screen_size };
  ui_push_parent(ui.root);
}

ui_node :: (id: string, flags: UI_Node_Flags, params: UI_Params) -> *UI_Node {
  parent: *UI_Node = ui.parent_stack[ui.parent_stack.count - 1];
  node:   *UI_Node = arena_new(*ui.frame_arena, UI_Node);
  node.key    = hash(parent.key, id, call_site);
  node.flags  = flags;
  node.params = params;
  node.window = ifx flags & .WINDOW then node.key else parent.window;

  node.parent = parent;
  if parent.last {
    parent.last.next = node;
    node.prev        = parent.last;
  } else {
    parent.first = node;
  }
  parent.last = node;

  node.depth = ui.next_depth;
  ui.next_depth -= 0.0001;

  node.rect.pos  = parent.cursor;
  node.rect.size = params.size;
  node.cursor    = node.rect.pos;
  if parent.params.axis == .X {               // + part 6: rows, for widgets with parts
    parent.cursor.x += node.rect.size.x;
  } else {
    parent.cursor.y += node.rect.size.y;
  }

  under: bool = contains(node.rect, ui.input.mouse_pos);

  if under && node.depth < ui.next_window_depth {
    ui.next_mouse_window = node.window;
    ui.next_window_depth = node.depth;
  }

  in_owner: bool = node.window == ui.mouse_window;
  if under && in_owner && (flags & .HOVERABLE) && node.depth < ui.hot_depth {
    ui.hot_key   = node.key;
    ui.hot_depth = node.depth;
  }
  return node;
}

ui_push_parent :: (node: *UI_Node) {
  array_add(*ui.parent_stack, node);
}

ui_pop_parent :: () {
  ui.parent_stack.count -= 1;
}

ui_signal :: (node: *UI_Node) -> UI_Signal {
  signal: UI_Signal;
  signal.hovered = ui.hot_key == node.key;
  signal.clicked = signal.hovered && ui.input.mouse_pressed;
  return signal;
}

ui_cache_get :: (key: u64) -> *UI_Node_Cache {
  cache: *UI_Node_Cache = table_find(*ui.caches, key);
  if !cache {
    cache = arena_new(*ui.persistent_arena, UI_Node_Cache);
    table_add(*ui.caches, key, cache);
  }
  cache.last_touched = ui.frame;
  return cache;
}

ui_end :: () {
  ui_pop_parent();
  emit(ui.root);

  for cache, key: ui.caches {
    if ui.frame - cache.last_touched > 240 {
      remove;
    }
  }

  ui.mouse_window = ui.next_mouse_window;
}

emit :: (node: *UI_Node) {
  cache:  *UI_Node_Cache = ui_cache_get(node.key);
  target: Vector4 = ifx ui.hot_key == node.key then node.params.hover else node.params.background;
  t:      float   = 1.0 - exp(-ui.input.dt * 10.0);
  cache.color += (target - cache.color) * t;

  quad: UI_Quad;
  quad.rect  = node.rect;
  quad.color = cache.color;
  array_add(*ui.quads, quad);

  child: *UI_Node = node.first;
  while child {
    emit(child);
    child = child.next;
  }
}

ui_button :: (text: string) -> UI_Signal {
  flags: UI_Node_Flags = .CLICKABLE | .HOVERABLE | .DRAW_TEXT;
  params: UI_Params;
  params.text       = text;
  params.size       = .{ 120, 30 };
  params.background = ui.theme.button;        // + part 6: style, copied from the theme
  params.hover      = ui.theme.button_hover;  // + part 6
  node: *UI_Node = ui_node(text, flags, params);
  return ui_signal(node);
}

// + part 6: a widget made of three nodes
ui_checkbox :: (text: string, value: *bool) -> bool {
  row_flags: UI_Node_Flags = .CLICKABLE | .HOVERABLE;
  row_params: UI_Params;
  row_params.axis = .X;                       // its children side by side
  row_params.size = .{ 200, 24 };
  row: *UI_Node = ui_node(text, row_flags, row_params);

  clicked: bool = ui_signal(row).clicked;
  if clicked {
    value.* = !value.*;
  }

  ui_push_parent(row);
    box_params: UI_Params;
    box_params.size       = .{ 24, 24 };
    box_params.background = ifx value.* then ui.theme.accent else ui.theme.button;
    ui_node("box", 0, box_params);

    label_params: UI_Params;
    label_params.text = text;
    label_params.size = .{ 176, 24 };
    ui_node("label", .DRAW_TEXT, label_params);
  ui_pop_parent();
  return clicked;
}
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
