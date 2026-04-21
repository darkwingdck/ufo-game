extends RayCast3D

@export var pull_speed: float = 15.0
@export var stop_distance: float = 2.2

var grabbed_cow: CharacterBody3D = null
var grab_ring_hint: Node3D = null

var grab_beam: MeshInstance3D = null

func _ready() -> void:
	init_grabber()

func init_grabber() -> void:
	grab_ring_hint = get_node("../GrabRingHint")
	grab_beam = get_node("../GrabBeam")
	

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

	if Input.is_action_pressed("grab"):
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
