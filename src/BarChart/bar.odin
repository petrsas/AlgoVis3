package BarChart

import rl "vendor:raylib"
import "../Globals"

Bar::struct {
    r : rl.Rectangle,
    is_highlighted : bool,
}

new_bar::proc(x,y,w,h : f32) -> Bar {
    return Bar {
        r = rl.Rectangle{x,y,w,h},
        is_highlighted = false,
    }
}

bar_draw::proc(b: ^Bar) {
    if b.is_highlighted {
        rl.DrawRectangleRec(b.r, Globals.HIGHLIGHT_COLOR)
    } else {
        rl.DrawRectangleRec(b.r, Globals.REGULAR_COLOR)
    }
}

bar_update::proc(b: ^Bar) {
    bar_draw(b)
}
