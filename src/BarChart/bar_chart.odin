package BarChart

import "core:strconv"
import "core:strings"
import "core:slice"
import "core:fmt"
import "base:intrinsics"
import "core:thread"
import "core:sync"
import "core:sync/chan"
import "core:log"

import vv "../VisualVector"
import "../Globals"
import con "../Connectors"

InstructionBag::struct {
    instructions: [dynamic]string,
    instruction_pointer: int,
    move_and_get: proc(ib: ^InstructionBag, distance: int) -> (string, bool),
}

ib_get::proc(ib:^ InstructionBag) -> string {
    return ib.instructions[ib.instruction_pointer]
}

ib_move_and_get::proc(ib:^ InstructionBag, distance: int) -> (string, bool) {
    if len(ib.instructions) < 2 {
        return "", false
    }
    ib.instruction_pointer += distance
    if ib.instruction_pointer < 1 {
        ib.instruction_pointer = 1
        return "", false
    }
    l := len(ib.instructions) 
    if ib.instruction_pointer >= l {
        ib.instruction_pointer = l-1
        return "", false
    }
    return ib.instructions[ib.instruction_pointer], true
}

new_instruction_bag::proc() -> InstructionBag { 
    return InstructionBag {
        make([dynamic]string),
        0,
        ib_move_and_get,
    }
}

destory_instruction_bag::proc(ib: InstructionBag) {
    delete(ib.instructions)
}

IndexBag::struct {
    idxs: []int,
    idx_pointer: int,
    add: proc(ib: ^IndexBag, idx: int) -> bool,
    get_all: proc(ib: ^IndexBag) -> []int,
    clear: proc(ib: ^IndexBag),
}

ib_add::proc(ib: ^IndexBag, idx: int) -> bool {
    if ib.idx_pointer >= len(ib.idxs) {
        return false
    }
    ib.idxs[ib.idx_pointer] = idx
    ib.idx_pointer += 1
    return true
}

ib_get_all :: proc(ib: ^IndexBag) -> []int {
    if ib.idx_pointer < 0 || len(ib.idxs) == 0 {
        return ib.idxs[:0]
    }
    return ib.idxs[:ib.idx_pointer + 1]
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
    connector : con.Connector,
    bars : []Bar,
    instructions: InstructionBag,
    highlight_idxs: IndexBag,
    move : proc(bb: ^BarChart, direction: int),
    delta_accum : f32, //below should be all zero init
    delta_mark : f32,
}

