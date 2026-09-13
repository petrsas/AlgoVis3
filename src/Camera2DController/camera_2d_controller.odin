package Camera2DController

import rl "vendor:raylib"
import "core:math"

Camera2DController::struct {
    camera: rl.Camera2D,
}

new_camera_2d_controller::proc() -> Camera2DController{
    cam := rl.Camera2D {0, 0, 0, 0}
    cam.zoom = 1
    return Camera2DController {
        camera = cam,
    }
}

//Rewrite from Raylib examples, 2d camera mouse zoom
update_camera_2d_controller::proc(c: ^Camera2DController) {
    if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
        delta := rl.GetMouseDelta()
        delta = delta * (-1/c.camera.zoom)
        c.camera.target = c.camera.target + delta 
    }
    wheel := rl.GetMouseWheelMove()
    if wheel != 0 {
        mouse_world_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), c.camera)
        c.camera.offset = rl.GetMousePosition()
        c.camera.target = mouse_world_pos

        scale := 0.2*wheel
        c.camera.zoom = rl.Clamp(math.exp_f32(math.log_f32(c.camera.zoom, math.E)+scale), 0.125, 64)
    }
}
