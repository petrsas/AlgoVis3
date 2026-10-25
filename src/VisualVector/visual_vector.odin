package VisualVector

import "core:strings"
import "core:fmt"
import "base:intrinsics"
import "core:thread"
import "core:log"

import "../Utils"
import "../Globals"
import conn "../Connectors"
import i "../Instructions/"

VisualVector::struct($T: typeid) 
where intrinsics.type_is_numeric(T){
    arr : [dynamic]T,
    connector : conn.Connector,
    algorithm : proc(vv: ^VisualVector(T)),
    starting_state : [dynamic]T,
    size : proc(self: ^VisualVector(T)) -> int,
    swap : proc(self: ^VisualVector(T), idx_a, idx_b : int) -> bool,
    cmp : proc(self: ^VisualVector(T), idx_a, idx_b : int) -> (T, bool),
}

vv_size::proc(self: ^VisualVector($T)) -> int {
    return len(self.arr)
}

vv_swap::proc(self: ^VisualVector($T), idx_a, idx_b : int) -> bool {
    if idx_a < 0 || idx_a >= len(self.arr) || idx_b < 0 || idx_b >= len(self.arr) {
        return false
    }
    self.arr[idx_a], self.arr[idx_b] = self.arr[idx_b], self.arr[idx_a]
    conn.send_instruction(&self.connector, i.vvSwap{idx_a, idx_b})
    return true
} 

//0 > if a > b
//0 < if a < b
//0 if a == b
//false if error
vv_cmp::proc(self: ^VisualVector($T), idx_a, idx_b : int) -> (T, bool) {
    if idx_a < 0 || idx_a >= len(self.arr) || idx_b < 0 || idx_b >= len(self.arr) {
        return 0, false
    }
    conn.send_instruction(&self.connector, i.vvCmp{idx_a, idx_b})
    return self.arr[idx_a] - self.arr[idx_b], true
}

visual_vector_init::proc(array: [dynamic]$T, algorithm: proc(vv: ^VisualVector(T))) -> VisualVector(T) {
    return {
        connector = conn.connector_init(false, ""),
        arr = array,
        starting_state = array,
        algorithm = algorithm,
        size = vv_size,
        swap = vv_swap,
        cmp = vv_cmp,
    }
}

visual_vector_init_logging::proc(array: [dynamic]$T, algorithm: proc(visv: ^VisualVector(T)), logging_path: string) -> VisualVector(T) {
    return {
        connector = conn.connector_init(true, logging_path),
        arr = array,
        starting_state = array,
        algorithm = algorithm,
        size = vv_size,
        swap = vv_swap,
        cmp = vv_cmp,
    }
}

thread_worker::proc($T: typeid) -> proc(self: ^VisualVector(T)) {
    return proc(self: ^VisualVector(T)) {
        if self.algorithm != nil {
            self.algorithm(self)
        }
    }
}

trigger_algorithm::proc(self: ^VisualVector($T)) {
    handle := thread.create_and_start_with_poly_data(self, thread_worker(T))
    if handle == nil {
        log.fatal("Failed to launch the algorithm in a seperate thread.")
    }
}

visual_vector_destroy :: proc(self: ^VisualVector($T)) {
    conn.connector_destroy(&self.connector)
    delete(self.arr)
}
