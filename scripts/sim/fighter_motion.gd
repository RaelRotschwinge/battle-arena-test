# Moves one fighter by one tick (game design, "Movement", "Combat" and "Defence"): walking and
# running, the jump with its take-off, the double jump, air control, fast fall, dropping through
# thin platforms, wall jumps, hanging on and climbing up a ledge, starting attacks and moving
# during them, the shield and dodges, flying in hitstun, techs, the respawn platform, and the
# collision with the arena. Parameters: f a fighter state, input a fighter input, s the fighter's
# stats, arena an arena.
extends RefCounted

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const FighterDefense := preload("res://scripts/sim/fighter_defense.gd")

# Fast fall can start this many ticks of gravity before the top of a jump.
const FAST_FALL_APEX_TICKS := 3.0
# A falling fighter grabs a ledge when the side of its box facing the ledge is this close to the
# ledge corner and the top of its box is between these distances above and below the corner.
const LEDGE_REACH_X := 40.0
const LEDGE_REACH_UP := 40.0
const LEDGE_REACH_DOWN := 30.0
const LEDGE_HAND_ABOVE := 10.0  # While hanging, the top of the box is this far above the ledge.
const GETUP_CLIMB_TICKS := 8  # Climbing up before a getup attack or roll.
const AIR_DODGE_GRAB_AFTER := 6  # An air dodge can grab a ledge after this many ticks.
const WALL_REACH := 8.0  # A wall this close to the side of the box counts as touched.
# A fighter in hitstun that hits the ground or a wall at least this fast bounces off it, keeping
# this share of its speed; slower, it lands.
const BOUNCE_SPEED := 8.0
const BOUNCE_KEEP := 0.5
# A press of attack, up or the shield key that cannot act at once (during an attack, a landing
# lag, the take-off, hitstun) waits this many ticks and acts as soon as it can.
const BUFFER_TICKS := 8
const LANDED := 1  # Flags returned by the collision.
const HIT_WALL := 2


