package instructions

InstructionBag::struct {
    bag: [dynamic]Instruction,
    pointer: int,
    move_and_get: proc(self: ^InstructionBag, distance: int) -> (Instruction, bool),
}

instruction_bag_get::proc(self: ^InstructionBag) -> Instruction {
    return self.bag[self.pointer]
}

instruction_bag_move_and_get::proc(self: ^InstructionBag, distance: int) -> (Instruction, bool) {
    if len(self.bag) < 2 {
        return Instruction{}, false
    }
    self.pointer += distance
    if self.pointer < 1 {
        self.pointer = 1
        return Instruction{}, false
    }
    l := len(self.bag) 
    if self.pointer >= l {
        self.pointer = l-1
        return Instruction{}, false
    }
    return self.bag[self.pointer], true
}

instruction_bag_init::proc() -> InstructionBag { 
    return InstructionBag {
        pointer = 0,
        move_and_get = instruction_bag_move_and_get,
    }
}

instruction_bag_destroy::proc(self: InstructionBag) {
    delete(self.bag)
}
