package gamejam

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/rand"

import rl "vendor:raylib"

DEBUG_TEXTURES :: false

Platform :: struct {
	using pos: [2]f32,
	width: f32,
	thickness: f32,
}

RUN_SPEED :: 800
JUMP_SPEED :: 1700
GRAVITY :: 8000
IFRAMES :: 5

Entity_Flag :: enum {
	Null_Entity,
	Will_Jump_On_Touching_Ground,
	No_Physics,
	On_Ground,
	Consumed_Double_Jump,
	Enemy,
	Got_Hit,
	Slamming_Down,
}

Entity_Kind :: enum {
	Removed,
	Rectangle,
	Circle,
	Test_Samurai,
	Knight,
	Big_Knight,
	Archer,
	Samurai,
	Unlock_Big_Knight,
	Finish_Game,
}

Face_Direction :: enum {
	Right,
	Left,
}

Attack :: enum {
	None,
	Basic,
	Walk,
	Dash,
	Dead,
	Defend,
	Pray_Respects,
	Slam,
}

AI_State :: enum {
	Idle,
	Approaching,
	Attacking,
}

AI_Parameters :: struct {
	view_distance: f32,
	attack_distance: f32,
}

Entity :: struct {
	using pos: [2]f32,
	vel: [2]f32,
	size: [2]f32,
	kind: Entity_Kind,
	flags: bit_set[Entity_Flag],
	animation_start_number: int,
	facing_direction: Face_Direction,

	current_attack: Attack,
	attack_began_number: int,
	dash_began_pos: [2]f32,
	// player is invincible for 0.3ms
	dash_began_number: int,
	health: f32,
	ground_height: f32,
	ai_state: AI_State,
	ai_params: AI_Parameters,
	ai_next_attack_frame_number: int,

	last_got_hit_on: int,
	attack_power: f32,
}

entity_rect :: proc(e: Entity) -> rl.Rectangle {
	return {
		x = e.pos.x - e.size.x / 2,
		y = e.pos.y - e.size.y / 2,
		width = e.size.x,
		height = e.size.y,
	}
}

////////// Texture loading and drawing
sound_collection: map[string]rl.Sound

load_sound :: proc(path: string) -> rl.Sound {
	ensure(path != "")
	if sound, ok := sound_collection[path]; ok {
		return sound
	} else {
		sound := rl.LoadSound(strings.clone_to_cstring(path, context.temp_allocator))
		ensure(rl.IsSoundValid(sound))
		sound_collection[path] = sound
		return sound
	}
}

////////// Texture loading and drawing
texture_collection: map[string]rl.Texture

load_texture :: proc(path: string) -> rl.Texture {
	ensure(path != "")
	if texture, ok := texture_collection[path]; ok {
		return texture
	} else {
		texture := rl.LoadTexture(strings.clone_to_cstring(path, context.temp_allocator))
		ensure(rl.IsTextureValid(texture))
		texture_collection[path] = texture
		return texture
	}
}

Texture :: struct {
	path: string,
	divisions: int,
	offset: [2]f32,
	scale: f32,
}

draw_texture :: proc(texture: Texture, index: int, dest: [4]f32, direction: Face_Direction = .Right, tint: rl.Color = rl.WHITE) {
	loaded_texture := load_texture(texture.path)

	width, height := f32(loaded_texture.width), f32(loaded_texture.height)

	piece_width := width / f32(texture.divisions)
	piece_x := piece_width * f32(index)
	src := rl.Rectangle{piece_x, 0, piece_width, height}
	scaled_dest := dest
	scaled_dest.zw *= texture.scale
	scaled_dest.z *= 1.5

	rotation: f32

	if direction == .Left {
		src.width *= -1
	}

	rl.DrawTexturePro(loaded_texture, src, rl.Rectangle{**scaled_dest}, texture.offset + scaled_dest.zw / 2, 0, tint)
	when DEBUG_TEXTURES {
		rl.DrawRectangleLines(**cast([2]i32)(dest.xy - texture.offset - dest.zw / 2), **cast([2]i32)dest.zw, rl.RED)
		rl.DrawRectangleLines(**cast([2]i32)(scaled_dest.xy - texture.offset - scaled_dest.zw / 2), **cast([2]i32)scaled_dest.zw, rl.GREEN)
	}
}

