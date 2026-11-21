package savage_demo

import "core:fmt"
import "core:math"
import "core:math/rand"
import sg "savage"

DEFAULT_W :: 1600
DEFAULT_H :: 1600
PIXEL_SCALE_X :: 1
PIXEL_SCALE_Y :: 1
TITLE :: "Savage Demo"

AppState :: struct {
	page: Page,
}

vec2 :: sg.vec2
render_target: sg.RenderTarget

Page :: union {
	// MainPage,
	// GradientPage,
	// CoordinateTestPage,
	LinesPage,
	TrianglePage,
	QuadPage,
	PathPage,
	// PolygonPage,
	// BezierPage,
}

// MainPage :: struct {}
// GradientPage :: struct {}
LinesPage :: struct {
	angle_offset: f32,
	speed:        f32,
	paused:       bool,
	antialiasing: bool,
}
TrianglePage :: struct {
	triangle:        [3]vec2,
	switch_duration: f64,
	switch_counter:  int,
}
QuadPage :: struct {
	quad:            [4]vec2,
	fill_color:      sg.ColorLinPremul,
	switch_duration: f64,
	switch_counter:  int,
}
PathPage :: struct {
	path:            []vec2,
	fill_color:      sg.ColorLinPremul,
	switch_duration: f64,
	switch_counter:  int,
	half_pixel_offset: bool,
}

// CoordinateTestPage :: struct {}

// main_page := MainPage{}
// gradient_page := GradientPage{}
lines_page := LinesPage {
	speed        = 0.2,
	antialiasing = true,
}
triangle_page := TrianglePage {
	switch_counter  = -1,
	switch_duration = 2,
}
quad_page := QuadPage {
	switch_counter  = -1,
	switch_duration = 2,
}
path_page := PathPage {
	switch_counter  = -1,
	switch_duration = 2,
}

// coordinate_test_page := CoordinateTestPage{}

app_state: AppState = {
	// page = lines_page, // opening page
	// page = triangle_page, // opening page
	// page = quad_page, // opening page
	page = path_page, // opening page
}

// draw_gradient_page :: proc(buffer: ^Buffer, input: Input) {
// 	color: Color
// 	t := input.time
// 	color.b = u8((0.5 + 0.5 * math.sin(t)) * 255)
// 	color.a = 255
// 	x_mult := 255.0 / f32(buffer.w)
// 	y_mult := 255.0 / f32(buffer.h)
// 	for y in 0 ..< buffer.h {
// 		for x in 0 ..< buffer.w {
// 			color.r = u8(f32(x) * x_mult)
// 			color.g = u8(f32(y) * y_mult)
// 			buffer.data[x + y * buffer.w] = color
// 		}
// 	}
// }


refresh_render_target :: proc(buffer: ^Buffer, render_target: ^sg.RenderTarget) {
	if render_target.w != int(buffer.w) || render_target.h != int(buffer.h) {
		delete(render_target.data)
		render_target.data = make([]sg.ColorLinPremul, buffer.w * buffer.h)
		render_target.w = int(buffer.w)
		render_target.h = int(buffer.h)
	}
}

// TODO: @optim Certainly this can be optimized by using bigger blocks of data?
// TODO: could be moved to savage lib?
copy_render_target_to_buffer :: proc(buffer: ^Buffer, render_target: ^sg.RenderTarget) {
	loc: i32
	for x in 0 ..< buffer.w {
		for y in 0 ..< buffer.h {
			loc = x + buffer.w * y
			buffer.data[loc] = cast([4]u8)sg.to_srgb(render_target.data[loc])
		}
	}
}

