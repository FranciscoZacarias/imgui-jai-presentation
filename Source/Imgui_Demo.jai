ui_demo_window :: (open: *bool) {
  if !demo_ready {
    demo_ready = true;
    init(*demo_pool, commit_step = 4 * 1024 * 1024);
    ui_text_set(*demo_name, "player one");
    ui_text_set(*demo_notes, "Multi-line text area.\nEnter for a newline, Up/Down by line.\nCtrl+arrows by word, Ctrl+A/C/X/V.");
  }

  demo_time       += ui.input.dt;
  demo_fps_time   += ui.input.dt;
  demo_fps_frames += 1;
  if demo_fps_time >= 0.5 {
    demo_fps_value  = demo_fps_frames / demo_fps_time;
    demo_fps_time   = 0.0;
    demo_fps_frames = 0;
  }

  if open.*  demo_master_window(open);

  if demo_show.controls  demo_controls_window();
  if demo_show.layout    demo_layout_window();
  if demo_show.visuals   demo_visuals_window();
  if demo_show.pushid    demo_pushid_window();
  if demo_show.windows   demo_windows_window();

  ui_style_window(*demo_show.style);
  #if UI_DEBUG  ui_metrics_window(*demo_show.metrics);
  if demo_show.canvas        demo_canvas_window();
}

#scope_file

demo_master_window :: (open: *bool) {
  ui_window_begin("Imgui demo", open, 20, 40, 210, 360, .NO_COLLAPSE);

  ui_label("Showcase windows");
  ui_separator();
  ui_checkbox("Controls",     *demo_show.controls);
  ui_checkbox("Layout",       *demo_show.layout);
  ui_checkbox("Visuals",      *demo_show.visuals);
  ui_checkbox("push_id",      *demo_show.pushid);
  ui_checkbox("Windows",      *demo_show.windows);
  ui_checkbox("Canvas",       *demo_show.canvas);
  ui_checkbox("Style editor", *demo_show.style);
  #if UI_DEBUG  ui_checkbox("Metrics", *demo_show.metrics);
  ui_spacing();

  if ui_collapsing_header("Dock gestures", default_open = true) {
    ui_label("Shift-drag onto a chip to snap\nto a screen region; drag off to\nundock.");
  }
  ui_collapsing_end();

  ui_spacing();
  ms := ifx demo_fps_value > 0.0 then 1000.0 / demo_fps_value else 0.0;
  ui_label(tprint("% fps  (% ms)", cast(int)(demo_fps_value + 0.5), cast(int)(ms + 0.5)));
  ui_window_end();
}

demo_controls_window :: () {
  ui_window_begin("Controls", *demo_show.controls, 250, 60, 370, 480);
  demo_controls_body();
  ui_window_end();
}

#scope_export

