// Widgets that edit a caller value return true on the frame it changed.

ui_textf :: (format: string, args: .. Any, loc := #caller_location) {
  ui_label(tprint(format, ..args), loc);
}

ui_label :: (text: string, loc := #caller_location) {
  params: UI_Params;
  params.text        = text;
  params.size.width  = .{ kind = .TEXT, value = 0.0 };
  params.size.height = .{ kind = .TEXT, value = ui.metrics.line_height * 0.15 };
  params.foreground  = ui_theme.text;
  params.name = "Label";
  ui_node(text, .DRAW_TEXT | .TEXT_CENTER_Y, params, loc);
}

ui_set_tooltip :: (text: string) {
  last_node := ui.last_node;
  if !last_node || text.count == 0        return;
  if last_node.key != ui.hover_key        return;
  if ui.hover_t < UI_TOOLTIP_DELAY        return;
  ui.tooltip_active = true;
  ui.tooltip_text   = ui_frame_copy_string(text);
  ui.tooltip_anchor = ui.input.mouse_pos;
}

ui_button :: (id: string, disabled := false, width_frac := 0.0, on_press := UI_ACTIVATE_ON_PRESS, loc := #caller_location) -> UI_Signal {
  params := ui_box_params(ui_theme.button, ui_theme.button_border);
  params.text             = id;
  params.padding          = ui.metrics.line_height * 0.5;
  params.foreground       = ui_theme.text;
  params.size.height      = UI_Size.{ kind = .TEXT, value = ui.metrics.line_height * 0.5 };
  if width_frac > 0.0 {
    params.size.width = UI_Size.{ kind = .PARENT_RATIO, value = width_frac };
  } else {
    params.size.width = UI_Size.{ kind = .TEXT, value = ui.metrics.line_height };
  }

  params.name = "Button";
  params.disabled = disabled;
  node := ui_node(id, .DRAW_TEXT | .TEXT_CENTER_Y | .HOVERABLE | .CLICKABLE, params, loc);
  signal := ui_signal_from_node(node);
  signal.clicked = ifx on_press then signal.pressed else signal.released;
  return signal;
}

ui_row_begin :: (id := "row", spacing := UI_GAP, padding := 0.0, left_indent := 0.0, loc := #caller_location) {
  parent := ui_parent();
  row_params: UI_Params;
  row_params.axis        = .X;
  row_params.spacing     = spacing;
  row_params.padding     = padding;
  row_params.offset.x    = left_indent;
  row_params.size.width  = ifx left_indent > 0.0 then UI_Size.{ kind = .PIXELS, value = max(1.0, parent.inner.size.x - left_indent) }
                                                 else UI_Size.{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(parent) };
  row_params.name = "Row";
  row := ui_node(id, "row", 0, row_params, loc);
  ui_push_parent(row);
}

ui_row_end :: () {
  ui_shrink_row_to_content(ui_pop_parent());
}

ui_columns :: (count: int, id := "cols", loc := #caller_location) {
  parent := ui_parent();
  row_params: UI_Params;
  row_params.axis        = .X;
  row_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(parent) };
  row_params.name = "Columns";
  row := ui_node(id, "cols", 0, row_params, loc);
  ui_push_parent(row);

  frame: Columns_Frame;
  frame.row        = row;
  frame.count      = max(count, 1);
  frame.cell_width = row.inner.size.x / cast(float) frame.count;
  frame.current    = 0;
  array_add(*ui.columns_stack, frame);

  columns_cell(row, frame.cell_width, 0, loc);
}

ui_next_column :: (loc := #caller_location) {
  ui_check(ui.columns_stack.count > 0, "Imgui: ui_next_column outside a ui_columns / ui_columns_end pair.");
  frame := *ui.columns_stack[ui.columns_stack.count - 1];
  ui_shrink_panel_to_content(ui_pop_parent());
  frame.current += 1;
  #if UI_DEBUG  assert(frame.current < frame.count, "Imgui: ui_next_column called more times than the column count");
  frame.row.cursor.y = frame.row.inner.pos.y; // each cell starts at the row top
  columns_cell(frame.row, frame.cell_width, frame.current, loc);
}

ui_columns_end :: () {
  ui_check(ui.columns_stack.count > 0, "Imgui: ui_columns_end without a matching ui_columns.");
  ui.columns_stack.count -= 1;
  ui_shrink_panel_to_content(ui_pop_parent());
  ui_shrink_row_to_content(ui_pop_parent());
}

ui_table_begin :: (id: string, columns: [] UI_Table_Column, loc := #caller_location) {
  panel_params: UI_Params;
  panel_params.axis             = .Y;
  panel_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  panel_params.size.height      = .{ kind = .PIXELS, value = ui_provisional_panel_height(ui_parent()) };
  panel_params.border           = ui_theme.window_border;
  panel_params.border_thickness = ui_theme.border_thickness;
  panel_params.corner_radius    = ui_theme.corner_radius;
  panel_params.name = "Table";
  panel := ui_node(id, "table", 0, panel_params, loc);
  cache := ui_cache_get(panel.key);
  ui_push_parent(panel);

  frame: Table_Frame;
  frame.panel = panel;
  frame.count = min(columns.count, UI_TABLE_MAX_COLUMNS);

  inner := max(1.0, panel.inner.size.x);

  if cache.table_ready {
    sum := 0.0;
    for 0..frame.count - 1  sum += cache.table_widths[it];
    scale := ifx sum > 1.0 then inner / sum else 1.0;
    for 0..frame.count - 1  frame.widths[it] = cache.table_widths[it] * scale;
  } else {
    fixed := 0.0;
    autos := 0;
    for 0..frame.count - 1 {
      if columns[it].width > 0.0  fixed += columns[it].width * inner;
      else                        autos += 1;
    }
    auto_width := ifx autos > 0 then max(1.0, (inner - fixed) / cast(float) autos) else 0.0;
    for 0..frame.count - 1  frame.widths[it] = ifx columns[it].width > 0.0 then columns[it].width * inner else auto_width;
  }

  header_height := ui_row_height();
  header_top    := panel.inner.pos.y;
  hot_boundary: [UI_TABLE_MAX_COLUMNS] bool;
  boundary_x := panel.inner.pos.x;
  for i: 0..frame.count - 2 {
    boundary_x += frame.widths[i];
    over := abs(ui.input.mouse_pos.x - boundary_x) <= 3.0
         && ui.input.mouse_pos.y >= header_top && ui.input.mouse_pos.y <= header_top + header_height;
    hot_boundary[i] = over && ui.table_resize_key == 0 && panel.panel == ui.mouse_panel;

    if hot_boundary[i] && ui.input.mouse_pressed[0] {
      ui.table_resize_key        = panel.key;
      ui.table_resize_col        = i;
      ui.table_resize_grab_mouse = ui.input.mouse_pos.x;
      ui.table_resize_grab_a     = frame.widths[i];
      ui.table_resize_grab_b     = frame.widths[i + 1];
    }
    if ui.table_resize_key == panel.key && ui.table_resize_col == i {
      total := ui.table_resize_grab_a + ui.table_resize_grab_b;
      a := clamp(ui.table_resize_grab_a + (ui.input.mouse_pos.x - ui.table_resize_grab_mouse), 24.0, total - 24.0);
      frame.widths[i]     = a;
      frame.widths[i + 1] = total - a;
      cache.table_widths[i]     = a;
      cache.table_widths[i + 1] = total - a;
    }
  }
  if !cache.table_ready {
    for 0..frame.count - 1  cache.table_widths[it] = frame.widths[it];
    cache.table_ready = true;
  }

  header_params: UI_Params;
  header_params.axis             = .X;
  header_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  header_params.size.height      = .{ kind = .PIXELS, value = header_height };
  header_params.background       = ui_theme.title_bar;
  header_params.border           = ui_theme.window_border;
  header_params.border_thickness = ui_theme.border_thickness;
  header := ui_node(id, "thead", 0, header_params, loc);
  ui_push_parent(header);
  for 0..frame.count - 1 {
    head_params: UI_Params;
    head_params.size.width  = .{ kind = .PIXELS, value = max(1.0, frame.widths[it]) };
    head_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
    head_params.padding     = UI_CONTROL_PADDING;
    head_params.text        = columns[it].name;
    head_params.foreground  = ui_theme.text;
    ui_node(id, "th", it, .DRAW_TEXT | .TEXT_CENTER_Y, head_params, loc);
  }
  boundary := 0.0;
  for i: 0..frame.count - 2 {
    boundary += frame.widths[i];
    active := ui.table_resize_key == panel.key && ui.table_resize_col == i;
    if !(hot_boundary[i] || active)  continue;
    tint: UI_Params;
    tint.offset            = .{ boundary - 1.0, 0.0 };
    tint.size.width        = .{ kind = .PIXELS, value = 2.0 };
    tint.size.height       = .{ kind = .PARENT_FRACTION, value = 1.0 };
    tint.background.normal  = ifx active then ui_theme.accent else ui_mix(ui_theme.window_border.normal, ui_theme.accent, 0.5);
    ui_node(id, "trh", i, .FLOATING, tint, loc);
  }
  ui_pop_parent();

  array_add(*ui.table_stack, frame);
}

ui_table_row :: (loc := #caller_location) {
  ui_check(ui.table_stack.count > 0, "Imgui: ui_table_row outside a ui_table_begin / ui_table_end pair.");
  frame := *ui.table_stack[ui.table_stack.count - 1];
  if frame.row {
    ui_shrink_panel_to_content(ui_pop_parent());
    ui_shrink_row_to_content(ui_pop_parent());
  }
  frame.row_seq += 1;
  frame.cell     = 0;

  row_params: UI_Params;
  row_params.axis        = .X;
  row_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(frame.panel) };
  frame.row = ui_node(frame.panel.label, "tr", frame.row_seq, 0, row_params, loc);
  ui_push_parent(frame.row);
  table_open_cell(frame, loc);
}

