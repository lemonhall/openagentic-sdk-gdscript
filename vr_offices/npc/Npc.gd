extends CharacterBody3D

@export var npc_id: String = ""
@export_file("*.glb") var model_path: String = ""

@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

@onready var model_root: Node3D = $ModelRoot
@onready var selection_ring: Node3D = $SelectionRing

func _ready() -> void:
	add_to_group("vr_offices_npc")
	_load_model()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(0.0, velocity.y)
	move_and_slide()

func set_selected(is_selected: bool) -> void:
	selection_ring.visible = is_selected

func _load_model() -> void:
	for child in model_root.get_children():
		child.queue_free()

	if model_path.strip_edges() != "":
		var res := load(model_path)
		if res is PackedScene:
			var inst := (res as PackedScene).instantiate()
			if inst != null:
				model_root.add_child(inst)
				return

	# Fallback: a simple capsule mesh so the scene still works without imported assets.
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.25
	mesh.height = 1.1
	mi.mesh = mesh
	model_root.add_child(mi)
