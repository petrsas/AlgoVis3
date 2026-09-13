package main

import "core:fmt"
import "core:thread"
import vv "VisualVector"
import "Globals"
import bc "BarChart"
import rl "vendor:raylib"
import cam "Camera2DController"


BubbleSortOptimized::proc(t: ^thread.Thread) {
    //have to specify a type, unfortunate
    visv := cast(^vv.VisualVector(f32))t.user_args[0]
    n := visv.size(visv)

    if (n==0) {
        return
    } 
    for i:=0; i < n-0; i+=1 {
        swapped := false
        for j:=0; j < n-i-1; j+=1 {
            res, _ := visv.cmp(visv, j, j+1)
            if res > 0 {
                visv.swap(visv, j, j+1)
                swapped = true
            }
        }
        if !swapped {
            break
        }
    }
}

main::proc() {
    rl.InitWindow(Globals.SCREEN_WIDTH, Globals.SCREEN_HEIGHT, "Algo visualizer by Petr Chyla")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    camera2d := cam.new_camera_2d_controller()

/*
    arr := make([dynamic]int)
    append(&arr, 1,5,6,2,10,8,12)
    visv := vv.new_visual_vector(arr)
    BubbleSortOptimized(&visv)
    visv.store(&visv, Globals.FILE_PATH_INST)
*/
    dyn_arr := make_dynamic_array([dynamic]f32)
    append(&dyn_arr, 1,5,6,2,10,8,12)
    visv := vv.new_visual_vector(dyn_arr)
    defer vv.destroy_visual_vector(&visv)

    barc, _ := bc.new_bar_chart(&visv, BubbleSortOptimized)
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.BeginMode2D(camera2d.camera)
        rl.ClearBackground(rl.BLACK)
        cam.update_camera_2d_controller(&camera2d)
        bc.bar_chart_update(&barc, rl.GetFrameTime())
        rl.EndMode2D()
        rl.EndDrawing()
    }
}
