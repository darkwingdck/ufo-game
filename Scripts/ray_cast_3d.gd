extends RayCast3D

@export var pull_speed: float = 15.0
@export var stop_distance: float = 2.1

var grabbed_cow: CharacterBody3D = null

@onready var grab_ring_hint: Node3D = get_node("../GrabRingHint")
@onready var grab_beam: MeshInstance3D = get_node("../GrabBeam")
@export var player: CharacterBody3D

func _physics_process(delta: float) -> void:
	grab_beam.visible = false
	if !is_colliding():
		grab_ring_hint.visible = false
		return

	var hit: Object = get_collider()
	if "Cow" not in hit.name and "Tractor" not in hit.name:
		grab_ring_hint.visible = false
		return

	grab_ring_hint.visible = true

	if player.is_grabbing():
		grabbed_cow = hit
		grab_beam.visible = true
		pull_cow(delta)
	else:
		grab_beam.visible = false
		grabbed_cow = null


func pull_cow(delta: float) -> void:
	if !is_instance_valid(grabbed_cow):
		grabbed_cow = null
		return
	var target_pos: Vector3 = global_transform.origin
	var cow_pos: Vector3 = grabbed_cow.global_transform.origin

	var direction: Vector3 = (target_pos - cow_pos).normalized()

	grabbed_cow.global_transform.origin += direction * pull_speed * delta

	if cow_pos.distance_to(target_pos) < stop_distance:
		grabbed_cow.queue_free()
		grabbed_cow = null
