package BarChart

import "core:strconv"
import vv "../VisualVector"
import "core:strings"
import "core:slice"
import "core:fmt"
import "base:intrinsics"
import "core:thread"
import "core:sync"
import "core:sync/chan"
import "../Globals"
import "../Utils"

InstructionBag::struct {
    instructions: [dynamic]string,
    instruction_pointer: int,
    move: proc(ib: ^InstructionBag, distance: int) -> bool,
    get: proc(ib: ^InstructionBag) -> string,
    move_and_get: proc(ib: ^InstructionBag, distance: int) -> (string, bool),
}

ib_move::proc(ib: ^InstructionBag, distance: int) -> bool {
    ib.instruction_pointer += distance
    if ib.instruction_pointer < 0 {
        ib.instruction_pointer = 0
        return false
    }
    l := len(ib.instructions) 
    if ib.instruction_pointer >= l {
        ib.instruction_pointer = l-1
        return false
    }
    return true
}

ib_get::proc(ib:^ InstructionBag) -> string {
    return ib.instructions[ib.instruction_pointer]
}

ib_move_and_get::proc(ib:^ InstructionBag, distance: int) -> (string, bool) {
    ok := ib.move(ib, distance)
    return ib.get(ib), ok
}

new_instruction_bag::proc() -> InstructionBag { 
    return InstructionBag {
        make([dynamic]string),
        0,
        ib_move,
        ib_get,
        ib_move_and_get,
    }
}

destory_instruction_bat::proc(ib: InstructionBag) {
    delete(ib.instructions)
}

IndexBag::struct {
    idxs: []int,
    idx_pointer: int,
    add: proc(ib: ^IndexBag, idx: int) -> bool,
    get_all: proc(ib: IndexBag) -> []int,
    clear: proc(ib: ^IndexBag),
}

ib_add::proc(ib: ^IndexBag, idx: int) -> bool {
    ib.idx_pointer += 1
    if ib.idx_pointer >= len(ib.idxs) {
        ib.idx_pointer = len(ib.idxs) - 1
        return false
    }
    ib.idxs[ib.idx_pointer] = idx
    return true
}

ib_get_all::proc(ib: IndexBag) -> []int {
    return ib.idxs[:ib.idx_pointer]
}

ib_clear::proc(ib: ^IndexBag) {
    ib.idx_pointer = 0
}

new_index_bag::proc(size: int) -> IndexBag {
    return IndexBag {
        make_slice([]int, size),
        0,
        ib_add,
        ib_get_all,
        ib_clear,
    }
}

destroy_index_bag::proc(ib: ^IndexBag) {
    delete(ib.idxs)
}

BarChart::struct {
    ch: chan.Chan(string),
    bars : []Bar,
    instructions: InstructionBag,
    highlight_idxs: IndexBag,
    move : proc(bb: ^BarChart, direction: int),
    delta_accum : f32, //below should be all zero init
    delta_mark : f32,
}

execute_instruction::proc(bb: ^BarChart) {
    //clear highlights
    bb.highlight_idxs.clear(&bb.highlight_idxs)

    //split the instruction
    cmd := bb.instructions.get(&bb.instructions)
    cmds := strings.split(cmd, " ")
    if cmds[0] == "C" {
        idx_a, _ := strconv.parse_int(cmds[1])
        bb.bars[idx_a].is_highlighted = true
        bb.highlight_idxs.add(&bb.highlight_idxs, idx_a)

        idx_b, _ := strconv.parse_int(cmds[2])
        bb.bars[idx_b].is_highlighted = true
        bb.highlight_idxs.add(&bb.highlight_idxs, idx_a)
    } else if cmds[0] == "S" {
        idx_a, _ := strconv.parse_int(cmds[1])
        bb.bars[idx_a].is_highlighted = true
        bb.highlight_idxs.add(&bb.highlight_idxs, idx_a)

        idx_b, _ := strconv.parse_int(cmds[2])
        bb.bars[idx_b].is_highlighted = true
        bb.highlight_idxs.add(&bb.highlight_idxs, idx_a)

        slice.swap(bb.bars, idx_a, idx_b)
        bb.bars[idx_a].r.x, bb.bars[idx_b].r.x = bb.bars[idx_b].r.x, bb.bars[idx_a].r.x
    } else if cmds[0] == "DONE" {
        for idx in bb.highlight_idxs.get_all(bb.highlight_idxs) {
            bb.bars[idx].is_highlighted = false
        }
    }
}

map_value_to_height::proc(val, min_val, max_val : f32) -> f32 {
    min_h, max_h : f32
    min_h = 20
    max_h = Globals.SCREEN_HEIGHT - 40

    if (min_val == max_val) {
        return min_val
    }
    norm := (val - min_val) / (max_val - min_val)
    return min_h + norm * (max_h - min_h)
}