ui_table_cell :: (loc := #caller_location) {
  ui_check(ui.table_stack.count > 0, "Imgui: ui_table_cell outside a ui_table_begin / ui_table_end pair.");
  frame := *ui.table_stack[ui.table_stack.count - 1];
  ui_check(frame.row != null, "Imgui: ui_table_cell before the first ui_table_row.");
  ui_check(frame.cell + 1 < frame.count, "Imgui: ui_table_cell past the last column.");
  ui_shrink_panel_to_content(ui_pop_parent());
  frame.cell += 1;
  frame.row.cursor.y = frame.row.inner.pos.y; // each cell starts at the row top
  table_open_cell(frame, loc);
}

ui_table_end :: () {
  ui_check(ui.table_stack.count > 0, "Imgui: ui_table_end without a matching ui_table_begin.");
  frame := ui.table_stack[ui.table_stack.count - 1];
  ui.table_stack.count -= 1;
  if frame.row {
    ui_shrink_panel_to_content(ui_pop_parent());
    ui_shrink_row_to_content(ui_pop_parent());
  }
  panel := ui_pop_parent();
  ui_shrink_panel_to_content(panel);

  ui_push_parent(panel);
  x := 0.0;
  for i: 0..frame.count - 2 {
    x += frame.widths[i];
    line: UI_Params;
    line.offset             = .{ x, 0.0 };
    line.size.width         = .{ kind = .PIXELS, value = 1.0 };
    line.size.height        = .{ kind = .PIXELS, value = panel.rect.size.y };
    line.background.normal   = ui_theme.window_border.normal;
    line.background.normal.w = 0.5;
    ui_node(panel.label, "tsep", i, .FLOATING, line);
  }
  ui_pop_parent();
}

ui_separator :: (loc := #caller_location) {
  height := ui_separator_height();

  row_params: UI_Params;
  row_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height = .{ kind = .PIXELS, value = height };
  row_params.name = "Separator";
  row := ui_node("##__sep", 0, row_params, loc);

  ui_push_parent(row);
  line_params: UI_Params;
  line_params.offset             = .{ 0.0, floor(height * 0.5) };
  line_params.size.width         = .{ kind = .PARENT_FRACTION, value = 1.0 };
  line_params.size.height        = .{ kind = .PIXELS, value = 1.0 };
  line_params.background.normal   = ui_theme.window_border.normal;
  line_params.background.normal.w = 0.55;
  line_params.name = "line";
  ui_node("##__sepline", .FLOATING, line_params, loc);
  ui_pop_parent();
}

ui_spacing :: (amount := 0.0, loc := #caller_location) {
  gap := ifx amount > 0.0 then amount else floor(ui.metrics.line_height * 0.5);
  horizontal := ui_parent().params.axis == .X;
  params: UI_Params;
  params.render = false;
  if horizontal {
    params.size.width  = .{ kind = .PIXELS, value = gap };
    params.size.height = .{ kind = .PIXELS, value = 1.0 };
  } else {
    params.size.width  = .{ kind = .PIXELS, value = 1.0 };
    params.size.height = .{ kind = .PIXELS, value = gap };
  }
  params.name = "Spacing";
  ui_node("##__spacing", 0, params, loc);
}

ui_progress_bar :: (fraction: float, overlay := "", loc := #caller_location) {
  t     := clamp(fraction, 0.0, 1.0);
  inset := UI_SLIDER_INSET;

  track_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  track_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  track_params.size.height      = .{ kind = .PIXELS, value = ui_compact_height() };
  track_params.name = "Progress bar";
  track := ui_node("##__pbtrack", 0, track_params, loc);

  ui_push_parent(track);
  fill_params: UI_Params;
  fill_params.offset        = .{ inset, inset };
  fill_params.size.width    = .{ kind = .PIXELS, value = max(0.0, (track.rect.size.x - 2.0 * inset) * t) };
  fill_params.size.height   = .{ kind = .PIXELS, value = max(0.0, track.rect.size.y - 2.0 * inset) };
  fill_params.background    = ui_theme.slider_fill;
  fill_params.corner_radius = max(0.0, ui_theme.corner_radius - inset);
  fill_params.name = "fill";
  ui_node("##__pbfill", .FLOATING, fill_params, loc);

  overlay_text := overlay;
  if overlay_text.count == 0  overlay_text = tprint("% %", cast(int) floor(t * 100.0 + 0.5), "%");
  value_params: UI_Params;
  value_params.size.width  = .{ kind = .PIXELS, value = track.rect.size.x };
  value_params.size.height = .{ kind = .PIXELS, value = track.rect.size.y };
  value_params.text        = overlay_text;
  value_params.foreground  = ui_theme.text;
  value_params.name = "value";
  ui_node("##__pbval", .FLOATING | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, value_params, loc);
  ui_pop_parent();
}

ui_image :: (texture: UI_Texture, size: Vector2, tint := Vector4.{1,1,1,1},
             uv_min := Vector2.{0,0}, uv_max := Vector2.{1,1}, loc := #caller_location) {
  params: UI_Params;
  params.size.width        = .{ kind = .PIXELS, value = size.x };
  params.size.height       = .{ kind = .PIXELS, value = size.y };
  params.texture           = texture;
  params.uv_min            = uv_min;
  params.uv_max            = uv_max;
  params.foreground.normal = tint;
  params.name = "Image";
  ui_node("##__image", 0, params, loc);
}

ui_combo :: (id: string, selected: *int, items: [] string, disabled := false, loc := #caller_location) -> bool {
  cache := ui_cache_for(id, loc);
  current_label := ifx selected.* >= 0 && selected.* < items.count then items[selected.*] else "";

  changed := false;
  if ui_dropdown_begin(id, current_label, disabled, loc) {
    for item, index: items {
      ui_push_id(index);
      is_current := index == selected.*;
      if ui_selectable(item, *is_current, loc = loc) {
        if selected.* != index  { selected.* = index; changed = true; }
        cache.expanded = false;
      }
      ui_pop_id();
    }
  }
  ui_dropdown_end();
  return changed;
}

ui_group_begin :: (title: string, loc := #caller_location) {
  parent := ui_parent();
  group_params := ui_box_params(ui_theme.group_background, ui_theme.window_border);
  group_params.axis             = .Y;
  group_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  group_params.size.height      = .{ kind = .PIXELS, value = ui_provisional_panel_height(parent) };
  group_params.padding          = UI_PANEL_PADDING;
  group_params.spacing          = UI_STACK_SPACING;
  group_params.name = "Group";
  panel := ui_node(title, "group", 0, group_params, loc);
  ui_push_parent(panel);
  if title.count > 0 {
    ui_label(title, loc);
    ui_separator(loc);
  }
}
ui_group_end :: () {
  ui_shrink_panel_to_content(ui_pop_parent());
}

ui_slider :: (id: string, value: *$T, min_value: T, max_value: T, disabled := false, loc := #caller_location) -> bool {
  track := ui_slider_track_node(id, disabled, loc);
  span  := max_value - min_value;
  low    := min(min_value, max_value);
  high    := max(min_value, max_value);

  changed := false;
  if ui_signal_from_node(track).held && span != 0 {
    cursor_t := ui_slider_cursor_t(track);
    #if T == float  new_value := clamp(min_value + cursor_t * span, low, high);
    else            new_value := clamp(min_value + cast(T) floor(cursor_t * cast(float) span + 0.5), low, high);
    if new_value != value.*  { value.* = new_value;  changed = true; }
  }

  #if T == float {
    t       := ifx span != 0 then clamp((value.* - min_value) / span, 0.0, 1.0) else 0.0;
    shown   := floor(value.* * 100.0 + 0.5) / 100.0;
    display := tprint("%:  %", ui_display_label(id), shown);
  } else {
    t       := ifx span != 0 then clamp(cast(float) (value.* - low) / cast(float) (high - low), 0.0, 1.0) else 0.0;
    display := tprint("%:  %", ui_display_label(id), value.*);
  }
  ui_slider_decorate(track, id, t, display);
  return changed;
}

ui_drag_number :: (id: string, value: *$T, speed := 1.0, min_value: T = 0, max_value: T = 0, width_frac := 0.0, disabled := false, loc := #caller_location) -> bool
#modify {
  info := cast(*Type_Info) T;
  if info.type != .INTEGER && info.type != .FLOAT  return false, "ui_drag_number: T must be an int or float type";
  return true;
}
{
  box_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  box_params.size.width       = ifx width_frac > 0.0 then UI_Size.{ kind = .PARENT_RATIO, value = width_frac }
                                                     else UI_Size.{ kind = .PARENT_FRACTION, value = 1.0 };
  box_params.size.height      = .{ kind = .PIXELS, value = ui_row_height() };
  box_params.name = "Drag number";
  box_params.disabled = disabled;
  box    := ui_node(id, .CLICKABLE | .HOVERABLE, box_params, loc);
  cache  := ui_cache_get(box.key);
  signal := ui_signal_from_node(box);

  changed := false;
  if signal.pressed  cache.drag_accumulator = 0.0;
  if signal.held && ui.input.mouse_delta.x != 0.0 {
    cache.drag_accumulator += ui.input.mouse_delta.x * speed;
    #if T == float {
      if cache.drag_accumulator != 0.0 {
        value.* += cast(T) cache.drag_accumulator;
        cache.drag_accumulator = 0.0;
        changed = true;
      }
    } else {
      step := cast(int) cache.drag_accumulator;
      if step != 0 {
        value.* += cast(T) step;
        cache.drag_accumulator -= cast(float) step;
        changed = true;
      }
    }
    if min_value < max_value  value.* = clamp(value.*, min_value, max_value);
  }

  #if T == float  shown := tprint("%:  %", ui_display_label(id), floor(value.* * 100.0 + 0.5) / 100.0);
  else            shown := tprint("%:  %", ui_display_label(id), value.*);

  ui_push_parent(box);
  text_params: UI_Params;
  text_params.size.width  = .{ kind = .PIXELS, value = box.rect.size.x };
  text_params.size.height = .{ kind = .PIXELS, value = box.rect.size.y };
  text_params.text        = shown;
  text_params.foreground  = ui_theme.text;
  ui_node(id, "dragtext", .FLOATING | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, text_params, loc);
  ui_pop_parent();

  return changed;
}

