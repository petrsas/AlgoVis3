package Utils

import "core:fmt"
import "core:os"
import "core:strings"
import "core:log"

append_multiple_lines_to_file::proc(lines: [dynamic]string, file_path: string) -> bool {
    b := strings.builder_make()
    defer strings.builder_destroy(&b)
    for l in lines {
        strings.write_string(&b, fmt.tprintln(l))
    }

    err := os.write_entire_file_from_string(file_path, strings.to_string(b))
    if err != nil {
        fmt.println("Failed to write into file: ", err)
        return false
    }
    return true
}

append_line_to_file::proc(line: string, file_path: string) -> bool {
    err := os.write_entire_file_from_string(file_path, line)
    if err != nil {
        log.errorf("Failed to write %s into file %s", line, file_path)
        return false
    }
    return true
}

write_lines_to_cleared_file::proc(lines: [dynamic]string, file_path: string) -> bool {
    b := strings.builder_make()
    defer strings.builder_destroy(&b)
    for l in lines {
        strings.write_string(&b, fmt.tprintln(l))
    }

    err := os.write_entire_file_from_string(file_path, strings.to_string(b), truncate = true)
    if err != nil {
        fmt.println("Failed to write into file: ", err)
        return false
    }
    return true
}

read_lines_from_file::proc(file_path: string, allocator := context.allocator) -> ([]string, bool) {
    data, err := os.read_entire_file_from_path(file_path, allocator) 
    if err != nil {
        fmt.println("Failed to read from file: ", err)
        return nil, false
    }
    //defer delete(data) //cannot be done, because split_str being a slice requires is as underlying data

    data_str := string(data)
    split_str, err2 := strings.split_lines_after(data_str, allocator)
    if err2 != nil {
        fmt.println("Data cannot be split: ", err2)
        return nil, false
    }
    return split_str, true
}