demo_controls_body :: () {
  ui_tab_group_begin("controls-tabs");
    ui_tab("Buttons", *demo_ctrl_tab, 0);
    ui_tab("Values",  *demo_ctrl_tab, 1);
    ui_tab("Text",    *demo_ctrl_tab, 2);
    ui_tab("Select",  *demo_ctrl_tab, 3);
  ui_tab_group_end();

  if demo_ctrl_tab == 0 {
    if ui_button("Click me").clicked  demo_clicks += 1;
    ui_set_tooltip("Hover ~0.5s for a tooltip.");
    ui_label(tprint("clicks: %", demo_clicks));
    ui_button("Disabled", disabled = true);
    ui_separator();

    ui_label("ui_row  (natural widths)");
    ui_row_begin("nat");
      ui_button("Save");  ui_button("Load");  ui_button("Reset");
    ui_row_end();

    ui_label("ui_row + PARENT_RATIO grid");
    for row: 0..2 {
      ui_row_begin(tprint("g%", row), spacing = 4.0);
      for column: 0..2 {
        cell := row * 3 + column;
        if ui_button(tprint("%##cell%", ifx demo_cells[cell] then "*" else "-", cell), width_frac = 0.32).clicked
          demo_cells[cell] = !demo_cells[cell];
      }
      ui_row_end();
    }
  }

  if demo_ctrl_tab == 1 {
    ui_label("Sliders");
    ui_slider("Zoom",  *demo_zoom,  0.25, 4.0);
    ui_slider("Speed", *demo_speed, 0.0, 10.0);
    ui_slider("Count", *demo_count, 0, 10);
    ui_separator();

    ui_label("ui_drag_number  (drag the box)");
    ui_drag_number("Zoom##d",  *demo_drag_zoom,  speed = 0.01, min_value = 0.0, max_value = 8.0);
    ui_drag_number("Count##d", *demo_drag_count, speed = 0.05, min_value = 0,   max_value = 50);
    ui_separator();

    ui_row_begin("nfrow", spacing = 6.0);
      ui_label("Seed");
      ui_number_field("Seed##nf", *demo_seed);
    ui_row_end();
    ui_separator();

    ui_label("ui_drag_floats / ui_slider_floats");
    ui_drag_floats("Position", demo_position.component, speed = 0.05);
    ui_slider_floats("Scale##s", demo_scale.component, 0.0, 4.0);
    ui_separator();

    ui_label("ui_progress_bar");
    ui_slider("Value", *demo_progress, 0.0, 1.0);
    ui_progress_bar(demo_progress);
    ui_progress_bar(sin(demo_time) * 0.5 + 0.5, "loading");
    ui_separator();

    ui_color_edit("Accent", *demo_accent);
  }

  if demo_ctrl_tab == 2 {
    ui_label("Text field  (Enter submits)");
    if ui_text_input("Name", *demo_name, "type a name...").submitted  demo_submits += 1;
    ui_label(tprint("value: %   submits: %", ui_text(*demo_name), demo_submits));
    ui_separator();

    ui_text_area("Notes", *demo_notes, rows = 6);
    ui_label(tprint("% chars", ui_text(*demo_notes).count));
    ui_separator();

    ui_textf("ui_textf: % fps, pos.x = %", cast(int)(demo_fps_value + 0.5), demo_position.x);
    ui_label("A 16-byte buffer  (typing stops at 16)");
    ui_text_input("Path", *demo_path, "/path/to/file");
  }

  if demo_ctrl_tab == 3 {
    ui_label("Checkbox / selectable");
    ui_checkbox("Shadows", *demo_shadows);
    ui_checkbox("VSync",   *demo_vsync);
    ui_toggle("Toggle  (ui_toggle)", *demo_toggle);
    ui_selectable("Wireframe##s", *demo_wireframe);
    ui_separator();

    ui_label("Radios  (index-based, in a ui_group)");
    ui_group_begin("");
      if ui_radio("Solid",     *demo_view, 0)  demo_view_changes += 1;
      if ui_radio("Wireframe", *demo_view, 1)  demo_view_changes += 1;
      if ui_radio("Points",    *demo_view, 2)  demo_view_changes += 1;
    ui_group_end();
    ui_label(tprint("view: %   changes: %", demo_view, demo_view_changes));
    ui_separator();

    ui_label("ui_combo  (index-based)");
    ui_combo("Quality", *demo_quality, string.[ "Low", "Medium", "High", "Ultra" ]);
    ui_label("18 items  (popup scrolls past 12 rows)");
    ui_combo("Font size", *demo_font_size, string.[ "8", "9", "10", "11", "12", "13", "14", "15", "16", "18", "20", "22", "24", "28", "32", "36", "48", "64" ]);
    ui_separator();

    ui_label("ui_list_box  (index-based, scrolls)");
    ui_list_box("Layers##lb", *demo_list_pick,
                string.[ "Sky", "Terrain", "Water", "Props", "Characters", "FX", "UI", "Debug" ], visible_rows = 4);
    ui_separator();

    ui_label("ui_dropdown  (index-based items + any widget)");
    presets :: string.[ "Low", "Medium", "High" ];
    if ui_dropdown_begin("Preset", presets[demo_preset]) {
      for presets  ui_dropdown_item(it, *demo_preset, it_index);
      if ui_button("Reset##preset").clicked  demo_preset = 1;
    }
    ui_dropdown_end();
  }
}

#scope_file

