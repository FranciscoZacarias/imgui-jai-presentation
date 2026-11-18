Glyph :: struct {
  codepoint: u32;

  uv_min: Vector2;
  uv_max: Vector2;

  size:     Vector2; // bitmap width/height, px
  bearing:  Vector2; // baseline to top-left of glyph, px
  advance:  float;   // horizontal advance, px
}

Font :: struct {
  label: string;
  atlas: *Texture;

  face:      FT_Face; // kept alive so the font can be re-sized later
  ttf_bytes: [] u8;   // FT_New_Memory_Face keeps a pointer into this; freed in r_deinit

  glyphs: [..]Glyph; // indexed by codepoint minus first_codepoint
  first_codepoint: u32;
  num_glyphs: u32;

  height:      float; // requested pixel height
  ascent:      float;
  descent:     float;
  line_height: float;
}

r_init_freetype :: (renderer: *Renderer) {
  error := FT_Init_FreeType(*renderer.ft_library);
  if error {
    log_error("Failed to initialize FreeType");
    assert(false);
  }
}

r_deinit_freetype :: (renderer: *Renderer) {
  if renderer.ft_library  FT_Done_FreeType(renderer.ft_library);
  renderer.ft_library = null;
}

r_load_font :: (renderer: *Renderer, label: string, path: string, pixel_height: float = 32.0, first_codepoint: u32 = 32, num_glyphs: u32 = 96) -> *Font {
  file_data, ok := read_entire_file(path);
  defer free(file_data); // r_load_font_from_memory keeps its own copy
  if !ok {
    log_error("Failed to read font file '%'", path);
    assert(false);
  }
  return r_load_font_from_memory(renderer, label, file_data, pixel_height, first_codepoint, num_glyphs);
}

r_load_font_from_memory :: (renderer: *Renderer, label: string, data: string, pixel_height: float = 32.0, first_codepoint: u32 = 32, num_glyphs: u32 = 96) -> *Font {
  ttf_bytes := NewArray(data.count, u8, initialized = false);
  memcpy(ttf_bytes.data, data.data, data.count);

  face: FT_Face;
  error := FT_New_Memory_Face(renderer.ft_library, ttf_bytes.data, cast(s32) ttf_bytes.count, 0, *face);
  if error {
    log_error("FreeType: failed to load font face from memory (error %)", error);
    assert(false);
  }

  font := New(Font);
  font.label           = copy_string(label);
  font.face            = face;
  font.ttf_bytes       = ttf_bytes;
  font.first_codepoint = first_codepoint;
  font.num_glyphs      = num_glyphs;
  font_rasterize(renderer, font, pixel_height);

  array_add(*renderer.fonts, font);
  return font;
}

r_resize_font :: (renderer: *Renderer, font: *Font, pixel_height: float) {
  if font.height == pixel_height  return;
  font_rasterize(renderer, font, pixel_height);
}

#scope_file

