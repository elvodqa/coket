package main

import "core:fmt"

import "gfx"
import "system"

import SDL "vendor:sdl2"


texture: gfx.Texture
spritebatch: gfx.SpriteBatch

main :: proc() {
	using system

	game := new_game()
	game.load = load
	game.update = update
	game.render = render
	game.on_resize = resized
	// sexaaaadsf
	run_game(&game)

}

load :: proc() {
	texture = gfx.load_texture("assets/plank.jpeg")
	spritebatch = gfx.init()
}

update :: proc(game: ^system.Game, dt: f32) {
	if system.is_key_down(game, SDL.SCANCODE_A) {
		fmt.printf("A is down\n")
	}
	if system.is_key_pressed(game, SDL.SCANCODE_B) {
		fmt.printf("B was pressed\n")
	}
	if system.is_key_released(game, SDL.SCANCODE_C) {
		fmt.printf("C was released\n")
	}
}

render :: proc(dt: f32) {
	gfx.clear_screen({0.0, 0.0, 1.0, 1.0})

	gfx.batch_begin(&spritebatch)
	gfx.batch_draw_texture(&spritebatch, texture, {0.0, 0.0}, {100, 100}, {1, 1, 1, 1})
	gfx.batch_end(&spritebatch)

}

resized :: proc(width: i32, height: i32) {
	fmt.printf("Resized to %d, %d\n", width, height)
}