demo_layout_window :: () {
  ui_window_begin("Layout", *demo_show.layout, 310, 100, 370, 480);

  ui_tab_group_begin("layout-tabs");
    ui_tab("Rows",   *demo_lay_tab, 0);
    ui_tab("Groups", *demo_lay_tab, 1);
    ui_tab("Table",  *demo_lay_tab, 2);
    ui_tab("Menus",  *demo_lay_tab, 3);
  ui_tab_group_end();

  if demo_lay_tab == 0 {
    ui_label("ui_columns");
    ui_columns(2);
      ui_label("Name");
      ui_label("player one");
      ui_checkbox("Snap##c", *demo_snap);
    ui_next_column();
      ui_label("Count");
      ui_slider("n##c", *demo_col_n, 0, 10);
      ui_button("Apply##c");
    ui_columns_end();
    ui_separator();

    ui_label("ui_row  (mixed widgets)");
    ui_row_begin("mix", spacing = 6.0);
      ui_button("A");
      ui_checkbox("b##r", *demo_snap);
      ui_button("C");
    ui_row_end();
  }

  if demo_lay_tab == 1 {
    ui_group_begin("A titled group");
      ui_checkbox("Snap to grid", *demo_snap);
      ui_slider("Grid size", *demo_grid_size, 2, 32);
    ui_group_end();

    if ui_collapsing_header("Collapsing header") {
      ui_label("Body slides open / shut.");
      ui_checkbox("Backface cull##adv", *demo_backface_cull);
    }
    ui_collapsing_end();
    ui_separator();

    ui_label("ui_disabled_begin");
    ui_checkbox("Lock the fields below", *demo_lock);
    ui_disabled_begin(demo_lock);
      ui_slider("Locked slider", *demo_speed, 0.0, 10.0);
      ui_button("Locked button");
    ui_disabled_end();
    ui_separator();
    ui_label("disabled = true on each widget");
    ui_button("Disabled button", disabled = true);
    ui_toggle("Disabled toggle", *demo_disabled_toggle, disabled = true);
    ui_checkbox("Disabled checkbox", *demo_disabled_check, disabled = true);
    ui_slider("Disabled slider", *demo_disabled_value, 0.0, 1.0, disabled = true);
    ui_combo("Disabled combo", *demo_disabled_combo, string.[ "First", "Second" ], disabled = true);
    ui_radio("Disabled radio", *demo_disabled_radio, 0, disabled = true);
    ui_text_input("Disabled field", *demo_disabled_text, "can't type here", disabled = true);
  }

  if demo_lay_tab == 2 {
    ui_label("ui_table  (drag a header divider)");
    Asset :: struct { name: string; size: string; kind: string; }
    assets := Asset.[
      .{ "mesh.obj",  "1.2 MB", "model"   },
      .{ "hero.png",  "512 KB", "texture" },
      .{ "music.ogg", "3.4 MB", "audio"   },
      .{ "level.map", "88 KB",  "data"    },
      .{ "font.ttf",  "241 KB", "font"    },
    ];
    ui_table_begin("assets", .[ .{ "Name", 0.5 }, .{ "Size", 0.0 }, .{ "Kind", 0.0 } ]);
      for a: assets {
        ui_table_row();   ui_label(a.name);
        ui_table_cell();  ui_label(a.size);
        ui_table_cell();  ui_label(a.kind);
      }
    ui_table_end();
  }

  if demo_lay_tab == 3 {
    ui_menu_bar_begin("mb");
      if ui_menu_begin("File") {
        if ui_menu_item("New")   demo_clicks += 1;
        if ui_menu_item("Open")  demo_clicks += 1;
        ui_separator();
        if ui_menu_item("Close") demo_show.layout = false;
      }
      ui_menu_end();
      if ui_menu_begin("Edit") {
        if ui_menu_item("Undo")  demo_clicks += 1;
        if ui_menu_item("Redo")  demo_clicks += 1;
      }
      ui_menu_end();
      if ui_menu_begin("View") {
        ui_menu_toggle("Snap to grid", *demo_snap);
        ui_menu_toggle("Shadows",      *demo_shadows);
        ui_menu_toggle("VSync",        *demo_vsync);
      }
      ui_menu_end();
    ui_menu_bar_end();
    ui_spacing();

    ui_label("Right-click here for a context menu.");
    if ui_context_menu_begin("layout-ctx") {
      if ui_menu_item("Run all")      demo_clicks += 1;
      if ui_menu_item("Reset clicks") demo_clicks  = 0;
    }
    ui_context_menu_end();
  }

  ui_window_end();
}

