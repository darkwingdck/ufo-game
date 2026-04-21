extends CharacterBody3D

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var gamepad_sensitivity := 3.0
@export var deadzone := 0.1

@export_group("Movement")
@export var movement_speed := 16
@export var acceleration := 100.0

var _camera_input_direction := Vector2.ZERO

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D

@export_group("Tilt")
@export var tilt_amount := 0.01
@export var tilt_speed := 50
var current_tilt := Vector3.ZERO

var target_velocity: Vector3 = Vector3.ZERO

@export_group("Hover")
@export var hover_amplitude := 0.2
@export var hover_speed := 6

var hover_time := 0.0
var base_height := 0.0

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
	handle_gamepad_camera_movement()
	handle_camera_movement(delta)
	handle_movement(delta)
	handle_tilt(delta)
	move_and_slide()
	
func handle_camera_movement(delta: float) -> void:
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO
	
func handle_gamepad_camera_movement() -> void:
	var stick_input := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick_input.length() < deadzone:
		return
	_camera_input_direction.x += stick_input.x * gamepad_sensitivity
	

func handle_movement(delta: float) -> void:
	var raw_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var forward: Vector3 = _camera.global_basis.z
	var right: Vector3 = _camera.global_basis.x

	var move_direction: Vector3 = forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()

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