entities: [dynamic]Entity
interactive_entities: [dynamic]int
particles: [dynamic]Particle

frame_number: int

begin_attack :: proc(e: int, attack: Attack) {
	entities[e].current_attack = attack
	entities[e].attack_began_number = frame_number
	entities[e].animation_start_number = frame_number
}

Level :: struct {
	background: rl.Texture,
	enemies: []Entity,
	max_at_a_time: int,
	already_defeated: int,
}

Particle :: struct {
	using pos: [2]f32,
	size: [2]f32,
	texture: Texture,
	started_on: int,
	lifetime: int,
}

spawn_particle :: proc(texture: Texture, pos: [2]f32, size: [2]f32, lifetime: int) {
	append (&particles, Particle{
		pos = pos,
		texture = texture,
		size = size,
		lifetime = lifetime,
		started_on = frame_number,
	})
}

make_samurai :: proc(pos: [2]f32) -> Entity{
	return {
		kind = .Samurai,
		pos = pos,
		vel = {0, 0},
		size = {100, 200},
		health = 100,
		flags = {.Enemy},
		attack_power = 5,
		ai_params = {
			view_distance = 1000,
			attack_distance = 30,
		}
	}
}

Game_State :: enum {
	Starting1,
	Starting2,
	Game,
	Ending,
}

STARTING_MESSAGE := """
Far from his ancestral halls, a knight ventured
into distant lands,

seeking to prove his worth and earn the honours
befitting his name.

Through trials and countless battles,
he pursued the glory that would complete his banner,

and the day he might return before his sovereign.
"""

STARTING_MESSAGE2 := """
Yet, whilst he wandered, his homeland fell to ruin.

Its walls were broken, its banners silenced,
and its people scattered to the winds.

Unbeknownst to him, the kingdom he had sworn
to serve was no longer as he had left it.

And at last, with banner in hand, the knight
returned home.
"""

ENDING_MESSAGE := """
The throne stands empty.

The kingdom lies in ashes.

Those who once stood in its defense are gone.

And before the throne of his fallen king,

the knight kneels.

His banner bears no glory. Only remembrance.
"""