# blocked_ledges lists the ledges other fighters are climbing up; they cannot be grabbed.
static func step(f, input, s, arena, blocked_ledges: Array = []) -> void:
	if f.invuln > 0:
		f.invuln -= 1
	if f.grab_immune > 0:
		f.grab_immune -= 1
	if f.hitlag > 0:
		# Hit pause: the fighter stands frozen. The previous input stays, so a key pressed now
		# counts as a press on the first tick after the pause. At its end the held direction
		# bends the launch.
		f.hitlag -= 1
		if f.hitlag == 0 and f.launch_pending:
			FighterDefense.apply_di(f, input)
		return
	if f.launch_pending:
		FighterDefense.apply_di(f, input)
	if f.mode == Mode.HELD:  # Held in a grab: the holder places it.
		f.mode_ticks += 1
		f.prev_input.copy_from(input)
		return
	var dir: int = input.dir()
	var pressed_up: bool = input.up and not f.prev_input.up
	var pressed_jump: bool = pressed_up or (input.jump and not f.prev_input.jump)
	var pressed_down: bool = input.down and not f.prev_input.down
	var pressed_attack: bool = input.attack and not f.prev_input.attack
	var pressed_shield: bool = input.shield and not f.prev_input.shield
	var pressed_special: bool = input.special and not f.prev_input.special
	var pressed_dir := 0
	if input.right and not f.prev_input.right:
		pressed_dir = 1
	elif input.left and not f.prev_input.left:
		pressed_dir = -1
	_update_running(f, pressed_dir, dir, input, s)
	_update_buffers(f, pressed_up, pressed_down, pressed_jump, pressed_attack, pressed_shield)
	f.special_buffer = BUFFER_TICKS if pressed_special else maxi(f.special_buffer - 1, 0)
	if f.hazard_cooldown > 0:
		f.hazard_cooldown -= 1
	if pressed_shield and f.mode == Mode.HITSTUN:
		FighterDefense.press_in_hitstun(f)
	if f.drop_ticks > 0:
		f.drop_ticks -= 1
	if f.ledge_cooldown > 0:
		f.ledge_cooldown -= 1
	if f.lag > 0:
		f.lag -= 1
	f.mode_ticks += 1
	FighterCombat.advance(f)
	FighterDefense.tick(f)

	if f.mode == Mode.RESPAWN:
		# The respawn platform holds the fighter until a key is pressed or the time is up. The
		# key that leaves it acts at once.
		var pressed_any: bool = pressed_jump or pressed_down or pressed_attack or pressed_shield \
				or pressed_special or pressed_dir != 0
		if not pressed_any and f.mode_ticks < s.respawn_wait_ticks:
			f.prev_input.copy_from(input)
			return
		_set_mode(f, Mode.AIR)
		f.invuln = s.respawn_invuln_ticks

	if f.mode == Mode.LEDGE or f.mode == Mode.CLIMB:
		if f.mode == Mode.LEDGE:
			_ledge_control(f, pressed_jump, pressed_down, pressed_dir, s, arena)
		else:
			_climb(f, s, arena)
		if f.mode == Mode.LEDGE or f.mode == Mode.CLIMB:
			f.prev_input.copy_from(input)
			return
		if f.mode != Mode.AIR:  # Climbed up onto the ground, perhaps into a getup.
			_move_and_collide(f, s, arena)
			f.prev_input.copy_from(input)
			return
	elif f.mode == Mode.GRAB:
		f.velocity = Vector2.ZERO
		f.throw = FighterDefense.pick_throw(f, input)
		f.prev_input.copy_from(input)
		return
	elif f.mode == Mode.GROUND:
		_ground_actions(f, input, dir, pressed_up, pressed_down, pressed_dir, s, arena)
	elif f.mode == Mode.SHIELD:
		_shield_control(f, input, pressed_dir, pressed_down)
	elif f.mode == Mode.JUMP_SQUAT:
		_ground_control(f, dir, s, false)
		var up_attack: bool = input.up and f.ticks_since_up <= FighterCombat.UP_FRESH_TICKS
		if f.attack_buffer > 0 and up_attack:  # Up, then attack in the take-off: the uppercut.
			_set_mode(f, Mode.GROUND)
			FighterCombat.start(f, "up", dir)
		elif f.mode_ticks >= s.jump_squat_ticks:
			f.velocity.y = -s.jump_speed
			f.jump_rising = true
			if not (input.up or input.jump):  # Let go during the take-off: a short hop.
				f.velocity.y *= s.jump_release_cut
				f.jump_rising = false
			_set_mode(f, Mode.AIR)
	elif f.mode == Mode.DODGE:
		if FighterDefense.dodge_control(f, s):
			_set_mode(f, Mode.AIR if f.dodge == "air" else Mode.GROUND)
			f.dodge = ""
	elif f.mode == Mode.TECH:
		if FighterDefense.tech_control(f):
			f.dodge = ""
			_set_mode(f, Mode.GROUND)
	elif f.mode == Mode.SHIELD_BREAK:
		f.velocity.x = move_toward(f.velocity.x, 0.0, s.ground_friction)
		f.velocity.y = minf(f.velocity.y + s.gravity, s.max_fall_speed)
		if f.mode_ticks >= FighterDefense.SHIELD_BREAK_TICKS:
			f.shield_hp = FighterDefense.SHIELD_AFTER_BREAK
			_set_mode(f, Mode.GROUND)
	elif f.mode == Mode.HITSTUN and not FighterDefense.can_cancel_hitstun(f):
		_hitstun_control(f, dir, s)
	else:
		if f.mode == Mode.HITSTUN:  # The early way out: the buffered jump or dodge acts now.
			f.hitstun = 0
			_set_mode(f, Mode.AIR)
		_air_control(f, input, dir, pressed_up, pressed_down, pressed_dir, s, arena)

	if f.mode == Mode.DODGE and f.dodge == "roll" and not _ground_ahead(f, s, arena):
		f.velocity.x = 0.0  # A roll stops at the edge instead of falling off.
	if f.mode == Mode.TECH and not _ground_ahead(f, s, arena):
		f.velocity.x = 0.0
	var before: Vector2 = f.velocity
	var contact := _move_and_collide(f, s, arena)
	var landed: bool = contact & LANDED != 0
	if contact & HIT_WALL != 0 and f.attack.begins_with("special") and FighterCombat.is_active(f) \
			and FighterCombat.data(f).get("move", {}).get("stop_at_wall", false):
		FighterCombat.end_active(f, 0)  # A dash into a wall ends there.
	if f.mode == Mode.AIR:
		if landed:
			_land_from_air(f, s)
		else:
			_try_grab_ledge(f, s, arena, blocked_ledges)
	elif f.mode == Mode.DODGE and f.dodge == "air":
		if landed:  # Landing in an air dodge: the fighter slides on (a waveland).
			f.dodge = ""
			_land(f, s)
			f.velocity.x = before.x
			f.lag = FighterDefense.WAVELAND_LAG
		elif f.mode_ticks > AIR_DODGE_GRAB_AFTER:
			_try_grab_ledge(f, s, arena, blocked_ledges)
	elif f.mode == Mode.HITSTUN:
		if landed:
			if f.tech_window > 0:
				FighterDefense.ground_tech(f, dir)
			elif before.y >= BOUNCE_SPEED:
				f.velocity.y = -before.y * BOUNCE_KEEP
			else:
				f.hitstun = 0
				_land(f, s)
		elif contact & HIT_WALL != 0:
			if f.tech_window > 0:
				FighterDefense.wall_tech(f)
			elif absf(before.x) >= BOUNCE_SPEED:
				f.velocity.x = -before.x * BOUNCE_KEEP
	elif f.mode == Mode.SHIELD_BREAK:
		pass  # Stays stunned, also in the air, until the time is up.
	elif not _supported(f, s, arena):
		if f.mode == Mode.DODGE or f.mode == Mode.TECH:
			f.dodge = ""
		_set_mode(f, Mode.AIR)
		var flies: bool = f.attack.begins_with("special") \
				and FighterCombat.data(f).get("move", {}).get("fly", false)
		if not flies:
			f.attack = ""  # Sliding off the ground ends a ground attack; a flying dash goes on.
	f.prev_input.copy_from(input)


