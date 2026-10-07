package savage

// Components
// - 1. Platform layer
// - 2. Software renderer
// - 3. GPU renderer

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import "core:time"
import gl "vendor:OpenGL"
import "vendor:glfw"

DEFAULT_W :: 240
DEFAULT_H :: 240
PIXEL_SCALE_X :: 8
PIXEL_SCALE_Y :: 8
TITLE :: "savage"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

Color :: [4]u8

Buffer :: struct {
	data: []Color,
	w:    i32,
	h:    i32,
}

Viewer :: struct {
	window:                glfw.WindowHandle,
	buffer:                Buffer,
	pixel_scale:           [2]u32,
	blit_destination_size: [2]i32,
	texture_id:            u32,
	framebuffer_id:        u32,
	window_resized:        bool,
	input:                 Input,
	start_time:            time.Tick,
	frame_tick:            time.Tick,
	time_since_start:      time.Duration,
	show_info:             bool,
}


viewer_err_callback :: proc "c" (error: c.int, description: cstring) {
	context = runtime.default_context()
	fmt.eprintfln("GLFW Error: %s", description)
}

viewer_key_callback :: proc "c" (
	window: glfw.WindowHandle,
	key: i32,
	scancode: i32,
	action: i32,
	mods: i32,
) {
	viewer := (^Viewer)(glfw.GetWindowUserPointer(window))
	context = runtime.default_context()
	if action == glfw.PRESS {
		if key == glfw.KEY_ESCAPE {
			glfw.SetWindowShouldClose(window, true)
		} else if key == glfw.KEY_GRAVE_ACCENT {
			viewer.show_info = !viewer.show_info
		}
	}

	// NOTE: REPEAT events are ignored
	// TODO: Add modifier support
	if key == glfw.KEY_UNKNOWN do return
	key_id := Key(key)
	if action == glfw.PRESS || action == glfw.RELEASE {
		viewer.input.keys[key_id].half_transition_count += 1
		viewer.input.keys[key_id].ended_down = action == glfw.PRESS
		key_event: KeyEvent = {
			key    = key_id,
			action = KeyAction(action),
		}
		if len(viewer.input.key_events) >= cap(viewer.input.key_events) {
			ordered_remove(&viewer.input.key_events, 0)
		}
		if append(&viewer.input.key_events, key_event) != 1 {
			fmt.eprintfln("Failed to record key event!")
		}
	}
}

viewer_mouse_button_callback :: proc "c" (
	window: glfw.WindowHandle,
	button: i32,
	action: i32,
	mods: i32,
) {
	// NOTE: Only three buttons are supported
	viewer := (^Viewer)(glfw.GetWindowUserPointer(window))
	btn_id := MouseButton(button)
	if action == glfw.PRESS || action == glfw.RELEASE {
		viewer.input.mouse_btn[btn_id].half_transition_count += 1
		viewer.input.mouse_btn[btn_id].ended_down = action == glfw.PRESS
	}
}

viewer_cursor_callback :: proc "c" (window: glfw.WindowHandle, xpos: f64, ypos: f64) {
	// NOTE: only keeping last position for now
	// User coords conversion in update loop
	viewer := (^Viewer)(glfw.GetWindowUserPointer(window))
	xscale, yscale := glfw.GetWindowContentScale(viewer.window)
	viewer.input.mouse_pos.x = f32(xpos) * xscale / f32(viewer.pixel_scale.x)
	viewer.input.mouse_pos.y = f32(ypos) * yscale / f32(viewer.pixel_scale.y)
}

viewer_scroll_callback :: proc "c" (window: glfw.WindowHandle, xoffset: f64, yoffset: f64) {
	viewer := (^Viewer)(glfw.GetWindowUserPointer(window))
	viewer.input.scroll.x += f32(xoffset)
	viewer.input.scroll.y += f32(yoffset)
}

