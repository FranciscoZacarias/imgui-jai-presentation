Application :: struct {
  window: Window_Type;

  window_x: s64;
  window_y: s64;
  window_width:  s64 = 800;
  window_height: s64 = 600;

  mouse_x: s64;
  mouse_y: s64;
  mouse_delta_x: s64;
  mouse_delta_y: s64;

  delta_time: float64;
  last_time: Apollo_Time;

  should_quit: bool;
}

app_init :: (app: *Application, title: string) {
  app.window = create_window_with_backend(cast(s32) app.window_width, cast(s32) app.window_height, title);
  app.window_x, app.window_y, app.window_width, app.window_height = get_window_dimensions(app.window);
  app.last_time = current_time_monotonic();
}

// Escape never quits. Closing goes through the window's X button or Alt+F4.
app_tick :: (app: *Application) {
  Input.update_window_events();
  for Input.events_this_frame {
    if it.type == .QUIT  app.should_quit = true;
  }
  if is_key_down(Input.Key_Code.ALT) && is_key_clicked(Input.Key_Code.F4)  app.should_quit = true;

  if !app.should_quit {
    app.window_x, app.window_y, app.window_width, app.window_height = get_window_dimensions(app.window);
    app.mouse_x, app.mouse_y = get_mouse_position(app.window);
  }
  app.mouse_delta_x, app.mouse_delta_y = get_mouse_delta();

  now := current_time_monotonic();
  raw_delta_seconds, success := to_float64_seconds(now - app.last_time);
  if !success  raw_delta_seconds = 0.0;
  app.delta_time = clamp(raw_delta_seconds, 0.0, 0.5);
  app.last_time = now;
}