demo_visuals_window :: () {
  ui_window_begin("Visuals", *demo_show.visuals, 370, 160, 370, 480);

  ui_tab_group_begin("visuals-tabs");
    ui_tab("Plots",   *demo_vis_tab, 0);
    ui_tab("Inspect", *demo_vis_tab, 1);
    ui_tab("Image",   *demo_vis_tab, 2);
    ui_tab("Memory",  *demo_vis_tab, 3);
  ui_tab_group_end();

  if demo_vis_tab == 0 {
    ui_plot_push(*demo_frame_ms, ui.input.dt * 1000.0);
    ui_plot_begin("frame_ms", overlay = "frame ms (0..33)");
      ui_plot_line(ui_plot_values(*demo_frame_ms), y_range = .{ 0, 33 });
    ui_plot_end();
    ui_spacing();

    for i: 0..demo_wave.count-1 {
      demo_wave[i]  = sin(demo_time + cast(float) i * 0.4);
      demo_wave2[i] = cos(demo_time + cast(float) i * 0.4);
      demo_wave3[i] = cast(float) i + 12.0 * sin(demo_time * 0.7 + cast(float) i * 0.2);
    }
    ui_label("3 series, per-series scale - hover me");
    ui_plot_begin("multi");
      ui_plot_line(demo_wave,  label = "sin");
      ui_plot_line(demo_wave2, label = "cos");
      ui_plot_line(demo_wave3, label = "ramp");
    ui_plot_end();
    ui_spacing();

    ui_label("step + scatter");
    ui_plot_begin("stepscatter", height = 90.0);
      ui_plot_step(demo_wave);
      ui_plot_scatter(demo_wave2, color = ui_theme.accent);
    ui_plot_end();
    ui_spacing();

    ui_label("histogram");
    ui_plot_begin("wave_h");
      ui_plot_bars(demo_wave, y_range = .{ -1, 1 });
    ui_plot_end();
  }

  if demo_vis_tab == 1 {
    if ui_tree_node("ui_tree_node", default_open = true) {
      ui_tree_leaf("a leaf, aligned with the labels");
      if ui_tree_node("nested") {
        ui_tree_leaf("deeper");
        ui_tree_leaf("still deeper");
      }
      ui_tree_pop();
      ui_tree_leaf("another leaf");
    }
    ui_tree_pop();
    ui_separator();

    ui_label("ui_inspect  (editable reflection walk):");
    ui_inspect("ui_theme", ui_theme, true);
  }

  if demo_vis_tab == 2 {
    ui_label("The built-in icon sheet:");
    ui_image(ui_default_atlas, .{ 128, 128 });
    ui_label("A single cell via UVs:");
    grip_min, grip_max := ui_icon_uv(.RESIZE_GRIP);
    ui_image(ui_default_atlas, .{ 28, 28 }, uv_min = grip_min, uv_max = grip_max);
    ui_label("Every UI_Icon, in enum order:");
    ui_row_begin("icons", spacing = 4.0);
      for 1..cast(int) UI_Icon.RESIZE_GRIP {
        uv_min, uv_max := ui_icon_uv(cast(UI_Icon) it);
        ui_push_id(it);
        ui_image(ui_default_atlas, .{ 20, 20 }, tint = ui_theme.text.normal, uv_min = uv_min, uv_max = uv_max);
        ui_pop_id();
      }
    ui_row_end();
  }

  if demo_vis_tab == 3 {
    ui_label("Hover the filled or the empty part of a bar.");
    ui_flat_pool("ui.persistent", *ui.persistent);
    ui_flat_pool("ui.frame_pool  (mid-frame)", *ui.frame_pool);
    ui_separator();

    ui_flat_pool("demo pool", *demo_pool);
    ui_row_begin("poolbuttons");
      if ui_button("+1 KB").clicked    get(*demo_pool, 1024);
      if ui_button("+64 KB").clicked   get(*demo_pool, 64 * 1024);
      if ui_button("+1 MB").clicked    get(*demo_pool, 1024 * 1024);
      if ui_button("Reset").clicked    reset(*demo_pool);
    ui_row_end();
    ui_checkbox("+1 KB every frame", *demo_pool_stream);
    if demo_pool_stream  get(*demo_pool, 1024);
  }

  ui_window_end();
}

demo_pushid_window :: () {
  ui_window_begin("push_id", *demo_show.pushid, 660, 80, 300, 240);
  ui_label("One salt per row, plain ids inside:");
  for * layer, i: demo_layers {
    ui_push_id(i);
    ui_row_begin("row");
      ui_checkbox("on", *layer.visible);
      ui_label(layer.name);
      ui_slider("a", *layer.opacity, 0.0, 1.0);
    ui_row_end();
    ui_pop_id();
  }
  ui_window_end();
}

