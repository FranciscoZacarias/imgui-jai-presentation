ui_number_field :: (id: string, value: *$T, disabled := false, loc := #caller_location) -> bool
#modify {
  info := cast(*Type_Info) T;
  if info.type != .INTEGER && info.type != .FLOAT  return false, "ui_number_field: T must be an int or float type.";
  return true;
} {
  info    := type_info(T);
  pointer := cast(*void) value;

  is_float := info.type == .FLOAT;
  int_size := info.runtime_size;
  signed   := ifx info.type == .INTEGER then (cast(*Type_Info_Integer) info).signed else true;

  box_height := ui_title_height();
  field_params: UI_Params;
  field_params.axis             = .Y;
  field_params.padding          = UI_CONTROL_PADDING;
  field_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  field_params.size.height      = .{ kind = .PIXELS, value = box_height };
  field_params.background       = ui_theme.slider_track;
  field_params.border_thickness = ui_theme.border_thickness;
  field_params.corner_radius    = ui_theme.corner_radius;
  field_params.animate          = true;
  field_params.name = "Number field";
  field_params.disabled = disabled;
  node    := ui_node(id, .CLICKABLE | .HOVERABLE, field_params, loc);
  key     := node.key;
  cache   := ui_cache_get(key);
  signal  := ui_signal_from_node(node);
  focused := ui_focused(key);

  flash_amount := ifx ui_number_edit.flash_key == key then clamp(ui_number_edit.flash / 0.4, 0.0, 1.0) else 0.0;
  border_color := ui_mix(ui_theme.button_border.normal, ui_theme.danger.normal, flash_amount);
  node.border = .{ normal = border_color, hover = border_color, active = border_color };

  if signal.pressed  { ui_focus(key); focused = true; cache.blink_t = 0.0; }

  current_string :: (pointer: *void, float_value: bool, size: s64, is_signed: bool) -> string {
    return ifx float_value then tprint("%", (cast(*float) pointer).*) else tprint("%", ui_read_int(pointer, size, is_signed));
  }

  if focused && ui_number_edit.key != key {
    ui_number_edit.key = key;
    ui_text_set(*ui_number_edit.buffer, current_string(pointer, is_float, int_size, signed));
    cache.caret = ui_number_edit.buffer.count;  cache.selection = cache.caret;
  }

  changed := false;
  if focused && ui_number_edit.key == key {
    edit := UI_Edit.{ ui_number_edit.buffer.data.data, *ui_number_edit.buffer.count, ui_number_edit.buffer.data.count };

    typed := ui.input.text;
    if typed.count > 0 {
      have_decimal_point := ui_bytes_contain(ui_number_edit.buffer.data.data, ui_number_edit.buffer.count, #char ".");
      filtered: [..] u8;  filtered.allocator = ui_frame_allocator();
      rejected := false;
      for 0..typed.count-1 {
        byte := typed[it];
        accepted := (byte >= #char "0" && byte <= #char "9")
                 || (byte == #char "-" && cache.caret == 0 && cache.selection == 0)
                 || (byte == #char "." && is_float && !have_decimal_point);
        if accepted {
          if byte == #char "."  have_decimal_point = true;
          array_add(*filtered, byte);
        } else {
          rejected = true;
        }
      }
      if rejected  { ui_number_edit.flash = 0.4; ui_number_edit.flash_key = key; }
      filtered_text: string;  filtered_text.data = filtered.data;  filtered_text.count = filtered.count;
      ui.input.text = filtered_text;
    }

    _, submitted := ui_edit_keys(edit, cache, multiline = false);
    ui.input.text = typed;

    escape := ui_key_pressed(.ESCAPE);
    lost   := ui.input.mouse_pressed[0] && !signal.hovered;
    if submitted || lost || escape {
      if !escape {
        if ui_number_commit(pointer, info, ui_text(*ui_number_edit.buffer), int_size, is_float)  changed = true;
        else  { ui_number_edit.flash = 0.5;  ui_number_edit.flash_key = key; }
      }
      ui_number_edit.key = 0;
      if lost || escape  ui_blur(key);
    }
  }

  if ui_number_edit.flash_key == key {
    ui_number_edit.flash = max(0.0, ui_number_edit.flash - ui.input.dt);
    if ui_number_edit.flash <= 0.0  ui_number_edit.flash_key = 0;
  }

  padding_x := node.inner.pos.x - node.rect.pos.x;
  padding_y := node.inner.pos.y - node.rect.pos.y;
  editing := focused && ui_number_edit.key == key;
  display := ifx editing then ui_text(*ui_number_edit.buffer) else current_string(pointer, is_float, int_size, signed);

  ui_push_parent(node);
  text_params: UI_Params;
  text_params.offset  = .{ padding_x, padding_y };
  text_params.size.width = .{ kind = .PARENT_FRACTION, value = 1.0 };
  text_params.size.height = .{ kind = .PIXELS, value = node.inner.size.y };
  text_params.text        = display;
  text_params.foreground   = ui_theme.text;
  ui_node(id, "nt", .FLOATING | .DRAW_TEXT | .TEXT_CENTER_Y, text_params, loc);

  if editing {
    edit := UI_Edit.{ ui_number_edit.buffer.data.data, *ui_number_edit.buffer.count, ui_number_edit.buffer.data.count };
    caret_x := ui_prefix_width(edit, 0, clamp(cache.caret, 0, ui_number_edit.buffer.count));
    cache.blink_t += ui.input.dt;
    if (cache.blink_t - floor(cache.blink_t)) < 0.55 {
      ui_draw_caret(id, .{ padding_x + caret_x, padding_y }, node.inner.size.y,
                    ui_caret_glyph_width(edit, clamp(cache.caret, 0, ui_number_edit.buffer.count)), loc);
    }
  }
  ui_pop_parent();
  return changed;
}

ui_read_int :: (pointer: *void, size: s64, signed: bool) -> s64 {
  if signed {
    if size == 1  return (cast(*s8)  pointer).*;
    if size == 2  return (cast(*s16) pointer).*;
    if size == 4  return (cast(*s32) pointer).*;
    return (cast(*s64) pointer).*;
  }
  if size == 1  return cast(s64) (cast(*u8)  pointer).*;
  if size == 2  return cast(s64) (cast(*u16) pointer).*;
  if size == 4  return cast(s64) (cast(*u32) pointer).*;
  return cast(s64) (cast(*u64) pointer).*;
}

ui_write_int :: (pointer: *void, size: s64, value: s64) {
  if size == 1  { (cast(*u8)  pointer).* = cast(u8)  (value & 0xFF);        return; }
  if size == 2  { (cast(*u16) pointer).* = cast(u16) (value & 0xFFFF);      return; }
  if size == 4  { (cast(*u32) pointer).* = cast(u32) (value & 0xFFFF_FFFF); return; }
  (cast(*s64) pointer).* = value;
}

#scope_file

ui_number_edit: struct {
  key:       u64;
  buffer:    UI_Text_Buffer(64);
  flash:     float;
  flash_key: u64;
};

ui_bytes_contain :: (data: *u8, count: s64, byte: u8) -> bool {
  for 0..count-1  if data[it] == byte  return true;
  return false;
}

ui_number_commit :: (pointer: *void, info: *Type_Info, text: string, int_size: s64, is_float: bool) -> bool {
  trimmed := text;
  while trimmed.count > 0 && trimmed[0] == #char " "                { trimmed.data += 1; trimmed.count -= 1; }
  while trimmed.count > 0 && trimmed[trimmed.count - 1] == #char " "  trimmed.count -= 1;

  if trimmed.count == 0 {
    if is_float  { (cast(*float) pointer).* = 0.0; }
    else         { ui_write_int(pointer, int_size, 0); }
    return true;
  }
  if trimmed == "-" || trimmed == "." || trimmed == "-."  return false;

  if is_float {
    if info.runtime_size == 8 {
      value, ok, remainder := string_to_float64(trimmed);
      if !ok || remainder.count != 0  return false;
      (cast(*float64) pointer).* = value;
    } else {
      value, ok, remainder := string_to_float(trimmed);
      if !ok || remainder.count != 0  return false;
      (cast(*float) pointer).* = value;
    }
    return true;
  }

  value, ok, remainder := string_to_int(trimmed, 10, s64);
  if !ok || remainder.count != 0  return false;
  ui_write_int(pointer, int_size, value);
  return true;
}
