package system

import "core:fmt"
import SDL "vendor:sdl2"


is_key_down :: proc(game: ^Game, key: SDL.Scancode) -> bool {
	return game.keystate[key] != 0
}

is_key_pressed :: proc(game: ^Game, key: SDL.Scancode) -> bool {
	return game.last_key_pressed == key
}

is_key_released :: proc(game: ^Game, key: SDL.Scancode) -> bool {
	return game.last_key_released == key
}