font_rasterize :: (renderer: *Renderer, font: *Font, pixel_height: float) {
  face            := font.face;
  first_codepoint := font.first_codepoint;
  num_glyphs      := font.num_glyphs;

  error := FT_Set_Pixel_Sizes(face, 0, xx pixel_height);
  if error {
    log_error("FreeType: failed to set pixel size %", pixel_height);
    assert(false);
  }
  atlas_width  := 512;
  atlas_height := 512;
  padding      := 1;

  cursor_x   := padding;
  cursor_y   := padding;
  row_height := 0;

  for i: 0..num_glyphs-1 {
    codepoint := first_codepoint + i;

    error = FT_Load_Char(face, codepoint, FT_LOAD_RENDER);
    if error continue;

    bitmap := face.glyph.bitmap;
    w := xx bitmap.width;
    h := xx bitmap.rows;

    if cursor_x + w + padding >= atlas_width {
      cursor_x = padding;
      cursor_y += row_height + padding;
      row_height = 0;
    }

    if cursor_y + h + padding >= atlas_height {
      atlas_height *= 2;
    }

    cursor_x += w + padding;
    row_height = max(row_height, h);
  }

  atlas_height = max(atlas_height, cursor_y + row_height + padding);

  atlas_pixels := NewArray(atlas_width * atlas_height * 4, u8);
  defer array_free(atlas_pixels);

  glyphs := *font.glyphs;
  array_resize(glyphs, num_glyphs);
  for * glyphs.*  it.* = .{};

  cursor_x   = padding;
  cursor_y   = padding;
  row_height = 0;

  for i: 0..num_glyphs-1 {
    codepoint := first_codepoint + i;

    error = FT_Load_Char(face, codepoint, FT_LOAD_RENDER);
    if error continue;

    ft_glyph := face.glyph;
    bitmap   := ft_glyph.bitmap;

    if bitmap.width == 0 || bitmap.rows == 0 || bitmap.buffer == null {
      glyph := *glyphs.*[i];
      glyph.codepoint = codepoint;
      glyph.advance   = xx (ft_glyph.advance.x >> 6);
      continue;
    }

    w   := bitmap.width;
    h   := bitmap.rows;

    if cursor_x + w + padding >= atlas_width {
      cursor_x = padding;
      cursor_y += row_height + padding;
      row_height = 0;
    }

    if bitmap.buffer != null && w > 0 && h > 0 {
      pitch := bitmap.pitch; // negative when FreeType stores the bitmap upside down

      for row: 0..h-1 {
        src_row: *u8;

        if pitch >= 0 {
          src_row = bitmap.buffer + row * cast(u32)pitch;
        } else {
          src_row = bitmap.buffer + (h - 1 - row) * cast(u32)(-pitch);
        }

        for col: 0..w-1 {
          src_alpha := src_row[col];

          dst_index := ((cursor_y + row) * atlas_width + (cursor_x + col)) * 4;
          atlas_pixels[dst_index + 0] = 255;
          atlas_pixels[dst_index + 1] = 255;
          atlas_pixels[dst_index + 2] = 255;
          atlas_pixels[dst_index + 3] = src_alpha;
        }
      }
    }

    glyph := *glyphs.*[i];
    glyph.codepoint = codepoint;
    glyph.size      = .{xx w, xx h};
    glyph.bearing   = .{xx ft_glyph.bitmap_left, xx ft_glyph.bitmap_top};
    glyph.advance   = xx (ft_glyph.advance.x >> 6);

    glyph.uv_min = .{
      cast(float) cursor_x / cast(float) atlas_width,
      cast(float) cursor_y / cast(float) atlas_height
    };
    glyph.uv_max = .{
      cast(float) (cursor_x + w) / cast(float) atlas_width,
      cast(float) (cursor_y + h) / cast(float) atlas_height
    };

    cursor_x += w + padding;
    row_height = max(row_height, h);
  }

  if font.atlas {
    font_replace_atlas(font.atlas, atlas_width, atlas_height, atlas_pixels);
  } else {
    font.atlas = r_create_texture_from_pixels(renderer, tprint("%_atlas", font.label), xx atlas_width, xx atlas_height, atlas_pixels, GL_LINEAR);
  }

  // 26.6 fixed point -> float
  font.height      = pixel_height;
  font.ascent      = xx face.size.metrics.ascender  / 64.0;
  font.descent     = xx face.size.metrics.descender / 64.0;
  font.line_height = xx face.size.metrics.height    / 64.0;
}

font_replace_atlas :: (texture: *Texture, width: int, height: int, pixels: [] u8) {
  glDeleteTextures(1, *texture.handle);
  glCreateTextures(GL_TEXTURE_2D, 1, *texture.handle);
  glTextureStorage2D(texture.handle, 1, GL_RGBA8, xx width, xx height);
  glTextureParameteri(texture.handle, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTextureParameteri(texture.handle, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTextureParameteri(texture.handle, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTextureParameteri(texture.handle, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTextureSubImage2D(texture.handle, 0, 0, 0, xx width, xx height, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data);
  texture.width  = xx width;
  texture.height = xx height;
  glBindTextureUnit(xx texture.texture_unit_index, texture.handle);
}
