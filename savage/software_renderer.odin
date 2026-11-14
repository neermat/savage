package savage

import "core:fmt"
import "core:math"
import "core:slice"

// TODO: Learn more struct/array alignment and SIMD optimizations
// TODO: Support hexcode style color input (with u32?)
vec2 :: [2]f32
Color :: distinct [4]u8
ColorLinPremul :: distinct [4]f16

RenderTarget :: struct {
	data: []ColorLinPremul,
	w:    int,
	h:    int,
}

Style :: struct {
	stroke_color: Color,
	fill_color:   Color,
	stroke_width: f32,
	miter_limit:  f32,
}


// TODO: @optim We could also try storing the mapping from [0, 255] -> f16/f32; SIMD
to_linear_premul :: proc(color: Color) -> ColorLinPremul {
	color_out: ColorLinPremul
	alpha := f32(color.a) / 255.0
	col: f32
	for i in 0 ..< 3 {
		col = f32(color[i]) / 255.0
		if col <= 0.04045 {
			col = col / 12.92
		} else {
			col = math.pow((col + 0.055) / 1.055, 2.4)
		}
		color_out[i] = f16(alpha * col)
	}
	color_out[3] = f16(alpha)
	return color_out
}

// TODO: @optim (number of operations); SIMD
to_srgb :: proc(color_linear: ColorLinPremul) -> Color {
	color_out: Color
	col: f32
	for i in 0 ..< 3 {
		col = f32(color_linear[i])
		if col <= 0.0031308 {
			col = 12.92 * col
		} else {
			col = 1.055 * math.pow(col, 0.4166667) - 0.055
		}
		color_out[i] = u8(clamp(col, 0.0, 1.0) * 255)
	}
	color_out.a = u8(clamp(color_linear.a, 0.0, 1.0) * 255)

	return color_out
}

// NOTE: equivalent to mixing with {0, 0, 0, 1 - scale}
add_colors :: proc(color_a: ColorLinPremul, color_b: ColorLinPremul) -> ColorLinPremul {
	color_out: ColorLinPremul
	color_out.r =  color_a.r + color_b.r
	color_out.g =  color_a.g + color_b.g
	color_out.b =  color_a.b + color_b.b
	color_out.a =  color_a.a + color_b.a
	return color_out

}

// NOTE: equivalent to mixing with {0, 0, 0, 1 - scale}
scale_color :: proc(color: ColorLinPremul, scale: f16) -> ColorLinPremul {
	color_out: ColorLinPremul
	color_out.r = scale * color.r
	color_out.g = scale * color.g
	color_out.b = scale * color.b
	color_out.a = scale * color.a
	return color_out

}

// TODO: @optim SIMD can help here?
composite_over :: proc(color_bot: ColorLinPremul, color_top: ColorLinPremul) -> ColorLinPremul {
	color_out: ColorLinPremul
	k := 1.0 - color_top.a
	color_out.r = color_top.r + k * color_bot.r
	color_out.g = color_top.g + k * color_bot.g
	color_out.b = color_top.b + k * color_bot.b
	color_out.a = color_top.a + k * color_bot.a
	return color_out
}


fill :: proc(color: ColorLinPremul, target: ^RenderTarget) {
	for &pixel in target.data {
		pixel = composite_over(pixel, color)
	}
}

color_pixel :: proc(x: int, y: int, color: ColorLinPremul, target: ^RenderTarget) {
	if x >= 0 && x < target.w {
		if y >= 0 && y < target.h {
			loc := x + y * target.w
			target.data[loc] = composite_over(target.data[loc], color)
		}
	}
}


