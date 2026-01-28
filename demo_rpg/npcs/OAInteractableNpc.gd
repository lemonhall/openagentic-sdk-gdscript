extends Node2D

@export var npc_id: String = "npc_1"
@export var display_name: String = "NPC"

signal player_in_range(npc: Node, in_range: bool)

@onready var _area: Area2D = $InteractionArea

func _ready() -> void:
	add_to_group("openagentic_npc")
	if _area == null:
		push_error("OAInteractableNpc requires a child Area2D named InteractionArea")
		return
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("openagentic_player"):
		player_in_range.emit(self, true)

func _on_body_exited(body: Node) -> void:
	if body != null and body.is_in_group("openagentic_player"):
		player_in_range.emit(self, false)