ui_drag_floats :: (id: string, components: [] float, speed := 0.01, min_value := 0.0, max_value := 0.0, disabled := false, loc := #caller_location) -> bool {
  changed := false;
  ui_row_begin(id, spacing = UI_GAP, loc = loc);
    ui_label(ui_display_label(id), loc);
    frac := 1.0 / cast(float) max(components.count, 1);
    for * component, i: components {
      ui_push_id(i);
      if ui_drag_number("c", component, speed, min_value, max_value, width_frac = frac, disabled = disabled, loc = loc)  changed = true;
      ui_pop_id();
    }
  ui_row_end();
  return changed;
}

ui_slider_floats :: (id: string, components: [] float, min_value: float, max_value: float, disabled := false, loc := #caller_location) -> bool {
  axes :: string.[ "X", "Y", "Z", "W" ];
  changed := false;
  ui_label(ui_display_label(id), loc);
  for * component, i: components {
    ui_push_id(i);
    if ui_slider(axes[min(i, axes.count - 1)], component, min_value, max_value, disabled, loc)  changed = true;
    ui_pop_id();
  }
  return changed;
}

ui_checkbox :: (id: string, value: *bool, disabled := false, loc := #caller_location) -> bool {
  spacing    := UI_GAP;
  row_height := ui_compact_height();
  text_width, _ := ui_measure_display(id);

  row_params: UI_Params;
  row_params.axis        = .X;
  row_params.spacing     = spacing;
  row_params.size.width  = .{ kind = .PIXELS, value = row_height + spacing + text_width + 4.0 };
  row_params.size.height = .{ kind = .PIXELS, value = row_height };
  row_params.name = "Checkbox";
  row_params.disabled = disabled;
  row := ui_node(id, .CLICKABLE | .HOVERABLE, row_params, loc);
  signal := ui_signal_from_node(row);

  toggled := signal.clicked;
  if toggled  value.* = !value.*;

  ui_push_parent(row);

  box_height := row.inner.size.y;
  box_params := ui_box_params(ui_pick_set(ui_theme.button, signal.hovered, signal.held), ui_theme.button_border);
  box_params.size.width       = .{ kind = .PIXELS, value = box_height };
  box_params.size.height      = .{ kind = .PIXELS, value = box_height };
  box_params.padding          = UI_BOX_PADDING;
  box := ui_node(id, "box", 0, box_params, loc);

  if value.* {
    ui_push_parent(box);
    check_params: UI_Params;
    check_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    check_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
    check_params.foreground  = ui_theme.text;
    ui_icon_node(id, "chk", check_params, .CHECK, loc = loc);
    ui_pop_parent();
  }

  ui_row_label(id, "lbl", id, .{ kind = .TEXT, value = 0.0 }, loc = loc);

  ui_pop_parent();
  return toggled;
}

ui_toggle :: (id: string, value: *bool, disabled := false, loc := #caller_location) -> bool {
  spacing     := UI_GAP;
  row_height  := ui_compact_height();
  track_width := floor(row_height * 1.8);
  text_width, _ := ui_measure_display(id);

  row_params: UI_Params;
  row_params.axis        = .X;
  row_params.spacing     = spacing;
  row_params.disabled    = disabled;
  row_params.size.width  = .{ kind = .PIXELS, value = track_width + spacing + text_width + 4.0 };
  row_params.size.height = .{ kind = .PIXELS, value = row_height };
  row_params.name = "Toggle";
  row := ui_node(id, .CLICKABLE | .HOVERABLE, row_params, loc);
  signal := ui_signal_from_node(row);

  toggled := signal.clicked;
  if toggled  value.* = !value.*;

  cache  := ui_cache_get(row.key);
  target := ifx value.* then 1.0 else 0.0;
  if !cache.disclosure_ready {
    cache.disclosure_ready = true;
    cache.disclosure_t     = target;
  }
  cache.disclosure_t += (target - cache.disclosure_t) * ui_animation_t(ui.input.dt);

  ui_push_parent(row);

  track_height := row.inner.size.y;
  fill := ui_mix(ui_theme.slider_track.normal, ui_theme.slider_fill.normal, cache.disclosure_t);
  track_params := ui_box_params(ui_pick_set(.{ normal = fill }, signal.hovered, signal.held), ui_theme.button_border);
  track_params.size.width    = .{ kind = .PIXELS, value = track_width };
  track_params.size.height   = .{ kind = .PIXELS, value = track_height };
  track_params.corner_radius = track_height * 0.5;
  track := ui_node(id, "track", 0, track_params, loc);

  ui_push_parent(track);
    inset := 3.0;
    knob  := max(0.0, track_height - 2.0 * inset);
    knob_params: UI_Params;
    knob_params.offset            = .{ inset + (track_width - knob - 2.0 * inset) * cache.disclosure_t, inset };
    knob_params.size.width        = .{ kind = .PIXELS, value = knob };
    knob_params.size.height       = .{ kind = .PIXELS, value = knob };
    knob_params.background.normal = ui_theme.text.normal;
    knob_params.corner_radius     = knob * 0.5;
    ui_node(id, "knob", .FLOATING, knob_params, loc);
  ui_pop_parent();

  ui_row_label(id, "lbl", id, .{ kind = .TEXT, value = 0.0 }, loc = loc);

  ui_pop_parent();
  return toggled;
}

ui_selectable :: (label: string, value: *bool, disabled := false, loc := #caller_location) -> bool {
  line_height := ui.metrics.line_height;

  params: UI_Params;
  params.axis          = .X;
  params.padding       = floor(line_height * 0.35);
  params.size.width    = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.size.height   = .{ kind = .PIXELS, value = ui_row_height() };
  params.text          = label;
  params.foreground    = ui_theme.text;
  params.corner_radius = ui_theme.corner_radius;
  params.animate       = true;
  if value.* {
    params.background.normal = ui_theme.slider_fill.normal;
  } else {
    hover_fill := ui_theme.button.normal;  hover_fill.w = 0.5;
    params.background.hover  = hover_fill;
    params.background.active = hover_fill;
  }
  params.name = "Selectable";
  params.disabled = disabled;
  node := ui_node(label, .DRAW_TEXT | .TEXT_CENTER_Y | .CLICKABLE | .HOVERABLE, params, loc);
  signal := ui_signal_from_node(node);
  if signal.clicked  value.* = !value.*;
  return signal.clicked;
}

ui_list_box :: (id: string, selected: *int, items: [] string, visible_rows := 6, disabled := false, loc := #caller_location) -> bool {
  overflowing := ui_cache_get(ui_scoped_key(id, loc)).scroll_max > 0.5;

  panel_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  panel_params.axis             = .Y;
  panel_params.padding          = UI_BOX_PADDING;
  panel_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  panel_params.size.height      = .{ kind = .PIXELS, value = ui_row_height() * cast(float) max(visible_rows, 1) + 4.0 };
  if overflowing  panel_params.pad_right = UI_SCROLLBAR_W + 4.0;
  panel_params.name = "List box";
  panel_params.disabled = disabled;
  panel := ui_node(id, .SCROLL_Y, panel_params, loc);
  cache := ui_cache_get(panel.key);

  changed := false;
  ui_push_parent(panel);
  for item, i: items {
    ui_push_id(i);
    row_selected := i == selected.*;
    if ui_selectable(item, *row_selected, loc = loc) && selected.* != i {
      selected.* = i;
      changed = true;
    }
    ui_pop_id();
  }
  ui_pop_parent();

  ui_scrollbar(panel, cache);
  return changed;
}

ui_radio :: (id: string, selected: *int, index: int, disabled := false, loc := #caller_location) -> bool {
  spacing    := UI_GAP;
  row_height := ui_compact_height();

  row_params: UI_Params;
  row_params.axis        = .X;
  row_params.spacing     = spacing;
  row_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height = .{ kind = .PIXELS, value = row_height };
  row_params.name = "Radio";
  row_params.disabled = disabled;
  row := ui_node(id, .CLICKABLE | .HOVERABLE, row_params, loc);
  signal := ui_signal_from_node(row);

  changed := signal.clicked && selected.* != index;
  if signal.clicked  selected.* = index;

  ui_push_parent(row);

  box_height := row.inner.size.y;
  box_params := ui_box_params(ui_pick_set(ui_theme.button, signal.hovered, signal.held), ui_theme.button_border);
  box_params.size.width       = .{ kind = .PIXELS, value = box_height };
  box_params.size.height      = .{ kind = .PIXELS, value = box_height };
  box_params.padding          = UI_BOX_PADDING;
  box_params.corner_radius    = box_height * 0.5;
  box := ui_node(id, "box", 0, box_params, loc);

  ui_selection_mark(box, id, .CIRCLE, ui_theme.slider_fill, selected.* == index);

  ui_row_label(id, "lbl", id, loc = loc);

  ui_pop_parent();
  return changed;
}

ui_dropdown_begin :: (id: string, preview: string, disabled := false, loc := #caller_location) -> opened: bool {
  box_height  := ui_row_height();

  header_params := ui_box_params(ui_theme.button, ui_theme.button_border);
  header_params.axis             = .X;
  header_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  header_params.size.height      = .{ kind = .PIXELS, value = box_height };
  header_params.padding          = UI_CONTROL_PADDING;
  header_params.name = "Dropdown";
  header_params.disabled = disabled;
  header := ui_node(id, .CLICKABLE | .HOVERABLE, header_params, loc);
  signal := ui_signal_from_node(header);

  cache := ui_cache_for(id, loc);
  if signal.clicked  cache.expanded = !cache.expanded;
  open := cache.expanded;

  ui_push_parent(header);
  ui_row_label(id, "preview", preview, .{ kind = .PIXELS, value = max(0.0, header.inner.size.x - header.inner.size.y) }, loc = loc);

  chevron_params: UI_Params;
  chevron_params.size.width  = .{ kind = .PIXELS, value = header.inner.size.y };
  chevron_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  chevron_params.foreground  = ui_theme.text;
  ui_icon_node(id, "chev", chevron_params, ifx open then UI_Icon.CHEVRON_UP else .CHEVRON_DOWN, loc = loc);
  ui_pop_parent();

  return ui_popup_begin(id, open, cache, header.rect, header.rect.size.x, ui_row_height() * cast(float) UI_DROPDOWN_MAX_ROWS + 8.0, loc);
}

