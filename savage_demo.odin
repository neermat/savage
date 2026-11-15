package savage_demo

import "core:fmt"
import "core:math"
import "core:math/rand"
import sg "savage"

DEFAULT_W :: 200
DEFAULT_H :: 200
PIXEL_SCALE_X :: 8
PIXEL_SCALE_Y :: 8
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
	// RectanglePage,
	// PolylinePage,
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
// RectanglePage :: struct {
// 	rectangle:       sg.Element,
// 	switch_duration: f64,
// 	switch_counter:  int,
// }
// PolylinePage :: struct {
// 	polyline:        sg.Element,
// 	switch_duration: f64,
// 	switch_counter:  int,
// }
// PolygonPage :: struct {
// 	polygon:         sg.Element,
// 	switch_duration: f64,
// 	switch_counter:  int,
// }
// BezierPage :: struct {
// 	control_points:  [4]vec2,
// 	style:           sg.Style,
// 	switch_duration: f64,
// 	switch_counter:  int,
// }

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
// rectangle_page := RectanglePage {
// 	switch_duration = 2,
// 	rectangle = sg.Element {
// 		shape = Rect{},
// 		style = {fill_color = {125, 255, 0, 255}, stroke_color = {200, 0, 0, 255}},
// 	},
// }
// polyline_page := PolylinePage {
// 	switch_duration = 2,
// 	polyline = sg.Element {
// 		shape = Polyline{},
// 		style = {fill_color = {125, 255, 0, 255}, stroke_color = {200, 0, 0, 255}},
// 	},
// }
// polygon_page := PolygonPage {
// 	switch_duration = 2,
// 	polygon = Element{shape = Polygon{}, style = {}},
// }
// curve_page := BezierPage {
// 	switch_counter = -1,
// 	switch_duration = 2,
// 	style = {stroke_color = {255, 128, 0, 255}},
// }

// coordinate_test_page := CoordinateTestPage{}

app_state: AppState = {
	// page = lines_page, // opening page
	page = triangle_page, // opening page
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
	sg.fill(bg_color, &render_target)
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
	sg.fill(bg_color, &render_target)

	red := sg.ColorLinPremul{1.0, 0.0, 0.0, 0.0}
	blue := sg.ColorLinPremul{0.0, 1.0, 0.0, 1.0}
	green := sg.ColorLinPremul{0.0, 0.0, 1.0, 1.0}

	count := int(input.time / triangle_page.switch_duration)
	triangle := &triangle_page.triangle
	if count != triangle_page.switch_counter {
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
		// fmt.printfln("Triangle Sampled: %v", triangle^)
	}
	// sg.rasterize_triangle_old(triangle^, fill_color, &render_target)
	// sg.rasterize_triangle(triangle^, fill_color, &render_target)
	sg.rasterize_triangle_3colors(triangle^, {red, blue, green}, &render_target)
}