allocate_buffer :: proc(buffer: ^Buffer, w: i32, h: i32) {
	delete(buffer.data)
	buffer.data = make([]Color, buffer.w * buffer.h)
}

init_buffer :: proc(viewer: ^Viewer) {
	// create texture
	gl.GenTextures(1, &viewer.texture_id)
	gl.BindTexture(gl.TEXTURE_2D, viewer.texture_id)

	// create framebuffer
	gl.GenFramebuffers(1, &viewer.framebuffer_id)
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, viewer.framebuffer_id)
	gl.FramebufferTexture2D(
		gl.READ_FRAMEBUFFER,
		gl.COLOR_ATTACHMENT0,
		gl.TEXTURE_2D,
		viewer.texture_id,
		0,
	)
	refresh_buffer(viewer)
}

refresh_buffer :: proc(viewer: ^Viewer) {
	w, h := glfw.GetFramebufferSize(viewer.window)
	viewer.buffer.w = i32(math.ceil(f32(w) / f32(viewer.pixel_scale.x)))
	viewer.buffer.h = i32(math.ceil(f32(h) / f32(viewer.pixel_scale.y)))
	viewer.blit_destination_size.x = viewer.buffer.w * i32(viewer.pixel_scale.x)
	viewer.blit_destination_size.y = viewer.buffer.h * i32(viewer.pixel_scale.y)
	allocate_buffer(&viewer.buffer, w, h)
	gl.BindTexture(gl.TEXTURE_2D, viewer.texture_id)
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RGBA8,
		i32(viewer.buffer.w),
		i32(viewer.buffer.h),
		0,
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		raw_data(viewer.buffer.data),
	)
	fb_status := gl.CheckFramebufferStatus(gl.READ_FRAMEBUFFER)
	if fb_status == gl.FRAMEBUFFER_COMPLETE {
		window_w, window_h := glfw.GetWindowSize(viewer.window)
		fmt.eprintfln("[WindowRefresh] FBO complete!  FB Status: %v", fb_status)
		fmt.printfln(
			"[WindowRefresh] Window: [%v, %v], Buffer: [%v, %v] / [%v, %v], GL Frame Buffer: [%v, %v]!",
			window_w,
			window_h,
			viewer.buffer.w,
			viewer.buffer.h,
			viewer.blit_destination_size.x,
			viewer.blit_destination_size.y,
			w,
			h,
		)
	} else {
		fmt.eprintfln("[WindowRefresh] FBO incomplete!  FB Status: %v", fb_status)
	}
	viewer.window_resized = false
}


viewer_resize_callback :: proc "c" (window: glfw.WindowHandle, width, height: c.int) {
	viewer := (^Viewer)(glfw.GetWindowUserPointer(window))
	viewer.window_resized = true
}

viewer_init :: proc(viewer: ^Viewer) {
	viewer.start_time = time.tick_now()
	// setup basic error callback
	glfw.SetErrorCallback(viewer_err_callback)

	// initialize glfw
	if !glfw.Init() {
		fmt.eprintfln("Could not initialize GLFW!")
		os.exit(1)
	}

	// add GL context hints
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
	glfw.WindowHint(glfw.VISIBLE, glfw.FALSE)

	// Create Window
	viewer.window = glfw.CreateWindow(DEFAULT_W, DEFAULT_H, TITLE, nil, nil)
	if viewer.window == nil {
		fmt.eprintfln("Error: could not create window!")
		glfw.Terminate()
		os.exit(1)
	}
	// adjust window size based on initial requirements
	viewer.pixel_scale = {PIXEL_SCALE_X, PIXEL_SCALE_Y}
	xscale, yscale := glfw.GetWindowContentScale(viewer.window)
	window_w := i32(f32(DEFAULT_W) * f32(viewer.pixel_scale.x) / xscale)
	window_h := i32(f32(DEFAULT_H) * f32(viewer.pixel_scale.y) / yscale)
	glfw.SetWindowSize(viewer.window, window_w, window_h)

	// Load Opengl context
	glfw.MakeContextCurrent(viewer.window)
	// Load OpenGL function pointers with the specified version
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)
	// TODO: should be user-configurable? how does it work?
	glfw.SwapInterval(1) // vsync on

	// attach our state to the window for use in callbacks
	glfw.SetWindowUserPointer(viewer.window, viewer)

	// attach callbacks
	glfw.SetKeyCallback(viewer.window, viewer_key_callback)
	glfw.SetMouseButtonCallback(viewer.window, viewer_mouse_button_callback)
	glfw.SetScrollCallback(viewer.window, viewer_scroll_callback)
	glfw.SetCursorPosCallback(viewer.window, viewer_cursor_callback)
	glfw.SetFramebufferSizeCallback(viewer.window, viewer_resize_callback)

	init_buffer(viewer)
	//refresh_buffer(viewer, DEFAULT_W, DEFAULT_H)
	glfw.ShowWindow(viewer.window)
}