ui_dropdown_end :: () {
  ui_popup_end();
}

ui_dropdown_item :: (id: string, selected: *int, index: int, disabled := false, loc := #caller_location) -> bool {
  owner := ui_popup_owner();
  row_height := ui_row_height();

  row_params: UI_Params;
  row_params.axis          = .X;
  row_params.padding       = UI_CONTROL_PADDING;
  row_params.spacing       = UI_GAP;
  row_params.size.width    = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height   = .{ kind = .PIXELS, value = row_height };
  row_params.background    = ui_theme.button;
  row_params.corner_radius = ui_theme.corner_radius;
  row_params.animate       = true;
  row_params.name = "Dropdown item";
  row_params.disabled = disabled;
  row := ui_node(id, .CLICKABLE | .HOVERABLE, row_params, loc);
  signal := ui_signal_from_node(row);

  changed := signal.clicked && selected.* != index;
  if signal.clicked {
    selected.* = index;
    if owner  owner.expanded = false;
  }

  mark_width := row.inner.size.y;
  ui_push_parent(row);
  ui_row_label(id, "lbl", id, .{ kind = .PIXELS, value = max(0.0, row.inner.size.x - mark_width - 6.0) }, loc = loc);
  ui_pop_parent();

  ui_selection_mark(row, id, .CHECK, ui_theme.text, selected.* == index);
  return changed;
}

// Returns whether to build the body: while open, and while the close animation plays.
ui_collapsing_header :: (id: string, default_open := true, disabled := false, loc := #caller_location) -> bool {
  parent := ui_parent();
  row_height  := ui_row_height();

  cache := ui_cache_for(id, loc);
  if !cache.disclosure_ready {
    cache.disclosure_ready = true;
    cache.expanded         = default_open;
    cache.disclosure_t     = ifx default_open then 1.0 else 0.0;
  }

  header_params := ui_box_params(ui_theme.button, ui_theme.button_border);
  header_params.axis             = .X;
  header_params.spacing          = UI_STACK_SPACING;
  header_params.padding          = UI_CONTROL_PADDING;
  header_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  header_params.size.height      = .{ kind = .PIXELS, value = row_height };
  header_params.name = "Collapsing header";
  header_params.disabled = disabled;
  header := ui_node(id, .CLICKABLE | .HOVERABLE, header_params, loc);
  if ui_signal_from_node(header).clicked  cache.expanded = !cache.expanded;

  ui_push_parent(header);
  chevron_params: UI_Params;
  chevron_params.size.width  = .{ kind = .PIXELS, value = header.inner.size.y };
  chevron_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  chevron_params.foreground  = ui_theme.text;
  ui_icon_node(id, "chev", chevron_params, ifx cache.expanded then UI_Icon.CHEVRON_DOWN else .CHEVRON_RIGHT, loc = loc);

  ui_row_label(id, "lbl", id, loc = loc);
  ui_pop_parent();

  {
    dt     := ui_animation_t(ui.input.dt);
    target := ifx cache.expanded then 1.0 else 0.0;
    cache.disclosure_t += (target - cache.disclosure_t) * dt;
    if abs(cache.disclosure_t - target) < 0.001  cache.disclosure_t = target;
  }

  open := cache.expanded || cache.disclosure_t > 0.001;

  frame: Collapse_Frame;
  frame.open  = open;
  frame.owner = cache;

  if open {
    padding    := UI_PANEL_PADDING;
    have_height := cache.disclosure_height > 0.0;
    body_height := ifx have_height then max(1.0, cache.disclosure_height * cache.disclosure_t)
                                   else ui_provisional_panel_height(parent);

    body_params: UI_Params;
    body_params.axis          = .Y;
    body_params.padding       = padding;
    body_params.spacing       = UI_STACK_SPACING;
    body_params.size.width    = .{ kind = .PARENT_FRACTION, value = 1.0 };
    body_params.size.height   = .{ kind = .PIXELS, value = body_height };
    body_params.background    = ui_theme.group_background;
    body_params.corner_radius = ui_theme.corner_radius;
    body := ui_node(id, "cbody", 0, body_params, loc);
    frame.body = body;
    ui_push_parent(body);
  }

  array_add(*ui.collapse_stack, frame);
  return open;
}

ui_collapsing_end :: () {
  ui_check(ui.collapse_stack.count > 0, "Imgui: ui_collapsing_end without a matching ui_collapsing_header.");
  frame := ui.collapse_stack[ui.collapse_stack.count - 1];
  ui.collapse_stack.count -= 1;
  if !frame.open  return;

  body := ui_pop_parent();

  used := max(0.0, body.cursor.y - body.inner.pos.y - body.params.spacing);
  frame.owner.disclosure_height = used + 2.0 * body.params.padding;
}

ui_tree_node :: (label: string, default_open := false, disabled := false, loc := #caller_location) -> bool {
  parent      := ui_parent();
  line_height := ui.metrics.line_height;
  row_height  := ui_compact_height();

  cache := ui_cache_for(label, loc);
  if !cache.disclosure_ready {
    cache.disclosure_ready = true;
    cache.expanded         = default_open;
  }

  hover_fill := ui_theme.button.normal;
  hover_fill.w = 0.5;

  row_params: UI_Params;
  row_params.axis             = .X;
  row_params.spacing          = UI_STACK_SPACING;
  row_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height      = .{ kind = .PIXELS, value = row_height };
  row_params.background.hover  = hover_fill;
  row_params.background.active = hover_fill;
  row_params.corner_radius    = ui_theme.corner_radius;
  row_params.animate          = true;
  row_params.name = "Tree node";
  row_params.disabled = disabled;
  row := ui_node(label, .CLICKABLE | .HOVERABLE, row_params, loc);
  if ui_signal_from_node(row).clicked  cache.expanded = !cache.expanded;

  ui_push_parent(row);
  chevron_params: UI_Params;
  chevron_params.size.width  = .{ kind = .PIXELS, value = row.inner.size.y };
  chevron_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  chevron_params.foreground  = ui_theme.text;
  ui_icon_node(label, "tchev", chevron_params, ifx cache.expanded then UI_Icon.CHEVRON_DOWN else .CHEVRON_RIGHT, loc = loc);

  ui_row_label(label, "tlbl", label, loc = loc);
  ui_pop_parent();

  frame: Tree_Frame;
  frame.open = cache.expanded;
  if frame.open {
    indent := ui_tree_indent();
    child_params: UI_Params;
    child_params.axis        = .Y;
    child_params.spacing     = UI_TIGHT_SPACING;
    child_params.offset.x    = indent;
    child_params.size.width  = .{ kind = .PIXELS, value = max(1.0, parent.inner.size.x - indent) };
    child_params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(parent) };
    frame.container = ui_node(label, "tchild", 0, child_params, loc);
    ui_push_parent(frame.container);
  }

  array_add(*ui.tree_stack, frame);
  return frame.open;
}

ui_tree_pop :: () {
  ui_check(ui.tree_stack.count > 0, "Imgui: ui_tree_pop without a matching ui_tree_node.");
  frame := ui.tree_stack[ui.tree_stack.count - 1];
  ui.tree_stack.count -= 1;
  if frame.open  ui_shrink_panel_to_content(ui_pop_parent());
}

ui_tree_leaf :: (label: string, loc := #caller_location) {
  indent := ui_tree_indent();
  params: UI_Params;
  params.offset.x    = indent;
  params.size.width  = .{ kind = .PIXELS, value = max(1.0, ui_parent().inner.size.x - indent) };
  params.size.height = .{ kind = .TEXT, value = ui.metrics.line_height * 0.3 };
  params.text        = label;
  params.foreground  = ui_theme.text;
  params.name = "Tree leaf";
  ui_node(label, .DRAW_TEXT | .TEXT_CENTER_Y, params, loc);
}

ui_context_menu_begin :: (id: string, loc := #caller_location) -> bool {
  parent := ui_parent();
  cache  := ui_cache_for(id, loc);
  if ui.input.mouse_pressed[1] && parent.panel == ui.mouse_panel && rect_contains(parent.clip, ui.input.mouse_pos) {
    cache.expanded    = true;
    cache.menu_anchor = ui.input.mouse_pos;
  }
  return ui_popup_begin(id, cache.expanded, cache, .{ cache.menu_anchor, .{ 0, 0 } }, ui_menu_width(), loc = loc);
}

ui_context_menu_end :: () {
  ui_popup_end();
}

ui_menu_item :: (label: string, disabled := false, loc := #caller_location) -> bool {
  owner := ui_popup_owner();

  row_params: UI_Params;
  row_params.axis          = .X;
  row_params.padding       = UI_CONTROL_PADDING;
  row_params.size.width    = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height   = .{ kind = .PIXELS, value = ui_row_height() };
  row_params.text          = label;
  row_params.foreground    = ui_theme.text;
  row_params.background    = ui_theme.button;
  row_params.corner_radius = ui_theme.corner_radius;
  row_params.animate       = true;
  row_params.name = "Menu item";
  row_params.disabled = disabled;
  row := ui_node(label, .DRAW_TEXT | .TEXT_CENTER_Y | .CLICKABLE | .HOVERABLE, row_params, loc);
  signal := ui_signal_from_node(row);
  if signal.clicked && owner  owner.expanded = false;
  return signal.clicked;
}

ui_menu_toggle :: (label: string, value: *bool, disabled := false, loc := #caller_location) -> bool {
  owner := ui_popup_owner();

  row_params: UI_Params;
  row_params.axis          = .X;
  row_params.padding       = UI_CONTROL_PADDING;
  row_params.spacing       = UI_GAP;
  row_params.size.width    = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height   = .{ kind = .PIXELS, value = ui_row_height() };
  row_params.background    = ui_theme.button;
  row_params.corner_radius = ui_theme.corner_radius;
  row_params.animate       = true;
  row_params.name = "Menu toggle";
  row_params.disabled = disabled;
  row := ui_node(label, .CLICKABLE | .HOVERABLE, row_params, loc);
  signal := ui_signal_from_node(row);
  if signal.clicked {
    value.* = !value.*;
    if owner  owner.expanded = false;
  }

  ui_push_parent(row);
    check_params: UI_Params;
    check_params.size.width  = .{ kind = .PIXELS, value = row.inner.size.y };
    check_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
    check_params.foreground  = ui_theme.text;
    check_params.opacity     = ifx value.* then 1.0 else 0.0001;
    ui_icon_node(label, "mtck", check_params, .CHECK, loc = loc);

    ui_row_label(label, "mtlbl", label, loc = loc);
  ui_pop_parent();

  return signal.clicked;
}