//
// draw_polyline :: proc(polyline: Polyline, style: Style, target_buffer: ^Buffer) {
// 	for i in 0 ..< len(polyline.points) - 1 {
// 		rasterize_line(
// 			polyline.points[i],
// 			polyline.points[i + 1],
// 			style.stroke_color,
// 			target_buffer,
// 		)
// 	}
// }
//
// draw_triangle :: proc(triangle: Triangle, style: Style, target_buffer: ^Buffer) {
// 	// FIXME: visible misalignment b/w borders and fill
// 	pts := triangle.points
// 	rasterize_triangle(pts, style.fill_color, target_buffer)
// 	rasterize_line(pts[0], pts[1], style.stroke_color, target_buffer)
// 	rasterize_line(pts[1], pts[2], style.stroke_color, target_buffer)
// 	rasterize_line(pts[2], pts[0], style.stroke_color, target_buffer)
// }
//
// draw_rect :: proc(rect: Rect, style: Style, target_buffer: ^Buffer) {
// 	// FIXME: top and bottom edges are often extended towards left by 1px
// 	p0: vec2 = rect.position
// 	p1: vec2 = {rect.position.x + rect.dimension.x, rect.position.y}
// 	p2: vec2 = {rect.position.x, rect.position.y + rect.dimension.y}
// 	p3: vec2 = {rect.position.x + rect.dimension.x, rect.position.y + rect.dimension.y}
// 	triangle1: [3]vec2 = {p0, p1, p3}
// 	triangle2: [3]vec2 = {p0, p2, p3}
//
// 	rasterize_triangle({p0, p1, p3}, style.fill_color, target_buffer)
// 	rasterize_triangle({p0, p2, p3}, style.fill_color, target_buffer)
// 	rasterize_line(p0, p1, style.stroke_color, target_buffer)
// 	rasterize_line(p0, p2, style.stroke_color, target_buffer)
// 	rasterize_line(p2, p3, style.stroke_color, target_buffer)
// 	rasterize_line(p1, p3, style.stroke_color, target_buffer)
// }
//
// draw_rect_fill_only :: proc(rect: Rect, style: Style, target_buffer: ^Buffer) {
// 	p0: vec2 = rect.position
// 	p1: vec2 = {rect.position.x + rect.dimension.x, rect.position.y}
// 	p2: vec2 = {rect.position.x, rect.position.y + rect.dimension.y}
// 	p3: vec2 = {rect.position.x + rect.dimension.x, rect.position.y + rect.dimension.y}
// 	triangle1: [3]vec2 = {p0, p1, p3}
// 	triangle2: [3]vec2 = {p0, p2, p3}
//
// 	rasterize_triangle({p0, p1, p3}, style.fill_color, target_buffer)
// 	rasterize_triangle({p0, p2, p3}, style.fill_color, target_buffer)
// }
//
// BEZIER_SUBDIV_TOLERANCE :: 0.25
//
//
// draw_curve_bezier_casteljau :: proc(
// 	control_points: [4]vec2,
// 	style: Style,
// 	target_buffer: ^Buffer,
// ) {
// 	// Reference: https://agg.sourceforge.net/antigrain.com/research/adaptive_bezier/
// 	//            Paul De Casteljau's Divide and Conquer based method
// 	// TODO: control color should be in the style with a bool
// 	// TODO: think about the performance
// 	// TODO: degenerate curves handling (add tests)
// 	// TODO: decouple geometry processing from rasterization
// 	//		 (this proc should only about geometry processing)
//
// 	p1 := control_points[0]
// 	p2 := control_points[1]
// 	p3 := control_points[2]
// 	p4 := control_points[3]
//
// 	// Calculate mid points
// 	p12, p23, p34, p123, p234, p1234: vec2
// 	p12 = {(p1.x + p2.x) / 2, (p1.y + p2.y) / 2}
// 	p23 = {(p2.x + p3.x) / 2, (p2.y + p3.y) / 2}
// 	p34 = {(p3.x + p4.x) / 2, (p3.y + p4.y) / 2}
// 	p123 = {(p12.x + p23.x) / 2, (p12.y + p23.y) / 2}
// 	p234 = {(p23.x + p34.x) / 2, (p23.y + p34.y) / 2}
// 	p1234 = {(p123.x + p234.x) / 2, (p123.y + p234.y) / 2}
//
// 	// Estimate error
// 	d41: vec2 = {p4.x - p1.x, p4.y - p1.y}
// 	// d2, d3 is the dist. b/w p2, p3 and the line (p1, p4)
// 	d2 := math.abs((p2.x - p4.x) * d41.y - (p2.y - p4.y) * d41.y)
// 	d3 := math.abs((p3.x - p4.x) * d41.y - (p3.y - p4.y) * d41.y)
//
// 	// Draw control points
// 	control_color: Color = {60, 60, 100, 255}
// 	pt_size: f32 = 0.25
// 	rasterize_line(p1, p2, control_color, target_buffer)
// 	rasterize_line(p2, p3, control_color, target_buffer)
// 	rasterize_line(p3, p4, control_color, target_buffer)
// 	rasterize_line(p12, p23, control_color, target_buffer)
// 	rasterize_line(p23, p34, control_color, target_buffer)
// 	rasterize_line(p123, p234, control_color, target_buffer)
//
// 	is_flat_enough :=
// 		(d2 + d3) * (d2 + d3) < BEZIER_SUBDIV_TOLERANCE * (d41.x * d41.x + d41.y * d41.y)
// 	if is_flat_enough {
// 		rasterize_line(p1, p1234, style.stroke_color, target_buffer)
// 		rasterize_line(p1234, p4, style.stroke_color, target_buffer)
// 	} else {
// 		draw_curve_bezier_casteljau({p1, p12, p123, p1234}, style, target_buffer)
// 		draw_curve_bezier_casteljau({p1234, p234, p34, p4}, style, target_buffer)
// 	}
// }
//
// draw_curve_bezier_basic :: proc(control_points: [4]vec2, style: Style, target_buffer: ^Buffer) {
// 	// Reference: https://agg.sourceforge.net/antigrain.com/research/adaptive_bezier/
// 	// TODO: control color should be in the style
// 	p1 := control_points[0]
// 	p2 := control_points[1]
// 	p3 := control_points[2]
// 	p4 := control_points[3]
//
// 	// Draw control points
// 	control_color: Color = {60, 60, 100, 255}
// 	rasterize_line(p1, p2, control_color, target_buffer)
// 	rasterize_line(p2, p3, control_color, target_buffer)
// 	rasterize_line(p3, p4, control_color, target_buffer)
//
// 	// Curve length estimation for determining step size
// 	dx1 := p2.x - p1.x
// 	dy1 := p2.y - p1.y
// 	dx2 := p3.x - p2.x
// 	dy2 := p3.y - p2.y
// 	dx3 := p4.x - p3.x
// 	dy3 := p4.y - p3.y
//
// 	len :=
// 		math.sqrt(dx1 * dx1 + dy1 * dy1) +
// 		math.sqrt(dx2 * dx2 + dy2 * dy2) +
// 		math.sqrt(dx3 * dx3 + dy3 * dy3)
// 	num_steps := int(len * 0.25)
// 	fmt.printfln("[Draw_Bezier_Basic]: Length: %.2f, Num steps: %d", len, num_steps)
// 	dt: f32 = 1.0 / f32(num_steps)
//
// 	// Draw the curve
// 	t, t2, t3, tm, tm2, tm3: f32
// 	p_prev := p1
// 	p_curr: vec2
// 	for i in 0 ..< num_steps {
// 		t += dt
// 		t2 = t * t
// 		t3 = t2 * t
// 		tm = 1 - t
// 		tm2 = tm * tm
// 		tm3 = tm2 * tm
// 		p_curr.x = tm3 * p1.x + 3 * t * tm2 * p2.x + 3 * t2 * tm * p3.x + t3 * p4.x
// 		p_curr.y = tm3 * p1.y + 3 * t * tm2 * p2.y + 3 * t2 * tm * p3.y + t3 * p4.y
// 		rasterize_line(p_prev, p_curr, style.stroke_color, target_buffer)
// 		p_prev = p_curr
// 	}
// }
//
//
// ActiveEdge :: struct {
// 	edge:           [2]vec2,
// 	x_intersection: f32,
// }
//
// get_x_intersection :: proc(line: [2]vec2, y: f32) -> f32 {
// 	x1, y1 := line[0].x, line[0].y
// 	x2, y2 := line[1].x, line[1].y
// 	x := x1 + (y - y1) * (x2 - x1) / (y2 - y1)
// 	return x
// }
//
// edge_vertical_cmp_less :: proc(edge_a, edge_b: [2]vec2) -> bool {
// 	return min(edge_a[0].y, edge_a[1].y) < min(edge_b[0].y, edge_b[1].y)
// }
//
// edge_x_intersection_cmp_less :: proc(aedge_a, aedge_b: ActiveEdge) -> bool {
// 	return aedge_a.x_intersection < aedge_b.x_intersection
// }
//
// draw_polygon :: proc(polygon: Polygon, style: Style, target_buffer: ^Buffer) {
// 	// Reference:
// 	// How the stb_truetype Anti-Aliased Software Rasterizer v2 Works
// 	// https://www.nothings.org/gamedev/rasterize/
// 	// 					-- Sean Barrett
// 	points := polygon.points
// 	n := len(points)
//
// 	// 1. gather edges
// 	edges := make([][2]vec2, n)
// 	for i in 0 ..< n {
// 		edges[i] = {points[i], points[(i + 1) % n]}
// 	}
// 	defer delete(edges)
//
// 	// 2. sort by topmost vertex
// 	slice.sort_by(edges, edge_vertical_cmp_less)
// 	// fmt.printfln("\n------------------\nSorted edges:")
// 	// for edge in edges {
// 	// 	top := min(edge[0].y, edge[1].y)
// 	// fmt.printfln(
// 	// 	"Edge: [%.1f, %.1f] -> [%.1f, %.1f], Top : %.1f",
// 	// 	edge[0].x,
// 	// 	edge[0].y,
// 	// 	edge[1].x,
// 	// 	edge[1].y,
// 	// 	top,
// 	// )
// 	// }
//
// 	// 3. Move a line own (scanline)
// 	scanline_start := min(edges[0][0].y, edges[0][1].y)
// 	scanline_y := math.floor(scanline_start)
// 	active_edges: [dynamic]ActiveEdge
// 	defer delete(active_edges)
// 	edge_head: int = 0
// 	for {
// 		// TODO: use incremental append instead of starting afresh
// 		clear(&active_edges)
// 		// add to active edges (intersecting scanline)
// 		for edge_id in edge_head ..< len(edges) {
// 			edge := edges[edge_id]
// 			if edge[0].y < scanline_y || edge[1].y < scanline_y {
// 				append(
// 					&active_edges,
// 					ActiveEdge{edge = edge, x_intersection = get_x_intersection(edge, scanline_y)},
// 				)
// 			}
// 		}
// 		// remove edges past scanline
// 		#reverse for active_edge, ae_id in active_edges {
// 			edge := active_edge.edge
// 			if edge[0].y < scanline_y && edge[1].y < scanline_y {
// 				unordered_remove(&active_edges, ae_id)
// 			}
// 		}
// 		// sort active edges by their x intersection
// 		// TODO: replace by incremental sort
// 		slice.sort_by(active_edges[:], edge_x_intersection_cmp_less)
// 		fill: bool = true
// 		// if len(active_edges) > 0 {
// 		// 	fmt.printfln("-> scanline: %.1f", scanline_y)
// 		// }
// 		for active_edge, ae_id in active_edges {
// 			x_start := int(math.round(active_edge.x_intersection))
// 			x_end: int
// 			if ae_id < len(active_edges) - 1 {
// 				x_end = int(math.round(active_edges[ae_id + 1].x_intersection))
// 			} else if fill {
// 				x_end = int(target_buffer.w - 1)
// 			} else {
// 				break
// 			}
// 			// fmt.printfln("x_start: %v, x_end: %v, fill: %v", x_start, x_end, fill)
// 			pixel_id: int
// 			if fill {
// 				for x in x_start ..= x_end {
// 					pixel_id = int(x) + int(scanline_y) * int(target_buffer.w)
// 					if pixel_id < len(target_buffer.data) {
// 						target_buffer.data[pixel_id] = style.fill_color
// 					}
// 				}
// 			}
// 			fill = !fill
// 		}
// 		scanline_y += 1
// 		if i32(scanline_y) >= target_buffer.h {
// 			break
// 		}
// 	}
// }
//
//

