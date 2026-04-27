extends CharacterBody3D

signal player_hit

# ==[ MOVEMENT ]==
@export_group("Movement")
@export var controls: Resource
@export var move_speed := 16.0
@export var acceleration := 100.0
@export var push_force := 10.0

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

@export var stamina_bar: ProgressBar = null

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


func _physics_process(delta: float) -> void:
	update_stamina(delta)
	update_dash(delta)
	update_movement(delta)
	update_tilt(delta)

	move_and_slide()
	handle_collisions()
	update_stamina_ui()


# ==[ MOVEMENT ]==

func update_movement(delta: float) -> void:
	var input := Input.get_vector(
		controls.move_left,
		controls.move_right,
		controls.move_forward,
		controls.move_back
	)

	var forward := Vector3.BACK
	var right := Vector3.RIGHT

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
		dash_dir = Vector3.FORWARD



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

func handle_collisions() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()

		if other is CharacterBody3D and other != self:
			if is_dashing:
				apply_push(other, col)
				player_hit.emit()


func apply_push(other: CharacterBody3D, col: KinematicCollision3D) -> void:
	var dir := -col.get_normal()
	dir.y = 0.0
	dir = dir.normalized()

	other.velocity += dir * push_force


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
