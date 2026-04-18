extends RayCast3D

@export var pull_speed: float = 12.0
@export var stop_distance: float = 2.2
@export var grab_ring_hint_scene: PackedScene

var grabbed_mob: CharacterBody3D = null
var grab_ring: Node3D = null
var grab_ring_hint: Node3D = null

func _ready() -> void:
	grab_ring = get_node("../GrabRing")
	grab_ring_hint = grab_ring_hint_scene.instantiate()
	grab_ring_hint.visible = false
	grab_ring.add_child(grab_ring_hint, true)

func _physics_process(delta: float) -> void:
	if !is_colliding():
		grab_ring_hint.visible = false
		return
	var hit: Object = get_collider()
	if "Mob" not in hit.name:
		grab_ring_hint.visible = false
		return
	grab_ring_hint.visible = true
	grabbed_mob = hit
	
	if Input.is_action_pressed("grab"):
		pull_mob(delta)
	else:
		grabbed_mob = null


func pull_mob(delta: float) -> void:
	if !is_instance_valid(grabbed_mob):
		grabbed_mob = null
		return
	var target_pos: Vector3 = global_transform.origin
	var mob_pos: Vector3 = grabbed_mob.global_transform.origin

	var direction: Vector3 = (target_pos - mob_pos).normalized()

	grabbed_mob.global_transform.origin += direction * pull_speed * delta

	if mob_pos.distance_to(target_pos) < stop_distance:
		grabbed_mob.queue_free()
		grabbed_mob = null
