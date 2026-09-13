package VisualVector

import "core:strings"
import "core:fmt"
import "base:intrinsics"
import "core:thread"
import "core:sync/chan"
import "../Utils/"
import "../Globals/"

VisualVector::struct($T: typeid) 
where intrinsics.type_is_numeric(T){
    arr : [dynamic]T,
    size : proc(vv: ^VisualVector(T)) -> int,
    ch : chan.Chan(string),
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
    chan.send(vv.ch, fmt.tprintf("S %d %d", idx_a, idx_b))
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
    chan.send(vv.ch, fmt.tprintf("C %d %d", idx_a, idx_b))
    return vv.arr[idx_a] - vv.arr[idx_b], true
}

new_visual_vector::proc(arr: [dynamic]$T) -> VisualVector(T) {
    //creating a channel
    ch, err := chan.create(chan.Chan(string), context.allocator)
    if err != .None  {
        fmt.println("Failed to create a channel")
        return VisualVector(T){}
    }
    //logging starting state
    b: strings.Builder
    strings.builder_init(&b)
    defer strings.builder_destroy(&b)

    last_elem := len(arr) - 1

    for i:=0; i<last_elem; i+=1 {
        fmt.sbprintf(&b, "%v;", arr[i])
    }
    fmt.sbprintf(&b, "%v", arr[last_elem])

    return {
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
