// layer is a painter's-order key: higher = drawn later = on top. Sorting only
// kicks in when some layer != 0, so the common "just draw in order" path stays sort-free.
R_CORNER_TL   : u8 : 0x1;
R_CORNER_TR   : u8 : 0x2;
R_CORNER_BR   : u8 : 0x4;
R_CORNER_BL   : u8 : 0x8;
R_CORNERS_ALL : u8 : 0xF;

r_draw_screen_quad :: (renderer: *Renderer, top_left: Vector2, size: Vector2, 
                       tint := Vector4.{1, 1, 1, 1}, texture: *Texture = null, 
                       uv_min := Vector2.{0, 0}, uv_max := Vector2.{1, 1}, 
                       border_thickness: float = 0.0, border_color := Vector4.{0, 0, 0, 0}, 
                       border_radius: float = 0.0, layer: float = 0.0, 
                       rotation: float = 0.0, corners := R_CORNERS_ALL) {
  if !renderer.active_pass {
    log_error("r_draw_screen_quad called outside of a pass");
    return;
  }
  if current_clip_is_empty(renderer)  return;
  if !texture  texture = renderer.white_texture;

  clip := current_clip(renderer);

  corner_radius :: (mask: u8, bit: u8, radius: float) -> float {
    return ifx (mask & bit) != 0 then radius else 0.0;
  }
  radii := Vector4.{ corner_radius(corners, R_CORNER_TL, border_radius), corner_radius(corners, R_CORNER_TR, border_radius),
                     corner_radius(corners, R_CORNER_BR, border_radius), corner_radius(corners, R_CORNER_BL, border_radius) };

  instance: Screen_Quad_Instance;
  instance.top_left = top_left;
  instance.size     = size;
  instance.uv_min   = uv_min;
  instance.uv_max   = uv_max;
  instance.tint     = vector4_pack(tint);
  instance.texture_unit_index = texture.texture_unit_index;
  instance.border_thickness   = border_thickness;
  instance.border_color       = vector4_pack(border_color);
  instance.rotation           = rotation;
  instance.clip_min = clip.min;
  instance.clip_max = clip.max;
  instance.corner_radii = radii;
  instance.sort_key = layer;
  instance._seq     = renderer.frame_seq;
  renderer.frame_seq += 1;

  if layer != 0.0  renderer.screen_needs_sort = true;

  array_add(*renderer.immediate_screen_quads, instance);

  #if DEBUG {
    renderer.stats.screen_quads    += 1;
    renderer.stats.quads_submitted += 1;
  }
}

r_draw_screen_line :: (renderer: *Renderer, a: Vector2, b: Vector2, thickness: float = 1.0, tint := Vector4.{1, 1, 1, 1}, layer: float = 0.0) {
  delta  := b - a;
  length := sqrt(delta.x * delta.x + delta.y * delta.y);
  if length <= 0.0  return;

  center := (a + b) * 0.5;
  angle  := atan2(delta.y, delta.x);
  thick  := max(thickness, 1.0);
  r_draw_screen_quad(renderer, center - Vector2.{ length, thick } * 0.5, .{ length, thick },
                     tint = tint, layer = layer, rotation = angle);
}

