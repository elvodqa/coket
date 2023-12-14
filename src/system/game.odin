package system


import "core:fmt"
import "core:c/libc"
import linalg "core:math/linalg/glsl"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"


Game :: struct {

    load: proc(),
    update: proc(game: ^Game, deltaTime: f32),
    render: proc(deltaTime: f32),
    exit: proc(),

    // events
    on_resize : proc(width: i32, height: i32),


	keystate: [^]u8,
	last_key_pressed: SDL.Scancode,
	last_key_released: SDL.Scancode,
}

new_game :: proc() -> Game {
    return Game{
        load= proc() {},
        update= proc(game: ^Game, deltaTime: f32) {},
        render= proc(deltaTime: f32) {},
        exit= proc() {},
		on_resize= proc(width: i32, height: i32) {},
    }
}

run_game :: proc(game: ^Game) {
    if err := SDL.Init({.VIDEO}); err != 0 {
		fmt.eprintln(err)
		return
	}
	defer SDL.Quit()

	window := SDL.CreateWindow("Game", SDL.WINDOWPOS_UNDEFINED, SDL.WINDOWPOS_UNDEFINED, 1400, 800, {.SHOWN, .RESIZABLE})
	if window == nil {
		fmt.eprintln(SDL.GetError())
		return
	}
	defer SDL.DestroyWindow(window)

	backend_idx: i32 = -1
	if n := SDL.GetNumRenderDrivers(); n <= 0 {
		fmt.eprintln("No render drivers available")
		return
	} else {
		for i in 0..<n {
			info: SDL.RendererInfo
			if err := SDL.GetRenderDriverInfo(i, &info); err == 0 {
				// NOTE(bill): "direct3d" seems to not work correctly
				if info.name == "opengl" {
					fmt.println("Opengl found")
					backend_idx = i
					break
				}
			}
		}
	}

	gl_context := SDL.GL_CreateContext(window)
	SDL.GL_MakeCurrent(window, gl_context)

	gl.load_up_to(4, 1, SDL.gl_set_proc_address)


	SDL.GL_SetAttribute(SDL.GLattr.CONTEXT_MAJOR_VERSION, 4)
	SDL.GL_SetAttribute(SDL.GLattr.CONTEXT_MINOR_VERSION, 1)
	SDL.GL_SetAttribute(SDL.GLattr.CONTEXT_PROFILE_MASK, cast(i32)SDL.GLprofile.CORE)
	SDL.GL_SetAttribute(SDL.GLattr.CONTEXT_FLAGS, cast(i32)SDL.GLcontextFlag.FORWARD_COMPATIBLE_FLAG)



    // refresh limit shit
	frameStart, frameTime: u32
    maxFPS :: 60

    // deltatime shit
    now := SDL.GetPerformanceCounter()
    last: u64 = 0
    localDelta: f32 = 0

    game.load()

	main_loop: for {
		frameStart = SDL.GetTicks()

        last = now
        now = SDL.GetPerformanceCounter()
        localDelta = f32( (now - last)*1000 ) / f32(SDL.GetPerformanceFrequency())

		game.last_key_pressed = nil
		game.last_key_released = nil
	
		for e: SDL.Event; SDL.PollEvent(&e); {
			#partial switch e.type {
			case .QUIT:
				break main_loop
            // resize
			case .WINDOWEVENT:
				if e.window.event == .RESIZED {
					w, h: i32
					SDL.GetWindowSize(window, &w, &h)
					game.on_resize(w, h)
				}
			case .KEYDOWN:
				if e.key.repeat == 0 { // Check if the event is a repeat
					game.last_key_pressed = e.key.keysym.scancode
				}
			// key up
			case .KEYUP:
				game.last_key_released = e.key.keysym.scancode
			}
			
			// input checking

		}
		
		game.keystate = SDL.GetKeyboardState(nil) 
		
        game.update(game, localDelta)
        game.render(localDelta)
		
		SDL.GL_SwapWindow(window)	

		frameTime = SDL.GetTicks() - frameStart
        if frameTime < 1000/maxFPS {
            SDL.Delay(1000/maxFPS - frameTime)
        }
		
	}
}
