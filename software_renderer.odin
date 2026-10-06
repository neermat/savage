package drawsvg

import "core:container/topological_sort"
import "core:fmt"
import "core:math"

vec2 :: [2]f32


Point :: struct {
	position: vec2,
}

Line :: struct {
	from: vec2,
	end:  vec2,
}

Polyline :: struct {
	points: []vec2,
}

Rect :: struct {
	position:  vec2,
	dimension: vec2,
}

Polygon :: struct {
	points: []vec2,
}

Ellipse :: struct {
	center: vec2,
	radius: vec2,
}

// TODO: Define Image and Group elements

Shape :: union {
	Point,
	Line,
	Polyline,
	Rect,
	Polygon,
	Ellipse,
}

Style :: struct {
	stroke_color: Color,
	fill_color:   Color,
	stroke_width: f32,
	miter_limit:  f32,
}

Element :: struct {
	style: Style,
	shape: Shape,
	// TODO: add matrix transform
}

SVG :: struct {
	width:    f32,
	height:   f32,
	elements: []Element,
}

draw_element_sr :: proc(element: Element, target_buffer: ^Buffer) {
	#partial switch shape in element.shape {
	case Point:
		draw_point(shape, element.style, target_buffer)
	case Line:
		draw_line(shape, element.style, target_buffer)
	case Polyline:
		draw_polyline(shape, element.style, target_buffer)
	case Rect:
		draw_rect(shape, element.style, target_buffer)
	case Polygon:
		draw_polygon(shape, element.style, target_buffer)
	}
}


draw_point :: proc(point: Point, style: Style, target_buffer: ^Buffer) {
	target_w := target_buffer.w
	target_h := target_buffer.h

	// nearest pixel
	sx := i32(math.round(point.position.x))
	sy := i32(math.round(point.position.y))

	// skip if out of bounds
	if sx < 0 || sx >= target_w {
		return
	}
	if sy < 0 || sy >= target_h {
		return
	}

	target_buffer.data[sx + sy * target_w] = style.fill_color
}

draw_line :: proc(line: Line, style: Style, target_buffer: ^Buffer) {
	rasterize_line(line.from, line.end, style.stroke_color, target_buffer)
}

draw_polyline :: proc(polyline: Polyline, style: Style, target_buffer: ^Buffer) {
	for i in 0 ..< len(polyline.points) - 1 {
		rasterize_line(
			polyline.points[i],
			polyline.points[i + 1],
			style.stroke_color,
			target_buffer,
		)
	}
}

draw_rect :: proc(rect: Rect, style: Style, target_buffer: ^Buffer) {
	p0: vec2 = rect.position
	p1: vec2 = {rect.position.x + rect.dimension.x, rect.position.y}
	p2: vec2 = {rect.position.x, rect.position.y + rect.dimension.y}
	p3: vec2 = {rect.position.x + rect.dimension.x, rect.position.y + rect.dimension.y}
	triangle1: [3]vec2 = {p0, p1, p3}
	triangle2: [3]vec2 = {p0, p2, p3}

	rasterize_triangle({p0, p1, p3}, style.fill_color, target_buffer)
	rasterize_triangle({p0, p2, p3}, style.fill_color, target_buffer)
	rasterize_line(p0, p1, style.stroke_color, target_buffer)
	rasterize_line(p0, p2, style.stroke_color, target_buffer)
	rasterize_line(p2, p3, style.stroke_color, target_buffer)
	rasterize_line(p1, p3, style.stroke_color, target_buffer)
}

draw_polygon :: proc(polygon: Polygon, style: Style, target_buffer: ^Buffer) {
}

draw_polygon_ear_clipping :: proc(polygon: Polygon, style: Style, target_buffer: ^Buffer) {
	fmt.println("\n------------------------\n")
	vertices := polygon.points
	n := len(polygon.points)
	if len(vertices) < 3 {
		return
	}
	//
	// check if the polygon is simple.
	// following is a brute-force approach.
	// TODO: upgrade to better version: Shamos-Hoey?
	edge_counter := 0
	if len(vertices) > 3 {
		for i0 in 0 ..< n - 2 {
			fmt.println("---------")
			i1 := i0 + 1
			hplane := get_half_plane_simple({vertices[i0], vertices[i1]})
			for t0 in (i0 + 2) ..< n {
				t1 := (t0 + 1) % n
				if i0 != t1 {
					edge_counter += 1
					fmt.printfln(
						"[%v] Half-plane (%v, %v),  Test edge (%v, %v)",
						edge_counter,
						i0,
						i1,
						t0,
						t1,
					)
				}
			}
		}
	}

}

half_plane :: struct {
	line_eqn_a:     f32,
	line_eqn_b:     f32,
	line_eqn_c:     f32,
	reference_sign: bool,
}

// merge with get_half_plane_simple
get_half_plane_simple :: proc(line: [2]vec2) -> half_plane {
	x1, y1 := line[0].x, line[0].y
	x2, y2 := line[1].x, line[1].y
	hp_test: half_plane = {
		line_eqn_a = (y2 - y1),
		line_eqn_b = -(x2 - x1),
		line_eqn_c = x2 * y1 - x1 * y2,
	}
	return hp_test
}