// Hairline Rasterization (Two-Point Antialiasing)
rasterize_hariline_wu :: proc(p1: vec2, p2: vec2, color: ColorLinPremul, target: ^RenderTarget) {
	// TODO: @optim Ensure we aren't doing computations when off-screen
	target_w, target_h := target.w, target.h

	// sort by x-coord & offset by 0.5 to work in space
	//    where pixel centers are at integer coordinates
	x1, y1, x2, y2: f32
	if p1.x < p2.x {
		x1, y1 = p1.x - 0.5, p1.y - 0.5
		x2, y2 = p2.x - 0.5, p2.y - 0.5
	} else {
		x1, y1 = p2.x - 0.5, p2.y - 0.5
		x2, y2 = p1.x - 0.5, p1.y - 0.5
	}
	dx := x2 - x1
	dy := y2 - y1

	if dx == 0 && dy == 0 do return

	loc: int
	slope, intercept: f32
	x_start, x_end: int
	y_i, y_i_low, y_i_high: f32
	d_a: f16
	color_low, color_high: ColorLinPremul
	is_x_dominant := (dx >= dy && dy > 0) || (dx >= -dy && dy < 0)
	if is_x_dominant {
		slope = dy / dx
		intercept = y1 - slope * x1
		x_start = int(math.floor(x1))
		x_end = int(math.ceil(x2))
	} else {
		slope = dx / dy
		intercept = x1 - slope * y1
		if dy > 0 {
			x_start = clamp(int(math.floor(y1)), 0, target_h - 1)
			x_end = clamp(int(math.floor(y2)), 0, target_h - 1)
		} else {
			x_start = clamp(int(math.floor(y2)), 0, target_h - 1)
			x_end = clamp(int(math.floor(y1)), 0, target_h - 1)
		}
	}
	for x_i in x_start ..= x_end {
		y_i = slope * f32(x_i) + intercept
		y_i_low = math.floor(y_i)
		y_i_high = y_i_low + 1
		d_a = f16(y_i - y_i_low)
		color_high = scale_color(color, d_a)
		color_low = scale_color(color, 1 - d_a)
		if is_x_dominant {
			color_pixel(x_i, int(y_i_low), color_low, target)
			color_pixel(x_i, int(y_i_high), color_high, target)
		} else {
			color_pixel(int(y_i_low), x_i, color_low, target)
			color_pixel(int(y_i_high), x_i, color_high, target)
		}
	}
}