execute_instruction::proc(bb: ^BarChart, instruction: string) {
    //clear highlights, BUGGED: fails to clear completely
    for i in bb.highlight_idxs.get_all(&bb.highlight_idxs) {
        bb.bars[i].is_highlighted = false
    }
    bb.highlight_idxs.clear(&bb.highlight_idxs)
    log.debug("Highligted instructions cleared...")

    //split the instruction
    log.debugf("Instruction to be executed: %s", instruction)
    cmds, err := strings.split(instruction, " ")
    if err != .None {
        log.fatal("Failed to split command.")
    }
    if cmds[0] == "C" {
        idx_a, ok_a := strconv.parse_int(cmds[1])
        if !ok_a {
            log.fatal("Failed to parse index a for comparison command.")
        }
        bb.bars[idx_a].is_highlighted = true
        bb.highlight_idxs.add(&bb.highlight_idxs, idx_a)

        idx_b, ok_b := strconv.parse_int(cmds[2])
        if !ok_b {
            log.fatal("Failed to parse index b for comparison command.")
        }
        bb.bars[idx_b].is_highlighted = true
        bb.highlight_idxs.add(&bb.highlight_idxs, idx_a)

    } else if cmds[0] == "S" {
        idx_a, ok_a := strconv.parse_int(cmds[1])
        if !ok_a {
            log.fatal("Failed to parse index a for comparison command.")
        }
        bb.bars[idx_a].is_highlighted = true
        bb.highlight_idxs.add(&bb.highlight_idxs, idx_a)

        idx_b, ok_b := strconv.parse_int(cmds[2])
        if !ok_b {
            log.fatal("Failed to parse index b for comparison command.")
        }
        bb.bars[idx_b].is_highlighted = true
        bb.highlight_idxs.add(&bb.highlight_idxs, idx_a)

        slice.swap(bb.bars, idx_a, idx_b)
        bb.bars[idx_a].r.x, bb.bars[idx_b].r.x = bb.bars[idx_b].r.x, bb.bars[idx_a].r.x

    } else if cmds[0] == "DONE" {
        for idx in bb.highlight_idxs.get_all(&bb.highlight_idxs) {
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
    bar_space := Globals.SCREEN_WIDTH / (len(val_vec) + 2)
    x, y : f32
    x = f32(bar_space)
    y = 20
    bar_width := f32(bar_space) * 0.8

    val_vec_max, ok := slice.max(val_vec)
    if !ok {
        log.errorf("While creating Bar Chart, failed to get the max value while generating bars.")
        return make_slice([]Bar, 0), false
    }
    val_vec_min, ok2 := slice.min(val_vec)
    if !ok2 {
        log.errorf("While creating Bar Chart, failed to get the min value while generating bars.")
        return make_slice([]Bar, 0), false
    }

    bars, err := make_slice([]Bar, len(val_vec))
    if err != .None {
        log.errorf("While creating Bar Chart, failed to create slice for Bars: ", err)
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
            log.error("While creating Bar Chart, failed to parse the initial instruction.")
            return make_slice([]f32, 0), false
        }
        log.debugf("Extracted initial number: %v", val)
        nums[i] = val
    }
    return nums, true
}

bar_chart_move::proc(bb: ^BarChart, distance: int) {
    bb.instructions.move_and_get(&bb.instructions, distance)
}

bar_chart_draw::proc(bb: ^BarChart) {
    for &b in bb.bars {
        bar_update(&b)
    }
}

bar_chart_update::proc(bb: ^BarChart, delta_time: f32) {
    instructions, ok := con.receive_instructions(&bb.connector)
    if ok {
        for i in instructions {
            append(&bb.instructions.instructions, strings.clone(i))
        }
    }
        //delete(instruction), crashes my program, should not be needed anyawy, since I use tprintf to create it
    bb.delta_accum += delta_time

    if bb.delta_accum >= bb.delta_mark {
        log.debug("Delta marker passed!")
        bb.delta_accum = 0
        instr, ok := bb.instructions.move_and_get(&bb.instructions, 1)
        if ok {
            execute_instruction(bb, instr)
        }
    }
    bar_chart_draw(bb)
}

new_bar_chart::proc(visv: ^vv.VisualVector($T), algorithm: proc(t: ^thread.Thread)) -> (BarChart, bool) {
    instructions := new_instruction_bag()
    append(&instructions.instructions, visv.starting_state)
    log.debugf("Starting state from visv: %s", visv.starting_state)
    nums, nums_ok := extract_initial_numbers(visv.starting_state)
    if !nums_ok {
        log.fatal("While creating Bar Chart, failed to parse the initial instruction.")
        return BarChart{}, false
    }
    bars, gen_ok := generate_bars(nums)
    if !gen_ok{
        log.fatal("While creating Bar Chart, failed to generate bars from values given in initial instruction.")
        return BarChart{}, false
    }
    algo_thread := thread.create(algorithm)
    if algo_thread == nil {
        log.fatal("Failed to create the algo thread.")
    }
    algo_thread.init_context = context
    algo_thread.user_args = visv
    thread.start(algo_thread) //no returns. Will panic on its own 

    bar_chart := BarChart {
        connector = visv.connector,
        bars = bars,
        instructions = instructions,
        highlight_idxs = new_index_bag(5),
        move = bar_chart_move,
        delta_mark = 2,
    }
    return bar_chart, true
}