// Test hairline rasterization by drawing spokes of a rotating wheel
draw_lines_page :: proc(input: Input) {
	num_space_releases := 0
	num_a_releases := 0
	#reverse for key_event in input.key_events {
		// Press SPACE for pausing the animation
		if key_event.key == .Space && key_event.action == .RELEASE {
			num_space_releases += 1
		}
		// Press A for toggling antialiasing (Wu vs Bresenham)
		if key_event.key == .A && key_event.action == .RELEASE {
			num_a_releases += 1
		}
	}
	if num_space_releases % 2 != 0 {
		lines_page.paused = !lines_page.paused
		fmt.printfln("Lines Page Toggle, Pause: %v", lines_page.paused)
	}
	if num_a_releases % 2 != 0 {
		lines_page.antialiasing = !lines_page.antialiasing
	}

	w := f32(render_target.w)
	h := f32(render_target.h)
	bg_color := sg.to_linear_premul({40, 40, 80, 255})
	sg.clear_render_target(bg_color, &render_target)
	center: [2]f32 = {0.5 * w, 0.5 * h}
	num_lines: int = 30
	angle_step: f32 = 2.0 * math.PI / f32(num_lines)
	speed := lines_page.paused ? 0 : lines_page.speed
	lines_page.angle_offset += speed * input.dt
	angle: f32 = lines_page.angle_offset
	stroke_color1 := sg.to_linear_premul({255, 128, 0, 255})
	stroke_color2 := sg.to_linear_premul({128, 255, 0, 255})
	for i in 0 ..< num_lines {
		pt: [2]f32 = {0.3 * w * math.cos(angle) + center.x, 0.3 * h * math.sin(angle) + center.y}
		angle += angle_step
		if i % 2 == 0 {
			if lines_page.antialiasing {
				sg.rasterize_hariline_wu(pt, center, stroke_color1, &render_target)
			} else {
				sg.rasterize_hairline_bresenham(pt, center, stroke_color1, &render_target)
			}
		} else {
			if lines_page.antialiasing {
				sg.rasterize_hariline_wu(center, pt, stroke_color2, &render_target)
			} else {
				sg.rasterize_hairline_bresenham(center, pt, stroke_color2, &render_target)
			}
		}
	}
}

draw_triangle_page :: proc(input: Input) {
	// clear the background
	bg_color := sg.to_linear_premul({40, 40, 80, 255})
	fill_color := sg.to_linear_premul({255, 128, 0, 255})
	sg.clear_render_target(bg_color, &render_target)

	red := sg.to_linear_premul({255, 0, 0, 255})
	blue := sg.to_linear_premul({0, 255, 0, 255})
	green := sg.to_linear_premul({0, 0, 255, 255})

	count := int(input.time / triangle_page.switch_duration)
	triangle := &triangle_page.triangle
	if count != triangle_page.switch_counter {
		sg.clear_render_target(bg_color, &render_target)
		triangle_page.switch_counter = count
		triangle[0].x = rand.float32_range(0, f32(render_target.w))
		triangle[0].y = rand.float32_range(0, f32(render_target.h))
		triangle[1].x = rand.float32_range(0, f32(render_target.w))
		triangle[1].y = rand.float32_range(0, f32(render_target.h))
		triangle[2].x = rand.float32_range(0, f32(render_target.w))
		triangle[2].y = rand.float32_range(0, f32(render_target.h))
		// triangle[0] = {193.19, 112.26}
		// triangle[1] = {191.95, 1.16}
		// triangle[2] = {149.38, 144.37}
		fmt.printfln("Triangle Sampled: %v", triangle^)
	}
	sg.rasterize_triangle_3colors(triangle^, {red, blue, green}, &render_target)
	// sg.rasterize_triangle_old(triangle^, fill_color, &render_target)
	// sg.rasterize_triangle(triangle^, fill_color, &render_target)
}

draw_quad_page :: proc(input: Input) {
	// Draw quads as two rectangles - test for shared-edge gap
	// clear the background

	bg_color := sg.to_linear_premul({40, 40, 80, 255})
	sg.clear_render_target(bg_color, &render_target)
	fc := &quad_page.fill_color

	red := sg.to_linear_premul({255, 0, 0, 255})
	blue := sg.to_linear_premul({0, 255, 0, 255})
	green := sg.to_linear_premul({0, 0, 255, 255})

	count := int(input.time / quad_page.switch_duration)
	quad := &quad_page.quad
	rect_w: f32
	rect_h: f32
	w_f := f32(render_target.w)
	h_f := f32(render_target.h)
	axis_aligned_rectangle := false
	if count != quad_page.switch_counter {
		quad_page.switch_counter = count
		// sample random fill color
		color: sg.Color
		color.r = u8(rand.int_range(0, 256))
		color.g = u8(rand.int_range(0, 256))
		color.b = u8(rand.int_range(0, 256))
		color.a = 255
		fc^ = sg.to_linear_premul(color)

		if axis_aligned_rectangle {
			x1, y1, x2, y2: f32
			// axis-aligned rectangle
			x1 = rand.float32_range(0, w_f)
			y1 = rand.float32_range(0, h_f)
			x2 = rand.float32_range(x1, w_f)
			y2 = rand.float32_range(y1, h_f)
			quad[0] = {x2, y2}
			quad[1] = {x2, y1}
			quad[2] = {x1, y1}
			quad[3] = {x1, y2}

		} else {
			// General quad (sample one vertex in each quadrant)
			quad[0].x = rand.float32_range(w_f / 2, w_f)
			quad[0].y = rand.float32_range(h_f / 2, h_f)
			quad[1].x = rand.float32_range(w_f / 2, w_f)
			quad[1].y = rand.float32_range(0, h_f / 2)
			quad[2].x = rand.float32_range(0, w_f / 2)
			quad[2].y = rand.float32_range(0, h_f / 2)
			quad[3].x = rand.float32_range(0, w_f / 2)
			quad[3].y = rand.float32_range(h_f / 2, h_f)
		}

		fmt.printfln("Quad Sampled: %v", quad^)
	}
	colors: [2][3]sg.ColorLinPremul
	if count % 2 == 0 {
		colors = {{green, red, green}, {green, blue, green}}
	} else {
		colors = {{fc^, fc^, fc^}, {fc^, fc^, fc^}}
	}
	sg.rasterize_triangle_3colors(quad.xyz, colors[0], &render_target)
	sg.rasterize_triangle_3colors(quad.zwx, colors[1], &render_target)
	// sg.rasterize_triangle_old(triangle^, fill_color, &render_target)
	// sg.rasterize_triangle(triangle^, fill_color, &render_target)
}

