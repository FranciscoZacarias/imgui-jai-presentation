#import "Basic";
#import "File";
#import "Window_Creation";
#import "GL"(DUMP_GL_ERRORS=DEBUG);

USING_GL_MAJOR_VERSION :: 4;
USING_GL_MINOR_VERSION :: 6;

Graphics_Backend :: enum {
  OPENGL;
}

create_window_with_backend :: (width: s32, height: s32, title: string, window_x: s32 = -1, window_y: s32 = -1, backend: Graphics_Backend = .OPENGL, msaa: s32 = 8) -> Window_Type {
  result := create_window(width, height, title, window_x, window_y, wanted_msaa = msaa);
  if result == null {
    log_error("create_window returned null\n");
    return null;
  } 

  if backend == {
    case .OPENGL;
      gl_create_context(result, major_version = USING_GL_MAJOR_VERSION, minor_version = USING_GL_MINOR_VERSION, wanted_msaa = msaa);
      gl_load(*gl);
      if wglGetCurrentContext() == null {
        log_error("No current GL context after gl_create_context!\n");
        return null;
      }
    case;
      assert(false, "Graphics backend not supported.");
  }
  return result;
}

swap_buffers :: (window: Window_Type, vsync := true) {
  #if OS == {
    case .WINDOWS;
      swap_interval: s32 = 0;
      if vsync  swap_interval = 1;
      if wglSwapIntervalEXT  wglSwapIntervalEXT(swap_interval);
      dc := GetDC(window);
      SwapBuffers(dc);
    case;
      assert(false, "OS not supported by window_backend.jai");
  }
}

get_window_dimensions :: (window: Window_Type) -> x: s32, y: s32, width: s32, height: s32 {
  x, y, width, height, ok := get_dimensions(window, true);
  if !ok  log_error("Unable to get window dimensions.");
  return x, y, width, height;
}

get_mouse_position :: (window: Window_Type) -> x: s64, y: s64 {
  x, y, ok := get_mouse_pointer_position(window, false);
  if !ok  log_error("Unable to get mouse position.");
  return x, y;
}

get_mouse_delta :: () -> x: s64, y: s64 {
  return Input.mouse_delta_x, Input.mouse_delta_y;
}

compile_shader_from_source :: (label: string, source: string, shader_type: GLenum) -> handle: u32, ok: bool, error: string {
  result: u32;

  if source.count == 0 {
    return result, false, "Unable to compile shader. Shader source is empty.";
  }

  source_c_string := to_c_string(source); // glCreateShaderProgramv reads a zero-terminated string
  defer free(source_c_string);
  handle := glCreateShaderProgramv(shader_type, 1, *source_c_string);

  link_status: GLint;
  glGetProgramiv(handle, GL_LINK_STATUS, *link_status);

  if link_status == 0 {
    log_length: GLint;
    glGetProgramiv(handle, GL_INFO_LOG_LENGTH, *log_length);

    log := NewArray(log_length + 1, u8);
    defer free(log.data);

    glGetProgramInfoLog(handle, xx log_length, null, log.data);

    error_str := tprint("Shader % compile/link failed:\n%", label, to_string(log));
    log_error("%\n", error_str);
    glDeleteProgram(handle);
    return result, false, error_str;
  }

  result = handle;
  log("Compiled shader % successfully\n", label);
  return result, true, "";
}

compile_shader_from_file :: (label: string, file_path: string, shader_type: GLenum) -> handle: u32, ok: bool, error: string {
  shader_source, read_ok := read_entire_file(file_path);
  defer free(shader_source);

  if !read_ok || shader_source.count == 0 {
    error_str := tprint("Unable to compile shader. Could not load file path \"%\"", file_path);
    log_error("%\n", error_str);
    return 0, false, error_str;
  }

  handle, compile_ok, error_str := compile_shader_from_source(label, shader_source, shader_type);
  return handle, compile_ok, error_str;
}
