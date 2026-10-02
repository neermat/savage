package drawsvg

// TODO(viewer):
//   - register callbacks: SetFramebufferSizeCallback, key/char/cursor/scroll/mouse_button
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
import "core:os"
import "core:strings"
import "core:time"
import gl "vendor:OpenGL"
import "vendor:glfw"


DEFAULT_W: i32 = 960
DEFAULT_H: i32 = 640

Color :: struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8
}

Buffer :: struct {
    data: []Color,
    w: i32,
    h: i32,
}

Viewer :: struct {
    window: glfw.WindowHandle, 
    show_info: bool, 
    time_elapsed: time.Duration,
    buffer: Buffer,
    start_time: time.Tick,
    last_frame_time: time.Tick,
    texture_id: u32,
    framebuffer_id: u32,
}

viewer_err_callback :: proc "c" (error: c.int, description: cstring) {
	context = runtime.default_context()
	fmt.eprintfln("GLFW Error: %s", description)
}

viewer_key_callback :: proc "c" (window: glfw.WindowHandle, key: i32, scancode: i32, action: i32, mods: i32) {
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

allocate_buffer :: proc(viewer: ^Viewer, w: i32, h: i32) {
    delete(viewer.buffer.data)
    viewer.buffer.w = w
    viewer.buffer.h = h
    viewer.buffer.data = make([]Color, viewer.buffer.w * viewer.buffer.h)
}


refresh_buffer:: proc(viewer: ^Viewer) {
    w, h := glfw.GetFramebufferSize(viewer.window)
    allocate_buffer(viewer, w, h)
    gl.BindTexture(gl.TEXTURE_2D, viewer.texture_id);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, i32(viewer.buffer.w), i32(viewer.buffer.h), 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(viewer.buffer.data))
    fb_check := gl.CheckFramebufferStatus(gl.READ_FRAMEBUFFER)
    if fb_check == gl.FRAMEBUFFER_COMPLETE {
        fmt.printfln("Frame buffer complete!")
    } else {
        fmt.eprintfln("Error encountered on Framebuffer binding, FB status: %v", fb_check)
    }

}

init_buffer :: proc(viewer: ^Viewer) {
    // create texture
    gl.GenTextures(1, &viewer.texture_id)
    gl.BindTexture(gl.TEXTURE_2D, viewer.texture_id);

    // create framebuffer
    gl.GenFramebuffers(1, &viewer.framebuffer_id)
    gl.BindFramebuffer(gl.READ_FRAMEBUFFER, viewer.framebuffer_id)
    gl.FramebufferTexture2D(gl.READ_FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, viewer.texture_id, 0)
    refresh_buffer(viewer)
}

viewer_resize_callback :: proc "c" (window: glfw.WindowHandle, width, height: c.int) {
    context = runtime.default_context()

	// get framebuffer size
	w, h := glfw.GetFramebufferSize(window)

	gl.Viewport(0, 0, w, h)

	viewer:= (^Viewer)(glfw.GetWindowUserPointer(window))
    if w != i32(viewer.buffer.w) || h != i32(viewer.buffer.h) {
        fmt.printfln("w: %d, h: %d, viewer.w: %d, viewer.h: %d", w, h, viewer.buffer.w, viewer.buffer.h)
        refresh_buffer(viewer)
    }

	// TODO: resize on-screen display

	// TODO: resize render if there is a user space renderer
	//if viewer.renderer != nil {
		//renderer_resize(buffer_w, buffer_h)
	//}

}

viewer_init :: proc(viewer: ^Viewer) {
    viewer.start_time = time.tick_now()
	// setup basic error callback 
	glfw.SetErrorCallback(viewer_err_callback)

	// initialize glfw
	if !glfw.Init() {
		fmt.eprintfln("Error: could not initialize GLFW!")
		os.exit(1)
	}


	// define window title 
	title := "CMU462"
	title_cstring, err := strings.clone_to_cstring(title)
	if err != nil {
		fmt.eprintfln("Error: could not convert title to cstring!")
		os.exit(1)
	}
	defer delete(title_cstring)

    // add GL context hints
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)


	// create window 
	viewer.window = glfw.CreateWindow(DEFAULT_W, DEFAULT_H, title_cstring, nil, nil)
	if viewer.window == nil {
		fmt.eprintfln("Error: could not create window!")
		glfw.Terminate()
		os.exit(1)
	}

    // set context
	glfw.MakeContextCurrent(viewer.window)

    // load GL functions
    gl.load_up_to(3, 3, glfw.gl_set_proc_address)

    // vsync on; caps the frame rate at the display rate 
	glfw.SwapInterval(1)

    // attach our state to window
	glfw.SetWindowUserPointer(viewer.window, viewer)

    glfw.SetKeyCallback(viewer.window, viewer_key_callback)
	// TODO: set rest of the callbacks and features from `viewer.cpp`

    // resize callback
    glfw.SetFramebufferSizeCallback(viewer.window, viewer_resize_callback)

    init_buffer(viewer)
    //refresh_buffer(viewer, DEFAULT_W, DEFAULT_H)

}

viewer_draw_info :: proc(viewer: ^Viewer) {
    time_elapsed_ms := time.duration_milliseconds(viewer.time_elapsed)
    current_fps := 1000 / time_elapsed_ms
    fmt.printfln("Time Elapsed since last frame: %.2f ms (%.0f FPS)", time_elapsed_ms, current_fps)
    fmt.printfln("Viewer.w: %d, Viewer.h: %d, Viewer.backbuffer size: %d", viewer.buffer.w, viewer.buffer.h, len(viewer.buffer.data))
}

viewer_update:: proc(viewer: ^Viewer) {
    app_update_and_render(&viewer.buffer, viewer.start_time)

    gl.ClearColor(0.2, 0.3, 0.3, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
    gl.BindTexture(gl.TEXTURE_2D, viewer.texture_id)
    gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, i32(viewer.buffer.w), i32(viewer.buffer.h), gl.RGBA, gl.UNSIGNED_BYTE, raw_data(viewer.buffer.data))

    gl.BindFramebuffer(gl.READ_FRAMEBUFFER, viewer.framebuffer_id)
    gl.BlitFramebuffer(0, 0, viewer.buffer.w, viewer.buffer.h, 0, viewer.buffer.h, viewer.buffer.w, 0, gl.COLOR_BUFFER_BIT, gl.NEAREST)

    // TODO: run user renderer
    //if viewer.renderer {
        //viewer.renderer.render()
    //}
    // TODO: draw info

    viewer.time_elapsed = time.tick_lap_time(&viewer.last_frame_time)
    if viewer.show_info {
        viewer_draw_info(viewer)
    }

    // swap buffers
    glfw.SwapBuffers(viewer.window) 

    // poll events
    glfw.PollEvents()

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