// TODO: remove reference_sign and make it simpler
get_half_plane :: proc(line: [2]vec2, ref_point: vec2) -> half_plane {
	x1, y1 := line[0].x, line[0].y
	x2, y2 := line[1].x, line[1].y
	hp_test: half_plane = {
		line_eqn_a = (y2 - y1),
		line_eqn_b = -(x2 - x1),
		line_eqn_c = x2 * y1 - x1 * y2,
	}
	hp_test.reference_sign =
		(hp_test.line_eqn_a * ref_point.x + hp_test.line_eqn_b * ref_point.y + hp_test.line_eqn_c <
			0)
	return hp_test
}

evaluate_half_plane :: proc(hplane: half_plane, test_point: vec2) -> f32 {
	val := hplane.line_eqn_a * test_point.x + hplane.line_eqn_b * test_point.y + hplane.line_eqn_c
	return val
}

test_half_plane :: proc(hplane: half_plane, test_point: vec2) -> bool {
	val := hplane.line_eqn_a * test_point.x + hplane.line_eqn_b * test_point.y + hplane.line_eqn_c
	return (val < 0) == hplane.reference_sign
}

rasterize_line :: proc(p0: vec2, p1: vec2, stroke_color: Color, target_buffer: ^Buffer) {
	// TODO: optimize, should work for every octant
	target_w, target_h := target_buffer.w, target_buffer.h
	x0, y0, x1, y1: f32
	if p0.x < p1.x {
		x0, y0 = p0.x, p0.y
		x1, y1 = p1.x, p1.y
	} else {
		x0, y0 = p1.x, p1.y
		x1, y1 = p0.x, p0.y
	}
	dx := x1 - x0
	dy := y1 - y0

	// pixel centers assumed to be integer
	x_start := i32(math.round(x0 - 0.5)) // nearest pixel center
	y_start := i32(math.round(y0 - 0.5)) // nearest pixel center
	x_end := i32(math.round(x1 - 0.5)) // nearest pixel center
	y_end := i32(math.round(y1 - 0.5)) // nearest pixel center

	// implicit line equation
	f_a: f32 = y0 - y1
	f_b: f32 = x1 - x0
	f_c: f32 = x0 * y1 - x1 * y0
	if dx >= dy && dy > 0 { 	// Case1: slope in (0, 1]
		y := y_start
		for x in x_start ..= x_end {
			// draw (x, y)
			if x >= 0 && x < target_w {
				if y >= 0 && y < target_h {
					target_buffer.data[x + target_w * y] = stroke_color
				}
			}
			// evaluate the midpoint b/w two next candidates
			val := f_a * (f32(x) + 1.0) + f_b * (f32(y) + 0.5) + f_c
			if val < 0 {
				y += 1
			}
		}
	} else if dy > dx && dy > 0 { 	// case2: slope in (1, +inf)
		x := x_start
		for y in y_start ..= y_end {
			// draw (x, y)
			if x >= 0 && x < target_w {
				if y >= 0 && y < target_h {
					target_buffer.data[x + target_w * y] = stroke_color
				}
			}
			// evaluate the midpoint b/w two next candidates
			val := f_a * (f32(x) + 0.5) + f_b * (f32(y) + 1.0) + f_c
			if val >= 0 {
				x += 1
			}
		}
	} else if dx >= -dy && dy <= 0 { 	// case3: slope in [-1, 0)
		y := y_start
		for x in x_start ..= x_end {
			// draw (x, y)
			if x >= 0 && x < target_w {
				if y >= 0 && y < target_h {
					target_buffer.data[x + target_w * y] = stroke_color
				}
			}
			// evaluate the midpoint b/w two next candidates
			val := f_a * (f32(x) + 1.0) + f_b * (f32(y) - 0.5) + f_c
			if val >= 0 {
				y -= 1
			}
		}
	} else if dx < -dy && dy <= 0 { 	// case4: slope in (-inf, -1)
		x := x_start
		for y := y_start; y >= y_end; y -= 1 { 	// decreasing order
			// draw (x, y)
			if x >= 0 && x < target_w {
				if y >= 0 && y < target_h {
					target_buffer.data[x + target_w * y] = stroke_color
				}
			}
			// evaluate the midpoint b/w two next candidates
			val := f_a * (f32(x) + 0.5) + f_b * (f32(y) - 1.0) + f_c
			if val < 0 {
				x += 1
			}
		}
	}
}

rasterize_triangle :: proc(points: [3]vec2, color: Color, target_buffer: ^Buffer) {
	// edge 1
	hp1 := get_half_plane({points[0], points[1]}, points[2])
	hp2 := get_half_plane({points[1], points[2]}, points[0])
	hp3 := get_half_plane({points[2], points[0]}, points[1])
	// TODO: implement supersampling, tie-breaking, optimization etc.
	for y in 0 ..< target_buffer.h {
		for x in 0 ..< target_buffer.w {
			test_point: vec2 = {f32(x) + 0.5, f32(y) + 0.5}
			is_inside :=
				test_half_plane(hp1, test_point) &&
				test_half_plane(hp2, test_point) &&
				test_half_plane(hp3, test_point)
			if is_inside {
				target_buffer.data[x + y * target_buffer.w] = color
			}
		}
	}
}
