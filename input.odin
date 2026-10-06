package savage

// TODO: Add support for typed text
Input :: struct {
	dt:        f32,
	mouse_pos: [2]f32,
	mouse_btn: [MouseButton]Button,
	scroll:    [2]f32,
	keys:      #sparse[Key]Button,
}

Button :: struct {
	ended_down:            bool,
	half_transition_count: u8,
}

MouseButton :: enum {
	Left,
	Right,
	Middle,
}

// NOTE: Explicitly mapped to glfw.
// Write a separate mapper if want to add another windowing library
Key :: enum i32 {
	Space = 32,
	Apostrophe = 39,
	Comma = 44,
	Minus, // 45
	Period, // 46
	Slash, // 47
	Num_0, // 48
	Num_1,
	Num_2,
	Num_3,
	Num_4,
	Num_5,
	Num_6,
	Num_7,
	Num_8,
	Num_9,
	Semicolon = 59,
	Equal = 61,
	A = 65,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z, // Z = 90
	Left_Bracket, // 91
	Backslash, // 92
	Right_Bracket, // 93
	Grave_Accent = 96,
	World_1 = 161,
	World_2, // 162
	Escape = 256,
	Enter,
	Tab,
	Backspace,
	Insert,
	Delete, // 257..261
	Right,
	Left,
	Down,
	Up, // 262..265
	Page_Up,
	Page_Down,
	Home,
	End, // 266..269
	Caps_Lock = 280,
	Scroll_Lock,
	Num_Lock,
	Print_Screen,
	Pause, // 281..284
	F1 = 290,
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,
	F13,
	F14,
	F15,
	F16,
	F17,
	F18,
	F19,
	F20,
	F21,
	F22,
	F23,
	F24,
	F25, // 314
	KP_0 = 320,
	KP_1,
	KP_2,
	KP_3,
	KP_4,
	KP_5,
	KP_6,
	KP_7,
	KP_8,
	KP_9, // 321..
	KP_Decimal,
	KP_Divide,
	KP_Multiply,
	KP_Subtract,
	KP_Add,
	KP_EntKP_Equal, // 330..336
	Left_Shift = 340,
	Left_Control,
	Left_Alt,
	Left_Super,
	Right_Shift,
	Right_Control,
	Right_Alt,
	Right_Super, // 344..34
	Menu, // 348
}