static func box(f, s) -> Rect2:
	return Rect2(f.position.x - s.width / 2.0, f.position.y - s.height, s.width, s.height)


static func _update_running(f, tap: int, dir: int, input, s) -> void:
	if tap != 0:
		f.running = tap == f.tap_dir and f.ticks_since_tap <= s.run_double_tap_ticks
		f.tap_dir = tap
		f.ticks_since_tap = 0
	elif f.ticks_since_tap < 1000:
		f.ticks_since_tap += 1
	if input.run and dir != 0:  # A gamepad stick tilted all the way runs at once.
		f.running = true
		f.tap_dir = dir
	if dir != f.tap_dir or dir == 0:
		f.running = false


static func _update_buffers(f, pressed_up: bool, pressed_down: bool, pressed_jump: bool,
		pressed_attack: bool, pressed_shield: bool) -> void:
	if pressed_up:
		f.ticks_since_up = 0
	elif f.ticks_since_up < 1000:
		f.ticks_since_up += 1
	if pressed_down:
		f.ticks_since_down = 0
	elif f.ticks_since_down < 1000:
		f.ticks_since_down += 1
	if pressed_shield:
		f.ticks_since_shield = 0
	elif f.ticks_since_shield < 1000:
		f.ticks_since_shield += 1
	f.jump_buffer = BUFFER_TICKS if pressed_jump else maxi(f.jump_buffer - 1, 0)
	f.attack_buffer = BUFFER_TICKS if pressed_attack else maxi(f.attack_buffer - 1, 0)
	f.shield_buffer = BUFFER_TICKS if pressed_shield else maxi(f.shield_buffer - 1, 0)


static func _ground_actions(f, input, dir: int, pressed_up: bool, pressed_down: bool,
		pressed_dir: int, s, arena) -> void:
	if f.shield_drop > 0:
		f.shield_drop -= 1
	var free: bool = f.attack == "" and f.lag == 0
	var lowering: bool = f.shield_drop > 0
	var special := FighterCombat.special_for(f, false)
	if free and not lowering and f.attack_buffer > 0:
		FighterCombat.start(f, FighterCombat.ground_attack(f, input), dir)
	elif free and not lowering and f.special_buffer > 0 and special != "":
		FighterCombat.start_special(f, special, input, false)
	elif free and f.jump_buffer > 0:
		f.jump_buffer = 0
		f.shield_drop = 0
		_set_mode(f, Mode.JUMP_SQUAT)
	elif free and input.shield:
		_enter_shield(f, input)
	elif free and not lowering and pressed_down and _stands_on_thin(f, s, arena):
		f.drop_ticks = s.drop_through_ticks
		_set_mode(f, Mode.AIR)
	elif pressed_up or pressed_down or pressed_dir != 0:
		FighterCombat.repick(f, FighterCombat.ground_attack(f, input), dir)
	FighterCombat.reaim(f, input, false)
	if f.mode == Mode.GROUND:
		var steer: bool = f.attack == "" and f.lag == 0 and f.shield_drop == 0
		if f.attack == "dash":  # The dash attack carries the fighter forward.
			f.velocity.x = move_toward(f.velocity.x, f.facing * s.run_speed * 0.6,
					s.ground_friction * 0.5)
		elif _special_motion(f):
			pass
		else:
			_ground_control(f, dir, s, steer)


