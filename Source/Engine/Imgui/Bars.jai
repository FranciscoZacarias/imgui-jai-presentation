ui_tab_group_begin :: (id := "tabs", loc := #caller_location) {
  row_params: UI_Params;
  row_params.axis        = .X;
  row_params.spacing     = UI_TIGHT_SPACING;
  row_params.size.width  = .{ kind = .PARENT_FRACTION, value = 1.0 };
  row_params.size.height = .{ kind = .PIXELS, value = ui_title_height() };
  row_params.name = "Tab bar";
  row := ui_node(id, "tabbar", 0, row_params, loc);
  ui_push_parent(row);

  rule_params: UI_Params;
  rule_params.offset             = .{ 0.0, row.inner.size.y - 1.0 };
  rule_params.size.width         = .{ kind = .PARENT_FRACTION, value = 1.0 };
  rule_params.size.height        = .{ kind = .PIXELS, value = 1.0 };
  rule_params.background.normal   = ui_theme.window_border.normal;
  rule_params.background.normal.w = 0.5;
  ui_node(id, "tabrule", .FLOATING, rule_params, loc);
}

ui_tab_group_end :: () {
  ui_pop_parent();
}

ui_tab :: (label: string, selected: *int, index: int, disabled := false, loc := #caller_location) -> bool {
  active := selected.* == index;

  tab_params: UI_Params;
  tab_params.axis          = .X;
  tab_params.size.width    = .{ kind = .TEXT, value = ui.metrics.line_height };
  tab_params.size.height   = .{ kind = .PARENT_FRACTION, value = 1.0 };
  tab_params.text          = label;
  tab_params.background     = ifx active then ui_theme.button
                                        else UI_Color_Set.{ normal = ui_window_dim(ui_theme.button.normal) };
  tab_params.foreground    = ui_theme.text;
  tab_params.corner_radius = ui_theme.corner_radius;
  tab_params.animate       = true;
  tab_params.name = "Tab";
  tab_params.disabled = disabled;
  tab := ui_node(label, .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y | .CLICKABLE | .HOVERABLE, tab_params, loc);
  signal := ui_signal_from_node(tab);

  changed := signal.clicked && !active;
  if signal.clicked  selected.* = index;

  if active {
    ui_push_parent(tab);
    underline_params: UI_Params;
    underline_params.offset            = .{ 0.0, tab.inner.size.y - 2.0 };
    underline_params.size.width        = .{ kind = .PARENT_FRACTION, value = 1.0 };
    underline_params.size.height       = .{ kind = .PIXELS, value = 2.0 };
    underline_params.background.normal  = ui_theme.accent;
    ui_node(label, "tabline", .FLOATING, underline_params, loc);
    ui_pop_parent();
  }

  return changed;
}

ui_menu_bar_begin :: (id := "menubar", loc := #caller_location) {
  bar_params: UI_Params;
  bar_params.axis          = .X;
  bar_params.spacing       = UI_TIGHT_SPACING;
  bar_params.padding       = UI_BOX_PADDING;
  bar_params.size.width    = .{ kind = .PARENT_FRACTION, value = 1.0 };
  bar_params.size.height   = .{ kind = .PIXELS, value = ui_title_height() };
  bar_params.background     = ui_theme.title_bar;
  bar_params.corner_radius = ui_theme.corner_radius;
  bar_params.name = "Menu bar";
  bar := ui_node(id, "menubar", 0, bar_params, loc);
  ui_push_parent(bar);
}

ui_menu_bar_end :: () {
  ui_pop_parent();
}

ui_menu_begin :: (label: string, disabled := false, loc := #caller_location) -> bool {
  line_height := ui.metrics.line_height;

  title_params: UI_Params;
  title_params.axis          = .X;
  title_params.size.width    = .{ kind = .TEXT, value = line_height };
  title_params.size.height   = .{ kind = .PARENT_FRACTION, value = 1.0 };
  title_params.text          = label;
  title_params.background     = ui_theme.button;
  title_params.foreground    = ui_theme.text;
  title_params.corner_radius = ui_theme.corner_radius;
  title_params.animate       = true;
  title_params.name = "Menu";
  title_params.disabled = disabled;
  title := ui_node(label, .DRAW_TEXT | .TEXT_CENTER_X | .TEXT_CENTER_Y | .CLICKABLE | .HOVERABLE, title_params, loc);
  signal := ui_signal_from_node(title);

  open := menu_bar_open == title.key;
  if signal.clicked {
    menu_bar_open = ifx open then 0 else title.key;
    open = !open;
  } else if signal.hovered && menu_bar_open != 0 && menu_bar_open != title.key {
    menu_bar_open = title.key;
    open = true;
  }

  owner := ui_cache_get(title.key);
  if open  owner.expanded = true;   // cleared by ui_menu_item / ui_popup_end to close
  return ui_popup_begin(label, open, owner, title.rect, ui_menu_width(), loc = loc);
}

ui_menu_end :: () {
  frame := ui.popup_stack[ui.popup_stack.count - 1];
  ui_popup_end();
  if frame.open && !frame.owner.expanded  menu_bar_open = 0;
}

#scope_file

menu_bar_open: u64;
