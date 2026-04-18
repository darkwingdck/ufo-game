extends CharacterBody3D

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var gamepad_sensitivity := 3.0
@export var deadzone := 0.1

@export_group("Movement")
@export var movement_speed := 14
@export var acceleration := 30.0

var _camera_input_direction := Vector2.ZERO

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D

var target_velocity: Vector3 = Vector3.ZERO

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
	handle_gamepad_camera_input()
	handle_camera_movement(delta)
	handle_movement(delta)
	move_and_slide()
	
func handle_camera_movement(delta: float) -> void:
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 3, PI / 6)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	
	_camera_input_direction = Vector2.ZERO
	
func handle_gamepad_camera_input() -> void:
	var stick_input := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick_input.length() < deadzone:
		return
	stick_input.y *= -1.0
	_camera_input_direction += stick_input * gamepad_sensitivity
	

func handle_movement(delta: float) -> void:
	var raw_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var vertical_input: float = Input.get_axis("move_down", "move_up")

	var forward: Vector3 = _camera.global_basis.z
	var right: Vector3 = _camera.global_basis.x

	var move_direction: Vector3 = forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()

	# --- Горизонталь ---
	var horizontal_velocity: Vector3 = velocity
	horizontal_velocity.y = 0.0
	horizontal_velocity = horizontal_velocity.move_toward(
		move_direction * movement_speed,
		acceleration * delta
	)

	# --- Вертикаль (с инерцией) ---
	var target_y: float = vertical_input * movement_speed
	var new_y: float = move_toward(velocity.y, target_y, acceleration * delta)

	# --- Итог ---
	velocity = Vector3(
		horizontal_velocity.x,
		new_y,
		horizontal_velocity.z
	)
