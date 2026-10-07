package savage

import "core:fmt"
import "core:math"
import "core:math/rand"


AppState :: struct {
	page: Page,
}

Page :: union {
	MainPage,
	GradientPage,
	CoordinateTestPage,
	LinesPage,
	TrianglePage,
	RectanglePage,
	PolylinePage,
}

MainPage :: struct {}
GradientPage :: struct {}
LinesPage :: struct {
	angle_offset: f32,
	speed:        f32,
	paused:       bool,
}
TrianglePage :: struct {
	triangle:        Element,
	switch_duration: f64,
	switch_counter:  int,
}
RectanglePage :: struct {
	rectangle:       Element,
	switch_duration: f64,
	switch_counter:  int,
}
PolylinePage :: struct {
	polyline:        Element,
	switch_duration: f64,
	switch_counter:  int,
}
CoordinateTestPage :: struct {}

main_page := MainPage{}
gradient_page := GradientPage{}
lines_page := LinesPage {
	speed = 0.2,
}
triangle_page := TrianglePage {
	switch_duration = 2,
	triangle = Element {
		shape = Triangle{},
		style = {fill_color = {125, 255, 0, 255}, stroke_color = {200, 0, 0, 255}},
	},
}
rectangle_page := RectanglePage {
	switch_duration = 2,
	rectangle = Element {
		shape = Rect{},
		style = {fill_color = {125, 255, 0, 255}, stroke_color = {200, 0, 0, 255}},
	},
}
polyline_page := PolylinePage {
	switch_duration = 2,
	polyline = Element {
		shape = Polyline{},
		style = {fill_color = {125, 255, 0, 255}, stroke_color = {200, 0, 0, 255}},
	},
}
coordinate_test_page := CoordinateTestPage{}

app_state: AppState = {
	page = polyline_page, // opening page
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
	num_space_releases := 0
	#reverse for key_event in input.key_events {
		if key_event.key == .Space && key_event.action == .RELEASE {
			num_space_releases += 1
		}
	}
	if num_space_releases % 2 != 0 {
		lines_page.paused = !lines_page.paused
		fmt.printfln("Lines Page Toggle, Pause: %v", lines_page.paused)
	}
	w := f32(buffer.w)
	h := f32(buffer.h)
	clear_buffer({0, 0, 125, 255}, buffer)
	center: [2]f32 = {0.5 * w, 0.5 * h}
	num_lines: int = 30
	angle_step: f32 = 2.0 * math.PI / f32(num_lines)
	speed := lines_page.paused ? 0 : lines_page.speed
	lines_page.angle_offset += speed * input.dt
	angle: f32 = lines_page.angle_offset
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

draw_triangle_page :: proc(buffer: ^Buffer, input: Input) {
	clear_buffer({0, 0, 125, 255}, buffer)
	count := int(input.time / triangle_page.switch_duration)
	triangle := &triangle_page.triangle.shape.(Triangle)
	if count != triangle_page.switch_counter || triangle^ == {} {
		triangle_page.switch_counter = count
		triangle.points[0].x = rand.float32_range(0, f32(buffer.w))
		triangle.points[0].y = rand.float32_range(0, f32(buffer.h))
		triangle.points[1].x = rand.float32_range(0, f32(buffer.w))
		triangle.points[1].y = rand.float32_range(0, f32(buffer.h))
		triangle.points[2].x = rand.float32_range(0, f32(buffer.w))
		triangle.points[2].y = rand.float32_range(0, f32(buffer.h))
	}
	draw_element_sr(triangle_page.triangle, buffer)
}


draw_rectangle_page :: proc(buffer: ^Buffer, input: Input) {
	clear_buffer({0, 0, 125, 255}, buffer)
	count := int(input.time / rectangle_page.switch_duration)
	rect := &rectangle_page.rectangle.shape.(Rect)
	if count != triangle_page.switch_counter || rect^ == {} {
		triangle_page.switch_counter = count
		rect.dimension.x = rand.float32_range(0.1 * f32(buffer.w), 0.9 * f32(buffer.w))
		rect.dimension.y = rand.float32_range(0.1 * f32(buffer.h), 0.9 * f32(buffer.h))
		rect.position.x = rand.float32_range(0, f32(buffer.w) - rect.dimension.x)
		rect.position.y = rand.float32_range(0, f32(buffer.h) - rect.dimension.y)
	}
	draw_element_sr(rectangle_page.rectangle, buffer)
}

draw_coordinate_test_page :: proc(buffer: ^Buffer, input: Input) {
	clear_buffer({0, 0, 125, 255}, buffer)
	border_color: Color = {255, 128, 0, 255}
	corner_color: Color = {255, 64, 0, 255}
	// horizontal edges
	for x in 0 ..< buffer.w {
		buffer.data[x] = border_color
		buffer.data[(buffer.h - 1) * buffer.w + x] = border_color
	}
	// vertical edges
	for y in 0 ..< buffer.h {
		buffer.data[y * buffer.w] = border_color
		buffer.data[y * buffer.w + buffer.h - 1] = border_color
	}
	// corners
	buffer.data[0] = corner_color
	buffer.data[buffer.h - 1] = corner_color
	buffer.data[(buffer.h - 1) * buffer.w] = corner_color
	buffer.data[(buffer.h - 1) * buffer.w + buffer.h - 1] = corner_color
}

draw_polyline_page :: proc(buffer: ^Buffer, input: Input) {
	clear_buffer({0, 0, 125, 255}, buffer)
	count := int(input.time / polyline_page.switch_duration)
	polyline := &polyline_page.polyline.shape.(Polyline)
	n := rand.int_range(3, 25)
	if count != polyline_page.switch_counter || polyline.points == nil {
		delete(polyline.points)
		polyline.points = make([]vec2, n)
		polyline_page.switch_counter = count
		for i in 0 ..< n {
			polyline.points[i].x = rand.float32_range(0, f32(buffer.w) - 1)
			polyline.points[i].y = rand.float32_range(0, f32(buffer.h) - 1)
		}
	}
	draw_element_sr(polyline_page.polyline, buffer)

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
			app_state.page = main_page
		case .Num_1:
			app_state.page = gradient_page
		case .Num_2:
			app_state.page = coordinate_test_page
		case .Num_3:
			app_state.page = lines_page
		case .Num_4:
			app_state.page = triangle_page
		case .Num_5:
			app_state.page = rectangle_page
		case .Num_6:
			app_state.page = polyline_page
		}

	}

	#partial switch page in app_state.page {
	case GradientPage:
		draw_gradient_page(buffer, input)
	case CoordinateTestPage:
		draw_coordinate_test_page(buffer, input)
	case LinesPage:
		draw_lines_page(buffer, input)
	case TrianglePage:
		draw_triangle_page(buffer, input)
	case RectanglePage:
		draw_rectangle_page(buffer, input)
	case PolylinePage:
		draw_polyline_page(buffer, input)
	case MainPage:

	}
}
