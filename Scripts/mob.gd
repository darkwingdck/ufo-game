extends CharacterBody3D

@export var min_speed: int = 1
@export var max_speed: int = 3


func _physics_process(_delta: float) -> void:
	move_and_slide()

func initialize() -> void:
	rotate_y(randf_range(-PI / 2, PI / 2))
	position.y = 0.5
	position.z = randf_range(-27, 27)
	position.x = randf_range(-27, 27)
