UI_Icon :: enum u8 {
  NONE;
  CLOSE;
  MINIMIZE;
  MAXIMIZE;
  RESTORE;
  CHEVRON_UP;
  CHEVRON_DOWN;
  CHEVRON_LEFT;
  CHEVRON_RIGHT;
  PLUS;
  MINUS;
  CHECK;
  CIRCLE;
  RESIZE_GRIP;
}

UI_ATLAS_SIZE       :: UI_ATLAS_CELL * UI_ATLAS_GRID;
UI_ATLAS_BYTE_COUNT :: UI_ATLAS_SIZE * UI_ATLAS_SIZE * 4;

// Rasterised at compile time; the host uploads it as ui_default_atlas.
ui_default_atlas_pixels := #run -> [UI_ATLAS_BYTE_COUNT] u8 {
  pixels: [UI_ATLAS_BYTE_COUNT] u8;
  ui_rasterize_icons(pixels.data);
  coverage := 0;
  for pixels  coverage += it;
  assert(coverage > 0, "Imgui: icon atlas bake produced an empty sheet");
  return pixels;
};

ui_icon_uv :: (icon: UI_Icon) -> uv_min: Vector2, uv_max: Vector2 {
  index := (cast(int) icon) - 1;
  if index < 0  return .{ 0, 0 }, .{ 1, 1 };
  grid := cast(float) UI_ATLAS_GRID;
  column  := cast(float) (index % UI_ATLAS_GRID);
  row  := cast(float) (index / UI_ATLAS_GRID);
  return .{ column / grid, row / grid }, .{ (column + 1) / grid, (row + 1) / grid };
}

#scope_file

ui_rasterize_icons :: (pixels: *u8) {
  canvas := Atlas_Canvas.{ pixels, UI_ATLAS_SIZE };

  icons := UI_Icon.[
    .CLOSE, .MINIMIZE, .MAXIMIZE, .RESTORE,
    .CHEVRON_UP, .CHEVRON_DOWN, .CHEVRON_LEFT, .CHEVRON_RIGHT,
    .PLUS, .MINUS, .CHECK, .CIRCLE, .RESIZE_GRIP,
  ];
  for icon, index: icons {
    column := index % UI_ATLAS_GRID;
    row    := index / UI_ATLAS_GRID;
    ui_draw_icon(*canvas, icon, cast(float) (column * UI_ATLAS_CELL), cast(float) (row * UI_ATLAS_CELL), cast(float) UI_ATLAS_CELL);
  }
}

Atlas_Canvas :: struct { pixels: *u8; size: int; }

ui_atlas_put :: (canvas: *Atlas_Canvas, x: int, y: int, alpha: float) {
  if x < 0 || y < 0 || x >= canvas.size || y >= canvas.size  return;
  if alpha <= 0.0  return;
  if alpha > 1.0   alpha = 1.0;
  offset  := (y * canvas.size + x) * 4;
  current := (canvas.pixels + offset + 3).* / 255.0;
  blended := max(current, alpha);
  (canvas.pixels + offset + 0).* = 255;
  (canvas.pixels + offset + 1).* = 255;
  (canvas.pixels + offset + 2).* = 255;
  (canvas.pixels + offset + 3).* = cast(u8) (blended * 255.0);
}

ui_distance_to_segment :: (point_x: float, point_y: float, ax: float, ay: float, bx: float, by: float) -> float {
  dx := bx - ax;
  dy := by - ay;
  length_squared := dx * dx + dy * dy;
  t := 0.0;
  if length_squared > 0.0  t = clamp(((point_x - ax) * dx + (point_y - ay) * dy) / length_squared, 0.0, 1.0);
  closest_x := ax + t * dx;
  closest_y := ay + t * dy;
  return sqrt((point_x - closest_x) * (point_x - closest_x) + (point_y - closest_y) * (point_y - closest_y));
}

ui_atlas_segment :: (canvas: *Atlas_Canvas, ax: float, ay: float, bx: float, by: float, radius: float) {
  x0 := cast(int) floor(min(ax, bx) - radius - 1.0);
  x1 := cast(int) ceil (max(ax, bx) + radius + 1.0);
  y0 := cast(int) floor(min(ay, by) - radius - 1.0);
  y1 := cast(int) ceil (max(ay, by) + radius + 1.0);
  for y: y0..y1  for x: x0..x1 {
    distance := ui_distance_to_segment(x + 0.5, y + 0.5, ax, ay, bx, by) - radius;
    ui_atlas_put(canvas, x, y, 0.5 - distance);
  }
}

ui_atlas_disc :: (canvas: *Atlas_Canvas, center_x: float, center_y: float, radius: float) {
  x0 := cast(int) floor(center_x - radius - 1.0);
  x1 := cast(int) ceil (center_x + radius + 1.0);
  y0 := cast(int) floor(center_y - radius - 1.0);
  y1 := cast(int) ceil (center_y + radius + 1.0);
  for y: y0..y1  for x: x0..x1 {
    distance := sqrt((x + 0.5 - center_x) * (x + 0.5 - center_x) + (y + 0.5 - center_y) * (y + 0.5 - center_y)) - radius;
    ui_atlas_put(canvas, x, y, 0.5 - distance);
  }
}

