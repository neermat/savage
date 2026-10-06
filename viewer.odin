package drawsvg

// Components
// - 1. Platform layer
// - 2. Software renderer
// - 3. Hardware renderer

// TODO Checklist from drawsvg reference:

// 1: Callbacks in viewer
//   - [x] err callback
//   - [ ] resize callback: update buffer size
//   - wire callbacks to renderer via GetWindowUserPointer (char/cursor/scroll/mouse/resize)
//   - key_callback: ESC -> SetWindowShouldClose
//   - viewer_update: run user renderer (renderer.render) + draw info/OSD
//   - cleanup: glfw.DestroyWindow + glfw.Terminate on exit
//   - clear color set in viewer_update (currently teal placeholder)
//
// TODO(architecture): treat Viewer as the "platform layer" (a la Handmade Hero).
//   Move presentation into Viewer: define Backbuffer{ pixels, w, h } that Viewer
//   owns and blits (GL texture + fullscreen quad). SoftwareRenderer only FILLS
//   the buffer and never touches GL. Keeps the app layer graphics-API-agnostic.
//   (Longer term: app emits a render-command list; platform executes it SW or HW.)


import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import "core:time"
import gl "vendor:OpenGL"
import "vendor:glfw"

DEFAULT_W :: 200
DEFAULT_H :: 200
PIXEL_SCALE_X :: 9
PIXEL_SCALE_Y :: 9
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
	window:          glfw.WindowHandle,
	buffer:          Buffer,
	pixel_scale:     [2]u32,
	texture_id:      u32,
	framebuffer_id:  u32,
	window_resized:  bool,
	start_time:      time.Tick,
	time_elapsed:    time.Duration,
	last_frame_time: time.Tick,
	show_info:       bool,
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
	if (action == glfw.PRESS) {
		if (key == glfw.KEY_ESCAPE) {
			glfw.SetWindowShouldClose(window, true)
		} else if (key == glfw.KEY_GRAVE_ACCENT) {
			viewer.show_info = !viewer.show_info
		}
	}

	// TODO: send key events to the app
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
			"[WindowRefresh] Window: [%v, %v], User Buffer: [%v, %v], GL Frame Buffer: [%v, %v]!",
			window_w,
			window_h,
			viewer.buffer.w,
			viewer.buffer.h,
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
	glfw.SetFramebufferSizeCallback(viewer.window, viewer_resize_callback)

	init_buffer(viewer)
	//refresh_buffer(viewer, DEFAULT_W, DEFAULT_H)
	glfw.ShowWindow(viewer.window)
}

viewer_draw_info :: proc(viewer: ^Viewer) {
	time_elapsed_ms := time.duration_milliseconds(viewer.time_elapsed)
	current_fps := 1000 / time_elapsed_ms
	fmt.printfln("Time Elapsed since last frame: %.2f ms (%.0f FPS)", time_elapsed_ms, current_fps)
	fmt.printfln(
		"Viewer.w: %d, Viewer.h: %d, Viewer.backbuffer size: %d",
		viewer.buffer.w,
		viewer.buffer.h,
		len(viewer.buffer.data),
	)
}

viewer_update :: proc(viewer: ^Viewer) {
	glfw.PollEvents()
	if viewer.window_resized {
		refresh_buffer(viewer)
	}
	app_update_and_render(&viewer.buffer, viewer.start_time)
	gl.ClearColor(0.2, 0.3, 0.3, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
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
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, viewer.framebuffer_id)
	fb_w, fb_h := glfw.GetFramebufferSize(viewer.window)
	gl.BlitFramebuffer(
		0,
		0,
		viewer.buffer.w,
		viewer.buffer.h,
		0,
		fb_h,
		fb_w,
		0,
		gl.COLOR_BUFFER_BIT,
		gl.NEAREST,
	)

	viewer.time_elapsed = time.tick_lap_time(&viewer.last_frame_time)
	if viewer.show_info {
		viewer_draw_info(viewer)
	}

	// swap buffers
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
