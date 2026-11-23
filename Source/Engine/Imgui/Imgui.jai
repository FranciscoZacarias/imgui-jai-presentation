#load "Variables.jai";
#load "Core.jai";
#load "Themes.jai";
#load "Icons.jai";
#load "Widgets.jai";
#load "Custom_Widgets.jai";
#load "Text_Edit.jai";
#load "Number_Field.jai";
#load "Bars.jai";
#load "Plot.jai";

// Nothing in here knows about the renderer, the window or the OS: the app
// gives the UI input, metrics and opaque handles, and draws the quads it gets
// back. The widget demo lives with the app (Imgui_Demo.jai), because its tree
// canvas draws through the renderer.
