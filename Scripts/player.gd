extends CharacterBody3D

# ==[ CAMERA ]==
@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var gamepad_sensitivity := 3.0
@export var deadzone := 0.1
@onready var _camera_pivot: Node3D = get_node("CameraPivot")
@onready var _camera: Camera3D = get_node("CameraPivot/Camera3D")
@export var enemy_camera: Camera3D = null
@export var random_camera_shake_strength: float = 1
@export var camera_shake_fade: float = 15
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var camera_shake_strength: float = 0.0
var _camera_input_direction := Vector2.ZERO

# ==[ MOVEMENT ]==
@export_group("Movement")
@export var controls: Resource = null
@export var movement_speed := 16
@export var acceleration := 100.0
@export var push_force := 20.0
var target_velocity: Vector3 = Vector3.ZERO
var last_move_direction: Vector3 = Vector3.ZERO


# ==[ DASH ]==
@export_group("Dash")
@export var dash_speed := 40.0
@export var dash_duration := 0.2
@export var dash_cooldown := 0.1
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector3.ZERO

# ==[ STAMINA ]==
@export_group("Stamina")
@export var max_stamina := 100.0
@export var stamina := 100.0
@export var dash_cost := 25.0
@export var stamina_regen := 20.0 # в секунду
@export var regen_delay := 0.5
@onready var stamina_bar: ProgressBar = get_node("../CanvasLayer/StaminaBar")
var regen_timer := 0.0

# ==[ TILT ]==
@export_group("Tilt")
@export var tilt_amount := 0.01
@export var tilt_speed := 50
var current_tilt := Vector3.ZERO

# ==[ HOVER ]==
@export_group("Hover")
@export var hover_amplitude := 0.2
@export var hover_speed := 6
var hover_time := 0.0

func _ready() -> void:
	stamina_bar.max_value = max_stamina

func _input(event:InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)

	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity


func _physics_process(delta: float) -> void:
	if controls.player_index == 0:
		handle_gamepad_camera(delta)
	else:
		handle_keyboard_camera(delta)
	update_stamina(delta)
	update_stamina_ui()
	handle_dash_input()
	update_dash(delta)
	handle_movement(delta)
	handle_tilt(delta)
	move_and_slide()
	handle_player_collisions(delta)

func shake_camera() -> void:
	camera_shake_strength = random_camera_shake_strength
	
func random_offset() -> Vector3:
	return Vector3(
		rng.randf_range(-camera_shake_strength, camera_shake_strength),
		rng.randf_range(-camera_shake_strength, camera_shake_strength),
		rng.randf_range(-camera_shake_strength, camera_shake_strength),
	)

func handle_player_collisions(delta: float) -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var other: Object = collision.get_collider()

		if other is CharacterBody3D and other != self:
			shake_camera()
			push_player(other, collision)
	if camera_shake_strength > 0:
		camera_shake_strength = lerpf(camera_shake_strength, 0, camera_shake_fade * delta)
		enemy_camera.h_offset = random_offset().x
		enemy_camera.v_offset = random_offset().y
			
func push_player(other: CharacterBody3D, collision: KinematicCollision3D) -> void:
	var normal: Vector3 = collision.get_normal()

	# толкаем в сторону от столкновения
	var push_dir: Vector3 = -normal
	push_dir.y = 0.0
	push_dir = push_dir.normalized()

	other.velocity += push_dir * push_force

func update_stamina_ui() -> void:
	stamina_bar.value = stamina

func update_stamina(delta: float) -> void:
	if regen_timer > 0.0:
		regen_timer -= delta
		return

	if stamina < max_stamina:
		stamina += stamina_regen * delta
		stamina = min(stamina, max_stamina)

func handle_dash_input() -> void:
	if is_dashing:
		return
		
	if stamina < dash_cost:
		return

	if Input.is_action_just_pressed(controls.dash):
		start_dash()

func start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration

	stamina -= dash_cost
	regen_timer = regen_delay

	# если есть ввод — дешим туда
	if last_move_direction.length() > 0.1:
		dash_direction = last_move_direction
	else:
		# fallback — вперёд по камере
		var forward: Vector3 = -_camera.global_basis.z
		forward.y = 0.0
		dash_direction = forward.normalized()

func update_dash(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if !is_dashing:
		return

	dash_timer -= delta

	# во время деша полностью переопределяем скорость
	velocity = dash_direction * dash_speed

	if dash_timer <= 0.0:
		is_dashing = false

func handle_keyboard_camera(delta: float) -> void:
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO

func handle_gamepad_camera(delta: float) -> void:
	var stick_input := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)

	if stick_input.length() < deadzone:
		return

	_camera_pivot.rotation.y -= stick_input.x * gamepad_sensitivity * delta

func handle_movement(delta: float) -> void:
	var raw_input: Vector2 = Input.get_vector(controls.move_left, controls.move_right, controls.move_forward, controls.move_back)

	var forward: Vector3 = _camera.global_basis.z
	var right: Vector3 = _camera.global_basis.x

	var move_direction: Vector3 = forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()
	
	if move_direction.length() > 0.1:
		last_move_direction = move_direction

	var horizontal_velocity: Vector3 = velocity
	horizontal_velocity.y = 0.0
	horizontal_velocity = horizontal_velocity.move_toward(
		move_direction * movement_speed,
		acceleration * delta
	)

	velocity = velocity.move_toward(move_direction * movement_speed, acceleration * delta)

func handle_tilt(delta: float) -> void:
	var model := get_node("Pivot/Character")

	if velocity.length() < 0.1:
		current_tilt = current_tilt.lerp(Vector3.ZERO, tilt_speed * delta)
	else:
		var local_vel: Vector3 = global_transform.basis.inverse() * velocity

		var target_tilt := Vector3(
			-local_vel.z * tilt_amount,
			0.0,
			local_vel.x * tilt_amount
		)
		current_tilt = current_tilt.lerp(target_tilt, tilt_speed * delta)

	hover_time += delta * hover_speed
	var hover_offset := sin(hover_time) * hover_amplitude

	model.rotation.x = -current_tilt.x
	model.rotation.z = -current_tilt.z
	model.position.y = hover_offset
	
func is_grabbing() -> bool:
	return Input.is_action_pressed(controls.grab)