# Raising the shield. A direction pressed just before the shield key dodges at once, so the two
# keys need not come in the same tick.
static func _enter_shield(f, input) -> void:
	FighterDefense.start_shield(f)
	if f.ticks_since_tap <= FighterDefense.FLICK_TICKS and input.dir() == f.tap_dir \
			and f.tap_dir != 0:
		FighterDefense.start_dodge(f, "roll", Vector2(f.tap_dir, 0.0))
	elif input.down and f.ticks_since_down <= FighterDefense.FLICK_TICKS:
		FighterDefense.start_dodge(f, "spot", Vector2.ZERO)


# In the shield: a new left or right press rolls, down dodges in place, up or jump jumps,
# attack grabs, letting go lowers it. A hit shield slides back and cannot act for a moment.
static func _shield_control(f, input, pressed_dir: int, pressed_down: bool) -> void:
	f.shield_hp -= FighterDefense.SHIELD_DECAY
	f.velocity = Vector2(f.shield_push, 0.0)
	f.shield_push *= FighterDefense.SHIELD_PUSH_FADE
	if absf(f.shield_push) < 0.2:
		f.shield_push = 0.0
	if f.shield_hp <= 0.0:
		FighterDefense.break_shield(f)
		return
	if f.shield_stun > 0:
		f.shield_stun -= 1
		return
	if f.jump_buffer > 0:
		f.jump_buffer = 0
		_set_mode(f, Mode.JUMP_SQUAT)
	elif f.attack_buffer > 0 and FighterCombat.has(f, "grab"):
		_set_mode(f, Mode.GROUND)
		FighterCombat.start(f, "grab", 0)
	elif f.special_buffer > 0 and FighterCombat.special_for(f, false) != "":
		_set_mode(f, Mode.GROUND)  # The special comes out of the shield at once.
		FighterCombat.start_special(f, FighterCombat.special_for(f, false), input, false)
	elif pressed_dir != 0:
		FighterDefense.start_dodge(f, "roll", Vector2(pressed_dir, 0.0))
	elif pressed_down:
		FighterDefense.start_dodge(f, "spot", Vector2.ZERO)
	elif not input.shield:
		_set_mode(f, Mode.GROUND)
		f.shield_drop = FighterDefense.SHIELD_DROP_TICKS


static func _ground_control(f, dir: int, s, steer: bool) -> void:
	if steer and dir != 0:
		var speed: float = s.run_speed if f.running else s.walk_speed
		f.velocity.x = move_toward(f.velocity.x, dir * speed, s.ground_accel)
		f.facing = dir
	else:
		f.velocity.x = move_toward(f.velocity.x, 0.0, s.ground_friction)


