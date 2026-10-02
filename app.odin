package drawsvg

import "core:fmt"
import "core:time"
import "core:math/rand"

app_update_and_render :: proc(buffer: ^Buffer, start_time: time.Tick) {
	//color : Color
	//t := time.duration_seconds(time.tick_since(start_time))
	//color.b = u8((0.5 + 0.5 * math.sin(t)) * 255)
	//color.a = 255
	//x_mult := 255.0 / f32(buffer.w)
	//y_mult := 255.0 / f32(buffer.h)
	//for y in 0..<buffer.h {
	//for x in 0..<buffer.w {
	//color.r = u8(f32(x) * x_mult)
	//color.g = u8(f32(y) * y_mult)
	//buffer.data[x + y*buffer.w] = color
	//}
	//}

	pt_elem: Element = {
		shape = Point{position = {500, 100}},
		style = Style{fill_color = {255, 0, 0, 255}, stroke_color = {0, 255, 0, 255}},
	}
    bg_rect_elem: Element = {
        shape = Rect{position = {0, 0}, dimension = {f32(buffer.w), f32(buffer.h)}},
		style = Style{fill_color = {0, 125, 150, 255}},
    }
    rect_elem: Element = {
        shape = Rect{position = {100, 100}, dimension = {600, 600}},
		style = Style{fill_color = {0, 125, 180, 255}, stroke_color = {125, 0, 0, 255}},
    }

	//line1: Element = {
		//shape = Line{from = {50, 50}, end = {1500, 500}},
		//style = Style{stroke_color = {0, 255, 0, 255}},
	//}
	//line2: Element = {
		//shape = Line{from = {1600, 500}, end = {50, 50}},
		//style = Style{stroke_color = {0, 255, 0, 255}},
	//}
	//line3: Element = {
		//shape = Line{from = {50, 50}, end = {500, 1000}},
		//style = Style{stroke_color = {255, 0, 0, 255}},
	//}
	//line4: Element = {
		//shape = Line{from = {500, 1100}, end = {50, 50}},
		//style = Style{stroke_color = {255, 0, 0, 255}},
	//}
	//line5: Element = {
		//shape = Line{from = {50, 50}, end = {400, 400}},
		//style = Style{stroke_color = {255, 255, 255, 255}},
	//}
	//line6: Element = {
		//shape = Line{from = {50, 1000}, end = {1500, 700}},
		//style = Style{stroke_color = {255, 255, 0, 255}},
	//}
	//line7: Element = {
		//shape = Line{from = {1600, 700}, end = {50, 1000}},
		//style = Style{stroke_color = {255, 255, 0, 255}},
	//}
	//line8: Element = {
		//shape = Line{from = {50, 1000}, end = {200, 50}},
		//style = Style{stroke_color = {0, 255, 255, 255}},
	//}
	//line9: Element = {
		//shape = Line{from = {200, 100}, end = {50, 1000}},
		//style = Style{stroke_color = {0, 255, 255, 255}},
	//}
	//draw_element_sr(bg_rect_elem, buffer)
	//draw_element_sr(rect_elem, buffer)
    //draw_element_sr(line1, buffer)
    //draw_element_sr(line2, buffer)
    //draw_element_sr(line3, buffer)
    //draw_element_sr(line4, buffer)
    //draw_element_sr(line5, buffer)
    //draw_element_sr(line6, buffer)
    //draw_element_sr(line7, buffer)
    //draw_element_sr(line8, buffer)
    //draw_element_sr(line9, buffer)
    n := 10 
    polyline: Polyline
    polyline.points = make([]vec2, n)
    rand.reset(1)
    for i in 0..<n {
        polyline.points[i].x = rand.float32_range(0, f32(buffer.w) - 1)
        polyline.points[i].y = rand.float32_range(0, f32(buffer.h) - 1)
    }
    polyline_elm: Element = {
        shape = polyline,
        style = Style{stroke_color  = {255, 200, 0, 255}}
    }
    draw_element_sr(polyline_elm, buffer)
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