ui_menu_separator :: (loc := #caller_location) {
  height := ui_separator_height();
  row_params: UI_Params;
  row_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height = .{ kind = .PIXELS, value = height };
  row_params.name = "Separator";
  row := ui_node("##__msep", 0, row_params, loc);

  ui_push_parent(row);
    line_params: UI_Params;
    line_params.offset             = .{ 3.0, floor(height * 0.5) };
    line_params.size.width         = .{ kind = .PIXELS, value = max(1.0, row.inner.size.x - 6.0) };
    line_params.size.height        = .{ kind = .PIXELS, value = 1.0 };
    line_params.background.normal   = ui_theme.window_border.normal;
    line_params.background.normal.w = 0.5;
    line_params.name = "line";
    ui_node("##__msepline", .FLOATING, line_params, loc);
  ui_pop_parent();
}

ui_color_edit :: (id: string, color: *Vector4, disabled := false, loc := #caller_location) -> bool {
  cache := ui_cache_for(id, loc);
  row_height := ui_row_height();

  ui_row_begin(id, loc = loc);
    swatch_params: UI_Params;
    swatch_params.size.width        = .{ kind = .PIXELS, value = row_height };
    swatch_params.size.height       = .{ kind = .PIXELS, value = row_height };
    swatch_params.background.normal = .{ color.x, color.y, color.z, 1.0 };
    swatch_params.background.hover  = swatch_params.background.normal;
    swatch_params.background.active = swatch_params.background.normal;
    swatch_params.border           = ui_theme.button_border;
    swatch_params.border_thickness = ui_theme.border_thickness;
    swatch_params.corner_radius    = ui_theme.corner_radius;
    swatch_params.disabled         = disabled;
    swatch := ui_node(id, "sw", .CLICKABLE | .HOVERABLE, swatch_params, loc);
    if ui_signal_from_node(swatch).clicked  cache.expanded = !cache.expanded;

    label_params: UI_Params;
    label_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
    label_params.size.height = .{ kind = .PIXELS, value = row_height };
    label_params.text        = id;
    label_params.foreground  = ui_theme.text;
    label_params.disabled    = disabled;
    label := ui_node(id, "celbl", .DRAW_TEXT | .TEXT_CENTER_Y | .CLICKABLE | .HOVERABLE, label_params, loc);
    if ui_signal_from_node(label).clicked  cache.expanded = !cache.expanded;
  ui_row_end();

  changed := false;
  if cache.expanded {
    if ui_slider("R", *color.x, 0.0, 1.0, disabled, loc)  changed = true;
    if ui_slider("G", *color.y, 0.0, 1.0, disabled, loc)  changed = true;
    if ui_slider("B", *color.z, 0.0, 1.0, disabled, loc)  changed = true;
    if ui_slider("A", *color.w, 0.0, 1.0, disabled, loc)  changed = true;
  }
  return changed;
}

ui_style_window :: (open: *bool) {
  if !open.*  return;

  ui_window_begin("Style", open, 1310, 40, 280, 400);

  theme_names: [..] string;
  theme_names.allocator = ui_frame_allocator();
  for ui_palettes  array_add(*theme_names, it.name);

  ui_label("Theme");
  if ui_combo("Theme##sw", *style_theme_index, theme_names) {
    ui_set_theme(ui_theme_from_palette(ui_palettes[style_theme_index]));
  }

  ui_separator();
  ui_label("Colours (live, not saved)");
  ui_color_edit("Window background", *ui_theme.window_background.normal);
  ui_color_edit("Title bar",         *ui_theme.title_bar.normal);
  ui_color_edit("Text",              *ui_theme.text.normal);
  ui_color_edit("Button",            *ui_theme.button.normal);
  ui_color_edit("Border",            *ui_theme.window_border.normal);
  ui_color_edit("Accent",            *ui_theme.accent);
  ui_color_edit("Slider fill",       *ui_theme.slider_fill.normal);
  ui_color_edit("Group background",  *ui_theme.group_background.normal);
  ui_color_edit("Danger",            *ui_theme.danger.normal);

  ui_separator();
  ui_label("Metrics");
  ui_slider("Corner radius",    *ui_theme.corner_radius,    0.0, 12.0);
  ui_slider("Border thickness", *ui_theme.border_thickness, 0.0, 4.0);
  ui_slider("Window shadow",    *ui_theme.window_shadow,    0.0, 30.0);
  ui_slider("Transition speed", *ui_theme.transition_speed, 1.0, 40.0);

  ui_window_end();
}

ui_inspect :: (name: string, value: Any, editable := false, depth := 0, loc := #caller_location) {
  info := value.type;
  if !info || depth >= UI_INSPECT_MAX_DEPTH {
    ui_tree_leaf(tprint("%:  ...", name), loc);
    return;
  }

  if info.type == .STRUCT {
    struct_info := cast(*Type_Info_Struct) info;
    inline_struct := !editable && (struct_info.name == "Vector2" || struct_info.name == "Vector3"
                  || struct_info.name == "Vector4" || struct_info.name == "Quaternion" || struct_info.name == "Apollo_Time");
    if inline_struct || struct_info.members.count == 0 {
      ui_tree_leaf(tprint("%:  %", name, value), loc);
      return;
    }
    if ui_tree_node(name, default_open = depth < 1, loc = loc) {
      for member: struct_info.members {
        if member.flags & .CONSTANT  continue;
        member_any: Any;
        member_any.type          = member.type;
        member_any.value_pointer = cast(*u8) value.value_pointer + member.offset_in_bytes;
        ui_push_id(member.name);
        ui_inspect(member.name, member_any, editable, depth + 1, loc);
        ui_pop_id();
      }
    }
    ui_tree_pop();
    return;
  }

  if !editable {
    ui_tree_leaf(tprint("%:  %", name, value), loc);
    return;
  }

  if info.type == .BOOL {
    ui_row_begin(name, left_indent = ui_tree_indent(), loc = loc);
      ui_checkbox(name, cast(*bool) value.value_pointer, loc = loc);
    ui_row_end();
    return;
  }
  if info.type == .ENUM {
    enum_info := cast(*Type_Info_Enum) info;
    if enum_info.names.count == 0 { ui_tree_leaf(tprint("%:  %", name, value), loc); return; }
    int_size := enum_info.internal_type.runtime_size;
    signed   := enum_info.internal_type.signed;
    current_value := ui_read_int(value.value_pointer, int_size, signed);
    current_index := 0;
    for enum_info.values  if it == current_value  { current_index = it_index; break; }
    index := current_index;
    ui_row_begin(name, left_indent = ui_tree_indent(), loc = loc);
      ui_label(name);
      ui_combo(name, *index, enum_info.names, loc = loc);
    ui_row_end();
    if index != current_index && index >= 0 && index < enum_info.values.count
      ui_write_int(value.value_pointer, int_size, enum_info.values[index]);
    return;
  }
  if info.type == .INTEGER || info.type == .FLOAT {
    pointer := value.value_pointer;
    size    := info.runtime_size;
    ui_row_begin(name, left_indent = ui_tree_indent(), loc = loc);
      ui_label(name);
      if info.type == .FLOAT {
        if size == 8  ui_number_field(name, cast(*float64) pointer, loc = loc);
        else          ui_number_field(name, cast(*float)   pointer, loc = loc);
      } else if (cast(*Type_Info_Integer) info).signed {
        if      size == 1  ui_number_field(name, cast(*s8)  pointer, loc = loc);
        else if size == 2  ui_number_field(name, cast(*s16) pointer, loc = loc);
        else if size == 4  ui_number_field(name, cast(*s32) pointer, loc = loc);
        else               ui_number_field(name, cast(*s64) pointer, loc = loc);
      } else {
        if      size == 1  ui_number_field(name, cast(*u8)  pointer, loc = loc);
        else if size == 2  ui_number_field(name, cast(*u16) pointer, loc = loc);
        else if size == 4  ui_number_field(name, cast(*u32) pointer, loc = loc);
        else               ui_number_field(name, cast(*u64) pointer, loc = loc);
      }
    ui_row_end();
    return;
  }

  ui_tree_leaf(tprint("%:  %", name, value), loc);
}

ui_window_begin :: (id: string, open: *bool, x: float, y: float, w: float, h: float, options: UI_Window_Flags = 0, initial_dock := UI_Dock.NONE, loc := #caller_location) -> UI_Signal {
  window_key   := ui_child_key(id, "window", loc);
  window_cache := ui_cache_get(window_key);
  window_cache.options = options;

  if initial_dock != .NONE && !window_cache.dock_seeded {
    window_cache.dock_seeded = true;
    window_cache.dock        = initial_dock;
    window_cache.dock_t      = 1.0;
  }

  // The parent's padded content area: children are clipped to it, so docking and
  // clamping to the full rect would push a docked window's edges under the padding.
  region := ui_parent().inner;

  layout := window_resolve_layout(window_key, window_cache, region, x, y, w, h, options);
  window_cache.saved_next_depth = ui.next_depth;
  window := window_frame_node(id, window_key, region, layout, loc);
  ui_push_parent(window);

  focused := ui_window_is_focused(window_key);

  signal: UI_Signal;
  signal.node      = window;
  signal.dragging  = ui.drag_panel_key == window_key;
  signal.resizing  = ui.resizing_key   == window_key;
  signal.focused   = focused;
  signal.docked    = layout.docked;
  signal.minimized = window_cache.minimized;
  signal.close     = window_cache.closing && window_cache.close_t >= 1.0;
  if open && signal.close  open.* = false;

  chrome_height := window_title_bar(id, window, window_cache, focused, options, loc);
  window_body_begin(id, ui_child_key(id, "body", loc), window, chrome_height, focused, loc);
  return signal;
}

