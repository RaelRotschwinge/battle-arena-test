# Moves one fighter by one tick (game design, "Movement"): walking and running, the jump with its
# take-off, the double jump, air control, fast fall, dropping through thin platforms, wall jumps,
# hanging on and climbing up a ledge, and the collision with the arena. Parameters: f a fighter
# state, input a fighter input, s the fighter stats, arena an arena.
extends RefCounted

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

const MAX_AIR_JUMPS := 1
# Fast fall can start this many ticks of gravity before the top of a jump.
const FAST_FALL_APEX_TICKS := 3.0
# A falling fighter grabs a ledge when the side of its box facing the ledge is this close to the
# ledge corner and the top of its box is between these distances above and below the corner.
const LEDGE_REACH_X := 40.0
const LEDGE_REACH_UP := 40.0
const LEDGE_REACH_DOWN := 30.0
const LEDGE_HAND_ABOVE := 10.0  # While hanging, the top of the box is this far above the ledge.
const WALL_REACH := 8.0  # A wall this close to the side of the box counts as touched.


# blocked_ledges lists the ledges other fighters hold; they cannot be grabbed.
static func step(f, input, s, arena, blocked_ledges: Array = []) -> void:
	var dir := int(input.right) - int(input.left)
	var pressed_up: bool = input.up and not f.prev_input.up
	var pressed_down: bool = input.down and not f.prev_input.down
	var pressed_dir := 0
	if input.right and not f.prev_input.right:
		pressed_dir = 1
	elif input.left and not f.prev_input.left:
		pressed_dir = -1
	_update_running(f, pressed_dir, dir, s)
	if f.drop_ticks > 0:
		f.drop_ticks -= 1
	if f.ledge_cooldown > 0:
		f.ledge_cooldown -= 1
	f.mode_ticks += 1

	if f.mode == Mode.LEDGE or f.mode == Mode.CLIMB:
		if f.mode == Mode.LEDGE:
			_ledge_control(f, pressed_up, pressed_down, pressed_dir, s, arena)
		else:
			_climb(f, s, arena)
		if f.mode != Mode.AIR:  # Still on the ledge, or climbed up onto the ground.
			f.prev_input.copy_from(input)
			return
	elif f.mode == Mode.GROUND:
		if pressed_up:
			_set_mode(f, Mode.JUMP_SQUAT)
		elif pressed_down and _stands_on_thin(f, s, arena):
			f.drop_ticks = s.drop_through_ticks
			_set_mode(f, Mode.AIR)
		_ground_control(f, dir, s, f.mode == Mode.GROUND)
	elif f.mode == Mode.JUMP_SQUAT:
		_ground_control(f, dir, s, false)
		if f.mode_ticks >= s.jump_squat_ticks:
			f.velocity.y = -s.jump_speed
			f.jump_rising = true
			if not input.up:  # Let go during the take-off: a short hop.
				f.velocity.y *= s.jump_release_cut
				f.jump_rising = false
			_set_mode(f, Mode.AIR)
	else:
		_air_control(f, input, dir, pressed_up, pressed_down, s, arena)

	var landed := _move_and_collide(f, s, arena)
	if f.mode == Mode.AIR:
		if landed:
			_land(f)
		else:
			_try_grab_ledge(f, s, arena, blocked_ledges)
	elif not _supported(f, s, arena):
		_set_mode(f, Mode.AIR)
	f.prev_input.copy_from(input)


static func box(f, s) -> Rect2:
	return Rect2(f.position.x - s.width / 2.0, f.position.y - s.height, s.width, s.height)


static func _update_running(f, tap: int, dir: int, s) -> void:
	if tap != 0:
		f.running = tap == f.tap_dir and f.ticks_since_tap <= s.run_double_tap_ticks
		f.tap_dir = tap
		f.ticks_since_tap = 0
	elif f.ticks_since_tap < 1000:
		f.ticks_since_tap += 1
	if dir != f.tap_dir:
		f.running = false