generate_bars::proc(val_vec: []$T) -> ([]Bar, bool) 
where intrinsics.type_is_numeric(T) {
    bars := make_slice([]Bar, len(val_vec))

    bar_space := Globals.SCREEN_WIDTH / (len(val_vec) + 2)
    x, y : f32
    x = f32(bar_space)
    y = 20
    bar_width := f32(bar_space) * 0.8

    val_vec_max, ok := slice.max(val_vec)
    if !ok {
        return nil, false
    }
    val_vec_min, ok2 := slice.min(val_vec)
    if !ok2 {
        return nil, false
    }
    for v, idx in val_vec {
        bar_height := map_value_to_height(f32(v), f32(val_vec_min), f32(val_vec_max))
        bars[idx] = new_bar(x,y,bar_width,bar_height)
        x += f32(bar_space)
    }
    return bars, true
}

extract_initial_numbers::proc(instruction: string) -> ([]f32, bool) {
    vals := strings.split(instruction, ";")
    defer delete(vals)

    nums := make_slice([]f32, len(vals))

    for s, i in vals {
        val, ok := strconv.parse_f32(s)
        if !ok {
            fmt.printfln("BarChart: Failed to parse the zero instruction.")
            return make_slice([]f32, 0), false
        }
        nums[i] = val
    }
    return nums, true
}

bar_chart_move::proc(bb: ^BarChart, distance: int) {
    bb.instructions.move(&bb.instructions, distance)
}

bar_chart_draw::proc(bb: ^BarChart) {
    for &b in bb.bars {
        bar_update(&b)
    }
}

bar_chart_update::proc(bb: ^BarChart, delta_time: f32) {
    bb.delta_accum += delta_time
    bb.move(bb, 1)
    for {
        instruction, ok := chan.try_recv(bb.ch)
        if !ok {
            break
        }
        append(&bb.instructions.instructions, strings.clone(instruction))
    }
    if bb.delta_accum >= bb.delta_mark {
        bb.delta_accum = 0
        ok := bb.instructions.move(&bb.instructions, 1)
        if ok {
            execute_instruction(bb)
        }
    }
    bar_chart_draw(bb)
}

new_bar_chart::proc {
    new_bar_chart_vv,
    //new_bar_chart_file,
}

/*
BarChart::struct {
    bars : []Bar,
    instructions: InstructionBag,
    highlight_idxs: IndexBag,
    move : proc(bb: ^BarChart, direction: int),
    delta_accum : f32, //below should be all zero init
    delta_mark : f32,
}
*/

/*
//Handling the absence of channel???
new_bar_chart_file::proc(file_path: string) -> (BarChart, bool) {
    instructions, read_ok := Utils.read_lines_from_file(file_path)
    if !read_ok{
        fmt.printfln("Failed to create BarChart, due to reading of %v failing.", file_path)
        return BarChart{}, false
    }
    nums, init_ok := extract_initial_numbers(instructions[0])
    if !init_ok {
        fmt.println("Failed to create BarChart, cannot extract the initial values, possible instructions corruption.")
        return BarChart{}, false
    }
    bars, gen_ok := generate_bars(nums)
    if !gen_ok{
        fmt.println("Failed to create BarChart, bars cannot be generated from those values. Verify the first line of instructions.")
        return BarChart{}, false
    }
    bar_chart := BarChart {
        ch = 
        bars = bars,
        instructions = new_instruction_bag(),
        highlight_idxs = new_index_bag(5),
        move = bar_chart_move,
        delta_mark = 2,
    }
    return bar_chart, true
}
*/
new_bar_chart_vv::proc(visv: ^vv.VisualVector($T), algorithm: proc(t: ^thread.Thread)) -> (BarChart, bool) {
    instructions := new_instruction_bag()
    append(&instructions.instructions, visv.starting_state)
    nums, nums_ok := extract_initial_numbers(visv.starting_state)
    if !nums_ok {
        fmt.println("Failed to extract numbers from starting state.")
        return BarChart{}, false
    }
    bars, gen_ok := generate_bars(nums)
    if !gen_ok{
        fmt.println("Failed to create BarChart, bars cannot be generated from those values. Verify the first line of instructions.")
        return BarChart{}, false
    }
    algo_thread := thread.create(algorithm)
    algo_thread.user_args = visv
    thread.start(algo_thread)

    bar_chart := BarChart {
        bars = bars,
        instructions = instructions,
        highlight_idxs = new_index_bag(5),
        move = bar_chart_move,
        delta_mark = 2,
    }
    return bar_chart, true
}