demo_windows_window :: () {
  ui_window_begin("Windows", *demo_show.windows, 680, 360, 420, 260);
  ui_label("Child windows float and dock inside");
  ui_label("their parent. Shift-drag them too:");
  ui_window_begin("Child", null, 20, 84, 170, 130, .NO_CLOSE);
    ui_button("inside");
    ui_checkbox("toggle##in", *demo_child_toggle);
    ui_combo("pick##in", *demo_child_pick, string.[ "spills", "over", "every", "window", "behind" ]);
  ui_window_end();
  ui_window_begin("Docked child", null, 0, 0, 150, 96, .NO_CLOSE, initial_dock = .RIGHT_EDGE);
    ui_label("starts docked");
  ui_window_end();
  ui_window_end();
}

Demo_Windows :: struct {
  controls := false;
  layout   := false;
  visuals  := false;
  pushid   := false;
  windows  := false;
  canvas   := false;
  style    := false;
  metrics  := false;
}
demo_show: Demo_Windows;

demo_ctrl_tab := 0;
demo_lay_tab  := 0;
demo_vis_tab  := 0;

Demo_Layer :: struct { name: string; visible: bool; opacity: float; }
demo_layers: [4] Demo_Layer = .[
  .{ "Terrain",    true,  1.0 },
  .{ "Props",      true,  0.8 },
  .{ "Characters", true,  1.0 },
  .{ "FX",         false, 0.5 },
];

demo_frame_ms: UI_Plot_Buffer;
demo_wave:     [24] float;
demo_wave2:    [24] float;
demo_wave3:    [24] float;

demo_ready: bool;
demo_time:  float;

demo_fps_time:   float;
demo_fps_frames: int;
demo_fps_value:  float;

demo_name:  UI_Text_Buffer(256);
demo_notes: UI_Text_Buffer(4096);
demo_path:  UI_Text_Buffer(16);

demo_clicks    := 0;
demo_submits   := 0;
demo_zoom      := 1.0;
demo_speed     := 2.5;
demo_grid_size := 8;
demo_count     := 3;
demo_drag_zoom  := 2.4;
demo_drag_count := 5;
demo_seed       := 1337;
demo_position   := Vector3.{ 1.0, 2.0, 3.0 };
demo_scale      := Vector3.{ 1.0, 1.0, 1.0 };
demo_lock       := false;
demo_list_pick  := 1;
demo_col_n     := 4;
demo_progress  := 0.35;
demo_quality   := 1;
demo_accent    := Vector4.{ 0.30, 0.55, 0.95, 1.0 };
demo_cells:    [9] bool;

demo_snap          := true;
demo_shadows       := false;
demo_vsync         := true;
demo_toggle        := true;
demo_disabled_toggle := true;
demo_disabled_check  := true;
demo_disabled_value  := 0.4;
demo_disabled_combo  := 1;
demo_disabled_radio  := 0;
demo_disabled_text:  UI_Text_Buffer(32);
demo_wireframe     := false;
demo_backface_cull := false;
demo_child_toggle  := false;

demo_view         := 1;
demo_view_changes := 0;
demo_preset       := 1;
demo_font_size    := 8;
demo_child_pick   := 0;
demo_pool:         Flat_Pool;
demo_pool_stream  := false;



Tree_Node :: struct {
  key:      u64;
  panel:    u64;
  name:     string;
  label:    string;
  text:     string;
  flags:    UI_Node_Flags;
  rect:     UI_Rect;
  z:        float;
  parent:   int;
  depth:    int;
  children: int;
  breadth:  float;
}

TREE_NODE_SIZE_LEFT_RIGHT :: Vector2.{ 160, 44 };
TREE_NODE_SIZE_TOP_DOWN   :: Vector2.{ 80, 44 };
TREE_GAP_BREADTH   :: 8.0;
TREE_GAP_DEPTH     :: 36.0;

demo_canvas: Tree_Canvas;

demo_canvas_window :: () {
  ui_window_begin("Canvas", *demo_show.canvas, 20, 20, 620, 460);
  demo_canvas_body();
  ui_window_end();
}

#scope_export

Tree_Canvas :: struct {
  camera:     Camera_2D;
  target:     *Render_Target;
  drag_mouse: Vector2;

  pool:           Flat_Pool;
  nodes:          [] Tree_Node;
  max_depth:      int;
  breadth_extent: float;
  captured:       bool;
  allocated:      int;
  left_to_right:  bool = true;
  levels:         int;  // how many levels to show from the root; 0 = all
}

demo_canvas_body :: () {
  ui_tree_canvas("canvas", *demo_canvas, ui.root);
}