static func _ground_control(f, dir: int, s, steer: bool) -> void:
	if steer and dir != 0:
		var speed: float = s.run_speed if f.running else s.walk_speed
		f.velocity.x = move_toward(f.velocity.x, dir * speed, s.ground_accel)
		f.facing = dir
	else:
		f.velocity.x = move_toward(f.velocity.x, 0.0, s.ground_friction)


static func _air_control(f, input, dir: int, pressed_up: bool, pressed_down: bool, s,
		arena) -> void:
	var wall := _touching_wall(f, s, arena)
	if pressed_up and wall != 0 and dir == wall and f.wall_jumps_used < s.max_wall_jumps:
		# Pressing against a wall and up: a jump off the wall, away from it.
		f.wall_jumps_used += 1
		f.velocity = Vector2(-wall * s.wall_jump_push, -s.wall_jump_speed)
		f.facing = -wall
		f.fast_falling = false
		f.jump_rising = false
	elif pressed_up and f.jumps_left > 0:
		# The double jump always adds its full height. Rising speeds add up the way jump heights
		# do (as squares), so a double jump while still rising is worth as much as one at the top.
		var rising_speed := maxf(-f.velocity.y, 0.0)
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
		elif not input.up:
			f.velocity.y *= s.jump_release_cut
			f.jump_rising = false

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


# On a ledge: up jumps off it, toward the arena climbs up, down or away lets go. Hanging too long
# lets go by itself.
static func _ledge_control(f, pressed_up: bool, pressed_down: bool, pressed_dir: int, s,
		arena) -> void:
	var side: int = arena.ledges[f.ledge]["side"]
	if pressed_up:
		_let_go(f, s)
		f.velocity.y = -s.jump_speed
		f.jump_rising = true
	elif pressed_dir == -side:
		_set_mode(f, Mode.CLIMB)
	elif pressed_down or pressed_dir == side or f.mode_ticks >= s.ledge_hang_ticks:
		_let_go(f, s)


static func _climb(f, s, arena) -> void:
	var ledge: Dictionary = arena.ledges[f.ledge]
	var t := minf(float(f.mode_ticks) / s.ledge_climb_ticks, 1.0)
	f.position = _hang_position(ledge, s).lerp(_climb_position(ledge, s), t)
	if f.mode_ticks >= s.ledge_climb_ticks:
		f.ledge = -1
		_land(f)


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
		f.jumps_left = MAX_AIR_JUMPS
		f.wall_jumps_used = 0
		f.fast_falling = false
		f.jump_rising = false
		f.running = false
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
# catch a falling fighter whose feet cross their top. Returns true when the fighter landed.
static func _move_and_collide(f, s, arena) -> bool:
	var half: float = s.width / 2.0
	f.position.x += f.velocity.x
	for r: Rect2 in arena.solids:
		if box(f, s).intersects(r):
			if f.velocity.x > 0.0:
				f.position.x = r.position.x - half
			else:
				f.position.x = r.end.x + half
			f.velocity.x = 0.0

	var old_feet: float = f.position.y
	f.position.y += f.velocity.y
	var landed := false
	for r: Rect2 in arena.solids:
		if box(f, s).intersects(r):
			if f.velocity.y > 0.0:
				f.position.y = r.position.y
				landed = true
			else:
				f.position.y = r.end.y + s.height
			f.velocity.y = 0.0
	if f.velocity.y > 0.0 and f.drop_ticks == 0:
		for r: Rect2 in arena.thin:
			if old_feet <= r.position.y and f.position.y >= r.position.y and _over(f, s, r):
				f.position.y = r.position.y
				f.velocity.y = 0.0
				landed = true
	return landed


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


static func _over(f, s, r: Rect2) -> bool:
	return f.position.x + s.width / 2.0 > r.position.x and f.position.x - s.width / 2.0 < r.end.x


static func _set_mode(f, mode: int) -> void:
	f.mode = mode
	f.mode_ticks = 0


static func _land(f) -> void:
	_set_mode(f, Mode.GROUND)
	f.velocity.y = 0.0
	f.jumps_left = MAX_AIR_JUMPS
	f.wall_jumps_used = 0
	f.fast_falling = false
	f.jump_rising = false
