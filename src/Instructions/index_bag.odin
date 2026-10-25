package instructions

IndexBag::struct {
    bag: []int,
    pointer: int,
    add: proc(self: ^IndexBag, idx: int) -> bool,
    get_all: proc(self: ^IndexBag) -> []int,
    clear: proc(self: ^IndexBag),
}

ib_add::proc(self: ^IndexBag, idx: int) -> bool {
    if self.pointer >= len(self.bag) {
        return false
    }
    self.bag[self.pointer] = idx
    self.pointer += 1
    return true
}

ib_get_all :: proc(self: ^IndexBag) -> []int {
    if self.pointer < 0 || len(self.bag) == 0 {
        return self.bag[:0]
    }
    return self.bag[:self.pointer + 1]
}

ib_clear::proc(self: ^IndexBag) {
    self.pointer = 0
}

index_bag_init::proc(size: int) -> IndexBag {
    return IndexBag {
        make_slice([]int, size),
        0,
        ib_add,
        ib_get_all,
        ib_clear,
    }
}

index_bag_destroy::proc(self: ^IndexBag) {
    delete(self.bag)
}
