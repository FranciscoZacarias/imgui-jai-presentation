// World space is y-down like the screen. zoom is screen pixels per world unit.
Camera_2D :: struct {
  position: Vector2;  // world point at the centre of the viewport
  zoom:     float = 1.0;
}

camera_2d_world_to_screen :: (camera: Camera_2D, viewport: Vector2, world: Vector2) -> Vector2 {
  return (world - camera.position) * camera.zoom + viewport * 0.5;
}

camera_2d_screen_to_world :: (camera: Camera_2D, viewport: Vector2, screen: Vector2) -> Vector2 {
  return (screen - viewport * 0.5) / camera.zoom + camera.position;
}

camera_2d_pan :: (camera: *Camera_2D, screen_delta: Vector2) {
  camera.position -= screen_delta / camera.zoom;
}

camera_2d_zoom_at :: (camera: *Camera_2D, viewport: Vector2, screen_point: Vector2, factor: float, min_zoom := 0.05, max_zoom := 20.0) {
  before := camera_2d_screen_to_world(camera.*, viewport, screen_point);
  camera.zoom = clamp(camera.zoom * factor, min_zoom, max_zoom);
  after := camera_2d_screen_to_world(camera.*, viewport, screen_point);
  camera.position += before - after;
}

camera_2d_view_matrix :: (camera: Camera_2D) -> Matrix4 {
  return make_translation_matrix4(.{ -camera.position.x, -camera.position.y, 0 });
}

camera_2d_projection_matrix :: (camera: Camera_2D, viewport_width: int, viewport_height: int) -> Matrix4 {
  half_w := cast(float) viewport_width  * 0.5 / camera.zoom;
  half_h := cast(float) viewport_height * 0.5 / camera.zoom;
  return orthographic_projection_matrix(-half_w, half_w, half_h, -half_h, -1.0, 1.0);
}
