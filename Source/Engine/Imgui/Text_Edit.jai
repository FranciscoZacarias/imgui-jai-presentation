UI_Text_Buffer :: struct (capacity: int) { data: [capacity] u8; count: s64; }

ui_text :: (buffer: *UI_Text_Buffer($capacity)) -> string { return .{ buffer.count, buffer.data.data }; }

ui_text_set :: (buffer: *UI_Text_Buffer($capacity), value: string) {
  buffer.count = min(value.count, capacity);
  memcpy(buffer.data.data, value.data, buffer.count);
}

ui_text_input :: (id: string, buffer: *UI_Text_Buffer($capacity), placeholder := "", disabled := false, loc := #caller_location) -> UI_Signal {
  return ui_text_field(id, .{ buffer.data.data, *buffer.count, capacity }, placeholder, disabled, loc);
}

ui_text_area :: (id: string, buffer: *UI_Text_Buffer($capacity), rows := 6, disabled := false, loc := #caller_location) -> UI_Signal {
  line_height := ui.metrics.line_height;
  box_height  := floor(line_height * cast(float) rows + 10.0);

  field_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  field_params.axis             = .Y;
  field_params.padding          = UI_CONTROL_PADDING;
  field_params.spacing          = 0.0;
  field_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  field_params.size.height      = .{ kind = .PIXELS, value = box_height };
  if ui_cache_get(ui_scoped_key(id, loc)).scroll_max > 0.5  field_params.pad_right = UI_SCROLLBAR_W + 4.0;
  field_params.name = "Text area";
  field_params.disabled = disabled;
  node    := ui_node(id, .CLICKABLE | .HOVERABLE | .SCROLL_Y, field_params, loc);
  cache   := ui_cache_get(node.key);
  signal  := ui_signal_from_node(node);
  key     := node.key;
  focused := ui_focused(key);

  edit := UI_Edit.{ buffer.data.data, *buffer.count, capacity };

  if signal.pressed  { ui_focus(key); focused = true; cache.blink_t = 0.0; }
  if focused && ui.input.mouse_pressed[0] && !signal.hovered { ui_blur(key); focused = false; }

  padding_x := node.inner.pos.x - node.rect.pos.x;
  padding_y := node.inner.pos.y - node.rect.pos.y;

  if signal.pressed || signal.held {
    relative_line := cast(s64) floor((ui.input.mouse_pos.y - node.inner.pos.y + cache.scroll) / line_height);
    line_start := 0;  line_index := 0;
    while line_index < relative_line {
      next_line := ui_line_tail(edit, line_start);
      if next_line >= buffer.count { line_start = next_line; break; }
      line_start = next_line + 1;  line_index += 1;
    }
    line_end := ui_line_tail(edit, line_start);
    hit := ui_column_hit(edit, line_start, line_end, ui.input.mouse_pos.x - node.inner.pos.x);
    cache.caret = hit;
    if signal.pressed && !ui.input.shift  cache.selection = hit;
    cache.blink_t = 0.0;
  }

  changed, submitted := false, false;
  if focused  changed, submitted = ui_edit_keys(edit, cache, multiline = true);
  if focused && ui_key_pressed(.ESCAPE)  { ui_blur(key); focused = false; }

  caret_line_start := ui_line_home(edit, cache.caret);
  caret_col_x      := ui_prefix_width(edit, caret_line_start, cache.caret);
  caret_line := 0;
  { scan := 0; while scan < caret_line_start { if edit.data[scan] == #char "\n"  caret_line += 1; scan += 1; } }

  caret_top := cast(float) caret_line * line_height;
  visible_height := node.inner.size.y;
  if caret_top < cache.scroll                          cache.scroll = caret_top;
  if caret_top + line_height > cache.scroll + visible_height  cache.scroll = caret_top + line_height - visible_height;
  cache.scroll = max(cache.scroll, 0.0);

  ui_push_parent(node);

  if focused && cache.caret != cache.selection {
    selection_low := min(cache.caret, cache.selection);
    selection_high := max(cache.caret, cache.selection);
    line_index := 0;  line_start := 0;
    while true {
      line_end := ui_line_tail(edit, line_start);
      clamped_lo := clamp(selection_low, line_start, line_end);
      clamped_hi := clamp(selection_high, line_start, line_end);
      covers_newline := selection_high > line_end && selection_low <= line_end;
      if clamped_hi > clamped_lo || covers_newline {
        x0 := ui_prefix_width(edit, line_start, clamped_lo);
        x1 := ui_prefix_width(edit, line_start, clamped_hi) + (ifx covers_newline then 6.0 else 0.0);
        highlight_params: UI_Params;
        highlight_params.offset              = .{ padding_x + x0, padding_y + cast(float) line_index * line_height - cache.scroll };
        highlight_params.size.width          = .{ kind = .PIXELS, value = max(2.0, x1 - x0) };
        highlight_params.size.height         = .{ kind = .PIXELS, value = line_height };
        highlight_params.background.normal   = ui_theme.slider_fill.normal;
        highlight_params.background.normal.w = 0.30;
        ui_node(id, "sel", line_index, .FLOATING, highlight_params, loc);
      }
      if line_end >= buffer.count  break;
      line_start = line_end + 1;  line_index += 1;
    }
  }

  // One non-floating node per line, so SCROLL_Y scrolls them and the scrollbar measures them.
  {
    line_start := 0;
    while true {
      line_end := ui_line_tail(edit, line_start);
      line_params: UI_Params;
      line_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
      line_params.size.height = .{ kind = .PIXELS, value = line_height };
      segment: string; segment.data = edit.data + line_start; segment.count = line_end - line_start;
      line_params.text        = segment;
      line_params.foreground  = ui_theme.text;
      ui_node(id, "ln", line_start, .DRAW_TEXT, line_params, loc);
      if line_end >= buffer.count  break;
      line_start = line_end + 1;
    }
  }

  if focused {
    cache.blink_t += ui.input.dt;
    if (cache.blink_t - floor(cache.blink_t)) < 0.55 {
      offset := Vector2.{ padding_x + caret_col_x, padding_y + cast(float) caret_line * line_height - cache.scroll };
      ui_draw_caret(id, offset, line_height, ui_caret_glyph_width(edit, cache.caret), loc);
    }
  }

  ui_pop_parent();
  ui_scrollbar(node, cache);

  signal.focused   = focused;
  signal.changed   = changed;
  signal.submitted = submitted;
  return signal;
}

// A translucent block, so the character under the caret stays legible.
ui_draw_caret :: (id: string, offset: Vector2, height: float, glyph_width: float, loc := #caller_location) {
  caret_params: UI_Params;
  caret_params.offset              = offset;
  caret_params.size.width          = .{ kind = .PIXELS, value = max(2.0, ifx glyph_width >= 1.0 then glyph_width else floor(ui.metrics.line_height * 0.5)) };
  caret_params.size.height         = .{ kind = .PIXELS, value = height };
  caret_params.background.normal   = ui_theme.text.normal;
  caret_params.background.normal.w = 0.45;
  ui_node(id, "caret", .FLOATING, caret_params, loc);
}

ui_caret_glyph_width :: (edit: UI_Edit, caret: s64) -> float {
  count := edit.count.*;
  if caret >= count || edit.data[caret] == #char "\n"  return 0.0;
  return ui_prefix_width(edit, caret, ui_codepoint_next(edit.data, count, caret));
}

ui_text_field :: (id: string, edit: UI_Edit, placeholder: string, disabled: bool, loc: Source_Code_Location) -> UI_Signal {
  box_height  := ui_title_height();

  field_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  field_params.axis             = .Y;
  field_params.padding          = UI_CONTROL_PADDING;
  field_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  field_params.size.height      = .{ kind = .PIXELS, value = box_height };
  field_params.name = "Text field";
  field_params.disabled = disabled;
  node    := ui_node(id, .CLICKABLE | .HOVERABLE, field_params, loc);
  cache   := ui_cache_get(node.key);
  signal  := ui_signal_from_node(node);
  key     := node.key;
  focused := ui_focused(key);

  if signal.pressed  { ui_focus(key); focused = true; cache.blink_t = 0.0; }
  if focused && ui.input.mouse_pressed[0] && !signal.hovered { ui_blur(key); focused = false; }

  padding_x := node.inner.pos.x - node.rect.pos.x;
  padding_y := node.inner.pos.y - node.rect.pos.y;
  text_origin_x := node.inner.pos.x - cache.text_scroll;

  if signal.pressed {
    cache.caret = ui_column_hit(edit, 0, edit.count.*, ui.input.mouse_pos.x - text_origin_x);
    if !ui.input.shift  cache.selection = cache.caret;
    cache.blink_t = 0.0;
  } else if signal.held {
    cache.caret = ui_column_hit(edit, 0, edit.count.*, ui.input.mouse_pos.x - text_origin_x);
  }

  changed, submitted := false, false;
  if focused  changed, submitted = ui_edit_keys(edit, cache, multiline = false);
  if focused && ui_key_pressed(.ESCAPE)  { ui_blur(key); focused = false; }

  caret_x := ui_prefix_width(edit, 0, cache.caret);
  inner_width := node.inner.size.x;
  if caret_x - cache.text_scroll > inner_width - 2.0  cache.text_scroll = caret_x - inner_width + 2.0;
  if caret_x - cache.text_scroll < 0.0                cache.text_scroll = caret_x;
  cache.text_scroll = max(cache.text_scroll, 0.0);

  contents: string;  contents.data = edit.data;  contents.count = edit.count.*;
  show_placeholder := contents.count == 0 && !focused && placeholder.count > 0;

  ui_push_parent(node);

  if focused && cache.caret != cache.selection {
    low := min(cache.caret, cache.selection);
    high := max(cache.caret, cache.selection);
    x0 := ui_prefix_width(edit, 0, low);
    x1 := ui_prefix_width(edit, 0, high);
    selection_params: UI_Params;
    selection_params.offset              = .{ padding_x - cache.text_scroll + x0, padding_y };
    selection_params.size.width          = .{ kind = .PIXELS, value = max(1.0, x1 - x0) };
    selection_params.size.height         = .{ kind = .PIXELS, value = node.inner.size.y };
    selection_params.background.normal   = ui_theme.slider_fill.normal;
    selection_params.background.normal.w = 0.35;
    selection_params.corner_radius       = min(ui_theme.corner_radius, 1.0);
    ui_node(id, "sel", .FLOATING, selection_params, loc);
  }

  // Wide enough for all of the text (or the placeholder), not just up to the caret:
  // sized from the caret, an unfocused field (caret at 0) clipped long text.
  shown_width := ui_prefix_width(edit, 0, edit.count.*);
  if show_placeholder {
    placeholder_width, _ := ui_measure_display(placeholder);
    shown_width = placeholder_width;
  }
  text_params: UI_Params;
  text_params.offset      = .{ padding_x - cache.text_scroll, padding_y };
  text_params.size.width  = .{ kind = .PIXELS, value = max(1.0, max(shown_width, caret_x) + 8.0) };
  text_params.size.height = .{ kind = .PIXELS, value = node.inner.size.y };
  text_params.foreground  = ui_theme.text;
  if show_placeholder {
    text_params.text                = placeholder;
    text_params.foreground.normal   = ui_theme.text.normal;
    text_params.foreground.normal.w = 0.4;
  } else {
    text_params.text = contents;
  }
  ui_node(id, "txt", .FLOATING | .DRAW_TEXT | .TEXT_CENTER_Y, text_params, loc);

  if focused {
    cache.blink_t += ui.input.dt;
    if (cache.blink_t - floor(cache.blink_t)) < 0.55 {
      offset := Vector2.{ padding_x - cache.text_scroll + caret_x, padding_y };
      ui_draw_caret(id, offset, node.inner.size.y, ui_caret_glyph_width(edit, cache.caret), loc);
    }
  }

  ui_pop_parent();

  signal.focused   = focused;
  signal.changed   = changed;
  signal.submitted = submitted;
  return signal;
}

UI_Edit :: struct {
  data:     *u8;
  count:    *s64;
  capacity: s64;
}

ui_utf8_is_cont :: inline (byte: u8) -> bool { return (byte & 0xC0) == 0x80; }

ui_codepoint_prev :: (data: *u8, index: s64) -> s64 {
  index -= 1;
  while index > 0 && ui_utf8_is_cont(data[index])  index -= 1;
  return max(index, 0);
}
ui_codepoint_next :: (data: *u8, count: s64, index: s64) -> s64 {
  if index >= count  return count;
  index += 1;
  while index < count && ui_utf8_is_cont(data[index])  index += 1;
  return min(index, count);
}

ui_is_word_char :: inline (byte: u8) -> bool {
  return (byte >= #char "0" && byte <= #char "9") ||
         (byte >= #char "A" && byte <= #char "Z") ||
         (byte >= #char "a" && byte <= #char "z") ||
         byte == #char "_" || byte >= 0x80; // non-ASCII counts as word content
}

ui_word_left :: (data: *u8, count: s64, index: s64) -> s64 {
  index = clamp(index, 0, count);
  while index > 0 && !ui_is_word_char(data[index - 1])  index -= 1;
  while index > 0 &&  ui_is_word_char(data[index - 1])  index -= 1;
  return index;
}
ui_word_right :: (data: *u8, count: s64, index: s64) -> s64 {
  index = clamp(index, 0, count);
  while index < count && !ui_is_word_char(data[index])  index += 1;
  while index < count &&  ui_is_word_char(data[index])  index += 1;
  return index;
}

// memcpy must not overlap.
ui_bytes_move :: (destination: *u8, source: *u8, count: s64) {
  if count <= 0 || destination == source  return;
  if destination < source { for 0..count-1  destination[it] = source[it]; }
  else         { i := count - 1; while i >= 0 { destination[i] = source[i]; i -= 1; } }
}

ui_edit_delete :: (edit: UI_Edit, low: s64, high: s64) {
  count := edit.count.*;
  low = clamp(low, 0, count);
  high = clamp(high, 0, count);
  if high <= low  return;
  tail := count - high;
  ui_bytes_move(edit.data + low, edit.data + high, tail);
  edit.count.* = low + tail;
}

ui_edit_insert :: (edit: UI_Edit, at: s64, text: string) -> s64 {
  count := edit.count.*;
  at = clamp(at, 0, count);
  added := text.count;
  if count + added > edit.capacity  added = edit.capacity - count;
  if added <= 0  return at;
  tail := count - at;
  ui_bytes_move(edit.data + at + added, edit.data + at, tail);
  memcpy(edit.data + at, text.data, added);
  edit.count.* = count + added;
  return at + added;
}

ui_prefix_width :: (edit: UI_Edit, from: s64, to: s64) -> float {
  measure := ui.metrics.measure_text;
  if !measure || to <= from  return 0.0;
  slice: string; slice.data = edit.data + from; slice.count = to - from;
  return measure(ui.metrics.font, slice);
}

ui_column_hit :: (edit: UI_Edit, low: s64, high: s64, target_x: float) -> s64 {
  measure := ui.metrics.measure_text;
  if !measure  return low;
  best_offset   := low;
  best_distance := abs(target_x);
  accumulated_x := 0.0;
  offset := low;
  while offset < high {
    next_offset := ui_codepoint_next(edit.data, high, offset);
    segment: string; segment.data = edit.data + offset; segment.count = next_offset - offset;
    accumulated_x += measure(ui.metrics.font, segment);
    distance := abs(target_x - accumulated_x);
    if distance < best_distance { best_distance = distance; best_offset = next_offset; }
    offset = next_offset;
  }
  return best_offset;
}

ui_line_home :: (edit: UI_Edit, index: s64) -> s64 { while index > 0 && edit.data[index-1] != #char "\n"  index -= 1;  return index; }
ui_line_tail :: (edit: UI_Edit, index: s64) -> s64 { count := edit.count.*;  while index < count && edit.data[index] != #char "\n"  index += 1;  return index; }

ui_line_step :: (edit: UI_Edit, caret: s64, direction: int) -> s64 {
  line_start := ui_line_home(edit, caret);
  column_x   := ui_prefix_width(edit, line_start, caret);
  if direction < 0 {
    if line_start == 0  return 0;
    prev_line_start := ui_line_home(edit, line_start - 1);
    return ui_column_hit(edit, prev_line_start, line_start - 1, column_x);
  }
  line_end := ui_line_tail(edit, caret);
  if line_end >= edit.count.*  return edit.count.*;
  next_line_end := ui_line_tail(edit, line_end + 1);
  return ui_column_hit(edit, line_end + 1, next_line_end, column_x);
}

ui_edit_keys :: (edit: UI_Edit, cache: *UI_Node_Cache, multiline: bool) -> changed: bool, submitted: bool {
  changed   := false;
  submitted := false;

  ctrl  := ui.input.ctrl;
  shift := ui.input.shift;

  cache.caret = clamp(cache.caret, 0, edit.count.*);
  cache.selection   = clamp(cache.selection,   0, edit.count.*);

  move :: (to: s64) #expand {
    `cache.caret = clamp(to, 0, `edit.count.*);
    if !`shift  `cache.selection = `cache.caret;
    `cache.blink_t = 0.0;
  }
  delete_selection :: () #expand {
    low := min(`cache.caret, `cache.selection);
    high := max(`cache.caret, `cache.selection);
    ui_edit_delete(`edit, low, high);
    `cache.caret = low; `cache.selection = low;
    `changed = true; `cache.blink_t = 0.0;
  }
  insert :: (text: string) #expand {
    if `cache.caret != `cache.selection {
      low := min(`cache.caret, `cache.selection);
      high := max(`cache.caret, `cache.selection);
      ui_edit_delete(`edit, low, high);
      `cache.caret = low; `cache.selection = low;
    }
    `cache.caret = ui_edit_insert(`edit, `cache.caret, text);
    `cache.selection   = `cache.caret;
    `changed = true; `cache.blink_t = 0.0;
  }

  has_selection := cache.caret != cache.selection;
  low := min(cache.caret, cache.selection);
  high := max(cache.caret, cache.selection);

  if ui.input.text.count > 0 { insert(ui.input.text); has_selection = false; }

  get_clipboard := ui.metrics.get_clipboard;
  set_clipboard := ui.metrics.set_clipboard;
  if ctrl && ui_key_pressed(.C) && has_selection && set_clipboard {
    selected_slice: string; selected_slice.data = edit.data + low; selected_slice.count = high - low; set_clipboard(selected_slice);
  }
  if ctrl && ui_key_pressed(.X) && has_selection && set_clipboard {
    selected_slice: string; selected_slice.data = edit.data + low; selected_slice.count = high - low; set_clipboard(selected_slice);
    delete_selection(); has_selection = false;
  }
  if ctrl && ui_key_pressed(.V) && get_clipboard {
    raw := get_clipboard();
    sanitized: [..] u8; sanitized.allocator = ui_frame_allocator();
    saw_cr := false;
    for 0..raw.count-1 {
      byte := raw[it];
      if byte == #char "\r" { array_add(*sanitized, ifx multiline then cast(u8) #char "\n" else #char " "); saw_cr = true; continue; }
      if byte == #char "\n" { if saw_cr { saw_cr = false; continue; } array_add(*sanitized, ifx multiline then cast(u8) #char "\n" else #char " "); continue; }
      saw_cr = false;
      if byte == #char "\t"  array_add(*sanitized, #char " ");
      else if byte >= 0x20   array_add(*sanitized, byte);
    }
    text: string; text.data = sanitized.data; text.count = sanitized.count;
    insert(text); has_selection = false;
  }

  if ui_key_pressed(.BACKSPACE) {
    if has_selection  delete_selection();
    else if cache.caret > 0 {
      word_start := ifx ctrl then ui_word_left(edit.data, edit.count.*, cache.caret) else ui_codepoint_prev(edit.data, cache.caret);
      ui_edit_delete(edit, word_start, cache.caret);
      cache.caret = word_start; cache.selection = word_start; changed = true; cache.blink_t = 0.0;
    }
  }
  if ui_key_pressed(.DELETE) {
    if has_selection  delete_selection();
    else if cache.caret < edit.count.* {
      word_end := ifx ctrl then ui_word_right(edit.data, edit.count.*, cache.caret) else ui_codepoint_next(edit.data, edit.count.*, cache.caret);
      ui_edit_delete(edit, cache.caret, word_end);
      cache.selection = cache.caret; changed = true; cache.blink_t = 0.0;
    }
  }
  if ui_key_pressed(.LEFT) {
    if      has_selection && !shift  move(ifx ctrl then ui_word_left(edit.data, edit.count.*, low) else low);
    else if ctrl                     move(ui_word_left(edit.data, edit.count.*, cache.caret));
    else                             move(ui_codepoint_prev(edit.data, cache.caret));
  }
  if ui_key_pressed(.RIGHT) {
    if      has_selection && !shift  move(ifx ctrl then ui_word_right(edit.data, edit.count.*, high) else high);
    else if ctrl                     move(ui_word_right(edit.data, edit.count.*, cache.caret));
    else                             move(ui_codepoint_next(edit.data, edit.count.*, cache.caret));
  }
  if multiline && ui_key_pressed(.UP)    move(ui_line_step(edit, cache.caret, -1));
  if multiline && ui_key_pressed(.DOWN)  move(ui_line_step(edit, cache.caret,  1));
  if ui_key_pressed(.HOME)  move(ifx multiline then ui_line_home(edit, cache.caret) else 0);
  if ui_key_pressed(.END)   move(ifx multiline then ui_line_tail(edit, cache.caret) else edit.count.*);
  if ctrl && ui_key_pressed(.A)  { cache.selection = 0; cache.caret = edit.count.*; cache.blink_t = 0.0; }
  if ui_key_pressed(.ENTER) {
    if multiline  insert("\n");
    else          submitted = true;
  }

  return changed, submitted;
}
