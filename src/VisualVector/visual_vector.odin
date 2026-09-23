package VisualVector

import "core:strings"
import "core:fmt"
import "base:intrinsics"
import "core:thread"
import "../Utils"
import "../Globals"
import con "../Connectors"

VisualVector::struct($T: typeid) 
where intrinsics.type_is_numeric(T){
    arr : [dynamic]T,
    size : proc(vv: ^VisualVector(T)) -> int,
    connector : con.Connector,
    starting_state : string,
    swap : proc(vv: ^VisualVector(T), idx_a, idx_b : int) -> bool,
    cmp : proc(vv: ^VisualVector(T), idx_a, idx_b : int) -> (T, bool),
}

vv_size::proc(vv: ^VisualVector($T)) -> int {
    return len(vv.arr)
}

vv_swap::proc(vv: ^VisualVector($T), idx_a, idx_b : int) -> bool {
    if idx_a < 0 || idx_a >= len(vv.arr) || idx_b < 0 || idx_b >= len(vv.arr) {
        return false
    }
    vv.arr[idx_a], vv.arr[idx_b] = vv.arr[idx_b], vv.arr[idx_a]
    con.send_instruction(&vv.connector, fmt.tprintf("S %d %d", idx_a, idx_b))
    return true
} 

//0 > if a > b
//0 < if a < b
//0 if a == b
//false if error
vv_cmp::proc(vv: ^VisualVector($T), idx_a, idx_b : int) -> (T, bool) {
    if idx_a < 0 || idx_a >= len(vv.arr) || idx_b < 0 || idx_b >= len(vv.arr) {
        return 0, false
    }
    con.send_instruction(&vv.connector, fmt.tprintf("C %d %d", idx_a, idx_b))
    return vv.arr[idx_a] - vv.arr[idx_b], true
}

new_visual_vector::proc(arr: [dynamic]$T) -> VisualVector(T) {
    //storing starting state
    b: strings.Builder
    strings.builder_init(&b)
    defer strings.builder_destroy(&b)

    last_elem := len(arr) - 1

    for i:=0; i<last_elem; i+=1 {
        fmt.sbprintf(&b, "%v;", arr[i])
    }
    fmt.sbprintf(&b, "%v", arr[last_elem])

    return {
        connector = con.new_channel_connector(),
        arr = arr,
        starting_state = strings.clone(strings.to_string(b)),
        size = vv_size,
        swap = vv_swap,
        cmp = vv_cmp,
    }
}

new_visual_vector_logging::proc(arr: [dynamic]$T, file_path: string) -> VisualVector(T) {
    //storing starting state
    b: strings.Builder
    strings.builder_init(&b)
    defer strings.builder_destroy(&b)

    last_elem := len(arr) - 1

    for i:=0; i<last_elem; i+=1 {
        fmt.sbprintf(&b, "%v;", arr[i])
    }
    fmt.sbprintf(&b, "%v", arr[last_elem])

    return {
        connector = con.new_file_connector(file_path),
        arr = arr,
        starting_state = strings.clone(strings.to_string(b)),
        size = vv_size,
        swap = vv_swap,
        cmp = vv_cmp,
    }
}

destroy_visual_vector :: proc(vv: ^VisualVector($T)) {
    delete(vv.arr)
}
