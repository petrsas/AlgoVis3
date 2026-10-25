package Connectors

import "core:sync/chan"
import "core:log"

import i "../Instructions/"
import "../Utils"


//Message broker
Connector::struct {
    ch : chan.Chan(i.Instruction),
    logging: bool,
    log_path: string,
}

connector_init::proc(logging: bool, log_path: string) -> Connector {
    ch, err := chan.create(chan.Chan(i.Instruction), context.allocator)
    if err != .None {
        log.fatalf("Failed to create a channel: %v", err)
    }
    return Connector {
        ch = ch,
        logging = logging,
        log_path = log_path,
    }
} 

connector_destroy::proc(conn: ^Connector) {
    chan.close(conn.ch)
    chan.destroy(conn.ch)
}

send_instruction::proc(conn: ^Connector, instruction: i.Instruction) {
    chan.send(conn.ch, instruction)
    if conn.logging {
        Utils.append_line_to_file(i.instruction_string(instruction), conn.log_path)
    }
}

receive_instructions::proc(conn: ^Connector) -> ([]i.Instruction, bool) {
    instructions := make_dynamic_array([dynamic]i.Instruction)
        for {
            instruction, ok := chan.try_recv(conn.ch)
            if !ok {
                //log.debugf("Failed to receive an instruction. Breaking.")
                break
            }
            append(&instructions, instruction)
        }
        if len(instructions) <= 0 {
            return instructions[:], false
        }
    return instructions[:], true
}
