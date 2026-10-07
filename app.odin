package savage

import "core:fmt"
import "core:math"
import "core:math/rand"


AppState :: struct {
	page: TestPage,
}

TestPage :: enum {
	MAIN_APP,
	GRADIENT,
	LINES,
	TRIANGLE,
	RECTANGLE,
	POLYLINE,
}

app_state: AppState = {
	page = .LINES,
}

draw_gradient_page :: proc(buffer: ^Buffer, input: Input) {
	color: Color
	t := input.time
	color.b = u8((0.5 + 0.5 * math.sin(t)) * 255)
	color.a = 255
	x_mult := 255.0 / f32(buffer.w)
	y_mult := 255.0 / f32(buffer.h)
	for y in 0 ..< buffer.h {
		for x in 0 ..< buffer.w {
			color.r = u8(f32(x) * x_mult)
			color.g = u8(f32(y) * y_mult)
			buffer.data[x + y * buffer.w] = color
		}
	}
}


draw_lines_page :: proc(buffer: ^Buffer, input: Input) {
	w := f32(buffer.w)
	h := f32(buffer.h)
	clear_buffer({0, 0, 125, 255}, buffer)
	center: [2]f32 = {0.5 * w, 0.5 * h}
	num_lines: int = 30
	angle_step: f32 = 2.0 * math.PI / f32(num_lines)
	angle: f32 = 2.0 * math.PI * math.sin(0.01 * f32(input.time))
	line_elem: Element
	for i in 0 ..< num_lines {
		pt: [2]f32 = {0.3 * w * math.cos(angle) + center.x, 0.3 * h * math.sin(angle) + center.y}
		angle += angle_step
		if i % 2 == 0 {
			line_elem = Element {
				shape = Line{from = center, end = pt},
				style = {stroke_color = {255, 128, 0, 255}},
			}
		} else {
			line_elem = Element {
				shape = Line{from = pt, end = center},
				style = {stroke_color = {128, 255, 0, 255}},
			}
		}
		draw_element_sr(line_elem, buffer)
	}
}

// for debugging purposes
log_input :: proc(buffer: ^Buffer, input: Input) {
	// test input
	if len(input.key_events) > 0 {
		fmt.printfln("Keyevents (Len: %v)", len(input.key_events))
		#reverse for key_event, event_idx in input.key_events {
			fmt.printfln("Key Event # %v : %v", event_idx, key_event)
		}
	}

	for k in Key {
		key := input.keys[k]
		if key.half_transition_count > 0 {
			fmt.printfln("Key %v: %v", k, key)
		}
	}
	for b in MouseButton {
		btn := input.mouse_btn[b]
		if btn.half_transition_count > 0 {
			fmt.printfln("Mouse %v: %v", b, btn)
		}
	}
	if input.scroll.x != 0 || input.scroll.y != 0 {
		fmt.printfln("Scroll: [x: %v, y: %v]", input.scroll.x, input.scroll.y)
	}
	// fmt.printfln("Mouse Position: [x: %v, y: %v]", input.mouse_pos.x, input.mouse_pos.y)
	mouse_pos := input.mouse_pos
	mouse_pos_size: f32 = 10
	mouse_point_elem: Element = {
		shape = Rect {
			position = {
				math.round(mouse_pos.x) - mouse_pos_size / 2,
				math.round(mouse_pos.y) - mouse_pos_size / 2,
			},
			dimension = {mouse_pos_size, mouse_pos_size},
		},
		style = Style{fill_color = {255, 125, 0, 255}},
	}
	draw_element_sr(mouse_point_elem, buffer)
}

app_update_and_render :: proc(buffer: ^Buffer, input: Input) {
	#reverse for key_event in input.key_events {
		#partial switch key_event.key {
		case .Num_0:
			app_state.page = TestPage.MAIN_APP
		case .Num_1:
			app_state.page = TestPage.GRADIENT
		case .Num_2:
			app_state.page = TestPage.LINES
		}
	}

	#partial switch app_state.page {
	case .GRADIENT:
		draw_gradient_page(buffer, input)
	case .LINES:
		draw_lines_page(buffer, input)
	case .MAIN_APP:
		// clear screen
		bg_rect_elem: Element = {
			shape = Rect{position = {0, 0}, dimension = {f32(buffer.w), f32(buffer.h)}},
			style = Style{fill_color = {0, 125, 150, 255}},
		}
		draw_element_sr(bg_rect_elem, buffer)


		pt_elem: Element = {
			shape = Point{position = {500, 100}},
			style = Style{fill_color = {255, 0, 0, 255}, stroke_color = {0, 255, 0, 255}},
		}
		rect_elem: Element = {
			shape = Rect{position = {100, 100}, dimension = {600, 600}},
			style = Style{fill_color = {0, 125, 180, 255}, stroke_color = {125, 0, 0, 255}},
		}

		n := 10
		polyline: Polyline
		polyline.points = make([]vec2, n)
		rand.reset(1)
		for i in 0 ..< n {
			polyline.points[i].x = rand.float32_range(0, f32(buffer.w) - 1)
			polyline.points[i].y = rand.float32_range(0, f32(buffer.h) - 1)
		}
		polyline_elm: Element = {
			shape = polyline,
			style = Style{stroke_color = {255, 200, 0, 255}},
		}
		draw_element_sr(polyline_elm, buffer)

	// n := 10
	// polygon: Polygon
	// polygon.points = make([]vec2, n)
	// rand.reset(1)
	// for i in 0..<n {
	//     polygon.points[i].x = rand.float32_range(0, f32(buffer.w) - 1)
	//     polygon.points[i].y = rand.float32_range(0, f32(buffer.h) - 1)
	// }
	// polygon_elm: Element = {
	//     shape = polygon,
	//     style = Style{stroke_color  = {255, 200, 0, 255}}
	// }
	// draw_element_sr(polygon_elm, buffer)

	//draw_element_sr(bg_rect_elem, buffer)
	//draw_element_sr(rect_elem, buffer)
	//points : [3]vec2 = {
	//{100, 100},
	//{800, 800},
	//{1600, 100},
	//}
	//rasterize_triangle(points, Color{255, 0, 0, 0}, buffer)

	//rasterize_line_bresenham({100, 1000}, {1000, 100}, Color{255, 255, 255, 0}, buffer)

	}
}
