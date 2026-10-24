package savage

import "core:fmt"
import "core:math"
import "core:slice"

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

Triangle :: struct {
	points: [3]vec2,
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
	Triangle,
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
	case Triangle:
		draw_triangle(shape, element.style, target_buffer)
	case Rect:
		draw_rect(shape, element.style, target_buffer)
	case Polygon:
		draw_polygon(shape, element.style, target_buffer)
	case Ellipse:
	}
}

clear_buffer :: proc(color: Color, target_buffer: ^Buffer) {
	for &pixel in target_buffer.data {
		pixel = color
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

draw_triangle :: proc(triangle: Triangle, style: Style, target_buffer: ^Buffer) {
	// FIXME: visible misalignment b/w borders and fill
	pts := triangle.points
	rasterize_triangle(pts, style.fill_color, target_buffer)
	rasterize_line(pts[0], pts[1], style.stroke_color, target_buffer)
	rasterize_line(pts[1], pts[2], style.stroke_color, target_buffer)
	rasterize_line(pts[2], pts[0], style.stroke_color, target_buffer)
}

draw_rect :: proc(rect: Rect, style: Style, target_buffer: ^Buffer) {
	// FIXME: top and bottom edges are often extended towards left by 1px
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

BEZIER_SUBDIV_TOLERANCE :: 0.25


draw_curve_bezier_casteljau :: proc(
	control_points: [4]vec2,
	style: Style,
	target_buffer: ^Buffer,
) {
	// Reference: https://agg.sourceforge.net/antigrain.com/research/adaptive_bezier/
	//            Paul De Casteljau's Divide and Conquer based method
	// TODO: control color should be in the style with a bool

	p1 := control_points[0]
	p2 := control_points[1]
	p3 := control_points[2]
	p4 := control_points[3]

	// Calculate mid points
	p12, p23, p34, p123, p234, p1234: vec2
	p12 = {(p1.x + p2.x) / 2, (p1.y + p2.y) / 2}
	p23 = {(p2.x + p3.x) / 2, (p2.y + p3.y) / 2}
	p34 = {(p3.x + p4.x) / 2, (p3.y + p4.y) / 2}
	p123 = {(p12.x + p23.x) / 2, (p12.y + p23.y) / 2}
	p234 = {(p23.x + p34.x) / 2, (p23.y + p34.y) / 2}
	p1234 = {(p123.x + p234.x) / 2, (p123.y + p234.y) / 2}

	// Estimate error
	d41: vec2 = {p4.x - p1.x, p4.y - p1.y}
	// d2, d3 is the dist. b/w p2, p3 and the line (p1, p4)
	d2 := math.abs((p2.x - p4.x) * d41.y - (p2.y - p4.y) * d41.y)
	d3 := math.abs((p3.x - p4.x) * d41.y - (p3.y - p4.y) * d41.y)

	// Draw control points
	control_color: Color = {60, 60, 100, 255}
	rasterize_line(p1, p2, control_color, target_buffer)
	rasterize_line(p2, p3, control_color, target_buffer)
	rasterize_line(p3, p4, control_color, target_buffer)
	rasterize_line(p12, p23, control_color, target_buffer)
	rasterize_line(p23, p34, control_color, target_buffer)
	rasterize_line(p123, p234, control_color, target_buffer)

	is_flat_enough :=
		(d2 + d3) * (d2 + d3) < BEZIER_SUBDIV_TOLERANCE * (d41.x * d41.x + d41.y * d41.y)
	if is_flat_enough {
		rasterize_line(p1, p1234, style.stroke_color, target_buffer)
		rasterize_line(p1234, p4, style.stroke_color, target_buffer)
	} else {
		draw_curve_bezier_casteljau({p1, p12, p123, p1234}, style, target_buffer)
		draw_curve_bezier_casteljau({p1234, p234, p34, p4}, style, target_buffer)
	}
}

draw_curve_bezier_basic :: proc(control_points: [4]vec2, style: Style, target_buffer: ^Buffer) {
	// Reference: https://agg.sourceforge.net/antigrain.com/research/adaptive_bezier/
	// TODO: control color should be in the style
	p1 := control_points[0]
	p2 := control_points[1]
	p3 := control_points[2]
	p4 := control_points[3]

	// Draw control points
	control_color: Color = {60, 60, 100, 255}
	rasterize_line(p1, p2, control_color, target_buffer)
	rasterize_line(p2, p3, control_color, target_buffer)
	rasterize_line(p3, p4, control_color, target_buffer)

	// Curve length estimation for determining step size
	dx1 := p2.x - p1.x
	dy1 := p2.y - p1.y
	dx2 := p3.x - p2.x
	dy2 := p3.y - p2.y
	dx3 := p4.x - p3.x
	dy3 := p4.y - p3.y

	len :=
		math.sqrt(dx1 * dx1 + dy1 * dy1) +
		math.sqrt(dx2 * dx2 + dy2 * dy2) +
		math.sqrt(dx3 * dx3 + dy3 * dy3)
	num_steps := int(len * 0.25)
	fmt.printfln("[Draw_Bezier_Basic]: Length: %.2f, Num steps: %d", len, num_steps)
	dt: f32 = 1.0 / f32(num_steps)

	// Draw the curve
	t, t2, t3, tm, tm2, tm3: f32
	p_prev := p1
	p_curr: vec2
	for i in 0 ..< num_steps {
		t += dt
		t2 = t * t
		t3 = t2 * t
		tm = 1 - t
		tm2 = tm * tm
		tm3 = tm2 * tm
		p_curr.x = tm3 * p1.x + 3 * t * tm2 * p2.x + 3 * t2 * tm * p3.x + t3 * p4.x
		p_curr.y = tm3 * p1.y + 3 * t * tm2 * p2.y + 3 * t2 * tm * p3.y + t3 * p4.y
		rasterize_line(p_prev, p_curr, style.stroke_color, target_buffer)
		p_prev = p_curr
	}
}


ActiveEdge :: struct {
	edge:           [2]vec2,
	x_intersection: f32,
}

get_x_intersection :: proc(line: [2]vec2, y: f32) -> f32 {
	x1, y1 := line[0].x, line[0].y
	x2, y2 := line[1].x, line[1].y
	x := x1 + (y - y1) * (x2 - x1) / (y2 - y1)
	return x
}

edge_vertical_cmp_less :: proc(edge_a, edge_b: [2]vec2) -> bool {
	return min(edge_a[0].y, edge_a[1].y) < min(edge_b[0].y, edge_b[1].y)
}

edge_x_intersection_cmp_less :: proc(aedge_a, aedge_b: ActiveEdge) -> bool {
	return aedge_a.x_intersection < aedge_b.x_intersection
}

draw_polygon :: proc(polygon: Polygon, style: Style, target_buffer: ^Buffer) {
	// Reference:
	// How the stb_truetype Anti-Aliased Software Rasterizer v2 Works
	// https://www.nothings.org/gamedev/rasterize/
	// 					-- Sean Barrett
	points := polygon.points
	n := len(points)

	// 1. gather edges
	edges := make([][2]vec2, n)
	for i in 0 ..< n {
		edges[i] = {points[i], points[(i + 1) % n]}
	}
	defer delete(edges)

	// 2. sort by topmost vertex
	slice.sort_by(edges, edge_vertical_cmp_less)
	// fmt.printfln("\n------------------\nSorted edges:")
	// for edge in edges {
	// 	top := min(edge[0].y, edge[1].y)
	// fmt.printfln(
	// 	"Edge: [%.1f, %.1f] -> [%.1f, %.1f], Top : %.1f",
	// 	edge[0].x,
	// 	edge[0].y,
	// 	edge[1].x,
	// 	edge[1].y,
	// 	top,
	// )
	// }

	// 3. Move a line own (scanline)
	scanline_start := min(edges[0][0].y, edges[0][1].y)
	scanline_y := math.floor(scanline_start)
	active_edges: [dynamic]ActiveEdge
	defer delete(active_edges)
	edge_head: int = 0
	for {
		// TODO: use incremental append instead of starting afresh
		clear(&active_edges)
		// add to active edges (intersecting scanline)
		for edge_id in edge_head ..< len(edges) {
			edge := edges[edge_id]
			if edge[0].y < scanline_y || edge[1].y < scanline_y {
				append(
					&active_edges,
					ActiveEdge{edge = edge, x_intersection = get_x_intersection(edge, scanline_y)},
				)
			}
		}
		// remove edges past scanline
		#reverse for active_edge, ae_id in active_edges {
			edge := active_edge.edge
			if edge[0].y < scanline_y && edge[1].y < scanline_y {
				unordered_remove(&active_edges, ae_id)
			}
		}
		// sort active edges by their x intersection
		// TODO: replace by incremental sort
		slice.sort_by(active_edges[:], edge_x_intersection_cmp_less)
		fill: bool = true
		// if len(active_edges) > 0 {
		// 	fmt.printfln("-> scanline: %.1f", scanline_y)
		// }
		for active_edge, ae_id in active_edges {
			x_start := int(math.round(active_edge.x_intersection))
			x_end: int
			if ae_id < len(active_edges) - 1 {
				x_end = int(math.round(active_edges[ae_id + 1].x_intersection))
			} else if fill {
				x_end = int(target_buffer.w - 1)
			} else {
				break
			}
			// fmt.printfln("x_start: %v, x_end: %v, fill: %v", x_start, x_end, fill)
			pixel_id: int
			if fill {
				for x in x_start ..= x_end {
					pixel_id = int(x) + int(scanline_y) * int(target_buffer.w)
					if pixel_id < len(target_buffer.data) {
						target_buffer.data[pixel_id] = style.fill_color
					}
				}
			}
			fill = !fill
		}
		scanline_y += 1
		if i32(scanline_y) >= target_buffer.h {
			break
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
