package array

import "core:fmt"
import "core:strings"
import "core:slice"
import "core:log"

import rl "vendor:raylib"
import vv "../VisualVector/"
import "../Globals/"
import i "../Instructions"
import con "../Connectors"

Element::struct
{
    c_str: cstring,
    r: rl.Rectangle,
    font_size: i32,
    is_highlighted: bool,
}

value_to_cstring::proc(value: $T) -> cstring {
    return strings.clone_to_cstring(fmt.tprintf("%v", value))
}

//Since the elements should be uniform, the fitting of text into elems will be arrays task
element_init::proc(val_str: cstring, x,y,w,h : f32) -> Element {
    font_size := h * 0.8
    return Element {
        c_str = val_str,
        r = rl.Rectangle{x,y,w,h},
        font_size = i32(h * 0.8),
        is_highlighted = false,
    }
}

element_draw::proc(self: ^Element) {
    //(width - text_len / 2) + x 
    text_x := i32(self.r.x) + (i32(self.r.width) - rl.MeasureText(self.c_str, self.font_size)) / 2
    text_y := i32(self.r.y) + (i32(self.r.height) - self.font_size) / 2 

    rl.DrawText(self.c_str, text_x, text_y, self.font_size, rl.WHITE)
    if self.is_highlighted {
        rl.DrawRectangleLinesEx(self.r, 4.0, Globals.HIGHLIGHT_COLOR)
    } else {
        rl.DrawRectangleLinesEx(self.r, 4.0, Globals.REGULAR_COLOR)
    }
}

element_update::proc(self: ^Element) {
    element_draw(self)
}

Array::struct
{
    connector: con.Connector,
    elements: []Element,
    i_bag: i.InstructionBag,
    high_bag: i.IndexBag,
    move: proc(self: ^Array, direction: int),
    delta_accum: f32,
    delta_mark: f32,
}

execute_instruction::proc(self: ^Array, instruction: i.Instruction) {
    for i in self.high_bag.get_all(&self.high_bag) {
        self.elements[i].is_highlighted = false
    }
    self.high_bag.clear(&self.high_bag)
    log.debug("Highligted instructions cleared...")

    //log.debugf("Instruction to be executed: %s", instruction)
    #partial switch cmd in instruction {
        case i.vvCmp:
            self.elements[cmd.idx_a].is_highlighted = true
            self.high_bag.add(&self.high_bag, cmd.idx_a)
            self.elements[cmd.idx_b].is_highlighted = true
            self.high_bag.add(&self.high_bag, cmd.idx_b)
        case i.vvSwap:
            self.elements[cmd.idx_a].is_highlighted = true
            self.elements[cmd.idx_b].is_highlighted = true

            slice.swap(self.elements, cmd.idx_a, cmd.idx_b)
            self.elements[cmd.idx_a].r.x, self.elements[cmd.idx_b].r.x = self.elements[cmd.idx_b].r.x, self.elements[cmd.idx_a].r.x
        //DONE missing
    }
}

array_move::proc(self: ^Array, distance: int) {
    self.i_bag.move_and_get(&self.i_bag, distance)
}


generate_elements::proc(val_vec: []$T) -> ([]Element, bool) {
    //find the longest c_string to extract a w
    elem_height := f32((Globals.SCREEN_HEIGHT / 2) * 0.8)
    font_size := i32(elem_height * 0.8)
    max_len : i32 //default init to 0

    for val in val_vec {
        len := rl.MeasureText(value_to_cstring(val), font_size)
        if len > max_len {
            max_len = len
        }
    }

    elem_width := f32(max_len) * 1.2

    elements, err := make_slice([]Element, len(val_vec))
    if err != .None {
        log.errorf("Failed to create slice for elems: ", err)
        return make_slice([]Element, 0), false
    }

    x_offset := elem_width 
    y_offset := (Globals.SCREEN_HEIGHT / 2) - (elem_height / 2)
    for val, idx in val_vec {
        elements[idx] = element_init(strings.clone_to_cstring(fmt.tprintf("%v", val)), x_offset, y_offset, elem_width, elem_height)
        x_offset += elem_width
    }
    return elements, true
}

array_init::proc(visv: ^vv.VisualVector($T)) -> (Array, bool) {
    elements, elems_ok := generate_elements(visv.starting_state[:])
    if elems_ok {
        return Array {
            connector = visv.connector,
            elements = elements,
            i_bag = i.instruction_bag_init(),
            high_bag = i.index_bag_init(5),
            move = array_move,
            delta_mark = 2,
        }, true
    }
    return Array{}, false
}

array_draw::proc(self: ^Array) {
    for &e in self.elements {
        element_draw(&e)
    }
}

array_update::proc(self: ^Array, delta_time: f32) {
    instructions, ok := con.receive_instructions(&self.connector)
    if ok {
        for i in instructions {
            append(&self.i_bag.bag, i)
        }
    }
    self.delta_accum += delta_time

    if self.delta_accum >= self.delta_mark {
        log.debug("Delta marker passed!")
        self.delta_accum = 0
        instr, ok := self.i_bag.move_and_get(&self.i_bag, 1)
        if ok {
            execute_instruction(self, instr)
        }
    }
    array_draw(self)
}

