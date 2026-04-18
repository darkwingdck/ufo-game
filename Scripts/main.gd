extends Node3D

@export var mob_scene: PackedScene

func _ready() -> void:
	for i in range(40):
		var mob: CharacterBody3D = mob_scene.instantiate()
		mob.initialize()
		add_child(mob, true)
