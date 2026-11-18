// Each sample is stored twice, at head and head + capacity, so the latest window is one slice.
UI_Plot_Buffer :: struct {
  data:  [UI_PLOT_CAPACITY * 2] float;
  head:  int;
  count: int;
}

ui_plot_push :: (buffer: *UI_Plot_Buffer, value: float) {
  buffer.data[buffer.head] = value;
  buffer.data[buffer.head + UI_PLOT_CAPACITY] = value;
  buffer.head  = (buffer.head + 1) % UI_PLOT_CAPACITY;
  buffer.count = min(buffer.count + 1, UI_PLOT_CAPACITY);
}

ui_plot_values :: (buffer: *UI_Plot_Buffer) -> [] float {
  return .{ buffer.count, buffer.data.data + buffer.head + UI_PLOT_CAPACITY - buffer.count };
}

ui_plot_begin :: (id: string, height := 0.0, overlay := "", loc := #caller_location) {
  box_height := ifx height > 0.0 then height else floor(ui.metrics.line_height * 5.0);

  box_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  box_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  box_params.size.height      = .{ kind = .PIXELS, value = box_height };
  box_params.name = "Plot";
  box := ui_node(id, .HOVERABLE, box_params, loc);

  inset := 3.0;
  frame: Plot_Frame;
  frame.box  = box;
  frame.area = .{ .{ box.rect.pos.x + inset, box.rect.pos.y + inset },
                  .{ max(0.0, box.rect.size.x - 2.0 * inset), max(0.0, box.rect.size.y - 2.0 * inset) } };
  // Last frame's hover: this frame's hot_key can still change if a later window covers the plot.
  frame.hovered = ui.hover_key == box.key
               && rect_contains(box.clip, ui.input.mouse_pos)
               && frame.area.size.x > 0.0 && frame.area.size.y > 0.0;
  frame.mouse_x = clamp(ui.input.mouse_pos.x, frame.area.pos.x, frame.area.pos.x + frame.area.size.x);
  frame.series_index = 0;
  array_add(*ui.plot_stack, frame);

  ui_push_parent(box);

  if frame.hovered {
    guide := ui_frame_allocate(Vector2, 2);
    guide[0] = .{ frame.mouse_x, frame.area.pos.y };
    guide[1] = .{ frame.mouse_x, frame.area.pos.y + frame.area.size.y };
    guide_params: UI_Params;
    guide_params.render             = false;
    guide_params.size.width         = .{ kind = .PARENT_FRACTION, value = 1.0 };
    guide_params.size.height        = .{ kind = .PARENT_FRACTION, value = 1.0 };
    guide_params.foreground.normal   = ui_theme.text.normal;
    guide_params.foreground.normal.w = 0.35;
    guide_params.line_width          = 1.0;
    guide_params.points              = guide;
    ui_node(id, "pguide", .FLOATING | .DRAW_LINES, guide_params, loc);
  }

  if overlay.count > 0 {
    overlay_params: UI_Params;
    overlay_params.offset      = .{ inset + 2.0, 1.0 };
    overlay_params.size.width  = .{ kind = .PIXELS, value = max(1.0, frame.area.size.x) };
    overlay_params.size.height = .{ kind = .PIXELS, value = ui.metrics.line_height };
    overlay_params.text        = overlay;
    overlay_params.foreground  = ui_theme.text;
    ui_node(id, "povl", .FLOATING | .DRAW_TEXT | .TEXT_CENTER_Y, overlay_params, loc);
  }
}

ui_plot_end :: () {
  frame := plot_top();
  if frame.hovered && frame.hover_count > 0  plot_emit_hover_box(frame);
  ui.plot_stack.count -= 1;
  ui_pop_parent();
}

