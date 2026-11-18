ui_flat_pool :: (id: string, pool: *Flat_Pool, loc := #caller_location) {
  if !pool.memory_base {
    ui_label(tprint("%:  not initialized", ui_display_label(id)), loc);
    return;
  }

  reserved  := pool.address_limit          - pool.memory_base;
  committed := pool.first_uncommitted_page - pool.memory_base;
  used      := pool.current_point          - pool.memory_base;

  used_tip        := tprint("Used  %\n% of committed\n% of reserved", bytes_text(used), percent_text(used, committed), percent_text(used, reserved));
  free_tip        := tprint("Committed, free  %\n% of committed\ncommits % at a time",bytes_text(committed - used), percent_text(committed - used, committed), bytes_text(pool.commit_step));
  uncommitted_tip := tprint("Reserved, uncommitted  %\n% of reserved\naddress space only, no memory", bytes_text(reserved - committed), percent_text(reserved - committed, reserved));

  // One bordered panel around the whole widget, so its extent is visible.
  panel_params := ui_box_params(ui_theme.group_background, .{ normal = ui_theme.accent });
  panel_params.name             = "Flat pool";
  panel_params.padding          = UI_PANEL_PADDING;
  panel_params.spacing          = UI_STACK_SPACING;
  panel_params.border_thickness = 1.5;
  panel_params.size.width       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  panel_params.size.height      = .{ kind = .PIXELS, value = ui_provisional_panel_height(ui_parent()) };
  panel := ui_node(id, "pool_panel", 0, panel_params, loc);
  ui_push_parent(panel);
    ui_label(tprint("%:  used %, committed %, reserved %, step %", ui_display_label(id), bytes_text(used), bytes_text(committed), bytes_text(reserved), bytes_text(pool.commit_step)), loc);
    pool_bar(id, "reserve", used, committed, reserved, tprint("reserve: % committed", percent_text(committed, reserved)), used_tip, free_tip, uncommitted_tip, loc);
    pool_bar(id, "committed", used, committed, committed, tprint("committed: % used", percent_text(used, committed)), used_tip, free_tip, uncommitted_tip, loc);
  ui_pop_parent();
  ui_shrink_panel_to_content(panel);
}

ui_viewport :: (id: string, texture: *Texture, flip_v := true, disabled := false, loc := #caller_location) -> UI_Signal {
  params: UI_Params;
  params.size.width        = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.size.height       = .{ kind = .PARENT_FRACTION, value = 1.0 };
  params.texture           = texture;
  params.uv_min            = ifx flip_v then Vector2.{ 0, 1 } else .{ 0, 0 };
  params.uv_max            = ifx flip_v then Vector2.{ 1, 0 } else .{ 1, 1 };
  params.foreground.normal = .{ 1, 1, 1, 1 };
  params.name = "Viewport";
  params.disabled = disabled;
  return ui_signal_from_node(ui_node(id, .CLICKABLE | .HOVERABLE | .SCROLL_Y, params, loc)); // SCROLL_Y takes the wheel from the window body
}

#scope_file

pool_bar ::(id: string, salt: string, used: s64, committed: s64, total: s64, overlay: string, used_tip: string, free_tip: string, uncommitted_tip: string, loc: Source_Code_Location) {
  track_params := ui_box_params(ui_theme.slider_track, ui_theme.button_border);
  track_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  track_params.size.height = .{ kind = .PIXELS, value = ui_compact_height() };
  track := ui_node(id, salt, 0, track_params, loc);

  inset  := UI_SLIDER_INSET;
  width  := max(0.0, track.rect.size.x - 2.0 * inset);
  height := max(0.0, track.rect.size.y - 2.0 * inset);

  // Any non-empty segment keeps at least 2 px, so KB inside a 256 MB reserve stays visible.
  used_x      := ifx used > 0 then max(2.0, width * cast(float) used / cast(float) total) else 0.0;
  committed_x := ifx committed > used then max(used_x + 2.0, width * cast(float) committed / cast(float) total) else used_x;
  used_x      = min(used_x, width);
  committed_x = min(committed_x, width);

  free_fill := ui_theme.slider_fill;
  free_fill.normal.w *= 0.35;
  empty_fill: UI_Color_Set;
  empty_fill.hover = ui_mix(ui_theme.slider_track.normal, ui_theme.text.normal, 0.12);

  segment :: (index: int, from: float, to: float, fill: UI_Color_Set, tip: string) #expand {
    params: UI_Params;
    params.offset        = .{ inset + from, inset };
    params.size.width    = .{ kind = .PIXELS, value = to - from };
    params.size.height   = .{ kind = .PIXELS, value = height };
    params.background    = fill;
    params.corner_radius = max(0.0, ui_theme.corner_radius - inset);
    params.animate       = true;
    ui_node(`id, `salt, index, .FLOATING | .HOVERABLE, params, `loc);
    ui_set_tooltip(tip);
  }

  ui_push_parent(track);
    segment(0, 0.0,         used_x,      ui_theme.slider_fill, used_tip);
    segment(1, used_x,      committed_x, free_fill,            free_tip);
    segment(2, committed_x, width,       empty_fill,           uncommitted_tip);

    text_params: UI_Params;
    text_params.size.width  = .{ kind = .PIXELS, value = track.rect.size.x };
    text_params.size.height = .{ kind = .PIXELS, value = track.rect.size.y };
    text_params.text        = overlay;
    text_params.foreground  = ui_theme.text;
    ui_node(id, salt, 3, .FLOATING | .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y, text_params, loc);
  ui_pop_parent();
}

bytes_text :: (count: s64) -> string {
  if count < 1024         return tprint("% B", count);
  if count < 1024 * 1024  return tprint("% KB", formatFloat(cast(float64) count / 1024.0, trailing_width = 1, zero_removal = .NO));
  return tprint("% MB", formatFloat(cast(float64) count / (1024.0 * 1024.0), trailing_width = 1, zero_removal = .NO));
}

percent_text :: (part: s64, whole: s64) -> string {
  if whole <= 0  return "0%";
  return tprint("%%", formatFloat(100.0 * cast(float64) part / cast(float64) whole, trailing_width = 2, zero_removal = .NO), "%");
}
