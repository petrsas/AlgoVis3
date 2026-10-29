package VisualGraph

import "core:strings"
import "core:fmt"
import "base:intrinsics"
import "core:thread"
import "core:log"

import "../Utils"
import "../Globals"
import conn "../Connectors"
import i "../Instructions/"

DoubleMap::struct($K, $V : typeid) {
    main: map[K]V,
    inversion: map[V]K,
    get_by_key: proc(self: DoubleMap($K, $V), key: K) -> (V, bool),
    get_by_value: proc(self: DoubleMap($K, $V), value: V) -> (K, bool),
    add: proc(self: DoubleMap($K, $V), key: K, value: V),
    remove_by_key: proc(self: DoubleMap($K, $V), key: K) -> bool,
    remove_by_value: proc(self: DoubleMap($K, $V), value: V) -> bool,
}

dm_get_by_key::proc(self: DoubleMap($K, $V), key: K) -> (V, bool) {
    if key in self.main {
        return self.main[key], true
    }
    return V{}, false
}

dm_get_by_value::proc(self: DoubleMap($K, $V), value: V) -> (K, bool) {
    if value in self.inversion {
        return self.inversion[value], true
    }
    return K{}, false
}

dm_add::proc(self: DoubleMap($K, $V), key: K, value: V) {
    self.main[key] = value
    self.inversion[value] = key
}

dm_remove_by_key::proc(self: DoubleMap($K, $V), key: K) -> bool {
    if key in self.main {
        value := self.main[key]
        delete_key(&self.main, key)
        delete_key(&self.inversion, value)
    }
    return false
}

dm_remove_by_value::proc(self: DoubleMap($K, $V), value: V) -> bool {
    if key in self.main {
        key := self.inversion[value]
        delete_key(&self.main, key)
        delete_key(&self.inversion, value)
    }
    return false
}

double_map_init::proc($K: typeid, $V: typeid) -> DoubleMap(K, V) {
    return DoubleMap {
        main = make(map[K]V),
        inversion = make(map[V]K),
        get_by_key = dm_get_by_key,
        get_by_value = dm_get_by_value,
        add = dm_add,
        remove_by_key = dm_remove_by_key,
        remove_by_value= dm_remove_by_value,
    }
}

VisualGraph::struct($T: typeid) 
where intrinsics.type_is_numeric(T)
    {
    last_idx: int,
    free_idxs: [dynamic]int,
    adj_matrix: [Globals.MAX_VERTS * Globals.MAX_VERTS]f32, //edges recording
    values: DoubleMap(T, int),
    sets: map[int]string, //idx of vertex and its set
    add_vertex: proc(self: ^VisualGraph($T), value: T, edges: map[T]f32, set: string, oriented: bool),
    add_edge: proc(self: ^VisualGraph($T), value: T, edges: map[T]f32, oriented: bool),
    remove_vertex: proc(self: ^VisualGraph($T), value: T),
    remove_edge: proc(self: ^VisualGraph($T), value: T, edges: map[T]f32, oriented: bool),
}

visual_graph_init::proc($T: typeid) -> VisualGraph(T) {
    return VisualGraph(T) {
        last_idx = -1, //for 0 idx
        free_idxs = make([dynamic]int),
        values = double_map_init(T, int),
        sets = make(map[int]string),
        add_vertex = vg_add_vertex,
        add_edge = vg_add_edge,
        remove_vertex = vg_remove_vertex,
        remove_edge = vg_remove_edge,
    }
}

//what value, its edges to other values and their cost, set to which the vertex belongs to, whether the edges are oriented
//ie. A -> B also means A <- B
vg_add_vertex::proc(self: ^VisualGraph($T), value: T, edges: map[T]f32, set: string, oriented: bool) {

    _, ok := self.values.get_by_key(self.values, value)
    if !ok {
        return
    }
    idx_to_add : int
    if len(self.free_idxs) > 0 {
        idx_to_add = self.free_idxs[0]
        unordered_remove(&self.free_idxs, 0)
    } else {
        idx_to_add = self.last_idx + 1
        self.last_idx += 1
    }
    self.values[value] = idx_to_add
    self.sets[idx_to_add] = set

    vg_add_edge(self, value, edges, oriented)

}

vg_add_edge::proc(self: ^VisualGraph($T), value: T, edges: map[T]f32, oriented: bool) {
    _, ok := self.values.get_by_key(self.values, value)
    if !ok {
        return
    }
    idx := self.values[value]
    row_len := Globals.MAX_VERTS 

    for val, w in edges {
        edge_idx, idx_ok := self.values.get_by_key(self.values, value)
        if !idx_ok {
            log.warnf("Skipped creationg edges for value: %v due to it not existing in visual graph.", val)
        }
        edge_idx := self.values[val]
        self.adj_matrix[row_len * idx + edge_idx] = w
        if !oriented {
            self.adj_matrix[row_len * edge_idx + idx] = w
        }
    }
}

vg_remove_vertex::proc(self: ^VisualGraph($T), value: T) {
    idx_to_remove, idx_ok := self.values.get_by_key(self.values, value)
    if !idx_ok {
        log.warnf("Cannot remove vertex of value %v due to it not existing", value)
        return
    }
    //clean all edges
    row_len := Globals.MAX_VERTS
    for i := 0; i <= self.last_idx; i += 1 {
        self.adj_matrix[row_len * idx_to_remove + i] = 0 //row clear
        self.adj_matrix[row_len * i + idx_to_remove] = 0 //col clear
    }
    //remove it from values and sets, also shrink the adj_matrix?
    delete_key(&self.sets, idx_to_remove)
    self.values.remove_by_key(self.values, value)
    append(&self.free_idxs, idx_to_remove)
}

vg_remove_edge::proc(self: ^VisualGraph($T), value: T, edges: []T, oriented: bool) {
    idx_to_clear, idx_ok := self.values.get_by_key(self.values, value)
    if !idx_ok {
        log.warnf("Cannot remove edges of that value: %v, due to this not existing", value)
    }
    row_len := Globals.MAX_VERTS
    for val in edges {
        if val in self.values {
            edge_idx := self.values[val]
            self.adj_matrix[row_len * idx_to_clear + edge_idx] = 0
            if !oriented {
                self.adj_matrix[row_len * edge_idx + idx_to_clear] = 0
            }
        }
    }
}

vg_modify_set::proc(self: ^VisualGraph($T), value: T, new_set: string) {
    idx, idx_ok := self.values.get_by_key(self.values, value)
    if !idx_ok {
        log.fatalf("Cannot modify set for this value: %v, due to it not existing", value)
        return
    }
    self.sets[idx] = new_set
}

//REWORK AND EXPANSION REQUIRED, ALSO CHECK ALL
//just gets the first value, got enough as a random entry point into the graph me thinks
vg_get_some::proc(self: ^VisualGraph($T)) -> (T, bool) {
    if len(self.values) > 0 {
        for key, val in self.values {
            return val, true
        }
    } 
    return 0, false
}

vg_get_neighbours::proc(self: ^VisualGraph($T), value: T) -> ([]T, bool) {
    if value in self.values {
        neighs := [dynamic]T
        row_len := Globals.MAX_VERTS
        //search the adj matrix for neighs?
        idx_main := self.values[value]
        for i:=0; i < self.last_idx; i+=1 {
            if self.adj_matrix[row_len * idx_main + i] != 0 {
                append(&neighs, )
            }
        }
    }
}
