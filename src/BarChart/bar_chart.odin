package BarChart

import "core:strconv"
import "core:strings"
import "core:slice"
import "base:intrinsics"
import "core:log"

import vv "../VisualVector"
import "../Globals"
import con "../Connectors"
import i "../Instructions"


BarChart::struct {
    connector : con.Connector,
    bars : []Bar,
    instructions_bag: i.InstructionBag,
    high_bag: i.IndexBag,
    move : proc(self: ^BarChart, direction: int),
    delta_accum : f32, //below should be all zero init
    delta_mark : f32,
}

execute_instruction::proc(bb: ^BarChart, instruction: i.Instruction) {
    for i in bb.high_bag.get_all(&bb.high_bag) {
        bb.bars[i].is_highlighted = false
    }
    bb.high_bag.clear(&bb.high_bag)
    log.debug("Highligted instructions cleared...")

    //log.debugf("Instruction to be executed: %s", instruction)
    #partial switch cmd in instruction {
        case i.vvCmp:
            bb.bars[cmd.idx_a].is_highlighted = true
            bb.high_bag.add(&bb.high_bag, cmd.idx_a)
            bb.bars[cmd.idx_b].is_highlighted = true
            bb.high_bag.add(&bb.high_bag, cmd.idx_b)
        case i.vvSwap:
            bb.bars[cmd.idx_a].is_highlighted = true
            bb.bars[cmd.idx_b].is_highlighted = true

            slice.swap(bb.bars, cmd.idx_a, cmd.idx_b)
            bb.bars[cmd.idx_a].r.x, bb.bars[cmd.idx_b].r.x = bb.bars[cmd.idx_b].r.x, bb.bars[cmd.idx_a].r.x
        //DONE missing
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
    bb.instructions_bag.move_and_get(&bb.instructions_bag, distance)
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
            append(&bb.instructions_bag.bag, i)
        }
    }
    bb.delta_accum += delta_time

    if bb.delta_accum >= bb.delta_mark {
        log.debug("Delta marker passed!")
        bb.delta_accum = 0
        instr, ok := bb.instructions_bag.move_and_get(&bb.instructions_bag, 1)
        if ok {
            execute_instruction(bb, instr)
        }
    }
    bar_chart_draw(bb)
}

bar_chart_init::proc(visv: ^vv.VisualVector($T)) -> (BarChart, bool) {
    bars, gen_ok := generate_bars(visv.starting_state[:])
    if !gen_ok{
        log.fatal("While creating Bar Chart, failed to generate bars from values given in initial instruction.")
        return BarChart{}, false
    }

    vv.trigger_algorithm(visv)

    bar_chart := BarChart {
        connector = visv.connector,
        bars = bars,
        instructions_bag = i.instruction_bag_init(),
        high_bag = i.index_bag_init(5),
        move = bar_chart_move,
        delta_mark = 2,
    }
    return bar_chart, true
}