// Draws the subtree under `root` as a diagram you can pan (drag) and zoom (wheel).
// live: capture the tree again every frame, instead of on 'Recalculate'.
ui_tree_canvas :: (id: string, canvas: *Tree_Canvas, root: *UI_Node, live := false, levels := 0) {
  canvas.levels = levels;
  ui_push_id(id);
  ui_row_begin("canvasbar");
    recalculate := false;
    if !live  recalculate = ui_button("Recalculate").clicked;
    fit     := ui_button("Fit").clicked;
    toggled := ui_toggle("Top-down", *canvas.left_to_right);
    ui_label(tprint("nodes % (allocated %)   depth %   zoom %", canvas.nodes.count, canvas.allocated, canvas.max_depth, formatFloat(canvas.camera.zoom, trailing_width = 3)));
  ui_row_end();

  texture: UI_Texture;
  if canvas.target  texture = cast(UI_Texture) canvas.target.color;
  view  := ui_viewport("canvas", texture);
  ui_pop_id();
  size  := view.node.rect.size;
  mouse := ui.input.mouse_pos - view.node.rect.pos;

  if view.pressed {
    canvas.drag_mouse = mouse;
  }
  if view.held {
    camera_2d_pan(*canvas.camera, mouse - canvas.drag_mouse);
    canvas.drag_mouse = mouse;
  }
  if view.hovered && ui.input.scroll != 0.0 {
    camera_2d_zoom_at(*canvas.camera, size, mouse, pow(1.1, -ui.input.scroll), min_zoom = 0.001);
  }

  if size.x < 1.0 || size.y < 1.0 || !root  return;

  if live || recalculate || toggled || !canvas.captured {
    tree_capture(canvas, root);
    if toggled || !canvas.captured {
      view_depth := ifx canvas.left_to_right then size.x else size.y;
      canvas.camera.zoom     = 1.0;
      canvas.camera.position = tree_world(canvas, canvas.nodes[0].breadth, view_depth * 0.5 - 24);
    }
    canvas.captured = true;
  }
  if fit {
    depth_extent := canvas.max_depth * tree_level(canvas) + tree_depth_size(canvas);
    extent := tree_world(canvas, canvas.breadth_extent, depth_extent);
    canvas.camera.position = tree_world(canvas, canvas.breadth_extent * 0.5 - tree_breadth_size(canvas) * 0.5, depth_extent * 0.5);
    canvas.camera.zoom     = clamp(min(size.x / extent.x, size.y / extent.y) * 0.95, 0.001, 20.0);
  }

  w := cast(s32) size.x;
  h := cast(s32) size.y;
  if !canvas.target {
    canvas.target = r_create_render_target(*renderer, "Tree canvas", w, h, samples = 4);
  } else {
    r_resize_render_target(*renderer, canvas.target, w, h);
  }

  camera := canvas.camera;
  nodes  := canvas.nodes;
  font   := ifx renderer.fonts.count then renderer.fonts[0] else null;
  level  := tree_level(canvas);
  node_size := tree_node_size(canvas);

  view_min    := camera_2d_screen_to_world(camera, size, .{ 0, 0 });
  view_max    := camera_2d_screen_to_world(camera, size, size);
  mouse_world := camera_2d_screen_to_world(camera, size, mouse);

  hovered := -1;
  if view.hovered {
    for nodes {
      box_min := tree_box_min(canvas, it);
      if mouse_world.x >= box_min.x && mouse_world.x < box_min.x + node_size.x && mouse_world.y >= box_min.y && mouse_world.y < box_min.y + node_size.y {
        hovered = it_index;
        break;
      }
    }
  }
  on_path := NewArray(nodes.count, bool,, temp);
  walk := hovered;
  while walk >= 0 {
    on_path[walk] = true;
    walk = nodes[walk].parent;
  }

  pass: Render_Pass;
  pass.label             = "Demo canvas";
  pass.target            = canvas.target;
  pass.clear.color_value = ui_theme.window_background.normal;
  pass.view              = camera_2d_view_matrix(camera);
  pass.projection        = camera_2d_projection_matrix(camera, w, h);
  r_begin_pass(*renderer, *pass);
    for depth: 0..canvas.max_depth {
      if depth % 2  continue;
      start := camera_2d_world_to_screen(camera, size, tree_world(canvas, 0, depth * level - TREE_GAP_DEPTH * 0.5));
      if canvas.left_to_right {
        r_draw_screen_quad(*renderer, .{ start.x, 0 }, .{ level * camera.zoom, size.y }, tint = .{ 1, 1, 1, 0.03 });
      } else {
        r_draw_screen_quad(*renderer, .{ 0, start.y }, .{ size.x, level * camera.zoom }, tint = .{ 1, 1, 1, 0.03 });
      }
    }

    for node: nodes {
      if node.parent < 0  continue;
      parent := nodes[node.parent];
      parent_end  := parent.depth * level + tree_depth_size(canvas);
      child_start := node.depth * level;
      mid         := child_start - TREE_GAP_DEPTH * 0.5;

      a := tree_world(canvas, parent.breadth, parent_end);
      b := tree_world(canvas, parent.breadth, mid);
      c := tree_world(canvas, node.breadth,   mid);
      d := tree_world(canvas, node.breadth,   child_start);
      if max(a.x, d.x) < view_min.x || min(a.x, d.x) > view_max.x || max(a.y, d.y) < view_min.y || min(a.y, d.y) > view_max.y  continue;

      color := ifx on_path[it_index] then ui_theme.accent else ui_theme.window_border.normal;
      r_draw_line_3d(*renderer, .{ a.x, a.y, 0 }, .{ b.x, b.y, 0 }, color);
      r_draw_line_3d(*renderer, .{ b.x, b.y, 0 }, .{ c.x, c.y, 0 }, color);
      r_draw_line_3d(*renderer, .{ c.x, c.y, 0 }, .{ d.x, d.y, 0 }, color);
    }

    faint_text := ui_theme.text.normal;
    faint_text.w = 0.5;
    depth_tints := Vector4.[ ui_theme.button.normal,
                             ui_mix(ui_theme.button.normal, ui_theme.slider_fill.normal, 0.25),
                             ui_mix(ui_theme.button.normal, ui_theme.slider_fill.normal, 0.5),
                             ui_mix(ui_theme.button.normal, ui_theme.accent, 0.3) ];
    for node: nodes {
      box_min := tree_box_min(canvas, node);
      if box_min.x + node_size.x < view_min.x || box_min.x > view_max.x || box_min.y + node_size.y < view_min.y || box_min.y > view_max.y  continue;

      screen_min  := camera_2d_world_to_screen(camera, size, box_min);
      screen_size := node_size * camera.zoom;
      highlight   := on_path[it_index];
      r_draw_screen_quad(*renderer, screen_min, screen_size, tint = depth_tints[node.depth % depth_tints.count],
                         border_thickness = ifx highlight then 2.0 else 1.0,
                         border_color = ifx highlight then ui_theme.accent else ui_theme.window_border.normal,
                         border_radius = 6 * camera.zoom);

      if font && screen_size.y >= font.line_height + 4 {
        lines := ifx node.text && screen_size.y >= 2 * font.line_height + 4 then 2 else 1;
        y := screen_min.y + (screen_size.y - cast(float) lines * font.line_height) * 0.5;
        tree_draw_centered(font, ifx node.name then node.name else "(unnamed)", screen_min.x, screen_size.x, y, ui_theme.text.normal);
        if lines == 2  tree_draw_centered(font, ui_display_label(node.text), screen_min.x, screen_size.x, y + font.line_height, faint_text);
      }
    }

    if font && hovered >= 0 {
      node := nodes[hovered];
      info := tprint("name      %\nlabel     %\ntext      %\nkey       0x%\nwindow    0x%\ndepth     %   children %\nz         %\nflags     %\nrect      %, %   % x %",
                     node.name, node.label, node.text, formatInt(node.key, base = 16), formatInt(node.panel, base = 16), node.depth, node.children,
                     node.z, node.flags, node.rect.pos.x, node.rect.pos.y, node.rect.size.x, node.rect.size.y);
      info_w, info_h := r_measure_text(font, info);
      box_size := Vector2.{ cast(float) info_w + 16, cast(float) info_h + 12 };
      box_pos  := mouse + Vector2.{ 16, 16 };
      if box_pos.x + box_size.x > size.x  box_pos.x = max(0.0, mouse.x - box_size.x - 8);
      if box_pos.y + box_size.y > size.y  box_pos.y = max(0.0, mouse.y - box_size.y - 8);
      r_draw_screen_quad(*renderer, box_pos, box_size, tint = ui_theme.window_background.normal, border_thickness = 1, border_color = ui_theme.accent, border_radius = 4);
      r_draw_screen_glyphs(*renderer, font, info, box_pos.x + 8, box_pos.y + 6, tint = ui_theme.text.normal);
    }
  r_end_pass(*renderer);
}