// Signed distance to a filled triangle (negative inside), by Inigo Quilez.
ui_triangle_distance :: (px: float, py: float, ax: float, ay: float, bx: float, by: float, cx: float, cy: float) -> float {
  project :: (vx: float, vy: float, ex: float, ey: float) -> x: float, y: float {
    t := clamp((vx * ex + vy * ey) / (ex * ex + ey * ey), 0.0, 1.0);
    return vx - ex * t, vy - ey * t;
  }
  e0x := bx - ax;  e0y := by - ay;   v0x := px - ax;  v0y := py - ay;
  e1x := cx - bx;  e1y := cy - by;   v1x := px - bx;  v1y := py - by;
  e2x := ax - cx;  e2y := ay - cy;   v2x := px - cx;  v2y := py - cy;

  q0x, q0y := project(v0x, v0y, e0x, e0y);
  q1x, q1y := project(v1x, v1y, e1x, e1y);
  q2x, q2y := project(v2x, v2y, e2x, e2y);

  winding := ifx (e0x * e2y - e0y * e2x) < 0.0 then -1.0 else 1.0;
  squared_distance := min(q0x*q0x + q0y*q0y, min(q1x*q1x + q1y*q1y, q2x*q2x + q2y*q2y));
  signed_side := min(winding * (v0x*e0y - v0y*e0x),
                 min(winding * (v1x*e1y - v1y*e1x),
                     winding * (v2x*e2y - v2y*e2x)));
  return -sqrt(squared_distance) * (ifx signed_side < 0.0 then -1.0 else 1.0);
}

ui_atlas_triangle :: (canvas: *Atlas_Canvas, ax: float, ay: float, bx: float, by: float, cx: float, cy: float) {
  x0 := cast(int) floor(min(ax, min(bx, cx)) - 1.0);
  x1 := cast(int) ceil (max(ax, max(bx, cx)) + 1.0);
  y0 := cast(int) floor(min(ay, min(by, cy)) - 1.0);
  y1 := cast(int) ceil (max(ay, max(by, cy)) + 1.0);
  for y: y0..y1  for x: x0..x1 {
    ui_atlas_put(canvas, x, y, 0.5 - ui_triangle_distance(x + 0.5, y + 0.5, ax, ay, bx, by, cx, cy));
  }
}

ui_draw_icon :: (canvas: *Atlas_Canvas, icon: UI_Icon, origin_x: float, origin_y: float, cell: float) {
  margin := cell * 0.24;
  far    := cell - margin;
  mid    := cell * 0.5;
  radius := max(cell * 0.06, 0.9);

  stroke :: (ax: float, ay: float, bx: float, by: float) #expand {
    ui_atlas_segment(`canvas, `origin_x + ax, `origin_y + ay, `origin_x + bx, `origin_y + by, `radius);
  }
  box :: (x: float, y: float, w: float, h: float) #expand {
    stroke(x,     y,     x + w, y);
    stroke(x + w, y,     x + w, y + h);
    stroke(x + w, y + h, x,     y + h);
    stroke(x,     y + h, x,     y);
  }

  if icon == {
    case .CLOSE;         stroke(margin, margin, far, far);  stroke(far, margin, margin, far);
    case .MINIMIZE;      stroke(margin, cell * 0.66, far, cell * 0.66);
    case .MAXIMIZE;      box(margin, margin, far - margin, far - margin);
    case .RESTORE;       box(margin, cell * 0.32, cell * 0.40, cell * 0.40);  box(cell * 0.32, margin, cell * 0.40, cell * 0.40);
    case .CHEVRON_UP;    stroke(cell * 0.28, cell * 0.60, mid, cell * 0.38);  stroke(mid, cell * 0.38, cell * 0.72, cell * 0.60);
    case .CHEVRON_DOWN;  stroke(cell * 0.28, cell * 0.40, mid, cell * 0.62);  stroke(mid, cell * 0.62, cell * 0.72, cell * 0.40);
    case .CHEVRON_LEFT;  stroke(cell * 0.60, cell * 0.28, cell * 0.38, mid);  stroke(cell * 0.38, mid, cell * 0.60, cell * 0.72);
    case .CHEVRON_RIGHT; stroke(cell * 0.40, cell * 0.28, cell * 0.62, mid);  stroke(cell * 0.62, mid, cell * 0.40, cell * 0.72);
    case .PLUS;          stroke(mid, margin, mid, far);  stroke(margin, mid, far, mid);
    case .MINUS;         stroke(margin, mid, far, mid);
    case .CHECK;         stroke(cell * 0.22, cell * 0.52, cell * 0.42, cell * 0.72);  stroke(cell * 0.42, cell * 0.72, cell * 0.80, cell * 0.26);
    case .CIRCLE;        ui_atlas_disc(canvas, origin_x + mid, origin_y + mid, cell * 0.34);
    case .RESIZE_GRIP;   corner := cell * 0.30;
                         ui_atlas_triangle(canvas, origin_x + corner, origin_y + far, origin_x + far, origin_y + far, origin_x + far, origin_y + corner);
    case;
  }
}