ui_window_end :: () {
  body   := ui_pop_parent();
  window := ui_parent();
  window_cache := ui_cache_get(window.key);

  ui_scrollbar(body, ui_cache_get(body.key));

  dock_animating := (window_cache.dock != .NONE && window_cache.dock_t < 0.999) || (window_cache.dock == .NONE && window_cache.dock_t > 0.001);
  resize_ready := window_cache.minimize_t <= 0.001 && !dock_animating;

  if resize_ready && !(window_cache.options & .NO_RESIZE) {
    grip_origin := Vector2.{ window.rect.size.x - UI_RESIZE_HANDLE, window.rect.size.y - UI_RESIZE_HANDLE };
    grip_rect   := UI_Rect.{ window.rect.pos + grip_origin, .{ UI_RESIZE_HANDLE, UI_RESIZE_HANDLE } };
    front       := ui_window_is_focused(window.key);
    resizing    := ui.resizing_key == window.key || ui.resize_cand_key == window.key;

    grip_color := ui_theme.handle;
    if resizing                                                    grip_color = ui_theme.accent;
    else if front && rect_contains(grip_rect, ui.input.mouse_pos)  grip_color = ui_mix(ui_theme.handle, ui_theme.accent, 0.6);

    grip_params: UI_Params;
    grip_params.offset      = grip_origin;
    grip_params.size.width  = .{ kind = .PIXELS, value = UI_RESIZE_HANDLE };
    grip_params.size.height = .{ kind = .PIXELS, value = UI_RESIZE_HANDLE };
    grip_params.animate     = true;
    grip_params.foreground.normal = grip_color;
    ui_icon_node(window.label, "resize", grip_params, .RESIZE_GRIP, .FLOATING);
  }

  if resize_ready && !(window_cache.options & .NO_RESIZE) && ui.resizing_key == 0 && ui.drag_panel_key == 0 {
    front := ui_window_is_focused(window.key);
    edge  := ifx front then ui_resize_edge_at(window.rect, ui.input.mouse_pos) else cast(u32) 0;
    if edge != 0 {
      hint_color := ui_theme.handle;
      hint_color.w = 0.6;
      thickness := 2.0;
      window_width  := window.rect.size.x;
      window_height := window.rect.size.y;

      bar :: (name: string, offset_x: float, offset_y: float, w: float, h: float) #expand {
        bar_params: UI_Params;
        bar_params.offset    = .{ offset_x, offset_y };
        bar_params.size.width   = .{ kind = .PIXELS, value = w };
        bar_params.size.height   = .{ kind = .PIXELS, value = h };
        bar_params.background.normal = `hint_color;
        ui_node(`window.label, name, .FLOATING, bar_params);
      }

      if (edge & UI_EDGE_L) != 0  bar("L", 0.0,                      0.0,                      thickness,    window_height);
      if (edge & UI_EDGE_R) != 0  bar("R", window_width - thickness, 0.0,                      thickness,    window_height);
      if (edge & UI_EDGE_T) != 0  bar("T", 0.0,                      0.0,                      window_width, thickness);
      if (edge & UI_EDGE_B) != 0  bar("B", 0.0,                      window_height - thickness, window_width, thickness);
    }
  }

  if ui.input.dock_modifier && ui.drag_panel_key == window.key && !(window_cache.options & .NO_DOCK) {
    ui_dock_overlay(window, window_cache);
  }

  ui_pop_parent();
  ui.next_depth = window_cache.saved_next_depth;
}

#if UI_DEBUG {
ui_metrics_window :: (open: *bool, loc := #caller_location) {
  if !open.*  return;
  ui_window_begin("Imgui metrics", open, 24, 24, 250, 240, loc = loc);
  stats := ui.stats;
  ui_label(tprint("nodes          %", stats.nodes));
  ui_label(tprint("quads          %", stats.quads));
  ui_label(tprint("cache entries  %", stats.cache_entries));
  ui_label(tprint("frame pool     % KB", stats.frame_bytes / 1024));
  ui_separator();
  ui_label(tprint("hot     %", ui.hot_key));
  ui_label(tprint("active  %", ui.active_key));
  ui_label(tprint("hover   %", ui.hover_key));
  ui_label(tprint("focus   %", ui.keyboard_focus_key));
  ui_window_end();
}
}

Window_Layout :: struct {
  display_pos:  Vector2;
  display_size: Vector2;
  min_size:     Vector2;
  appear:       float;
  resizable:    bool;
  docked:       bool;
  shadow:       bool;
}

// Also advances the eased dock / minimize / open-close state on `cache`.
window_resolve_layout :: (window_key: u64, cache: *UI_Node_Cache, region: UI_Rect, x: float, y: float, w: float, h: float, options: UI_Window_Flags) -> Window_Layout {
  line_height  := ui.metrics.line_height;
  title_height := ui_title_height();
  min_width  := max(line_height * 6.0, UI_RESIZE_HANDLE * 3.0);
  min_height := title_height + line_height * 2.0;

  if cache.dock != .NONE && ui.drag_panel_key == window_key && length(ui.input.mouse_pos - cache.grab_mouse) > UI_UNDOCK_DIST {
    grab_point := Vector2.{ (w + cache.resize_offset.x) * 0.35, title_height * 0.5 };
    cache.drag_offset      = ui.input.mouse_pos - grab_point - region.pos - Vector2.{ x, y };
    cache.grab_drag_offset = cache.drag_offset;
    cache.grab_mouse       = ui.input.mouse_pos;
    cache.dock = .NONE;  cache.dock_t = 0.0;
  }
  if cache.dock != .NONE && ui.resizing_key == window_key {
    docked := ui_dock_rect(cache.dock, region);
    cache.resize_offset      = docked.size - Vector2.{ w, h };
    cache.drag_offset        = docked.pos  - (region.pos + Vector2.{ x, y });
    cache.grab_resize_offset = cache.resize_offset;
    cache.grab_drag_offset   = cache.drag_offset;
    cache.grab_mouse         = ui.input.mouse_pos;
    cache.dock = .NONE;  cache.dock_t = 0.0;
  }

  {
    dt := ui_animation_t(ui.input.dt);
    dock_target := ifx cache.dock != .NONE then 1.0 else 0.0;
    cache.dock_t += (dock_target - cache.dock_t) * dt;
    if abs(cache.dock_t - dock_target) < 0.001  cache.dock_t = dock_target;
    minimize_target := ifx cache.minimized then 1.0 else 0.0;
    cache.minimize_t += (minimize_target - cache.minimize_t) * dt;
    if abs(cache.minimize_t - minimize_target) < 0.001  cache.minimize_t = minimize_target;
  }
  reopened := ui.frame - cache.last_seen_frame > 1;
  cache.last_seen_frame = ui.frame;
  if reopened { cache.open_t = 0.0; cache.closing = false; cache.close_t = 0.0; }
  cache.open_t = min(1.0, cache.open_t + ui.input.dt * UI_WIN_ANIM_SPEED);
  if cache.closing  cache.close_t = min(1.0, cache.close_t + ui.input.dt * UI_WIN_ANIM_SPEED);

  docked_or_animating := cache.dock != .NONE || cache.dock_t > 0.0;
  dock_animating      := (cache.dock != .NONE && cache.dock_t < 0.999) || (cache.dock == .NONE && cache.dock_t > 0.001);

  pos  := region.pos + Vector2.{ x, y } + cache.drag_offset;
  size := Vector2.{ w + cache.resize_offset.x, h + cache.resize_offset.y };
  {
    edge := ifx ui.resizing_key == window_key then cache.resize_edge else cast(u32) 0;
    clamped_w := clamp(size.x, min_width,  max(min_width,  region.size.x));
    clamped_h := clamp(size.y, min_height, max(min_height, region.size.y));
    if (edge & UI_EDGE_L) != 0  pos.x -= (clamped_w - size.x);
    if (edge & UI_EDGE_T) != 0  pos.y -= (clamped_h - size.y);
    size = .{ clamped_w, clamped_h };
  }
  if docked_or_animating {
    docked := ui_dock_rect(ifx cache.dock != .NONE then cache.dock else UI_Dock.FULL, region);
    pos  = ui_lerp2(pos,  docked.pos,  cache.dock_t);
    size = ui_lerp2(size, docked.size, cache.dock_t);
  } else {
    keep := min(72.0, size.x * 0.5);
    pos.x = clamp(pos.x, region.pos.x - (size.x - keep), region.pos.x + region.size.x - keep);
    pos.y = clamp(pos.y, region.pos.y, region.pos.y + max(0.0, region.size.y - title_height));
  }

  collapsed_h  := size.y + (title_height - size.y) * cache.minimize_t;
  display_pos  := pos;
  display_size := Vector2.{ size.x, collapsed_h };

  layout: Window_Layout;
  layout.appear = ui_smooth(cache.open_t) * (1.0 - ui_smooth(cache.close_t));
  if layout.appear < 0.999 {
    scale  := 0.93 + 0.07 * layout.appear;
    center := display_pos + display_size * 0.5;
    display_size *= scale;
    display_pos   = center - display_size * 0.5;
  }

  layout.display_pos  = display_pos;
  layout.display_size = display_size;
  layout.min_size     = .{ min_width, ifx (cache.minimize_t > 0.0 || docked_or_animating) then title_height else min_height };
  layout.resizable    = !(options & .NO_RESIZE) && !dock_animating && cache.minimize_t <= 0.0;
  layout.docked       = cache.dock != .NONE;
  layout.shadow       = cache.dock == .NONE && cache.dock_t <= 0.001;
  return layout;
}