static func _air_control(f, input, dir: int, pressed_up: bool, pressed_down: bool,
		pressed_dir: int, s, arena) -> void:
	if f.attack == "" and f.shield_buffer > 0 and not f.air_dodge_used:
		var aim := Vector2(dir, int(input.down) - int(input.up))
		FighterDefense.start_dodge(f, "air", aim)
		FighterDefense.dodge_control(f, s)
		return
	var special := FighterCombat.special_for(f, true)
	if f.attack == "" and f.attack_buffer > 0:
		FighterCombat.start(f, FighterCombat.air_attack(f, input), dir)
	elif f.attack == "" and f.special_buffer > 0 and special != "":
		FighterCombat.start_special(f, special, input, true)
	elif pressed_up or pressed_down or pressed_dir != 0:
		FighterCombat.repick(f, FighterCombat.air_attack(f, input), dir)
	FighterCombat.reaim(f, input, true)
	if _special_motion(f):
		return
	if f.attack == "ground_pound":
		# A short stop in the air, then straight down fast until landing.
		if FighterCombat.in_startup(f):
			f.velocity = Vector2.ZERO
		else:
			f.velocity = Vector2(0.0, s.fast_fall_speed * 2.0)
		return

	var wall := _touching_wall(f, s, arena)
	var free: bool = f.attack == ""
	var want_jump: bool = free and f.jump_buffer > 0
	if want_jump and wall != 0 and dir == wall and f.wall_jumps_used < s.max_wall_jumps:
		# Pressing against a wall and up: a jump off the wall, away from it.
		f.jump_buffer = 0
		f.wall_jumps_used += 1
		f.velocity = Vector2(-wall * s.wall_jump_push, -s.wall_jump_speed)
		f.facing = -wall
		f.fast_falling = false
		f.jump_rising = false
		f.air_dodge_used = false
		f.special_used = false
	elif want_jump and f.jumps_left > 0:
		# The double jump always adds its full height. Rising speeds add up the way jump heights
		# do (as squares), so a double jump while still rising is worth as much as one at the top.
		var rising_speed := maxf(-f.velocity.y, 0.0)
		f.jump_buffer = 0
		f.jumps_left -= 1
		f.velocity.y = -sqrt(rising_speed * rising_speed + s.double_jump_speed * s.double_jump_speed)
		f.fast_falling = false
		f.jump_rising = false
		if dir != 0:
			f.velocity.x = dir * s.air_speed
			f.facing = dir
	elif f.jump_rising:
		if f.velocity.y >= 0.0:
			f.jump_rising = false
		elif not (input.up or input.jump):
			f.velocity.y *= s.jump_release_cut
			f.jump_rising = false

	if FighterCombat.lifts(f):  # Carried up, but never slower than the fighter already rises.
		f.velocity.y = minf(f.velocity.y + s.gravity, -s.lift_speed)
	else:
		if pressed_down and not f.fast_falling and f.velocity.y > -FAST_FALL_APEX_TICKS * s.gravity:
			f.fast_falling = true
		if f.fast_falling:
			f.velocity.y = s.fast_fall_speed
		else:
			f.velocity.y = minf(f.velocity.y + s.gravity, s.max_fall_speed)

	# Steering. Speed from a run is kept in the air and fades only slowly.
	var keep_momentum: bool = dir != 0 and signf(f.velocity.x) == dir \
			and absf(f.velocity.x) > s.air_speed
	var rate: float = s.air_friction if dir == 0 or keep_momentum else s.air_accel
	f.velocity.x = move_toward(f.velocity.x, dir * s.air_speed, rate)


# A special with "move" data sets the fighter's speed itself: still in its startup when it
# "stalls", along its aim at "speed" (plus "rise" upward) while active; at the start of its
# recovery the speed drops to the share "keep". Returns true while it sets the speed.
static func _special_motion(f) -> bool:
	if not f.attack.begins_with("special"):
		return false
	var a := FighterCombat.data(f)
	if not a.has("move"):
		return false
	var m: Dictionary = a["move"]
	var t: int = f.attack_ticks
	if t <= a["startup"]:
		if m.get("stall", false):
			f.velocity = Vector2.ZERO
			return true
		return false
	if t <= a["startup"] + a["active"]:
		f.velocity = f.special_aim * m["speed"] + Vector2(0.0, -m.get("rise", 0.0))
		return true
	if t == a["startup"] + a["active"] + 1:
		f.velocity *= m.get("keep", 0.3)
	return false


# Launched by a hit: no control but a little drift, lighter gravity, the launch fades slowly.
# When the hitstun is over the fighter falls on as normal.
static func _hitstun_control(f, dir: int, s) -> void:
	if f.velocity.y < s.max_fall_speed:
		f.velocity.y = minf(f.velocity.y + s.gravity * s.hitstun_gravity, s.max_fall_speed)
	f.velocity.x = move_toward(f.velocity.x, 0.0, s.air_friction)
	FighterDefense.drift(f, dir)
	f.hitstun -= 1
	if f.hitstun <= 0:
		f.hitstun = 0
		_set_mode(f, Mode.AIR)


