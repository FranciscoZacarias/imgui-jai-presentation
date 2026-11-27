ui_font: *Font;
ui_previous_mouse:     Vector2;
ui_has_previous_mouse: bool;

UI_FONT_PATH   :: #run tprint("%Assets/Fonts/MartianMono-CnLt.ttf", #filepath);
UI_WHEEL_NOTCH :: 120.0;

ui_setup :: () {
  ui_font = r_load_font(*renderer, "UI Font", UI_FONT_PATH, pixel_height = 16);
  if !ui_font  log("Unable to load the font %", UI_FONT_PATH);

  ui_init();
  atlas := r_create_texture_from_pixels(*renderer, "UI Atlas", UI_ATLAS_SIZE, UI_ATLAS_SIZE, ui_default_atlas_pixels);
  ui_default_atlas = cast(UI_Texture) atlas;   // the UI only keeps the handle
}

ui_frame_begin :: () {
  input: UI_Input;
  input.screen_size = .{ cast(float) app.window_width, cast(float) app.window_height };
  input.mouse_pos   = .{ cast(float) app.mouse_x, cast(float) app.mouse_y };
  // From the cursor position, not the raw device delta: raw deltas are in mouse
  // counts (no pointer acceleration), so dragging by them outruns the cursor.
  if ui_has_previous_mouse  input.mouse_delta = input.mouse_pos - ui_previous_mouse;
  ui_previous_mouse     = input.mouse_pos;
  ui_has_previous_mouse = true;
  input.dt          = cast(float) app.delta_time;

  mouse_buttons := Input.Key_Code.[ .MOUSE_BUTTON_LEFT, .MOUSE_BUTTON_RIGHT, .MOUSE_BUTTON_MIDDLE ];
  for button, button_index: mouse_buttons {
    input.mouse_down[button_index]     = is_key_down(button);
    input.mouse_pressed[button_index]  = is_key_clicked(button);
    input.mouse_released[button_index] = is_key_released(button);
  }

  input.scroll        = -cast(float) Input.mouse_delta_z / UI_WHEEL_NOTCH;
  input.ctrl          = is_key_down(.CTRL);
  input.shift         = is_key_down(.SHIFT);
  input.dock_modifier = input.shift;

  text_builder: String_Builder;
  text_builder.allocator = temp;
  for event: Input.events_this_frame {
    if event.type == .TEXT_INPUT {
      utf8_buffer: [4] u8;
      byte_count := ui_utf8_encode(event.utf32, utf8_buffer);
      append(*text_builder, utf8_buffer.data, byte_count);
    }

    if event.type == .KEYBOARD && event.key_pressed {
      if event.key_code == {
        case .BACKSPACE;    input.keys[UI_Key.BACKSPACE] = true;
        case .DELETE;       input.keys[UI_Key.DELETE]    = true;
        case .ARROW_LEFT;   input.keys[UI_Key.LEFT]      = true;
        case .ARROW_RIGHT;  input.keys[UI_Key.RIGHT]     = true;
        case .ARROW_UP;     input.keys[UI_Key.UP]        = true;
        case .ARROW_DOWN;   input.keys[UI_Key.DOWN]      = true;
        case .HOME;         input.keys[UI_Key.HOME]      = true;
        case .END;          input.keys[UI_Key.END]       = true;
        case .ENTER;        input.keys[UI_Key.ENTER]     = true;
        case .ESCAPE;       input.keys[UI_Key.ESCAPE]    = true;
        case .TAB;          input.keys[UI_Key.TAB]       = true;
        case xx #char "A";  input.keys[UI_Key.A]         = true;
        case xx #char "C";  input.keys[UI_Key.C]         = true;
        case xx #char "V";  input.keys[UI_Key.V]         = true;
        case xx #char "X";  input.keys[UI_Key.X]         = true;
      }
    }
  }
  input.text = builder_to_string(*text_builder,, temp);

  metrics: UI_Metrics;
  metrics.font        = cast(UI_Font) ui_font;   // an opaque handle: the UI never looks inside
  metrics.line_height = ui_font.line_height;
  metrics.ascent      = ui_font.ascent;
  metrics.get_glyph   = ui_get_glyph;
  #if OS == .WINDOWS {
    metrics.get_clipboard = ui_get_clipboard;
    metrics.set_clipboard = ui_set_clipboard;
  }

  ui_begin(input, metrics);
}

ui_frame_end :: () {
  ui_end();
}

ui_draw :: () {
  for quad: ui_quads() {
    texture := cast(*Texture) quad.texture;   // the handle we gave the UI, back again
    r_push_clip_rect(*renderer, quad.clip.pos, quad.clip.size);
    r_draw_screen_quad(*renderer, quad.rect.pos, quad.rect.size, tint = quad.color, texture = texture, uv_min = quad.uv_min, uv_max = quad.uv_max,
                       border_thickness = quad.border_thickness, border_color = quad.border_color, border_radius = quad.corner_radius,
                       rotation = quad.rotation, corners = quad.corner_mask);  // UI_CORNER_* bits match R_CORNER_*
    r_pop_clip_rect(*renderer);
  }
}

#scope_file

ui_get_glyph :: (font: UI_Font, codepoint: u32) -> (found: bool, glyph: UI_Glyph) {
  f := cast(*Font) font;
  if codepoint < f.first_codepoint || codepoint >= f.first_codepoint + f.num_glyphs  return false, .{};

  g := f.glyphs[codepoint - f.first_codepoint];
  glyph: UI_Glyph;
  glyph.texture = cast(UI_Texture) f.atlas;
  glyph.uv_min  = g.uv_min;
  glyph.uv_max  = g.uv_max;
  glyph.size    = g.size;
  glyph.bearing = g.bearing;
  glyph.advance = g.advance;
  return true, glyph;
}

#if OS == .WINDOWS {
  ui_get_clipboard :: () -> string {
    text := os_clipboard_get_text();
    defer free(text);
    return copy_temporary_string(text);
  }

  ui_set_clipboard :: (text: string) {
    os_clipboard_set_text(text);
  }
}