// draw_coordinate_test_page :: proc(buffer: ^Buffer, input: Input) {
// 	clear_buffer({40, 40, 80, 255}, buffer)
// 	border_color: Color = {255, 128, 0, 255}
// 	corner_color: Color = {255, 64, 0, 255}
// 	// horizontal edges
// 	for x in 0 ..< buffer.w {
// 		buffer.data[x] = border_color
// 		buffer.data[(buffer.h - 1) * buffer.w + x] = border_color
// 	}
// 	// vertical edges
// 	for y in 0 ..< buffer.h {
// 		buffer.data[y * buffer.w] = border_color
// 		buffer.data[y * buffer.w + buffer.h - 1] = border_color
// 	}
// 	// corners
// 	buffer.data[0] = corner_color
// 	buffer.data[buffer.h - 1] = corner_color
// 	buffer.data[(buffer.h - 1) * buffer.w] = corner_color
// 	buffer.data[(buffer.h - 1) * buffer.w + buffer.h - 1] = corner_color
// }

//

draw_path_page :: proc(input: Input) {
	bg_color := sg.to_linear_premul({40, 40, 80, 255})
	sg.clear_render_target(bg_color, &render_target)
	fc := &path_page.fill_color

	count := int(input.time / path_page.switch_duration)
	path := &path_page.path

	num_p_releases : int
	#reverse for key_event in input.key_events {
		// Press P for toggling the half pixel offset
		if key_event.key == .P && key_event.action == .RELEASE {
			num_p_releases += 1
		}
	}

	if num_p_releases % 2 != 0 {
		path_page.half_pixel_offset = !path_page.half_pixel_offset
	}

	pixel_offset : f32 = 0
	if path_page.half_pixel_offset {
		pixel_offset = 0.5
	}


	n := rand.int_range(3, 20)
	sampled_angle: f32
	angle_bin_size: f32 = 2 * math.PI / f32(n)
	sampled_length: f32
	w, h := f32(render_target.w), f32(render_target.h)
	if count != path_page.switch_counter {
		delete(path^)
		path^ = make([]vec2, n)
		path_page.switch_counter = count
		if count % 3 == 0 {
			// truly random points
			for i in 0 ..< n {
				path[i].x = rand.float32_range(0, w - 1)
				path[i].y = rand.float32_range(0, h - 1)
			}
			fc^ = sg.to_linear_premul({128, 255, 0, 255})
		} else if count % 3 == 1 {
			// sampling non self-intersecting
			for i in 0 ..< n {
				sampled_angle = rand.float32_range(
					f32(i) * angle_bin_size,
					f32(i + 1) * angle_bin_size,
				)
				sampled_length = rand.float32_range(0.3, 0.45) * f32(math.min(w, h))
				path[i].x = 0.5 * w + sampled_length * math.cos(sampled_angle)
				path[i].y = 0.5 * h + sampled_length * math.sin(sampled_angle)
			}
			fc^ = sg.to_linear_premul({255, 128, 0, 255})
		} else {
			// sampling non self-intersecting (rectangularized)
			keypoints := make([]vec2, n)
			defer delete(keypoints)
			for i in 0 ..< n {
				sampled_angle = rand.float32_range(
					f32(i) * angle_bin_size,
					f32(i + 1) * angle_bin_size,
				)
				sampled_angle = (f32(i) + 0.5) * angle_bin_size
				sampled_length = rand.float32_range(0.4, 0.45) * f32(math.min(w, h))
				x_val := 0.5 * w + sampled_length * math.cos(sampled_angle)
				y_val := 0.5 * h + sampled_length * math.sin(sampled_angle)
				keypoints[i] = {x_val, y_val}
			}
			EPS :: 1e-3
			pts := make([dynamic]vec2, 0, 2 * n)
			for i in 0 ..< n {
				prev_kp := keypoints[(i + n - 1) % n]
				curr_kp := keypoints[i]
				if abs(curr_kp.x - prev_kp.x) > EPS && abs(curr_kp.y - prev_kp.y) > EPS {
					append(&pts, vec2{curr_kp.x, prev_kp.y})
				}
				append(&pts, curr_kp)
			}
			delete(path^)
			path^ = pts[:]
			fc^ = sg.to_linear_premul({150, 150, 0, 255})
		}
	}
	for &pt in path {
		pt = {math.floor(pt.x), math.floor(pt.y)} + pixel_offset
	}
	sg.fill_path(path^, fc^, &render_target)
}

