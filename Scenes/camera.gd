extends Camera3D

@export var shake_strength := 1.0
@export var shake_decay := 15.0

var rng := RandomNumberGenerator.new()
var shake := 0.0

var shake_cooldown := 0.0
@export var min_interval := 0.5


func _process(delta: float) -> void:
	if shake_cooldown > 0.0:
		shake_cooldown -= delta

	if shake <= 0.0:
		return

	shake = lerpf(shake, 0.0, shake_decay * delta)

	var offset := Vector3(
		rng.randf_range(-shake, shake),
		rng.randf_range(-shake, shake),
		0.0
	)

	h_offset = offset.x
	v_offset = offset.y

func trigger_shake(amount: float = -1.0) -> void:
	if shake_cooldown > 0.0:
		return

	shake_cooldown = min_interval

	if amount < 0.0:
		amount = shake_strength

	shake = max(shake, amount)