# On a ledge: up or jump jumps off it, toward the arena climbs up, attack climbs up with an
# attack, the shield key climbs up with a roll, down or away lets go. Hanging too long lets go by
# itself.
static func _ledge_control(f, pressed_jump: bool, pressed_down: bool, pressed_dir: int, s,
		arena) -> void:
	var side: int = arena.ledges[f.ledge]["side"]
	if pressed_jump:
		_let_go(f, s)
		f.jump_buffer = 0
		f.velocity.y = -s.jump_speed
		f.jump_rising = true
	elif f.attack_buffer > 0 and FighterCombat.has(f, "getup"):
		f.attack_buffer = 0
		_start_climb(f, s, "attack")
	elif f.shield_buffer > 0:
		f.shield_buffer = 0
		_start_climb(f, s, "roll")
	elif pressed_dir == -side:
		_start_climb(f, s, "")
	elif pressed_down or pressed_dir == side or f.mode_ticks >= s.ledge_hang_ticks:
		_let_go(f, s)


static func _start_climb(f, s, next: String) -> void:
	_set_mode(f, Mode.CLIMB)
	f.climb_next = next
	f.invuln = maxi(f.invuln, _climb_ticks(f, s) + 2)


static func _climb_ticks(f, s) -> int:
	return GETUP_CLIMB_TICKS if f.climb_next != "" else s.ledge_climb_ticks


static func _climb(f, s, arena) -> void:
	var ledge: Dictionary = arena.ledges[f.ledge]
	var ticks := _climb_ticks(f, s)
	var t := minf(float(f.mode_ticks) / ticks, 1.0)
	f.position = _hang_position(ledge, s).lerp(_climb_position(ledge, s), t)
	if f.mode_ticks >= ticks:
		var toward: int = -ledge["side"]
		var next: String = f.climb_next
		f.ledge = -1
		f.climb_next = ""
		_land(f, s)
		if next == "attack":
			FighterCombat.start(f, "getup", 0)
			f.invuln = maxi(f.invuln, FighterCombat.data(f)["startup"] + 1)
		elif next == "roll":
			f.ticks_since_dodge = 1000
			FighterDefense.start_dodge(f, "roll", Vector2(toward, 0.0))


static func let_go(f, s) -> void:
	_let_go(f, s)


static func _let_go(f, s) -> void:
	f.ledge = -1
	f.ledge_cooldown = s.ledge_regrab_ticks
	f.velocity = Vector2.ZERO
	_set_mode(f, Mode.AIR)


static func _try_grab_ledge(f, s, arena, blocked_ledges: Array) -> void:
	if f.velocity.y < 0.0 or f.ledge_cooldown > 0:
		return
	var b := box(f, s)
	for i in arena.ledges.size():
		if blocked_ledges.has(i):
			continue
		var ledge: Dictionary = arena.ledges[i]
		var point: Vector2 = ledge["point"]
		var side: int = ledge["side"]
		if side * (f.position.x - point.x) <= 0.0:
			continue  # Not on the open side of the ledge.
		var near_side: float = b.end.x if side < 0 else b.position.x
		if absf(near_side - point.x) > LEDGE_REACH_X:
			continue
		if b.position.y < point.y - LEDGE_REACH_UP or b.position.y > point.y + LEDGE_REACH_DOWN:
			continue
		_set_mode(f, Mode.LEDGE)
		f.ledge = i
		f.position = _hang_position(ledge, s)
		f.velocity = Vector2.ZERO
		f.facing = -side
		f.jumps_left = s.air_jumps
		f.wall_jumps_used = 0
		f.lift_used = false
		f.lifting = false
		f.air_dodge_used = false
		f.special_used = false
		f.dodge = ""
		f.attack = ""  # Grabbing a ledge ends an air attack.
		f.attack_buffer = 0  # Presses from before the grab do not act on the ledge.
		f.jump_buffer = 0
		f.shield_buffer = 0
		f.special_buffer = 0
		f.fast_falling = false
		f.jump_rising = false
		f.running = false
		if f.ledge_invuln_ok:  # Only the first grab since landing or being hit protects.
			f.ledge_invuln_ok = false
			f.invuln = maxi(f.invuln, FighterDefense.LEDGE_INVULN)
		return