//
//
// draw_curve_page :: proc(buffer: ^Buffer, input: Input) {
// 	clear_buffer({40, 40, 80, 255}, buffer)
// 	count := int(input.time / curve_page.switch_duration)
// 	if count != curve_page.switch_counter {
// 		curve_page.switch_counter = count
// 		// truly random points
// 		for i in 0 ..< 4 {
// 			curve_page.control_points[i].x = rand.float32_range(0, f32(buffer.w) - 1)
// 			curve_page.control_points[i].y = rand.float32_range(0, f32(buffer.h) - 1)
// 		}
// 	}
// 	// draw_curve_bezier_basic(curve_page.control_points, curve_page.style, buffer)
// 	draw_curve_bezier_casteljau(curve_page.control_points, curve_page.style, buffer)
// }
//
// // for debugging purposes
// log_input :: proc(buffer: ^Buffer, input: Input) {
// 	// test input
// 	if len(input.key_events) > 0 {
// 		fmt.printfln("Keyevents (Len: %v)", len(input.key_events))
// 		#reverse for key_event, event_idx in input.key_events {
// 			fmt.printfln("Key Event # %v : %v", event_idx, key_event)
// 		}
// 	}
//
// 	for k in Key {
// 		key := input.keys[k]
// 		if key.half_transition_count > 0 {
// 			fmt.printfln("Key %v: %v", k, key)
// 		}
// 	}
// 	for b in MouseButton {
// 		btn := input.mouse_btn[b]
// 		if btn.half_transition_count > 0 {
// 			fmt.printfln("Mouse %v: %v", b, btn)
// 		}
// 	}
// 	if input.scroll.x != 0 || input.scroll.y != 0 {
// 		fmt.printfln("Scroll: [x: %v, y: %v]", input.scroll.x, input.scroll.y)
// 	}
// 	// fmt.printfln("Mouse Position: [x: %v, y: %v]", input.mouse_pos.x, input.mouse_pos.y)
// 	mouse_pos := input.mouse_pos
// 	mouse_pos_size: f32 = 10
// 	mouse_point_elem: Element = {
// 		shape = Rect {
// 			position = {
// 				math.round(mouse_pos.x) - mouse_pos_size / 2,
// 				math.round(mouse_pos.y) - mouse_pos_size / 2,
// 			},
// 			dimension = {mouse_pos_size, mouse_pos_size},
// 		},
// 		style = Style{fill_color = {255, 125, 0, 255}},
// 	}
// 	draw_element_sr(mouse_point_elem, buffer)
// }

app_update_and_render :: proc(buffer: ^Buffer, input: Input) {
	refresh_render_target(buffer, &render_target)
	#reverse for key_event in input.key_events {
		#partial switch key_event.key {
		case .Num_1:
			app_state.page = lines_page
		case .Num_2:
			app_state.page = triangle_page
		case .Num_3:
			app_state.page = quad_page
		case .Num_4:
			app_state.page = path_page
		}
	}

	#partial switch page in app_state.page {
	// case GradientPage:
	// 	draw_gradient_page(buffer, input)
	// case CoordinateTestPage:
	// 	draw_coordinate_test_page(buffer, input)
	case LinesPage:
		draw_lines_page(input)
	case TrianglePage:
		draw_triangle_page(input)
	case QuadPage:
		draw_quad_page(input)
	case PathPage:
		draw_path_page(input)
	// 	case MainPage:
	//
	}
	copy_render_target_to_buffer(buffer, &render_target)
}
