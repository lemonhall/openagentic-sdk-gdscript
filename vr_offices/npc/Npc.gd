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
				_autoplay_animation(inst)
				return

	# Fallback: a simple capsule mesh so the scene still works without imported assets.
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.25
	mesh.height = 1.1
	mi.mesh = mesh
	model_root.add_child(mi)

func _autoplay_animation(root: Node) -> void:
	# Kenney Mini Characters 1 includes animations embedded in the model files.
	# Imported scenes usually contain an AnimationPlayer, but nothing plays by default.
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return

	var ap := players[0] as AnimationPlayer
	var anims := ap.get_animation_list()
	if anims.is_empty():
		return

	var chosen := _pick_animation(anims)
	ap.play(chosen)

func _pick_animation(names: PackedStringArray) -> StringName:
	var best_idle := ""
	var best_walk := ""
	for n in names:
		var lower := String(n).to_lower()
		if best_idle == "" and lower.find("idle") != -1:
			best_idle = String(n)
		if best_walk == "" and lower.find("walk") != -1:
			best_walk = String(n)
	if best_idle != "":
		return StringName(best_idle)
	if best_walk != "":
		return StringName(best_walk)
	return StringName(names[0])