////////// Main function
main :: proc() {
	unlocked_entities := bit_set[Entity_Kind]{.Knight}
	unlocked_entities |= {.Big_Knight}

	rl.InitWindow(1200, 800, "Gamejam demo")
	defer rl.CloseWindow()

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	rl.SetTargetFPS(60)

	window_size := [2]f32{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

	player := len(entities)
	append(&entities, {
		kind = .Knight,
		pos = {0, 0},
		vel = {0, 0},
		size = {100, 200},
		health = 100,
		attack_power = 20,
	})

	// append(&interactive_entities, len(entities))
	// append(&entities, {
	// 	kind = .Unlock_Big_Knight,
	// 	pos = {800, -50},
	// 	vel = {0, 0},
	// 	size = {100, 100},
	// 	flags = {.No_Physics}
	// })

	platforms := []Platform{
		{
			pos = {0, 200},
			width = 10000,
			thickness = 30,
		}
	}

	current_level := 0
	levels := []Level {
		{
			background = load_texture("./Scenes/Forest.png"),
			enemies = {
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
			},
			max_at_a_time = 2,
		},
		{
			background = load_texture("./Scenes/Graveyard.png"),
			enemies = {
				{
					kind = .Unlock_Big_Knight,
					pos = {90, 0},
					vel = {0, 0},
					size = {500, 500},
					flags = {.No_Physics}
				},
			},
			max_at_a_time = 2,
		},
		{
			background = load_texture("./Scenes/Cemetary.png"),
			enemies = {
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
			},
			max_at_a_time = 3,
		},
		{
			background = load_texture("./Scenes/CastleHallWay.png"),
			enemies = {
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
				make_samurai({1000, 0}),
				// make_samurai({1000, 0}),
				// make_samurai({1000, 0}),
				// make_samurai({1000, 0}),
				// make_samurai({1000, 0}),
				// make_samurai({1000, 0}),
				// make_samurai({1000, 0}),
				// make_samurai({1000, 0}),
				// make_samurai({1000, 0}),
				// make_samurai({1000, 0}),
				// make_samurai({1000, 0}),
			},
			max_at_a_time = 4,
		},
		{
			background = load_texture("./Throne.png"),
			enemies = {
				{
					kind = .Finish_Game,
					pos = {90, 0},
					vel = {0, 0},
					size = {500, 500},
					flags = {.No_Physics}
				},
			},
			max_at_a_time = 100,
		},
	}

	bgm_music := rl.LoadMusicStream("./BGMusic.mp3")
	rl.PlayMusicStream(bgm_music)

	shield_sound := load_sound("shield.ogg")
	groundslam_sound := load_sound("GroundSlam.mp3")

	trigger_slam: bool
	finished_game: bool
	game_state: Game_State
	state_reached_at: int
	for !rl.WindowShouldClose() {
		message: cstring
		level := &levels[current_level]

		rl.UpdateMusicStream(bgm_music)

		dt := rl.GetFrameTime()
		window_size := [2]f32{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
		camera := rl.Camera2D{
			offset = window_size / 2,
			zoom = 0.5,
		}

		frame_number = int(rl.GetTime() / 0.1)

		player_rect := entity_rect(entities[player])
		enemy_count := len(entities) - 1
		if game_state == .Game {
			if frame_number % 10 == 0 {
				if enemy_count < level.max_at_a_time {
					next_enemy_index := enemy_count + level.already_defeated
					if next_enemy_index < len(level.enemies) {
						next_enemy := level.enemies[next_enemy_index]
						next_enemy.pos.x += rand.float32_range(-100, 100)
						append(&entities, next_enemy)
					}
				}
			}
		}

		if entities[player].last_got_hit_on + 20 < frame_number {
			if entities[player].health < 100 {
				entities[player].health += 0.1
			}
		}

		almost_on_ground: bool
		for plat in platforms {
			for &ent, ent_id in entities {
				TOLERENCE :: 1
				JUMP_BUFFER :: 100
				platform_rect := rl.Rectangle{
					x = plat.pos.x - plat.width / 2 - TOLERENCE,
					y = plat.y - TOLERENCE,
					width = plat.width + 2 * TOLERENCE,
					height = plat.thickness + 2 * TOLERENCE,
				}
				if rl.CheckCollisionRecs(platform_rect, entity_rect(ent)) {
					ent.flags |= {.On_Ground}
					ent.ground_height = plat.y
				} else {
					ent.flags &~= {.On_Ground}
				}
				buffer_rect := platform_rect
				buffer_rect.y -= JUMP_BUFFER
				buffer_rect.height += JUMP_BUFFER
				if ent_id == player && rl.CheckCollisionRecs(buffer_rect, player_rect) {
					almost_on_ground = true
				}
			}
		}

		////////// Controls
		if rl.IsKeyDown(.D) && entities[player].current_attack != .Dash {
			entities[player].pos.x += RUN_SPEED * dt
			entities[player].facing_direction = .Right
			entities[player].current_attack = .Walk
		}
		if rl.IsKeyDown(.A) && entities[player].current_attack != .Dash {
			entities[player].pos.x -= RUN_SPEED * dt
			entities[player].facing_direction = .Left
			entities[player].current_attack = .Walk
		}
		if (rl.IsKeyUp(.A) && rl.IsKeyUp(.D)) && entities[player].current_attack == .Walk {
			entities[player].current_attack = .None
		}
		if rl.IsKeyPressed(.E) {
			begin_attack(player, .Dash)
		}

		if rl.IsMouseButtonDown(.LEFT) && entities[player].current_attack == .None {
			begin_attack(player, .Basic)
		}
		#partial switch entities[player].kind {
		case .Big_Knight:
			if rl.IsMouseButtonPressed(.RIGHT) && entities[player].current_attack == .None {
				entities[player].flags &~= {.Slamming_Down}
				begin_attack(player, .Slam)
			}
		case .Knight:
			if rl.IsMouseButtonPressed(.RIGHT) && entities[player].current_attack == .None {
				begin_attack(player, .Defend)
			}
		}

		if rl.IsKeyPressed(.C) && entities[player].current_attack == .None {
			if entities[player].kind == .Knight {
				if .Big_Knight in unlocked_entities {
					entities[player].kind = .Big_Knight
				}
			} else {
				entities[player].kind = .Knight
			}
		}

		first_jump_p := rl.IsKeyPressed(.SPACE) && .On_Ground in entities[player].flags
		if first_jump_p {
			entities[player].flags &~= {.Consumed_Double_Jump}
		}
		if rl.IsKeyPressed(.SPACE) && almost_on_ground && .On_Ground not_in entities[player].flags {
			entities[player].flags |= {.Will_Jump_On_Touching_Ground}
		}

		double_jump_p := !first_jump_p && rl.IsKeyPressed(.SPACE) && .Consumed_Double_Jump not_in entities[player].flags
		should_jump := first_jump_p || double_jump_p

		if double_jump_p {
			entities[player].flags |= {.Consumed_Double_Jump}
		}
		if should_jump {
			entities[player].vel.y = -JUMP_SPEED
			entities[player].flags &~= {.Will_Jump_On_Touching_Ground}
		}

		////////// Interaction with interactive entities
		for &ie, i in entities {
			#partial switch ie.kind {
			case .Unlock_Big_Knight, .Finish_Game:
				rect := entity_rect(ie)
				if rl.CheckCollisionRecs(player_rect, rect) {
					message = "Press F to pay respects"

					if rl.IsKeyPressed(.F) {
						#partial switch ie.kind {
						case .Unlock_Big_Knight:
							ie.kind = .Removed
							level.already_defeated += 1
							unlocked_entities |= {.Big_Knight}
							begin_attack(player, .Pray_Respects)
						case .Finish_Game:
							ie.kind = .Removed
							level.already_defeated += 1
							begin_attack(player, .Pray_Respects)
							finished_game = true
							state_reached_at = frame_number
						}
					}
				}
			}
		}
		if game_state == .Game && finished_game && state_reached_at + 15 < frame_number {
			game_state = .Ending
			state_reached_at = frame_number
		}

		for &ent, ent_id in entities {
			if ent.kind == .Removed do continue

			if .Enemy in ent.flags {
				////////// Simulate AI
				player := &entities[player]
				distance := math.abs(player.x - ent.x)
				if ent.ai_state == .Idle {
					if distance < ent.ai_params.view_distance {
						ent.ai_state = .Approaching
						begin_attack(ent_id, .Walk)
					}
				}
				if ent.ai_state == .Approaching {
					if distance < ent.ai_params.attack_distance {
						ent.ai_state = .Attacking
					} else {
						facing_sign := math.sign(player.x - ent.x)
						ent.vel.x = math.sign(player.x - ent.x) * RUN_SPEED / 3
						if facing_sign == 1 {
							ent.facing_direction = .Right
						} else {
							ent.facing_direction = .Left
						}
					}
				}
				if ent.ai_state == .Attacking && frame_number > ent.ai_next_attack_frame_number  {
					if distance < ent.ai_params.attack_distance {
						ent.vel.x = 0
						ent.ai_state = .Attacking
						ent.ai_next_attack_frame_number = frame_number + 12
						begin_attack(ent_id, .Basic)
					} else {
						ent.ai_state = .Approaching
						begin_attack(ent_id, .Walk)
					}
				}

				////////// Test for attacks from player
				if player.current_attack == .Basic {
					HITBOX_FORWARD_LEANING :: 10
					HITBOX_BACKWARDS_WEAKNESS :: 10

					hitbox := entity_rect(player^)
					switch player.facing_direction {
					case .Right:
						hitbox.x += HITBOX_BACKWARDS_WEAKNESS
						hitbox.width += HITBOX_FORWARD_LEANING
					case .Left:
						hitbox.x -= HITBOX_BACKWARDS_WEAKNESS
						hitbox.width += HITBOX_FORWARD_LEANING
					}
					time_since_hit := frame_number - ent.last_got_hit_on

					if time_since_hit > IFRAMES && rl.CheckCollisionRecs(hitbox, entity_rect(ent)) {
						ent.last_got_hit_on = frame_number
						ent.flags |= {.Got_Hit}
						ent.health -= player.attack_power
						if ent.health <= 0 {
							ent.current_attack = .Dead
						}
					}
				}
				////////// Test for attacks from enemy
				if ent.current_attack == .Basic {
					HITBOX_FORWARD_LEANING :: 20
					HITBOX_BACKWARDS_WEAKNESS :: 10

					hitbox := entity_rect(ent)
					switch ent.facing_direction {
					case .Right:
						hitbox.x += HITBOX_BACKWARDS_WEAKNESS
						hitbox.width += HITBOX_FORWARD_LEANING
					case .Left:
						hitbox.x -= HITBOX_BACKWARDS_WEAKNESS
						hitbox.width += HITBOX_FORWARD_LEANING
					}
					IFRAMES :: 5
					DASH_IFRAMES :: 5
					time_since_hit := frame_number - player.last_got_hit_on
					time_since_dash := frame_number - player.dash_began_number

					if time_since_dash > DASH_IFRAMES &&
					   time_since_hit > IFRAMES &&
					   rl.CheckCollisionRecs(hitbox, entity_rect(player^)) {
						if player.current_attack == .Defend {
							rl.PlaySound(shield_sound)
						} else {
							player.last_got_hit_on = frame_number
							player.flags |= {.Got_Hit}
							player.health -= ent.attack_power
							if player.health <= 0 {
								fmt.panicf("You lost!")
							}
						}
					}
				}
			}
		}

		if trigger_slam {
			trigger_slam = false
			spawn_particle(
				pos = entities[player].pos,
				texture = GROUD_SLAM_PARTICLES,
				size = {200, 200},
				lifetime = 10,
			)
			rl.PlaySound(groundslam_sound)

			hitbox := entity_rect(entities[player])
			hitbox.height *= 0.5
			hitbox.width *= 2
			hitbox.x -= hitbox.width / 4

			for &ent in entities {
				if .Enemy not_in ent.flags do continue

				time_since_hit := frame_number - ent.last_got_hit_on
				if time_since_hit > IFRAMES && rl.CheckCollisionRecs(hitbox, entity_rect(ent)) {
					ent.last_got_hit_on = frame_number
					ent.flags |= {.Got_Hit}
					ent.health -= entities[player].attack_power * 1.5
					if ent.health <= 0 {
						ent.current_attack = .Dead
						level.already_defeated += 1
					}
				}
			}
		}


		////////// Simulate physics
		for &ent in entities {
			if .Null_Entity in ent.flags {
				continue
			}
			ent.pos += ent.vel * dt
			if .No_Physics not_in ent.flags {
				if .On_Ground in ent.flags && ent.vel.y > 0 {
					if .Slamming_Down in ent.flags {
						trigger_slam = true
						ent.flags &~= {.Slamming_Down}
						ent.current_attack = .None
					}

					ent.vel.y = 0
					ent.pos.y = ent.ground_height - ent.size.y / 2
				} else {
					if ent.current_attack != .Slam {
						ent.vel.y = ent.vel.y + GRAVITY * dt
					}
				}
			}
		}

		////////// Move to next level if necessary
		world_end := rl.GetScreenToWorld2D(window_size, camera)
		if entities[player].pos.x > world_end.x {
			entities[player].pos.x = -world_end.x
			if enemy_count == 0 {
				current_level += 1
			} else {
				entities[player].pos.x = world_end.x - 10
			}
		}
		if entities[player].pos.x < -world_end.x {
			entities[player].pos.x = -world_end.x
			entities[player].vel.x = 0
		}

		////////// Simulate attacks
		for &ent in entities {
			if ent.current_attack == .Slam {
				if entities[player].pos.y < -200 || .Slamming_Down in entities[player].flags {
					entities[player].flags |= {.Slamming_Down}
					entities[player].vel.y = 3000
				} else {
					entities[player].vel.y = -1000
				}
			}

			attack_length := TIME_OF_ATTACK[ent.kind][ent.current_attack]
			if attack_length != 0 && (frame_number - ent.attack_began_number) >= attack_length {
				if ent.current_attack == .Dead {
					ent.kind = .Removed
					level.already_defeated += 1
				} else {
					ent.current_attack = .None
				}
			}
			if ent.current_attack == .Dash {
				switch ent.facing_direction {
				case .Left:
					ent.x -= 100
				case .Right:
					ent.x += 100
				}
			}
		}

		////////// Remove old particles
		for i := 0; i < len(particles); {
			if frame_number > particles[i].started_on + particles[i].lifetime {
				unordered_remove(&particles, i)
			} else {
				i += 1
			}
		}
		for i := 0; i < len(entities); {
			if entities[i].kind == .Removed {
				fmt.println("Removing entity", i)
				unordered_remove(&entities, i)
			} else {
				i += 1
			}
		}

		////////// Do rendering
		rl.BeginDrawing()
		switch game_state {
		case .Starting1:
			char_count := (frame_number - state_reached_at) * 2
			if char_count < len(STARTING_MESSAGE) {
				rl.ClearBackground(rl.BLACK)

				rl.DrawText(strings.clone_to_cstring(STARTING_MESSAGE[:char_count]), 20, 20, 40, rl.WHITE)
			} else if char_count > len(STARTING_MESSAGE) + 20 {
				game_state = .Starting2
				state_reached_at = frame_number
			}
		case .Starting2:
			char_count := (frame_number - state_reached_at) * 2
			if char_count < len(STARTING_MESSAGE2) {
				rl.ClearBackground(rl.BLACK)

				rl.DrawText(strings.clone_to_cstring(STARTING_MESSAGE2[:char_count]), 20, 20, 50, rl.WHITE)
			} else if char_count > len(STARTING_MESSAGE2) + 20 {
				game_state = .Game
				state_reached_at = frame_number
			}
		case .Ending:
			char_count := (frame_number - state_reached_at) * 2
			if char_count < len(ENDING_MESSAGE) {
				rl.ClearBackground(rl.BLACK)

				rl.DrawText(strings.clone_to_cstring(ENDING_MESSAGE[:char_count]), 20, 20, 50, rl.WHITE)
			} else if char_count > len(ENDING_MESSAGE) + 20 {
				return
			}
		case .Game:
			ui_topleft := [2]f32{0, window_size.y * 0.25}

			////////// Draw background
			rl.ClearBackground(rl.BLACK)

			rl.DrawTexturePro(level.background, {0, 0, f32(level.background.width), f32(level.background.height)},
			                  		    {**ui_topleft,window_size.x, window_size.y * 0.5}, {}, 0, rl.WHITE)

			rl.BeginMode2D(camera)

			for plat in platforms {
				rl.DrawLineEx({-plat.width / 2, plat.y + plat.thickness / 2}, {plat.width / 2, plat.y + plat.thickness / 2}, plat.thickness, {0, 0, 0, 0})
			}

			////////// Draw entities
			for ent in entities {
				if .Null_Entity in ent.flags {
					continue
				}
				switch ent.kind {
				case .Rectangle:
					rl.DrawRectangle(**cast([2]i32)(ent.pos - ent.size/2), **cast([2]i32)ent.size, rl.RED)
				case .Circle:
					rl.DrawCircleV(ent.pos, ent.size.x/2, rl.GREEN)
				case .Test_Samurai:
					#partial switch ent.current_attack {
					case .None:
						draw_texture(TEST_SAMURAI_IDLE, (frame_number - ent.animation_start_number) % TEST_SAMURAI_IDLE.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					case .Basic:
						draw_texture(TEST_SAMURAI_ATTACK, (frame_number - ent.animation_start_number) % TEST_SAMURAI_ATTACK.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					case .Walk, .Dash:
						draw_texture(TEST_SAMURAI_WALK, (frame_number - ent.animation_start_number) % TEST_SAMURAI_WALK.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					}
				case .Knight:
					#partial switch ent.current_attack {
					case .None:
						draw_texture(KNIGHT_IDLE, (frame_number - ent.animation_start_number) % KNIGHT_IDLE.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					case .Basic:
						draw_texture(KNIGHT_ATTACK_BASIC, (frame_number - ent.animation_start_number) % KNIGHT_ATTACK_BASIC.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					case .Defend:
						draw_texture(KNIGHT_DEFEND, (frame_number - ent.animation_start_number) % KNIGHT_DEFEND.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					case .Walk, .Dash:
						draw_texture(KNIGHT_RUN, (frame_number - ent.animation_start_number) % KNIGHT_RUN.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					case .Pray_Respects:
						draw_texture(KNIGHT_PRAY_RESPECTS, min(1, frame_number - ent.animation_start_number) % KNIGHT_PRAY_RESPECTS.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					}
				case .Archer:
					#partial switch ent.current_attack {
					case .None:
						draw_texture(ARCHER_IDLE, (frame_number - ent.animation_start_number) % ARCHER_IDLE.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					case .Basic:
						draw_texture(ARCHER_ATTACK_BASIC, (frame_number - ent.animation_start_number) % ARCHER_ATTACK_BASIC.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					case .Walk, .Dash:
						draw_texture(ARCHER_RUN, (frame_number - ent.animation_start_number) % ARCHER_RUN.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					}
				case .Samurai:
					tint := rl.WHITE
					time_since_hit := frame_number - ent.last_got_hit_on
					if .Got_Hit in ent.flags && 0 < time_since_hit && time_since_hit < 4 {
						tint = rl.RED
					}
					if ent.health < 0 {
						tint = rl.GREEN
					}
					#partial switch ent.current_attack {
					case .None:
						draw_texture(SAMURAI_IDLE, (frame_number - ent.animation_start_number) % SAMURAI_IDLE.divisions, {**ent.pos, **ent.size}, ent.facing_direction, tint)
					case .Basic:
						draw_texture(SAMURAI_ATTACK_BASIC, (frame_number - ent.animation_start_number) % SAMURAI_ATTACK_BASIC.divisions, {**ent.pos, **ent.size}, ent.facing_direction, tint)
					case .Dead:
						draw_texture(SAMURAI_DEAD, (frame_number - ent.animation_start_number) % SAMURAI_DEAD.divisions, {**ent.pos, **ent.size}, ent.facing_direction, tint)
					case .Walk, .Dash:
					 	draw_texture(SAMURAI_RUN, (frame_number - ent.animation_start_number) % SAMURAI_RUN.divisions, {**ent.pos, **ent.size}, ent.facing_direction, tint)
					}
				case .Big_Knight:
					#partial switch ent.current_attack {
					case .None:
						draw_texture(BIG_KNIGHT_IDLE, (frame_number - ent.animation_start_number) % BIG_KNIGHT_IDLE.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					case .Basic:
					 	draw_texture(BIG_KNIGHT_ATTACK, (frame_number - ent.animation_start_number) % BIG_KNIGHT_ATTACK.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					case .Walk, .Dash, .Slam:
					 	draw_texture(BIG_KNIGHT_WALK, (frame_number - ent.animation_start_number) % BIG_KNIGHT_WALK.divisions, {**ent.pos, **ent.size}, ent.facing_direction)
					}
				case .Unlock_Big_Knight:
				case .Finish_Game:
				case .Removed:
				}
			}

			////////// Draw particles
			for part in particles {
				draw_texture(part.texture, (frame_number - part.started_on) % part.texture.divisions, {**part.pos, **part.size})
			}


			rl.EndMode2D()

			////////// Draw UI
			BAR_HEIGHT :: 30
			BAR_LENGTH :: 200
			BAR_PADDING :: 2

			if message != "" {
				rl.DrawText(message, i32(window_size.x / 2 * 0.7) , i32(window_size.y / 2 * 1.2), 25, rl.WHITE)
			}

			rl.DrawRectangleV(ui_topleft + {10, 10}, {BAR_LENGTH, BAR_HEIGHT}, rl.BLACK)
			rl.DrawRectangleV(ui_topleft + {10, 10} + BAR_PADDING, {BAR_LENGTH * f32(entities[player].health) / 100, BAR_HEIGHT} - BAR_PADDING * 2, rl.GREEN)
		}

		rl.EndDrawing()
	}
}
