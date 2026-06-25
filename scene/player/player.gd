extends CharacterBody2D

@export var speed: float = 60.0
@export var shallow_water_speed_multiplier: float = 0.65
@export var walk_frame_time: float = 0.15
## How far (px) the player will be nudged sideways to slip around a wall corner.
@export var corner_correction: float = 6.0
## Fraction (0–1) of the player's footprint that must overlap shallow water before
## wading. At 1.0 the player only wades when fully in the water, so standing even a
## little on solid ground keeps the normal walk animation/speed. Used when moving
## horizontally (crossing a vertical sand/water edge).
@export_range(0.0, 1.0, 0.01) var wade_threshold: float = 1.0
## Same as wade_threshold but applied when the player is moving mostly vertically
## (down from sand into water, or up from water onto sand). Kept smaller so vertical
## transitions begin wading with less overlap than horizontal ones.
@export_range(0.0, 1.0, 0.01) var wade_threshold_vertical: float = 0.5
@export var walk_texture: Texture2D
@export var wade_texture: Texture2D

const SHALLOW_TILE := Vector2i(0, 4)
## Number of sample points per axis used to measure footprint water coverage.
const FOOTPRINT_SAMPLES := 3

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var tile_map: TileMapLayer = get_parent().get_node("TileMapLayer")

var _step_timer: float = 0.0
var _footprint_offset: Vector2 = Vector2(0, 3)
var _footprint_half: Vector2 = Vector2(5, 4)
## Last non-zero move direction, used to pick the horizontal vs vertical wade threshold.
var _last_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	if walk_texture == null:
		walk_texture = sprite.texture
	if wade_texture == null:
		var wade_path := "res://resource/sprite/player_wade.png"
		if ResourceLoader.exists(wade_path):
			wade_texture = load(wade_path)
		else:
			wade_texture = walk_texture
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		var rect := collision_shape.shape as RectangleShape2D
		_footprint_offset = collision_shape.position
		_footprint_half = rect.size * 0.5

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		_last_direction = direction
	var move_speed := _get_move_speed()
	velocity = direction * move_speed
	if direction != Vector2.ZERO:
		_apply_corner_correction(direction, delta, move_speed)
	move_and_slide()
	_update_animation(direction, delta, move_speed)

func _get_move_speed() -> float:
	if _is_in_shallow_water():
		return speed * shallow_water_speed_multiplier
	return speed

func _is_in_shallow_water() -> bool:
	return _shallow_water_coverage() >= _current_wade_threshold()

## Smaller threshold while moving mostly vertically so up/down sand<->water
## transitions wade sooner; horizontal movement keeps the full wade_threshold.
func _current_wade_threshold() -> float:
	if absf(_last_direction.y) > absf(_last_direction.x):
		return wade_threshold_vertical
	return wade_threshold

## Fraction of the player's footprint (sampled on a grid) sitting on shallow water.
func _shallow_water_coverage() -> float:
	var center := global_position + _footprint_offset
	var water := 0
	var total := 0
	for ix in FOOTPRINT_SAMPLES:
		for iy in FOOTPRINT_SAMPLES:
			var nx := 0.0 if FOOTPRINT_SAMPLES == 1 else float(ix) / float(FOOTPRINT_SAMPLES - 1) * 2.0 - 1.0
			var ny := 0.0 if FOOTPRINT_SAMPLES == 1 else float(iy) / float(FOOTPRINT_SAMPLES - 1) * 2.0 - 1.0
			var point := center + Vector2(nx * _footprint_half.x, ny * _footprint_half.y)
			var cell := tile_map.local_to_map(tile_map.to_local(point))
			total += 1
			if tile_map.get_cell_atlas_coords(cell) == SHALLOW_TILE:
				water += 1
	return float(water) / float(total)

## When moving straight into a wall corner, gently nudge perpendicular so the
## player rounds the corner instead of snagging on it.
func _apply_corner_correction(direction: Vector2, delta: float, move_speed: float) -> void:
	var motion := velocity * delta
	if not test_move(global_transform, motion):
		return

	if direction.y == 0.0 and direction.x != 0.0:
		_try_nudge(motion, Vector2.DOWN, delta, move_speed)
	elif direction.x == 0.0 and direction.y != 0.0:
		_try_nudge(motion, Vector2.RIGHT, delta, move_speed)

func _try_nudge(motion: Vector2, axis: Vector2, delta: float, move_speed: float) -> void:
	for sign_dir: float in [1.0, -1.0]:
		var probe: Vector2 = axis * sign_dir * corner_correction
		if not test_move(global_transform.translated(probe), motion):
			var step: Vector2 = axis * sign_dir * move_speed * delta
			if not test_move(global_transform, step):
				global_position += step
			return

func _update_animation(direction: Vector2, delta: float, move_speed: float) -> void:
	var in_shallow_water := _is_in_shallow_water()
	var target_texture := wade_texture if in_shallow_water else walk_texture
	if sprite.texture != target_texture:
		sprite.texture = target_texture
		sprite.frame = 0
		_step_timer = 0.0

	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0

	if direction == Vector2.ZERO:
		_step_timer = 0.0
		sprite.frame = 0
		return

	var speed_ratio := move_speed / speed
	_step_timer += delta * speed_ratio
	if _step_timer >= walk_frame_time:
		_step_timer = 0.0
		sprite.frame = 1 if sprite.frame == 0 else 0
