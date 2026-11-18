UI_DEBUG   :: true; // id collision and begin/end balance asserts
UI_DEBUG_NODE_BORDERS      :: false; // initial value of ui_debug_node_borders: outline every node's rect, drawn over its children
UI_DEBUG_NODE_BORDER_COLOR :: Vector4.{ 1, 0, 1, 1 };
IMGUI_DEMO :: true;

UI_ACTIVATE_ON_PRESS :: true;

UI_PLOT_CAPACITY      :: 256;
UI_INSPECT_MAX_DEPTH  :: 8;

UI_RESIZE_HANDLE :: 14.0;

UI_DEPTH_EPSILON    :: 0.00001;
UI_HOVER_LIFT       :: 0.15; // toward white, for a derived hover colour
UI_ACTIVE_PRESS     :: 0.24; // toward black, for a derived active colour
UI_UNDOCK_DIST      :: 6.0;
UI_SCROLL_STEP      :: 42.0; // px per wheel notch
UI_SCROLLBAR_W      :: 8.0;
UI_RESIZE_EDGE      :: 6.0;
UI_WIN_ANIM_SPEED   :: 6.5;  // 1 / seconds
UI_TOOLTIP_DELAY    :: 0.5;  // seconds
UI_CACHE_TTL_FRAMES : u64 : 240;
UI_CACHE_PURGE_INTERVAL : u64 : 60;

UI_DROPDOWN_MAX_ROWS :: 12;
UI_SLIDER_INSET      :: 2.0;

UI_GAP             :: 6.0;
UI_STACK_SPACING   :: 4.0;
UI_TIGHT_SPACING   :: 2.0;
UI_PANEL_PADDING   :: 6.0;
UI_CONTROL_PADDING :: 4.0;
UI_BOX_PADDING     :: 2.0;

UI_DOCK_EDGE_FRACTION :: 0.25;

// Multiples of the host line height.
UI_ROW_HEIGHT_FACTOR   :: 1.5;
UI_COMPACT_ROW_FACTOR  :: 1.4;
UI_TITLE_HEIGHT_FACTOR :: 1.6;
UI_SEPARATOR_FACTOR    :: 0.6;
UI_MENU_WIDTH_FACTOR   :: 9.0;

UI_ATLAS_GRID :: 8;  // cells per side
UI_ATLAS_CELL :: 16; // px