#scope_file

tree_node_size    :: (canvas: *Tree_Canvas) -> Vector2 { return ifx canvas.left_to_right then TREE_NODE_SIZE_LEFT_RIGHT else TREE_NODE_SIZE_TOP_DOWN; }
tree_breadth_size :: (canvas: *Tree_Canvas) -> float { return ifx canvas.left_to_right then tree_node_size(canvas).y else tree_node_size(canvas).x; }
tree_depth_size   :: (canvas: *Tree_Canvas) -> float { return ifx canvas.left_to_right then tree_node_size(canvas).x else tree_node_size(canvas).y; }
tree_level        :: (canvas: *Tree_Canvas) -> float { return tree_depth_size(canvas) + TREE_GAP_DEPTH; }

tree_world :: (canvas: *Tree_Canvas, breadth: float, depth: float) -> Vector2 {
  return ifx canvas.left_to_right then Vector2.{ depth, breadth } else Vector2.{ breadth, depth };
}

tree_box_min :: (canvas: *Tree_Canvas, node: Tree_Node) -> Vector2 {
  return tree_world(canvas, node.breadth - tree_breadth_size(canvas) * 0.5, node.depth * tree_level(canvas));
}

tree_capture :: (canvas: *Tree_Canvas, root: *UI_Node) {
  count :: (node: *UI_Node, depth: int, levels: int) -> int {
    total := 1;
    if levels > 0 && depth + 1 >= levels  return total;
    child := node.first;
    while child {
      total += count(child, depth + 1, levels);
      child = child.next;
    }
    return total;
  }

  pool := *canvas.pool;
  reset(pool);
  node_count := count(root, 0, canvas.levels);
  canvas.nodes.data  = get(pool, node_count * size_of(Tree_Node));
  canvas.nodes.count = node_count;
  canvas.max_depth   = 0;

  next_index := 0;
  next_leaf  := 0.0;
  tree_place(canvas, root, -1, 0, *next_index, *next_leaf);
  canvas.breadth_extent = max(next_leaf - TREE_GAP_BREADTH, tree_breadth_size(canvas));
  canvas.allocated = node_count;
  #if UI_DEBUG  if root == ui.root  canvas.allocated = ui.frame_node_count;
}

