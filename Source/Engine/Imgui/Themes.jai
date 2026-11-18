ui_theme_make :: (base: Vector3, text: Vector3, accent: Vector3, button: Vector3,
                  fill: Vector3, panel: Vector3, light := false) -> UI_Theme {
  with_alpha :: (color: Vector3, alpha: float) -> Vector4 { return .{ color.x, color.y, color.z, alpha }; }
  scale      :: (color: Vector3, factor: float) -> Vector3 { return .{ clamp(color.x*factor,0,1), clamp(color.y*factor,0,1), clamp(color.z*factor,0,1) }; }
  toward     :: (from: Vector3, to: Vector3, t: float) -> Vector3 { return .{ from.x+(to.x-from.x)*t, from.y+(to.y-from.y)*t, from.z+(to.z-from.z)*t }; }

  white := Vector3.{ 1, 1, 1 };
  border    := ifx light then scale(base, 0.74) else toward(base, white, 0.30);
  title_bar := ifx light then scale(base, 0.90) else scale(base, 0.60);
  groove    := ifx light then scale(base, 0.82) else scale(base, 0.52);

  theme: UI_Theme;
  theme.window_background = .{ normal = with_alpha(base,      0.98) };
  theme.window_border     = .{ normal = with_alpha(border,    1.0)  };
  theme.title_bar         = .{ normal = with_alpha(title_bar, 1.0)  };
  theme.button            = .{ normal = with_alpha(button,    1.0)  };
  theme.button_border     = .{ normal = with_alpha(border,    1.0)  };
  theme.danger            = .{ normal = ifx light then Vector4.{ 0.82, 0.30, 0.30, 1 } else .{ 0.52, 0.18, 0.18, 1 } };
  theme.text              = .{ normal = with_alpha(text,      1.0)  };
  theme.slider_track      = .{ normal = with_alpha(groove,    1.0)  };
  theme.slider_fill       = .{ normal = with_alpha(fill,      1.0)  };
  theme.group_background  = .{ normal = with_alpha(panel,     1.0)  };
  theme.handle            = with_alpha(toward(border, text, 0.35), 1.0);
  theme.dock_hint         = with_alpha(accent, 0.22);
  theme.scroll_track      = with_alpha(groove, 0.55);
  theme.scroll_thumb      = .{ normal = with_alpha(toward(base, text, 0.30), 1.0) };
  theme.accent            = with_alpha(accent, 1.0);
  theme.window_shadow     = ifx light then 8.0 else 12.0;
  theme.corner_radius     = 3.0;
  theme.border_thickness  = 1.0;
  theme.unfocused_dim     = ifx light then 0.35 else 0.42;
  theme.transition_speed  = 16.0;
  return theme;
}

UI_Palette :: struct {
  name: string;
  base, text, accent, button, fill, panel: Vector3;
  light := false;
}

ui_theme_from_palette :: (palette: UI_Palette) -> UI_Theme {
  return ui_theme_make(palette.base, palette.text, palette.accent, palette.button, palette.fill, palette.panel, palette.light);
}

ui_palettes :: #run ui_build_palettes();

#scope_file

ui_rgb :: (r: float, g: float, b: float) -> Vector3 {
  return .{ r / 255.0, g / 255.0, b / 255.0 };
}

ui_build_palettes :: () -> [16] UI_Palette {
  return .[
    .{ "Orange",          ui_rgb(20,20,18),    ui_rgb(245,245,245), ui_rgb(230,120,20),  ui_rgb(50,45,40),    ui_rgb(200,90,0),    ui_rgb(14,14,12),    false },
    .{ "Monokai",         ui_rgb(39,40,34),    ui_rgb(248,248,242), ui_rgb(166,226,46),  ui_rgb(62,61,50),    ui_rgb(73,72,62),    ui_rgb(30,31,26),    false },
    .{ "Brassica",        ui_rgb(38,36,29),    ui_rgb(228,216,174), ui_rgb(210,181,141), ui_rgb(77,69,40),    ui_rgb(135,78,18),   ui_rgb(8,38,40),     false },
    .{ "Gold",            ui_rgb(35,33,39),    ui_rgb(240,240,240), ui_rgb(200,170,60),  ui_rgb(83,83,70),    ui_rgb(156,109,0),   ui_rgb(19,17,19),    false },
    .{ "Green screen",    ui_rgb(0,15,0),      ui_rgb(120,255,120), ui_rgb(0,200,0),     ui_rgb(20,60,30),    ui_rgb(0,140,0),     ui_rgb(0,8,0),       false },
    .{ "Midnight",        ui_rgb(40,40,46),    ui_rgb(235,235,240), ui_rgb(0,121,203),   ui_rgb(60,60,68),    ui_rgb(36,97,160),   ui_rgb(30,30,36),    false },
    .{ "Blue purple",     ui_rgb(44,42,46),    ui_rgb(236,236,248), ui_rgb(120,110,235), ui_rgb(68,66,76),    ui_rgb(78,86,170),   ui_rgb(20,20,30),    false },
    .{ "Moss",            ui_rgb(40,47,49),    ui_rgb(240,244,240), ui_rgb(105,101,255), ui_rgb(70,74,64),    ui_rgb(60,110,70),   ui_rgb(24,32,30),    false },
    .{ "Kanagawa",        ui_rgb(54,54,70),    ui_rgb(220,215,205), ui_rgb(126,156,216), ui_rgb(60,60,78),    ui_rgb(58,80,120),   ui_rgb(31,31,40),    false },
    .{ "Multi-coloured",  ui_rgb(58,54,50),    ui_rgb(245,242,238), ui_rgb(220,150,20),  ui_rgb(74,70,64),    ui_rgb(210,145,15),  ui_rgb(20,19,17),    false },
    .{ "Solarized dark",  ui_rgb(0,43,54),     ui_rgb(147,161,161), ui_rgb(38,139,210),  ui_rgb(7,54,66),     ui_rgb(38,110,150),  ui_rgb(0,36,46),     false },
    .{ "Solarized light", ui_rgb(238,232,213), ui_rgb(50,70,78),    ui_rgb(38,139,210),  ui_rgb(213,206,187), ui_rgb(131,148,186), ui_rgb(253,246,227), true  },
    .{ "Icing",           ui_rgb(238,236,234), ui_rgb(24,24,28),    ui_rgb(80,120,230),  ui_rgb(198,196,194), ui_rgb(150,150,220), ui_rgb(255,255,255), true  },
    .{ "Sunset",          ui_rgb(47,45,40),    ui_rgb(245,240,235), ui_rgb(214,150,40),  ui_rgb(70,64,54),    ui_rgb(200,120,30),  ui_rgb(36,34,30),    false },
    .{ "Spice",           ui_rgb(45,42,48),    ui_rgb(240,238,240), ui_rgb(0,121,203),   ui_rgb(66,63,70),    ui_rgb(160,45,45),   ui_rgb(34,32,37),    false },
    .{ "VS classic",      ui_rgb(45,45,48),    ui_rgb(240,240,240), ui_rgb(0,122,204),   ui_rgb(62,62,66),    ui_rgb(38,79,120),   ui_rgb(30,30,32),    false },
  ];
}