static func _hang_position(ledge: Dictionary, s) -> Vector2:
	var point: Vector2 = ledge["point"]
	return Vector2(point.x + ledge["side"] * s.width / 2.0, point.y - LEDGE_HAND_ABOVE + s.height)


static func _climb_position(ledge: Dictionary, s) -> Vector2:
	var point: Vector2 = ledge["point"]
	return Vector2(point.x - ledge["side"] * (s.width / 2.0 + 4.0), point.y)


# Returns 1 when a wall touches the right side of the fighter, -1 for the left side, 0 for none.
static func _touching_wall(f, s, arena) -> int:
	var b := box(f, s)
	for r: Rect2 in arena.solids:
		if b.end.y <= r.position.y or b.position.y >= r.end.y:
			continue
		if absf(b.end.x - r.position.x) <= WALL_REACH:
			return 1
		if absf(b.position.x - r.end.x) <= WALL_REACH:
			return -1
	return 0


# Moves along x, then along y, and pushes the fighter out of solid platforms. Thin platforms
# catch a falling fighter whose feet cross their top. Returns LANDED and HIT_WALL flags.
static func _move_and_collide(f, s, arena) -> int:
	var half: float = s.width / 2.0
	var contact := 0
	f.position.x += f.velocity.x
	for r: Rect2 in arena.solids:
		if box(f, s).intersects(r):
			if f.velocity.x > 0.0:
				f.position.x = r.position.x - half
			else:
				f.position.x = r.end.x + half
			f.velocity.x = 0.0
			contact |= HIT_WALL

	var old_feet: float = f.position.y
	f.position.y += f.velocity.y
	for r: Rect2 in arena.solids:
		if box(f, s).intersects(r):
			if f.velocity.y > 0.0:
				f.position.y = r.position.y
				contact |= LANDED
			else:
				f.position.y = r.end.y + s.height
			f.velocity.y = 0.0
	if f.velocity.y > 0.0 and f.drop_ticks == 0:
		for r: Rect2 in arena.thin:
			if old_feet <= r.position.y and f.position.y >= r.position.y and _over(f, s, r):
				f.position.y = r.position.y
				f.velocity.y = 0.0
				contact |= LANDED
	return contact


static func _supported(f, s, arena) -> bool:
	for r: Rect2 in arena.solids:
		if is_equal_approx(f.position.y, r.position.y) and _over(f, s, r):
			return true
	return _stands_on_thin(f, s, arena)


static func _stands_on_thin(f, s, arena) -> bool:
	if f.drop_ticks > 0:
		return false
	for r: Rect2 in arena.thin:
		if is_equal_approx(f.position.y, r.position.y) and _over(f, s, r):
			return true
	return false


# True when the middle of the fighter, moved by its speed along x, is still over the ground it
# stands on.
static func _ground_ahead(f, s, arena) -> bool:
	var x: float = f.position.x + f.velocity.x
	for r: Rect2 in arena.solids + arena.thin:
		if is_equal_approx(f.position.y, r.position.y) and x >= r.position.x and x <= r.end.x:
			return true
	return false


static func _over(f, s, r: Rect2) -> bool:
	return f.position.x + s.width / 2.0 > r.position.x and f.position.x - s.width / 2.0 < r.end.x


static func _set_mode(f, mode: int) -> void:
	if f.mode == Mode.HITSTUN and mode != Mode.HITSTUN:
		f.combo_hits = 0
	f.mode = mode
	f.mode_ticks = 0


# Landing during an air attack ends it with a short landing lag, the ground pound with its own.
static func _land_from_air(f, s) -> void:
	if f.attack == "ground_pound":
		f.lag = FighterCombat.data(f)["recovery"]
	elif f.attack != "" and FighterCombat.data(f).has("landing_lag"):
		f.lag = FighterCombat.data(f)["landing_lag"]
	elif f.attack != "":
		f.lag = mini(s.landing_lag_ticks, FighterCombat.ticks_left(f))
	f.attack = ""
	_land(f, s)


static func _land(f, s) -> void:
	_set_mode(f, Mode.GROUND)
	f.velocity.y = 0.0
	f.jumps_left = s.air_jumps
	f.wall_jumps_used = 0
	f.lift_used = false
	f.lifting = false
	f.fast_falling = false
	f.jump_rising = false
	f.air_dodge_used = false
	f.special_used = false
	f.ledge_invuln_ok = true
