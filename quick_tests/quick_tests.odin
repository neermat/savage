package quick_tests

import "core:fmt"

main :: proc() {
	a : int = -1 % 3
	fmt.printfln("a = %d", a)
}
