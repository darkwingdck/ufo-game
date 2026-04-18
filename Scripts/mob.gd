extends CharacterBody3D

@export var min_speed: int = 1
@export var max_speed: int = 3
@export var gravity: float = 9.8 # TODO: take from settings

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func initialize() -> void:
	rotate_y(randf_range(-PI / 2, PI / 2))
	position.y = 0.5
	position.z = randf_range(-27, 27)
	position.x = randf_range(-27, 27)