window_title_bar :: (id: string, window: *UI_Node, cache: *UI_Node_Cache, focused: bool, options: UI_Window_Flags, loc: Source_Code_Location) -> float {
  background := ui_theme.title_bar;
  border     := ui_theme.window_border;
  if focused  border.normal = ui_theme.accent;
  else      { background.normal = ui_window_dim(background.normal); border.normal = ui_window_dim(border.normal); }

  bar_params := ui_box_params(background, border);
  bar_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  bar_params.size.height      = .{ kind = .PIXELS, value = ui_title_height() };
  bar_params.axis             = .X;
  bar_params.padding          = UI_CONTROL_PADDING;
  bar_params.corners          = UI_CORNER_TL | UI_CORNER_TR;
  bar := ui_node(id, "titlebar", .HOVERABLE, bar_params, loc);
  ui_push_parent(bar);

  button_size  := bar.inner.size.y;
  show_min     := !(options & .NO_COLLAPSE);
  show_max     := !(options & .NO_DOCK);
  show_close   := !(options & .NO_CLOSE);
  button_count := (cast(int) show_min) + (cast(int) show_max) + (cast(int) show_close);

  text_flags := UI_Node_Flags.DRAW_TEXT | .TEXT_CENTER_Y | .CLICKABLE;
  if !(options & .NO_MOVE)  text_flags |= .DRAGGABLE;
  text_params: UI_Params;
  text_params.text        = ui_display_label(id);
  text_params.size.width  = .{ kind = .PIXELS, value = max(0.0, bar.inner.size.x - cast(float) button_count * button_size) };
  text_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  text_params.padding     = UI_CONTROL_PADDING;
  text_params.foreground  = ui_theme.text;
  ui_node(id, "title", text_flags, text_params, loc);

  if show_min {
    if window_chrome_button(id, "min", ifx cache.minimized then UI_Icon.PLUS else .MINIMIZE, ui_theme.button, button_size, loc)
      cache.minimized = !cache.minimized;
  }
  if show_max {
    maximized := cache.dock == .FULL;
    if window_chrome_button(id, "max", ifx maximized then UI_Icon.RESTORE else .MAXIMIZE, ui_theme.button, button_size, loc)
      cache.dock = ifx maximized then UI_Dock.NONE else UI_Dock.FULL;
  }
  if show_close {
    if window_chrome_button(id, "close", .CLOSE, ui_theme.danger, button_size, loc)  cache.closing = true;
  }

  ui_pop_parent();
  return bar.rect.size.y;
}

window_chrome_button :: (id: string, salt: string, icon: UI_Icon, fill: UI_Color_Set, size: float, loc: Source_Code_Location) -> clicked: bool {
  params: UI_Params;
  params.size.width    = .{ kind = .PIXELS, value = size };
  params.size.height   = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.background    = fill;
  params.border        = ui_theme.window_border;
  params.foreground    = ui_theme.text;
  params.corner_radius = ui_theme.corner_radius;
  params.animate       = true;
  node := ui_icon_node(id, salt, params, icon, .HOVERABLE | .CLICKABLE, loc);
  return ui_signal_from_node(node).clicked;
}

ui_icon_node :: (id: string, salt: string, params: UI_Params, icon: UI_Icon, flags: UI_Node_Flags = 0, loc := #caller_location) -> *UI_Node {
  resolved := params;
  resolved.texture = ui_default_atlas;
  resolved.uv_min, resolved.uv_max = ui_icon_uv(icon);
  return ui_node(id, salt, flags, resolved, loc);
}

window_frame_node :: (label: string, frame_key: u64, region: UI_Rect, layout: Window_Layout, loc: Source_Code_Location) -> *UI_Node {
  params: UI_Params;
  params.axis    = .Y;
  params.render  = false;
  params.opacity = max(layout.appear, 0.001);
  params.offset  = layout.display_pos - ui_parent().rect.pos; // FLOATING offsets are from the parent's rect, not the region
  params.size.width  = .{ kind = .PIXELS, value = layout.display_size.x, min = layout.min_size.x };
  params.size.height = .{ kind = .PIXELS, value = layout.display_size.y, min = layout.min_size.y };
  if layout.shadow  params.shadow = ui_theme.window_shadow;

  parent_window := ui_parent();
  while parent_window != ui.root && !(parent_window.flags & .DRAGGABLE_PANEL)  parent_window = parent_window.parent;

  if ui_window_rank(frame_key) < 0  array_add(*ui.window_order, .{ frame_key, parent_window.key });
  rank, sibling_count := ui_window_rank(frame_key);

  // Root windows split (0.209, 0.999], above popups; nested windows split the front half of their parent's band.
  if parent_window == ui.root {
    params.depth_band = 0.79 / cast(float) sibling_count;
    params.depth_base = 0.999 - cast(float) rank * params.depth_band;
  } else {
    parent_band := parent_window.params.depth_band;
    params.depth_band = parent_band * 0.5 / cast(float) sibling_count;
    params.depth_base = parent_window.depth - parent_band * 0.5 - cast(float) rank * params.depth_band;
  }

  flags := UI_Node_Flags.FLOATING | .DRAGGABLE_PANEL | .INPUT_SINK;
  if layout.resizable  flags |= .RESIZABLE;
  params.name = "Window";
  return ui_node_keyed(frame_key, label, flags, params, loc);
}

window_body_begin :: (label: string, body_key: u64, window: *UI_Node, chrome_height: float, focused: bool, loc: Source_Code_Location) {
  border := ui_theme.border_thickness;
  body_border := ui_theme.window_border;
  if focused  body_border.normal = ui_theme.accent;
  else        body_border.normal = ui_window_dim(body_border.normal);

  body_params: UI_Params;
  body_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  body_params.size.height      = .{ kind = .PIXELS, value = max(0.0, window.rect.size.y - chrome_height + border) };
  body_params.offset           = .{ 0.0, -border }; // overlap the title bar's border
  body_params.axis             = .Y;
  body_params.padding          = UI_PANEL_PADDING;
  body_params.spacing          = UI_STACK_SPACING;
  body_params.background       = ui_theme.window_background;
  body_params.border           = body_border;
  body_params.border_thickness = border;
  if ui_cache_get(body_key).scroll_max > 0.5  body_params.pad_right = UI_SCROLLBAR_W + 4.0;
  body_params.name = "body";
  body := ui_node_keyed(body_key, label, .SCROLL_Y, body_params, loc);
  ui_push_parent(body);
}

style_theme_index := 0;

ui_row_label :: (id: string, salt: string, text: string, width := UI_Size.{ kind = .PARENT_FRACTION, value = 1.0 }, loc: Source_Code_Location) {
  params: UI_Params;
  params.size.width  = width;
  params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.text        = text;
  params.foreground  = ui_theme.text;
  ui_node(id, salt, .DRAW_TEXT | .TEXT_CENTER_Y, params, loc);
}

ui_box_params :: (background: UI_Color_Set, border: UI_Color_Set) -> UI_Params {
  params: UI_Params;
  params.background       = background;
  params.border           = border;
  params.border_thickness = ui_theme.border_thickness;
  params.corner_radius    = ui_theme.corner_radius;
  return params;
}

// Locks a colour set to one state, so a child can mirror its parent's hover / press.
ui_pick_set :: (set: UI_Color_Set, hovered: bool, held: bool) -> UI_Color_Set {
  resolved := ui_resolve_color_set(set, derive = true);
  color := resolved.normal;
  if held         color = resolved.active;
  else if hovered color = resolved.hover;
  return .{ normal = color, hover = color, active = color };
}

ui_selection_mark :: (container: *UI_Node, id: string, icon: UI_Icon, color: UI_Color_Set, on: bool) {
  if !on  return;
  ui_push_parent(container);
  mark_params: UI_Params;
  mark_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  mark_params.size.height = .{ kind = .PARENT_FRACTION, value = 1.0 };
  mark_params.foreground  = color;
  ui_icon_node(id, "mark", mark_params, icon);
  ui_pop_parent();
}

// A starting height for a content-hugging panel, shrunk once its content is known.
// Bounded by the clip, so a panel deep in a scrolled window keeps its children's clips.
ui_provisional_panel_height :: (parent: *UI_Node) -> float {
  clip_bottom := parent.child_clip.pos.y + parent.child_clip.size.y;
  remaining   := clip_bottom - parent.cursor.y;
  return max(remaining, ui.metrics.line_height * 6.0);
}

columns_cell :: (row: *UI_Node, cell_width: float, index: int, loc: Source_Code_Location) {
  cell_params: UI_Params;
  cell_params.axis        = .Y;
  cell_params.spacing     = UI_STACK_SPACING;
  cell_params.size.width  = .{ kind = .PIXELS, value = max(1.0, cell_width) };
  cell_params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(row) };
  cell := ui_node(row.label, "col", index, 0, cell_params, loc);
  ui_push_parent(cell);
}

ui_shrink_panel_to_content :: (panel: *UI_Node, max_height := 0.0) {
  height := max(0.0, panel.cursor.y - panel.inner.pos.y - panel.params.spacing) + 2.0 * panel.params.padding;
  if max_height > 0.0  height = min(height, max_height);
  ui_node_set_height(panel, height);
}

ui_shrink_row_to_content :: (row: *UI_Node) {
  tallest := 0.0;
  child := row.first;
  while child { tallest = max(tallest, child.rect.size.y); child = child.next; }
  ui_node_set_height(row, tallest + 2.0 * row.params.padding);
}

ui_node_set_height :: (node: *UI_Node, height: float) {
  if !(node.flags & .FLOATING)  node.parent.cursor.y += height - node.rect.size.y;
  node.rect.size.y = height;
  ui_node_set_rect(node);
}

ui_slider_track_node :: (id: string, disabled: bool, loc: Source_Code_Location) -> *UI_Node {
  params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.size.height      = .{ kind = .PIXELS, value = ui_row_height() };
  params.foreground       = ui_theme.text;
  params.name = "Slider";
  params.disabled = disabled;
  return ui_node(id, .CLICKABLE | .HOVERABLE, params, loc);
}

ui_slider_cursor_t :: (track: *UI_Node) -> float {
  width := track.rect.size.x - 2.0 * UI_SLIDER_INSET;
  if width <= 0.0  return 0.0;
  return clamp((ui.input.mouse_pos.x - (track.rect.pos.x + UI_SLIDER_INSET)) / width, 0.0, 1.0);
}