viewer_draw_info :: proc(viewer: ^Viewer) {
	current_fps := 1 / viewer.input.dt
	fmt.printfln("Time Elapsed since last frame: %.3f s (%.0f FPS)", viewer.input.dt, current_fps)
	fmt.printfln(
		"Viewer.w: %d, Viewer.h: %d, Viewer.backbuffer size: %d",
		viewer.buffer.w,
		viewer.buffer.h,
		len(viewer.buffer.data),
	)
}

viewer_update :: proc(viewer: ^Viewer) {
	// Timekeeping
	dt := f32(time.duration_seconds(time.tick_lap_time(&viewer.frame_tick)))
	viewer.input.dt = math.clamp(dt, 1e-6, 0.1)
	viewer.time_since_start = time.tick_since(viewer.start_time)
	viewer.input.time = time.duration_seconds(viewer.time_since_start)

	// Clear input
	for &key in viewer.input.keys {
		key.half_transition_count = 0
	}
	for &b in viewer.input.mouse_btn {
		b.half_transition_count = 0
	}
	viewer.input.scroll = {}
	clear(&viewer.input.key_events)

	// Process all incoming events via callbacks (input, resizes etc.)
	glfw.PollEvents()
	if viewer.window_resized {
		refresh_buffer(viewer)
	}

	// Let the App update the buffer
	app_update_and_render(&viewer.buffer, viewer.input)

	// Clear background
	gl.ClearColor(0.2, 0.3, 0.3, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	// Upload Buffer to GPU
	gl.BindTexture(gl.TEXTURE_2D, viewer.texture_id)
	gl.TexSubImage2D(
		gl.TEXTURE_2D,
		0,
		0,
		0,
		i32(viewer.buffer.w),
		i32(viewer.buffer.h),
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		raw_data(viewer.buffer.data),
	)

	// Blit to Framebuffer 0
	fb_w, fb_h := glfw.GetFramebufferSize(viewer.window)
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, viewer.framebuffer_id)
	// NOTE: dest's not guaranteed to be a perfect multiple,
	//       allow it to crop bottom & right side
	//       Alternative: snap the window size
	gl.BlitFramebuffer(
		0,
		0,
		viewer.buffer.w,
		viewer.buffer.h,
		0,
		fb_h,
		viewer.blit_destination_size.x,
		fb_h - viewer.blit_destination_size.y,
		gl.COLOR_BUFFER_BIT,
		gl.NEAREST,
	)

	if viewer.show_info {
		viewer_draw_info(viewer)
	}

	// Swap Buffers
	glfw.SwapBuffers(viewer.window)

}

main :: proc() {
	viewer := Viewer{}
	viewer_init(&viewer)
	defer glfw.Terminate()
	defer glfw.DestroyWindow(viewer.window)
	defer delete(viewer.buffer.data)

	for !glfw.WindowShouldClose(viewer.window) {
		viewer_update(&viewer)
	}

}