// Hairline Rasterization (Bresenham's incremental approach - No Antialiasing)
rasterize_hairline_bresenham :: proc(
	p0: vec2,
	p1: vec2,
	color: ColorLinPremul,
	target: ^RenderTarget,
) {
	// TODO: See if we can shorten the cases by using symmetry in a better manner
	target_w, target_h := target.w, target.h

	// sort by x-coord
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

	// // pixel centers assumed to be integer
	x_start := int(math.round(x0 - 0.5)) // nearest pixel center
	y_start := int(math.round(y0 - 0.5)) // nearest pixel center
	x_end := int(math.round(x1 - 0.5)) // nearest pixel center
	y_end := int(math.round(y1 - 0.5)) // nearest pixel center

	// implicit line equation: f_a * x + f_b * y + f_c = 0
	f_a: f32 = y0 - y1
	f_b: f32 = x1 - x0
	f_c: f32 = x0 * y1 - x1 * y0
	loc: int
	if dx >= dy && dy > 0 { 	// Case1: slope in (0, 1], x-dominant
		y := y_start
		for x in x_start ..= x_end {
			color_pixel(x, y, color, target)
			// evaluate the midpoint b/w two next candidates
			val := f_a * (f32(x) + 1.0) + f_b * (f32(y) + 0.5) + f_c
			if val < 0 {
				y += 1
			}
		}
	} else if dy > dx && dy > 0 { 	// case2: slope in (1, +inf)
		x := x_start
		for y in y_start ..= y_end {
			color_pixel(x, y, color, target)
			// evaluate the midpoint b/w two next candidates
			val := f_a * (f32(x) + 0.5) + f_b * (f32(y) + 1.0) + f_c
			if val >= 0 {
				x += 1
			}
		}
	} else if dx >= -dy && dy <= 0 { 	// case3: slope in [-1, 0)
		y := y_start
		for x in x_start ..= x_end {
			color_pixel(x, y, color, target)
			// evaluate the midpoint b/w two next candidates
			val := f_a * (f32(x) + 1.0) + f_b * (f32(y) - 0.5) + f_c
			if val >= 0 {
				y -= 1
			}
		}
	} else if dx < -dy && dy <= 0 { 	// case4: slope in (-inf, -1)
		x := x_start
		for y := y_start; y >= y_end; y -= 1 { 	// decreasing order
			color_pixel(x, y, color, target)
			// evaluate the midpoint b/w two next candidates
			val := f_a * (f32(x) + 0.5) + f_b * (f32(y) - 1.0) + f_c
			if val < 0 {
				x += 1
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


EdgeFuncInterpolator :: struct {
	val:         f32,
	dx:          f32,
	dy:          f32,
	ve_dist:     f32,
	ve_dist_inv: f32,
	opp_color:   ColorLinPremul,
}


// TODO: use proper polymorphism and/or merge with the one color one
// TODO: get more clarity about the coordinate system (where are the pixel centers etc.)
rasterize_triangle_3colors :: proc(
	points: [3]vec2,
	colors: [3]ColorLinPremul,
	target: ^RenderTarget,
) {
	// Reference: "A Parallel Algorithm for Polygon Rasterization" by _Juan Pineda_
	w, h := target.w, target.h

	p1 := points[0]
	p2 := points[1]
	p3 := points[2]

	// Bounding box
	x_min := int(math.floor(min(p1.x, p2.x, p3.x)))
	x_max := int(math.floor(max(p1.x, p2.x, p3.x)))
	y_min := int(math.ceil(min(p1.y, p2.y, p3.y)))
	y_max := int(math.ceil(max(p1.y, p2.y, p3.y)))

	// check and correct the winding if necessary
	points := points
	ef1_at_p3 := (p3.x - p2.x) * (p2.y - p1.y) - (p3.y - p2.y) * (p2.x - p1.x)
	if ef1_at_p3 < 0 {
		points[0], points[1] = points[1], points[0]
	}


	// Start from the top-most point
	p_start: [2]int
	p_start.y = target.h
	for v in points {
		if int(v.y) <= p_start.y {
			p_start.x = int(math.round(v.x))
			p_start.y = int(math.round(v.y))
		}
	}


	edge_fn_interps: [3]EdgeFuncInterpolator

	// initialize edge function interpolators
	interp: ^EdgeFuncInterpolator
	ve_dist: f32
	for v1, i in points {
		v2 := points[(i + 1) % 3]
		opp_idx :=  (i + 2) % 3
		v3 := points[opp_idx]
		interp = &edge_fn_interps[i]
		interp.opp_color = colors[opp_idx]
		interp.dx = v2.x - v1.x
		interp.dy = v2.y - v1.y
		interp.val = (f32(p_start.x) - v2.x) * interp.dy - (f32(p_start.y) - v2.y) * interp.dx
		ve_dist =
			interp.val + (v3.x - f32(p_start.x)) * interp.dy - (v3.y - f32(p_start.y)) * interp.dx
		interp.ve_dist_inv = 1 / (ve_dist + 1e-7)
	}


	// Traverse the pixels
	p_center, p: [2]int
	val_at_center: [3]f32
	is_inside: bool
	// traverse down the center-line
	// TODO: Do not check outside the target
	p = p_start
	center_shift_x: int
	color : ColorLinPremul
	for p.y <= y_max {

		// Save value at center
		p_center = p
		for interp, i in edge_fn_interps {
			val_at_center[i] = interp.val
		}
		// Go in the -> right direction
		for p.x <= x_max {
			p.x += 1
			// test p
			is_inside = true
			color = {}
			for &interp in edge_fn_interps {
				interp.val += interp.dy
				// TODO: this is not incremental!
				color = add_colors(color, scale_color(interp.opp_color, f16(interp.val * interp.ve_dist_inv)))
				is_inside &&= interp.val >= 0
			}
			if is_inside {
				color_pixel(p.x, p.y, color, target)
			} else {
				break
			}
		}

		// Come back to the <-|-> center
		p = p_center
		for &interp, i in edge_fn_interps {
			interp.val = val_at_center[i]
		}

		// Go in the <- left direction
		// TODO: factor out the code for testing the point and color compute from here
		for p.x >= x_min {
			p.x -= 1
			// test p
			is_inside = true
			color = {}
			for &interp in edge_fn_interps {
				interp.val -= interp.dy
				color = add_colors(color, scale_color(interp.opp_color, f16(interp.val * interp.ve_dist_inv)))
				// color = add_colors(color, scale_color(interp.opp_color, f16(interp.val)))
				is_inside &&= interp.val >= 0
			}
			if is_inside {
				color_pixel(p.x, p.y, color, target)
			} else {
				break
			}
		}

		// Come back to the center
		p = p_center
		for &interp, i in edge_fn_interps {
			interp.val = val_at_center[i]
		}

		// Go down & Compute shift
		center_shift_x = 0
		p.y += 1
		for &interp in edge_fn_interps {
			interp.val -= interp.dx
			if interp.val < 0 {
				if interp.dy > 0 {
					center_shift_x = int(math.ceil(-interp.val / interp.dy))
				} else if interp.dy < 0 {
					center_shift_x = int(math.floor(-interp.val / interp.dy))
				}
			}
		}

		// Shift the center line & test
		p.x += center_shift_x
		// test p
		is_inside = true
		color = {}
		for &interp in edge_fn_interps {
			interp.val += f32(center_shift_x) * interp.dy
			color = add_colors(color, scale_color(interp.opp_color, f16(interp.val * interp.ve_dist_inv)))
			// color = add_colors(color, scale_color(interp.opp_color, f16(interp.val)))
			is_inside &&= interp.val >= 0
		}
		if is_inside {
			color_pixel(p.x, p.y, color, target)
		}
	}
}

rasterize_triangle :: proc(points: [3]vec2, color: ColorLinPremul, target: ^RenderTarget) {

	// Reference: "A Parallel Algorithm for Polygon Rasterization" by _Juan Pineda_
	w, h := target.w, target.h


	p1 := points[0]
	p2 := points[1]
	p3 := points[2]

	// Bounding box
	x_min := int(math.floor(min(p1.x, p2.x, p3.x)))
	x_max := int(math.floor(max(p1.x, p2.x, p3.x)))
	y_min := int(math.ceil(min(p1.y, p2.y, p3.y)))
	y_max := int(math.ceil(max(p1.y, p2.y, p3.y)))

	// check and correct the winding if necessary
	points := points
	ef1_at_p3 := (p3.x - p2.x) * (p2.y - p1.y) - (p3.y - p2.y) * (p2.x - p1.x)
	if ef1_at_p3 < 0 {
		points[0], points[1] = points[1], points[0]
	}


	// Start from the top-most point
	p_start: [2]int
	p_start.y = target.h
	for v in points {
		if int(v.y) <= p_start.y {
			p_start.x = int(math.round(v.x))
			p_start.y = int(math.round(v.y))
		}
	}


	edge_fn_interps: [3]EdgeFuncInterpolator

	// initialize edge function interpolators
	interp: ^EdgeFuncInterpolator
	for v1, i in points {
		v2 := points[(i + 1) % 3]
		interp = &edge_fn_interps[i]
		interp.dx = v2.x - v1.x
		interp.dy = v2.y - v1.y
		interp.val = (f32(p_start.x) - v2.x) * interp.dy - (f32(p_start.y) - v2.y) * interp.dx
	}


	// Traverse the pixels
	p_center, p: [2]int
	val_at_center: [3]f32
	is_inside: bool
	// traverse down the center-line
	// TODO: Do not check outside the target
	p = p_start
	center_shift_x: int
	for p.y <= y_max {

		// Save value at center
		p_center = p
		for interp, i in edge_fn_interps {
			val_at_center[i] = interp.val
		}
		// Go in the -> right direction
		for p.x <= x_max {
			p.x += 1
			// test p
			is_inside = true
			for &interp in edge_fn_interps {
				interp.val += interp.dy
				is_inside &&= interp.val >= 0
			}
			if is_inside {
				color_pixel(p.x, p.y, color, target)
			} else {
				break
			}
		}

		// Come back to the <-|-> center
		p = p_center
		for &interp, i in edge_fn_interps {
			interp.val = val_at_center[i]
		}

		// Go in the <- left direction
		for p.x >= x_min {
			p.x -= 1
			// test p
			is_inside = true
			for &interp in edge_fn_interps {
				interp.val -= interp.dy
				is_inside &&= interp.val >= 0
			}
			if is_inside {
				color_pixel(p.x, p.y, color, target)
			} else {
				break
			}
		}

		// Come back to the center
		p = p_center
		for &interp, i in edge_fn_interps {
			interp.val = val_at_center[i]
		}

		// Go down & Compute shift
		center_shift_x = 0
		p.y += 1
		for &interp in edge_fn_interps {
			interp.val -= interp.dx
			if interp.val < 0 {
				if interp.dy > 0 {
					center_shift_x = int(math.ceil(-interp.val / interp.dy))
				} else if interp.dy < 0 {
					center_shift_x = int(math.floor(-interp.val / interp.dy))
				}
			}
		}

		// Shift the center line & test
		p.x += center_shift_x
		// test p
		is_inside = true
		for &interp in edge_fn_interps {
			interp.val += f32(center_shift_x) * interp.dy
			is_inside &&= interp.val >= 0
		}
		if is_inside {
			color_pixel(p.x, p.y, color, target)
		}
	}
}


rasterize_triangle_old :: proc(points: [3]vec2, color: ColorLinPremul, target: ^RenderTarget) {
	// edge 1
	hp1 := get_half_plane({points[0], points[1]}, points[2])
	hp2 := get_half_plane({points[1], points[2]}, points[0])
	hp3 := get_half_plane({points[2], points[0]}, points[1])

	// TODO: implement supersampling, tie-breaking,
	// TODO: @optim
	for y in 0 ..< target.h {
		for x in 0 ..< target.w {
			test_point: vec2 = {f32(x) + 0.5, f32(y) + 0.5}
			is_inside :=
				test_half_plane(hp1, test_point) &&
				test_half_plane(hp2, test_point) &&
				test_half_plane(hp3, test_point)
			if is_inside {
				color_pixel(x, y, color, target)
			}
		}
	}
}