ui_plot_line    :: (values: [] float, color := Vector4.{}, y_range := Vector2.{}, label := "", loc := #caller_location) { plot_series(.LINE,    values, color, y_range, label, loc); }
ui_plot_step    :: (values: [] float, color := Vector4.{}, y_range := Vector2.{}, label := "", loc := #caller_location) { plot_series(.STEP,    values, color, y_range, label, loc); }
ui_plot_scatter :: (values: [] float, color := Vector4.{}, y_range := Vector2.{}, label := "", loc := #caller_location) { plot_series(.SCATTER, values, color, y_range, label, loc); }
ui_plot_bars    :: (values: [] float, color := Vector4.{}, y_range := Vector2.{}, label := "", loc := #caller_location) { plot_series(.BARS,    values, color, y_range, label, loc); }

ui_plot_series_color :: (index: int) -> Vector4 {
  if index == 0  return ui_theme.slider_fill.normal;
  if index == 1  return ui_theme.accent;
  palette :: Vector4.[
    .{ 0.90, 0.55, 0.20, 1.0 },
    .{ 0.38, 0.78, 0.42, 1.0 },
    .{ 0.72, 0.46, 0.88, 1.0 },
    .{ 0.30, 0.74, 0.82, 1.0 },
    .{ 0.88, 0.42, 0.56, 1.0 },
  ];
  return palette[(index - 2) % palette.count];
}

#scope_file

Plot_Series_Kind :: enum u8 { LINE; STEP; SCATTER; BARS; }

plot_top :: () -> *Plot_Frame {
  ui_check(ui.plot_stack.count > 0, "Imgui: ui_plot_<kind> / ui_plot_end outside a ui_plot_begin pair.");
  return *ui.plot_stack[ui.plot_stack.count - 1];
}

plot_value_y :: (value: float, low: float, high: float, area: UI_Rect) -> float {
  span := max(high - low, 0.0001);
  t    := clamp((value - low) / span, 0.0, 1.0);
  return area.pos.y + area.size.y - t * area.size.y;
}

// y_range.x < y_range.y means the caller set one.
plot_series_range :: (values: [] float, y_range: Vector2) -> low: float, high: float {
  if y_range.x < y_range.y  return y_range.x, y_range.y;
  if values.count == 0      return 0.0, 1.0;
  low := values[0];  high := values[0];
  for values { low = min(low, it);  high = max(high, it); }
  if high <= low  high = low + 1.0;
  return low, high;
}

plot_series :: (kind: Plot_Series_Kind, values: [] float, color: Vector4, y_range: Vector2, label: string, loc: Source_Code_Location) {
  frame := plot_top();
  index := frame.series_index;
  frame.series_index += 1;

  area := frame.area;
  if area.size.x <= 0.0 || area.size.y <= 0.0 || values.count == 0  return;

  series_color := ifx color.w > 0.0 then color else ui_plot_series_color(index);
  low, high       := plot_series_range(values, y_range);
  origin       := frame.box.rect.pos;
  series_id    := ifx label.count > 0 then label else tprint("s%", index);

  point_x :: (i: int) -> float #expand {
    step := ifx `values.count > 1 then `area.size.x / cast(float) (`values.count - 1) else 0.0;
    return `area.pos.x + cast(float) i * step;
  }

  if kind == .BARS {
    slot       := area.size.x / cast(float) values.count;
    gap        := clamp(slot * 0.2, 0.0, 3.0);
    baseline_y := ifx low < 0.0 && high > 0.0 then plot_value_y(0.0, low, high, area) else area.pos.y + area.size.y;
    for value, i: values {
      top := plot_value_y(value, low, high, area);
      bar_params: UI_Params;
      bar_params.offset           = .{ area.pos.x - origin.x + cast(float) i * slot, min(top, baseline_y) - origin.y };
      bar_params.size.width       = .{ kind = .PIXELS, value = max(1.0, slot - gap) };
      bar_params.size.height      = .{ kind = .PIXELS, value = max(1.0, abs(baseline_y - top)) };
      bar_params.background.normal = series_color;
      ui_node(series_id, "pbar", i, .FLOATING, bar_params, loc);
    }
  } else if kind == .SCATTER {
    marker := 4.0;
    for value, i: values {
      x := point_x(i);
      y := plot_value_y(value, low, high, area);
      dot_params: UI_Params;
      dot_params.offset           = .{ x - origin.x - marker * 0.5, y - origin.y - marker * 0.5 };
      dot_params.size.width       = .{ kind = .PIXELS, value = marker };
      dot_params.size.height      = .{ kind = .PIXELS, value = marker };
      dot_params.background.normal = series_color;
      dot_params.corner_radius    = marker * 0.5;
      ui_node(series_id, "pdot", i, .FLOATING, dot_params, loc);
    }
  } else {
    count := values.count;
    points: [] Vector2;
    if kind == .STEP {
      points = ui_frame_allocate(Vector2, max(1, 2 * count - 1));
      points[0] = .{ point_x(0), plot_value_y(values[0], low, high, area) };
      write := 1;
      for i: 1..count-1 {
        x := point_x(i);
        points[write] = .{ x, plot_value_y(values[i - 1], low, high, area) };  write += 1;
        points[write] = .{ x, plot_value_y(values[i],     low, high, area) };  write += 1;
      }
    } else {
      points = ui_frame_allocate(Vector2, count);
      for value, i: values  points[i] = .{ point_x(i), plot_value_y(value, low, high, area) };
    }
    line_params: UI_Params;
    line_params.render           = false;
    line_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
    line_params.size.height      = .{ kind = .PARENT_FRACTION, value = 1.0 };
    line_params.foreground.normal = series_color;
    line_params.line_width       = 1.5;
    line_params.points           = points;
    ui_node(series_id, "pline", .FLOATING | .DRAW_LINES, line_params, loc);
  }

  if !frame.hovered  return;

  sample: int;
  if kind == .BARS {
    slot   := area.size.x / cast(float) values.count;
    sample = clamp(cast(int) floor((frame.mouse_x - area.pos.x) / slot), 0, values.count - 1);
  } else {
    step   := ifx values.count > 1 then area.size.x / cast(float) (values.count - 1) else 1.0;
    sample = clamp(cast(int) floor((frame.mouse_x - area.pos.x) / step + 0.5), 0, values.count - 1);
  }
  hovered_value := values[sample];
  hovered_y     := plot_value_y(hovered_value, low, high, area);

  marker := 7.0;
  marker_params: UI_Params;
  marker_params.offset           = .{ frame.mouse_x - origin.x - marker * 0.5, hovered_y - origin.y - marker * 0.5 };
  marker_params.size.width       = .{ kind = .PIXELS, value = marker };
  marker_params.size.height      = .{ kind = .PIXELS, value = marker };
  marker_params.background.normal = series_color;
  marker_params.border            = ui_theme.window_background;
  marker_params.border_thickness  = 1.5;
  marker_params.corner_radius     = marker * 0.5;
  ui_node(series_id, "phdot", .FLOATING, marker_params, loc);

  shown_value := floor(hovered_value * 1000.0 + 0.5) / 1000.0;
  readout     := ifx label.count > 0 then tprint("%: %", label, shown_value) else tprint("%", shown_value);
  if frame.hover_count < frame.hover_texts.count {
    frame.hover_texts[frame.hover_count]  = readout;
    frame.hover_colors[frame.hover_count] = series_color;
    frame.hover_count += 1;
  }
}

plot_emit_hover_box :: (frame: *Plot_Frame) {
  line_height := ui.metrics.line_height;
  padding     := UI_CONTROL_PADDING;

  text_width  := 0.0;
  text_height := 0.0;
  for 0..frame.hover_count - 1 {
    width, height := ui_measure_display(frame.hover_texts[it]);
    text_width  = max(text_width, width);
    text_height = max(text_height, height);
  }
  box_width  := text_width + padding * 2.0;
  box_height := line_height * cast(float) frame.hover_count + padding * 2.0;

  pos  := ui.input.mouse_pos + Vector2.{ 14.0, 8.0 };
  clip := UI_Rect.{ .{ 0, 0 }, ui.input.screen_size };

  background: UI_Quad;
  background.rect             = .{ pos, .{ box_width, box_height } };
  background.clip             = clip;
  background.color            = ui_theme.window_background.normal;
  background.color.w          = 0.92;
  background.border_color     = ui_theme.window_border.normal;
  background.border_thickness = ui_theme.border_thickness;
  background.corner_radius    = ui_theme.corner_radius;
  array_add(*ui.overlay_quads, background);

  for 0..frame.hover_count - 1 {
    row_top_left := Vector2.{ pos.x + padding, pos.y + padding + line_height * cast(float) it + (line_height - text_height) * 0.5 };
    ui_push_text(*ui.overlay_quads, frame.hover_texts[it], row_top_left, clip, frame.hover_colors[it]);
  }
}