ui_slider_decorate :: (track: *UI_Node, id: string, t: float, display: string) {
  ui_push_parent(track);

  inset := UI_SLIDER_INSET;
  fill_params: UI_Params;
  fill_params.offset        = .{ inset, inset };
  fill_params.size.width    = .{ kind = .PIXELS, value = max(0.0, (track.rect.size.x - 2.0 * inset) * clamp(t, 0.0, 1.0)) };
  fill_params.size.height   = .{ kind = .PIXELS, value = max(0.0, track.rect.size.y - 2.0 * inset) };
  fill_params.background     = ui_theme.slider_fill;
  fill_params.corner_radius  = max(0.0, ui_theme.corner_radius - inset);
  fill_params.animate        = true;
  ui_node(id, "fill", .FLOATING, fill_params);

  value_params: UI_Params;
  value_params.size.width  = .{ kind = .PIXELS, value = track.rect.size.x };
  value_params.size.height = .{ kind = .PIXELS, value = track.rect.size.y };
  value_params.text        = display;
  value_params.foreground  = ui_theme.text;
  ui_node(id, "val", .FLOATING | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, value_params);

  ui_pop_parent();
}

ui_scrollbar :: (body: *UI_Node, scroll_cache: *UI_Node_Cache) {
  // Measured now, not from the emit walk, so the bar does not lag a frame.
  laid_out := max(0.0, body.cursor.y - body.inner.pos.y + scroll_cache.scroll - body.params.spacing);
  track_height := body.inner.size.y;
  scroll_cache.scroll_max = max(0.0, laid_out - track_height);
  scroll_cache.scroll     = clamp(scroll_cache.scroll, 0.0, scroll_cache.scroll_max);

  if scroll_cache.scroll_max <= 0.5 || track_height <= 8.0  return;

  content_height := track_height + scroll_cache.scroll_max;
  thumb_height   := clamp(track_height * track_height / content_height, 24.0, track_height);
  travel         := track_height - thumb_height;
  thumb_y        := ifx travel > 0.0 then (scroll_cache.scroll / scroll_cache.scroll_max) * travel else 0.0;

  inner_right := (body.inner.pos.x - body.rect.pos.x) + body.inner.size.x;
  track_x := ifx body.params.pad_right > 0.5
             then inner_right + (body.params.pad_right - UI_SCROLLBAR_W) * 0.5
             else inner_right - UI_SCROLLBAR_W;
  track_y := (body.inner.pos.y - body.rect.pos.y);

  ui_push_parent(body);

  track_params: UI_Params;
  track_params.offset            = .{ track_x, track_y };
  track_params.size.width        = .{ kind = .PIXELS, value = UI_SCROLLBAR_W };
  track_params.size.height       = .{ kind = .PIXELS, value = track_height };
  track_params.background.normal = ui_theme.scroll_track;
  track_params.corner_radius     = UI_SCROLLBAR_W * 0.5;
  ui_node(body.label, "sbtrack", .FLOATING, track_params);

  thumb_params: UI_Params;
  thumb_params.offset        = .{ track_x, track_y + thumb_y };
  thumb_params.size.width    = .{ kind = .PIXELS, value = UI_SCROLLBAR_W };
  thumb_params.size.height   = .{ kind = .PIXELS, value = thumb_height };
  thumb_params.background     = ui_theme.scroll_thumb;
  thumb_params.corner_radius  = UI_SCROLLBAR_W * 0.5;
  thumb_params.animate        = true;
  thumb := ui_node(body.label, "sbthumb", .FLOATING | .HOVERABLE | .CLICKABLE, thumb_params);

  thumb_signal := ui_signal_from_node(thumb);
  if thumb_signal.pressed {
    scroll_cache.scroll_grab       = scroll_cache.scroll;
    scroll_cache.scroll_grab_mouse = ui.input.mouse_pos.y;
  }
  if thumb_signal.held && travel > 0.0 {
    scroll_cache.scroll = clamp(scroll_cache.scroll_grab + (ui.input.mouse_pos.y - scroll_cache.scroll_grab_mouse) * (scroll_cache.scroll_max / travel),
                                0.0, scroll_cache.scroll_max);
  }

  ui_pop_parent();
}

Dock_Slot :: struct { dock: UI_Dock; rect: UI_Rect; }

ui_dock_overlay :: (window: *UI_Node, window_cache: *UI_Node_Cache) {
  region := window.parent.inner;
  if min(region.size.x, region.size.y) < 84.0  return;

  chip := clamp(min(region.size.x, region.size.y) * 0.22, 16.0, 38.0);
  step := chip * 1.16;
  center_x := region.pos.x + region.size.x * 0.5;
  center_y := region.pos.y + region.size.y * 0.5;

  square :: (cx: float, cy: float) -> UI_Rect #expand { return .{ .{ cx - chip * 0.5, cy - chip * 0.5 }, .{ chip, chip } }; }

  slots: [9] Dock_Slot;
  slots[0] = .{ .FULL,   square(center_x,        center_y) };
  slots[1] = .{ .LEFT,   square(center_x - step, center_y) };
  slots[2] = .{ .RIGHT,  square(center_x + step, center_y) };
  slots[3] = .{ .TOP,    square(center_x,        center_y - step) };
  slots[4] = .{ .BOTTOM, square(center_x,        center_y + step) };
  count := 5;

  if region.size.x >= 260.0 && region.size.y >= 230.0 {
    inset := chip * 0.5 + 24.0;
    slots[5] = .{ .LEFT_EDGE,   square(region.pos.x + inset,                 center_y) };
    slots[6] = .{ .RIGHT_EDGE,  square(region.pos.x + region.size.x - inset, center_y) };
    slots[7] = .{ .TOP_EDGE,    square(center_x, region.pos.y + inset) };
    slots[8] = .{ .BOTTOM_EDGE, square(center_x, region.pos.y + region.size.y - inset) };
    count = 9;
  }

  hovered := UI_Dock.NONE;
  for i: 0..count - 1  if rect_contains(slots[i].rect, ui.input.mouse_pos)  hovered = slots[i].dock;

  outline := ui_mix(ui_theme.accent, .{ 0, 0, 0, 1 }, 0.35);
  if hovered != .NONE  ui_overlay_rect(ui_dock_rect(hovered, region), ui_theme.dock_hint, outline, 2.5, 0.0);
  for i: 0..count - 1 {
    lit := slots[i].dock == hovered;
    background := ifx lit then ui_state_color(ui_theme.button, .HOVER) else ui_theme.button.normal;
    ui_overlay_rect(slots[i].rect, background, outline, ifx lit then 2.5 else 1.5, 4.0);
  }

  if ui.input.mouse_released[0]  window_cache.dock = hovered;
}

ui_popup_begin :: (id: string, open: bool, owner: *UI_Node_Cache, anchor: UI_Rect, width: float, max_height := 0.0, loc: Source_Code_Location) -> bool {
  frame: Popup_Frame;
  frame.open             = open;
  frame.owner            = owner;
  frame.anchor           = anchor;
  frame.saved_next_depth = ui.next_depth;
  frame.max_height       = max_height;
  array_add(*ui.popup_stack, frame);
  if !open  return false;

  // Placed with last frame's height, so hit-testing matches what gets drawn.
  screen := ui.input.screen_size;
  height := ifx owner.popup_height > 0.0 then owner.popup_height else 220.0;
  pos    := Vector2.{ anchor.pos.x, anchor.pos.y + anchor.size.y + 2.0 };
  if pos.y + height > screen.y && anchor.pos.y - height - 2.0 >= 0.0  pos.y = anchor.pos.y - height - 2.0;
  if pos.x + width  > screen.x  pos.x = max(0.0, screen.x - width);

  popup_params := ui_box_params(ui_theme.window_background, ui_theme.window_border);
  popup_params.axis             = .Y;
  popup_params.offset           = pos - ui_parent().rect.pos;
  popup_params.size.width       = .{ kind = .PIXELS, value = width };
  popup_params.size.height      = .{ kind = .PIXELS, value = ifx max_height > 0.0 then max_height else screen.y };
  popup_params.padding          = UI_CONTROL_PADDING;
  popup_params.spacing          = UI_TIGHT_SPACING;
  popup_params.depth_base       = 0.0009; // in front of every window
  flags := UI_Node_Flags.FLOATING | .OVERLAY | .INPUT_SINK;
  if max_height > 0.0 {
    flags |= .SCROLL_Y;
    if ui_cache_get(ui_child_key(id, "popup", loc)).scroll_max > 0.5  popup_params.pad_right = UI_SCROLLBAR_W + 4.0;
  }
  popup_params.name = "Popup";
  ui_push_parent(ui_node(id, "popup", flags, popup_params, loc));
  return true;
}

ui_popup_end :: () {
  ui_check(ui.popup_stack.count > 0, "Imgui: a dropdown / menu end without its begin.");
  frame := pop(*ui.popup_stack);
  if !frame.open  return;

  popup := ui_pop_parent();
  ui_shrink_panel_to_content(popup, frame.max_height);
  if frame.max_height > 0.0  ui_scrollbar(popup, ui_cache_get(popup.key));
  frame.owner.popup_height = popup.rect.size.y;
  ui.next_depth = frame.saved_next_depth;

  mouse := ui.input.mouse_pos;
  pressed_outside := ui.input.mouse_pressed[0] && !rect_contains(popup.rect, mouse) && !rect_contains(frame.anchor, mouse);
  if pressed_outside || ui_key_pressed(.ESCAPE)  frame.owner.expanded = false;
}

ui_popup_owner :: () -> *UI_Node_Cache {
  if ui.popup_stack.count == 0  return null;
  return ui.popup_stack[ui.popup_stack.count - 1].owner;
}

#scope_file

table_open_cell :: (frame: *Table_Frame, loc: Source_Code_Location) {
  cell_params: UI_Params;
  cell_params.axis        = .Y;
  cell_params.spacing     = UI_TIGHT_SPACING;
  cell_params.padding     = UI_CONTROL_PADDING;
  cell_params.size.width  = .{ kind = .PIXELS, value = max(1.0, frame.widths[clamp(frame.cell, 0, frame.count - 1)]) };
  cell_params.size.height = .{ kind = .PIXELS, value = ui_provisional_panel_height(frame.row) };
  cell := ui_node(frame.panel.label, "td", frame.row_seq * UI_TABLE_MAX_COLUMNS + frame.cell, 0, cell_params, loc);
  ui_push_parent(cell);
}

ui_tree_indent :: () -> float {
  return ui_compact_height() + UI_STACK_SPACING;
}