tree_place :: (canvas: *Tree_Canvas, node: *UI_Node, parent: int, depth: int, next_index: *int, next_leaf: *float) -> float {
  copy :: (pool: *Flat_Pool, text: string) -> string {
    if !text  return "";
    result: string;
    result.data  = get(pool, text.count);
    result.count = text.count;
    memcpy(result.data, text.data, text.count);
    return result;
  }

  index := next_index.*;
  next_index.* += 1;
  item := *canvas.nodes[index];
  item.* = .{ key = node.key, panel = node.panel, name = copy(*canvas.pool, node.params.name), label = copy(*canvas.pool, node.label), text = copy(*canvas.pool, node.text), flags = node.flags,
              rect = node.rect, z = node.depth, parent = parent, depth = depth };
  canvas.max_depth = max(canvas.max_depth, depth);

  first, last: float;
  child := node.first;
  if canvas.levels > 0 && depth + 1 >= canvas.levels  child = null;  // deeper than asked for
  while child {
    child_breadth := tree_place(canvas, child, index, depth + 1, next_index, next_leaf);
    if item.children == 0  first = child_breadth;
    last = child_breadth;
    item.children += 1;
    child = child.next;
  }

  if item.children {
    item.breadth = (first + last) * 0.5;
  } else {
    item.breadth = next_leaf.*;
    next_leaf.* += tree_breadth_size(canvas) + TREE_GAP_BREADTH;
  }
  return item.breadth;
}

tree_fit_text :: (font: *Font, text: string, max_width: float) -> string {
  width, _ := r_measure_text(font, text);
  if cast(float) width <= max_width  return text;

  dots_width, _ := r_measure_text(font, "...");
  cut := text;
  while cut.count > 0 {
    cut.count -= 1;
    while cut.count > 0 && (text[cut.count] & 0xC0) == 0x80  cut.count -= 1;
    width, _ = r_measure_text(font, cut);
    if cast(float) (width + dots_width) <= max_width  return tprint("%...", cut);
  }
  return "";
}

tree_draw_centered :: (font: *Font, text: string, x: float, width: float, y: float, tint: Vector4) {
  fitted := tree_fit_text(font, text, width - 6);
  if !fitted  return;
  text_width, _ := r_measure_text(font, fitted);
  r_draw_screen_glyphs(*renderer, font, fitted, x + (width - cast(float) text_width) * 0.5, y, tint = tint);
}
