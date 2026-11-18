#import "Basic";
#import "Compiler";

#run build();

output_name       := "run";
enable_release    := false;
optimization_type := Optimization_Type.DEBUG;

build :: () {

  for arg: get_build_options().compile_time_command_line {
    if arg == {
      case "release"; enable_release = true;
      case; compiler_report(tprint("Unknown build argument '%'\n", arg));
    }
  }

  if enable_release {
    optimization_type = .OPTIMIZED;
    output_name = "run_release";
  }

  workspace := compiler_create_workspace("Target Workspace");
  if !workspace {
    compiler_report("Failed to create workspace.\n");
    return;
  }

  options := get_build_options(workspace);
  options.output_executable_name = output_name;

  set_optimization(*options, optimization_type);
  set_build_options(options, workspace);

  compiler_begin_intercept(workspace);
    add_build_string(tprint("DEBUG :: %;\n", !enable_release), workspace);
    add_build_file("Source/Main.jai", workspace);
  compiler_end_intercept(workspace);

  set_build_options_dc(.{do_output = false});
}
