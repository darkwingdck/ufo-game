extends CharacterBody3D

# ==[ CAMERA ]==
@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var gamepad_sensitivity := 3.0
@export var deadzone := 0.1
@export var enemy_camera: Camera3D = null
@export var camera_shake_strength_random := 1.0
@export var camera_shake_decay := 15.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var rng := RandomNumberGenerator.new()
var camera_shake := 0.0
var camera_input := Vector2.ZERO

# ==[ MOVEMENT ]==
@export_group("Movement")
@export var controls: Resource
@export var move_speed := 16.0
@export var acceleration := 100.0
@export var push_force := 20.0

var last_move_dir := Vector3.ZERO

# ==[ DASH ]==
@export_group("Dash")
@export var dash_speed := 40.0
@export var dash_time := 0.2
@export var dash_cooldown := 0.1

var dash_timer := 0.0
var dash_cd_timer := 0.0
var dash_dir := Vector3.ZERO
var is_dashing := false

# ==[ STAMINA ]==
@export_group("Stamina")
@export var max_stamina := 100.0
@export var stamina := 100.0
@export var dash_cost := 25.0
@export var stamina_regen := 20.0
@export var regen_delay := 0.5

@onready var stamina_bar: ProgressBar = $"../CanvasLayer/StaminaBar"

var regen_timer := 0.0

# ==[ TILT ]==
@export_group("Tilt")
@export var tilt_amount := 0.01
@export var tilt_speed := 50.0

var tilt := Vector3.ZERO

# ==[ HOVER ]==
@export_group("Hover")
@export var hover_amplitude := 0.2
@export var hover_speed := 9.0

var hover_time := 0.0


func _ready() -> void:
	stamina_bar.max_value = max_stamina


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_input = event.screen_relative * mouse_sensitivity


func _physics_process(delta: float) -> void:
	update_camera(delta)
	update_stamina(delta)
	update_dash(delta)
	update_movement(delta)
	update_tilt(delta)

	move_and_slide()
	handle_collisions(delta)
	update_stamina_ui()


# ==[ CAMERA ]==

func update_camera(delta: float) -> void:
	if controls.player_index == 0:
		handle_gamepad_camera(delta)
	else:
		handle_mouse_camera(delta)


func handle_mouse_camera(delta: float) -> void:
	camera_pivot.rotation.y -= camera_input.x * delta
	camera_input = Vector2.ZERO


func handle_gamepad_camera(delta: float) -> void:
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)

	if stick.length() < deadzone:
		return

	camera_pivot.rotation.y -= stick.x * gamepad_sensitivity * delta


# ==[ MOVEMENT ]==

func update_movement(delta: float) -> void:
	var input := Input.get_vector(
		controls.move_left,
		controls.move_right,
		controls.move_forward,
		controls.move_back
	)

	var forward := camera.global_basis.z
	var right := camera.global_basis.x

	var dir := (forward * input.y + right * input.x)
	dir.y = 0.0
	dir = dir.normalized()

	if dir.length() > 0.1:
		last_move_dir = dir

	var target_velocity := dir * move_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)


# ==[ DASH ]==

func update_dash(delta: float) -> void:
	handle_dash_input()

	if dash_cd_timer > 0.0:
		dash_cd_timer -= delta

	if not is_dashing:
		return

	dash_timer -= delta
	velocity = dash_dir * dash_speed

	if dash_timer <= 0.0:
		is_dashing = false


func handle_dash_input() -> void:
	if is_dashing or stamina < dash_cost:
		return

	if Input.is_action_just_pressed(controls.dash):
		start_dash()


func start_dash() -> void:
	is_dashing = true
	dash_timer = dash_time

	stamina -= dash_cost
	regen_timer = regen_delay

	if last_move_dir.length() > 0.1:
		dash_dir = last_move_dir
	else:
		var forward := -camera.global_basis.z
		forward.y = 0.0
		dash_dir = forward.normalized()


# ==[ STAMINA ]==

func update_stamina(delta: float) -> void:
	if regen_timer > 0.0:
		regen_timer -= delta
		return

	if stamina < max_stamina:
		stamina = min(stamina + stamina_regen * delta, max_stamina)


func update_stamina_ui() -> void:
	stamina_bar.value = stamina


# ==[ COLLISIONS ]==

func handle_collisions(delta: float) -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()

		if other is CharacterBody3D and other != self:
			apply_push(other, col)
			trigger_camera_shake()

	update_camera_shake(delta)


func apply_push(other: CharacterBody3D, col: KinematicCollision3D) -> void:
	var dir := -col.get_normal()
	dir.y = 0.0
	dir = dir.normalized()

	other.velocity += dir * push_force


# ==[ CAMERA SHAKE ]==

func trigger_camera_shake() -> void:
	camera_shake = camera_shake_strength_random


func update_camera_shake(delta: float) -> void:
	if camera_shake <= 0.0:
		return

	camera_shake = lerpf(camera_shake, 0.0, camera_shake_decay * delta)

	var offset := Vector3(
		rng.randf_range(-camera_shake, camera_shake),
		rng.randf_range(-camera_shake, camera_shake),
		rng.randf_range(-camera_shake, camera_shake)
	)

	enemy_camera.h_offset = offset.x
	enemy_camera.v_offset = offset.y


# ==[ TILT + HOVER ]==

func update_tilt(delta: float) -> void:
	var model := $Pivot/Character

	if velocity.length() < 0.1:
		tilt = tilt.lerp(Vector3.ZERO, tilt_speed * delta)
	else:
		var local_vel := global_transform.basis.inverse() * velocity

		var target := Vector3(
			-local_vel.z * tilt_amount,
			0.0,
			local_vel.x * tilt_amount
		)

		tilt = tilt.lerp(target, tilt_speed * delta)

	hover_time += delta * hover_speed
	var hover := sin(hover_time) * hover_amplitude

	model.rotation.x = -tilt.x
	model.rotation.z = -tilt.z
	model.position.y = hover


func is_grabbing() -> bool:
	return Input.is_action_pressed(controls.grab)
