package Connectors

import "core:sync"
import "core:sync/chan"
import "core:strings"
import "core:log"
import "../Utils"

Connector::union {
    ChannelConnector,
    FileConnector,
}

FileConnector::struct {
    file_path : string,
    all_read : bool,
    file_mutex : sync.Mutex,
}

ChannelConnector::struct {
    ch : chan.Chan(string),
}

new_channel_connector::proc() -> ChannelConnector {
    chan, err := chan.create(chan.Chan(string), context.allocator)
    if err != .None {
        log.fatalf("Failed to create a channel: %v", err)
    }
    return ChannelConnector{
        ch = chan,
    }
}

new_file_connector::proc(file_path: string) -> FileConnector {
    return FileConnector {
       file_path = file_path,
       all_read = false,
    }
}

destroy_channel_connector::proc(cc: ^ChannelConnector) {
    chan.close(cc.ch)
    chan.destroy(cc.ch)
}

send_instruction::proc(con: ^Connector, instruction: string) {
    switch &c in con { //& so that I can modify flags
        case ChannelConnector:
            chan.send(c.ch, instruction)
        case FileConnector:
            log.debug("Sending instruction...")
            sync.mutex_lock(&c.file_mutex)
            log.debug("Locked the file for appending...")
            Utils.append_line_to_file(instruction, c.file_path)
            sync.mutex_unlock(&c.file_mutex)
            log.debug("Appended and unlocked the file")
            sync.atomic_store(&c.all_read, false)
    }
}

receive_instructions::proc(con: ^Connector) -> ([]string, bool) {
    switch &c in con {
        case ChannelConnector:
            instructions := make_dynamic_array([dynamic]string)
            for {
                instruction, ok := chan.try_recv(c.ch)
                if !ok {
                    //log.debugf("Failed to receive an instruction. Breaking.")
                    break
                }
                append(&instructions, strings.clone(instruction))
            }
            if len(instructions) <= 0 {
                return instructions[:], false
            }
            return instructions[:], true
        case FileConnector:
            if sync.atomic_load(&c.all_read) {
                if sync.mutex_try_lock(&c.file_mutex) {
                    log.debug("Locked for reading...")
                    instructions, ok := Utils.read_lines_from_file(c.file_path)
                    if ok {
                        sync.mutex_unlock(&c.file_mutex)
                        log.debug("Unlocking reading...")
                        sync.atomic_store(&c.all_read, true)
                        return instructions, ok
                    }
                    sync.mutex_unlock(&c.file_mutex)
                    log.debug("Unlocking reading...")
                }
            } 
    }
    return []string{}, false
}
