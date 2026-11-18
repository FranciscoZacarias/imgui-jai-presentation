DEBUG_MEMORY :: false;
#import "Basic"()(MEMORY_DEBUGGER=DEBUG_MEMORY, VISUALIZE_MEMORY_DEBUGGER=DEBUG_MEMORY, REPLACEMENT_INTERFACE=Engine_Memory_Debugger);

#import "Math";
#import "File";
#import "Sort";
#import "Hash_Table";
#import "stb_image";
#import "freetype";

#if OS == .WINDOWS {
  #import "Windows";
  #import "Clipboard";
}

#load "Engine/Flat_Pool.jai";
#load "Engine/Utils.jai";
#load "Engine/Color.jai";
#load "Engine/Input.jai";
#load "Engine/Graphics_Backend.jai";
#load "Engine/Application.jai";
#load "Engine/Camera2D.jai";
#load "Engine/Renderer/Renderer.jai";
#load "Engine/Renderer/Draw2D.jai";
#load "Engine/Renderer/Draw3D.jai";
#load "Engine/Renderer/Mesh.jai";
#load "Engine/Renderer/Font.jai";
#load "Engine/Imgui/Imgui.jai";

#load "Imgui_Backend.jai";
#load "Presentation.jai";

app:      Application;
renderer: Renderer;

FRAME_CAP_UNLIMITED :: 257; // frame_cap at or above this = no cap
frame_cap := FRAME_CAP_UNLIMITED;

main :: () {
  app_init(*app, "Imgui Presentation");
  r_init(*renderer);
  ui_setup();

  while !app.should_quit {
    frame_start := seconds_since_init();
    app_tick(*app);

    r_begin_frame(*renderer, app.window_width, app.window_height);
    {
      if DEBUG_MEMORY {
        memory_visualizer_per_frame_update();
      } 

      ui_frame_begin();
      {
        presentation();
      }
      ui_frame_end();

      pass: Render_Pass;
      pass.label             = "Presentation";
      pass.clear.color_value = .{ 0.10, 0.12, 0.16, 1 };
      r_begin_pass(*renderer, *pass);
      {
        ui_draw();
      }
      r_end_pass(*renderer);
    }
    r_end_frame(*renderer);

    input_store_previous_state();
    reset_temporary_storage();
    swap_buffers(app.window, false);

    // Frame cap: sleep most of the remaining time, then spin for precision.
    if frame_cap < FRAME_CAP_UNLIMITED {
      target := 1.0 / cast(float64) max(frame_cap, 1);
      while true {
        remaining := target - (seconds_since_init() - frame_start);
        if remaining <= 0.0  break;
        if remaining > 0.002  sleep_milliseconds(cast(s32) ((remaining - 0.001) * 1000.0));
      }
    }
  }

  #if DEBUG_MEMORY {
    report_memory_leaks();
  } 
}