r_draw_screen_text :: (renderer: *Renderer, font: *Font, text: string, x: float, y: float, tint := Vector4.{0, 0, 0, 1}, layer: float = 0.0) {
  if !font {
    log_error("Provided a null font while trying to draw text!");
    return;
  }
  if !renderer.active_pass {
    log_error("r_draw_screen_text called outside of a pass");
    return;
  }
  if current_clip_is_empty(renderer)  return;

  packed     := vector4_pack(tint);
  atlas_unit := font.atlas.texture_unit_index;
  clip       := current_clip(renderer);

  if layer != 0.0  renderer.text_needs_sort = true;

  pen_x := x;
  // Offset the initial pen so (x, y) is the top-left of the text block.
  pen_y := y + font.ascent;

  i := 0;
  while i < text.count {
    codepoint, size := utf8_decode(text, i);
    i += size;

    if codepoint == #char "\n" {
      pen_x = x;
      pen_y += font.line_height;
      continue;
    }

    if codepoint < font.first_codepoint || codepoint >= (font.first_codepoint + font.num_glyphs) {
      continue;
    }

    glyph := font.glyphs[codepoint - font.first_codepoint];

    if glyph.size.x > 0 && glyph.size.y > 0 {
      instance: Text_Quad_Instance;
      instance.top_left = .{pen_x + glyph.bearing.x, pen_y - glyph.bearing.y};
      instance.size     = glyph.size;
      instance.uv_min   = glyph.uv_min;
      instance.uv_max   = glyph.uv_max;
      instance.tint     = packed;
      instance.texture_unit_index = atlas_unit;
      instance.clip_min = clip.min;
      instance.clip_max = clip.max;
      instance.sort_key = layer;
      instance._seq     = renderer.frame_seq;
      renderer.frame_seq += 1;

      array_add(*renderer.immediate_text_quads, instance);

      #if DEBUG {
        renderer.stats.text_quads      += 1;
        renderer.stats.quads_submitted += 1;
      }
    }

    pen_x += glyph.advance;
  }
}

// Like r_draw_screen_text but through the screen-quad pipeline, for interleaving
// with r_draw_screen_quad by layer (the text pipeline always flushes after).
r_draw_screen_glyphs :: (renderer: *Renderer, font: *Font, text: string, x: float, y: float, tint := Vector4.{1, 1, 1, 1}, layer: float = 0.0) {
  if !font  return;
  if !renderer.active_pass {
    log_error("r_draw_screen_glyphs called outside of a pass");
    return;
  }

  pen_x := x;
  pen_y := y + font.ascent;

  i := 0;
  while i < text.count {
    codepoint, size := utf8_decode(text, i);
    i += size;

    if codepoint == #char "\n" {
      pen_x = x;
      pen_y += font.line_height;
      continue;
    }
    if codepoint < font.first_codepoint || codepoint >= (font.first_codepoint + font.num_glyphs)  continue;

    glyph := font.glyphs[codepoint - font.first_codepoint];
    if glyph.size.x > 0 && glyph.size.y > 0 {
      r_draw_screen_quad(renderer, .{ pen_x + glyph.bearing.x, pen_y - glyph.bearing.y }, glyph.size,
                         tint = tint, texture = font.atlas,
                         uv_min = glyph.uv_min, uv_max = glyph.uv_max, layer = layer);
    }
    pen_x += glyph.advance;
  }
}

r_measure_text :: (font: *Font, text: string) -> width: s32, height: s32 {
  if !font || text.count == 0  return 0, 0;

  max_width     := 0.0;
  current_width := 0.0;
  line_count    := 1;

  i := 0;
  while i < text.count {
    codepoint, size := utf8_decode(text, i);
    i += size;

    if codepoint == #char "\n" {
      max_width = max(max_width, current_width);
      current_width = 0.0;
      line_count += 1;
      continue;
    }
    if codepoint < font.first_codepoint || codepoint >= (font.first_codepoint + font.num_glyphs)  continue;

    current_width += font.glyphs[codepoint - font.first_codepoint].advance;
  }
  max_width = max(max_width, current_width);

  return cast(s32) max_width, cast(s32) (line_count * font.line_height);
}

#scope_module

// On malformed input, returns U+FFFD and size 1 so callers still make progress.
utf8_decode :: (text: string, i: s64) -> codepoint: u32, size: s64 {
  first_byte := text[i];
  if first_byte < 0x80  return first_byte, 1;

  size:  s64;
  value: s64;
  if      (first_byte & 0xE0) == 0xC0 { size = 2; value = first_byte & 0x1F; }
  else if (first_byte & 0xF0) == 0xE0 { size = 3; value = first_byte & 0x0F; }
  else if (first_byte & 0xF8) == 0xF0 { size = 4; value = first_byte & 0x07; }
  else                                 return 0xFFFD, 1;

  if i + size > text.count  return 0xFFFD, 1;
  for 1..size-1 {
    continuation_byte := text[i + it];
    if (continuation_byte & 0xC0) != 0x80  return 0xFFFD, 1;
    value = (value << 6) | (continuation_byte & 0x3F);
  }
  return cast(u32) value, size;
}
