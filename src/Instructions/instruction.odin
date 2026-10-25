package instructions

import "core:fmt"

Instruction::union{
    vvCmp,
    vvSwap,
}

instruction_string::proc(self: Instruction) -> string {
    switch ins in self{
        case vvCmp:
            return fmt.aprintf("CMP %d %d", ins.idx_a, ins.idx_b)
        case vvSwap:
            return fmt.aprintf("SWP %d %d", ins.idx_a, ins.idx_b)
    }
    return ""
}