// draw_rectangle_page :: proc(buffer: ^Buffer, input: Input) {
// 	clear_buffer({40, 40, 80, 255}, buffer)
// 	count := int(input.time / rectangle_page.switch_duration)
// 	rect := &rectangle_page.rectangle.shape.(Rect)
// 	if count != triangle_page.switch_counter || rect^ == {} {
// 		triangle_page.switch_counter = count
// 		rect.dimension.x = rand.float32_range(0.1 * f32(buffer.w), 0.9 * f32(buffer.w))
// 		rect.dimension.y = rand.float32_range(0.1 * f32(buffer.h), 0.9 * f32(buffer.h))
// 		rect.position.x = rand.float32_range(0, f32(buffer.w) - rect.dimension.x)
// 		rect.position.y = rand.float32_range(0, f32(buffer.h) - rect.dimension.y)
// 	}
// 	draw_element_sr(rectangle_page.rectangle, buffer)
// }
//
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
// draw_polyline_page :: proc(buffer: ^Buffer, input: Input) {
// 	clear_buffer({40, 40, 80, 255}, buffer)
// 	count := int(input.time / polyline_page.switch_duration)
// 	polyline := &polyline_page.polyline.shape.(Polyline)
// 	n := rand.int_range(3, 25)
// 	sampled_angle: f32
// 	angle_bin_size: f32 = 2 * math.PI / f32(n)
// 	sampled_length: f32
// 	if count != polyline_page.switch_counter || polyline.points == nil {
// 		delete(polyline.points)
// 		polyline.points = make([]vec2, n)
// 		polyline_page.switch_counter = count
// 		if count % 2 == 0 {
// 			// truly random points
// 			for i in 0 ..< n {
// 				polyline.points[i].x = rand.float32_range(0, f32(buffer.w) - 1)
// 				polyline.points[i].y = rand.float32_range(0, f32(buffer.h) - 1)
// 			}
// 			polyline_page.polyline.style.stroke_color = {128, 255, 0, 255}
// 		} else {
// 			// sampling non self-intersecting
// 			for i in 0 ..< n {
// 				sampled_angle = rand.float32_range(
// 					f32(i) * angle_bin_size,
// 					f32(i + 1) * angle_bin_size,
// 				)
// 				sampled_length = rand.float32_range(0.3, 0.45) * f32(math.min(buffer.w, buffer.h))
// 				polyline.points[i].x =
// 					0.5 * f32(buffer.w) + sampled_length * math.cos(sampled_angle)
// 				polyline.points[i].y =
// 					0.5 * f32(buffer.h) + sampled_length * math.sin(sampled_angle)
// 			}
// 			polyline_page.polyline.style.stroke_color = {255, 128, 0, 255}
// 		}
// 	}
// 	draw_element_sr(polyline_page.polyline, buffer)
//
// }
//
// draw_polygon_page :: proc(buffer: ^Buffer, input: Input) {
// 	clear_buffer({40, 40, 80, 255}, buffer)
// 	count := int(input.time / polygon_page.switch_duration)
// 	polygon := &polygon_page.polygon.shape.(Polygon)
// 	n := rand.int_range(3, 25)
// 	sampled_angle: f32
// 	angle_bin_size: f32 = 2 * math.PI / f32(n)
// 	sampled_length: f32
// 	if count != polygon_page.switch_counter || polygon.points == nil {
// 		delete(polygon.points)
// 		polygon.points = make([]vec2, n)
// 		polygon_page.switch_counter = count
// 		if count % 2 == 0 {
// 			// truly random points
// 			for i in 0 ..< n {
// 				polygon.points[i].x = rand.float32_range(0, f32(buffer.w) - 1)
// 				polygon.points[i].y = rand.float32_range(0, f32(buffer.h) - 1)
// 			}
// 			polygon_page.polygon.style.fill_color = {120, 180, 90, 255}
// 		} else {
// 			// sampling non self-intersecting
// 			for i in 0 ..< n {
// 				sampled_angle = rand.float32_range(
// 					f32(i) * angle_bin_size,
// 					f32(i + 1) * angle_bin_size,
// 				)
// 				sampled_length = rand.float32_range(0.3, 0.45) * f32(math.min(buffer.w, buffer.h))
// 				polygon.points[i].x =
// 					0.5 * f32(buffer.w) + sampled_length * math.cos(sampled_angle)
// 				polygon.points[i].y =
// 					0.5 * f32(buffer.h) + sampled_length * math.sin(sampled_angle)
// 			}
// 			polygon_page.polygon.style.fill_color = {180, 120, 90, 255}
// 		}
// 	}
// 	draw_element_sr(polygon_page.polygon, buffer)
// }
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
	// 	case RectanglePage:
	// 		draw_rectangle_page(buffer, input)
	// 	case PolylinePage:
	// 		draw_polyline_page(buffer, input)
	// 	case PolygonPage:
	// 		draw_polygon_page(buffer, input)
	// 	case BezierPage:
	// 		draw_curve_page(buffer, input)
	// 	case MainPage:
	//
	}
	copy_render_target_to_buffer(buffer, &render_target)
}
