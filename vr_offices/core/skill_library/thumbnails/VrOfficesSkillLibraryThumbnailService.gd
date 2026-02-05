extends Node
class_name VrOfficesSkillLibraryThumbnailService

signal thumbnail_generated(save_id: String, skill_name: String, ok: bool, path: String)

const _GenScript := preload("res://vr_offices/core/skill_library/thumbnails/VrOfficesSkillThumbnailGenerator.gd")

const _GROUP := "vr_offices_skill_library_thumbnail_service"

var _queue: Array[Dictionary] = []
var _draining := false
var _transport_override: Callable = Callable()
var _options_override: Dictionary = {}

var _gen: RefCounted = _GenScript.new()

func _ready() -> void:
	add_to_group(_GROUP)

func bind_transport(transport: Callable) -> void:
	_transport_override = transport

func bind_options(options: Dictionary) -> void:
	_options_override = options if options != null else {}

func queue_generate(save_id: String, skill_name: String, force: bool = false) -> void:
	var sid := save_id.strip_edges()
	var name := skill_name.strip_edges()
	if sid == "" or name == "":
		return

	for i in range(_queue.size() - 1, -1, -1):
		var j0: Variant = _queue[i]
		if typeof(j0) != TYPE_DICTIONARY:
			continue
		var j: Dictionary = j0 as Dictionary
		if String(j.get("save_id", "")) == sid and String(j.get("skill_name", "")) == name:
			_queue.remove_at(i)
	_queue.append({"save_id": sid, "skill_name": name, "force": force})
	_start_drain_if_needed()

func _start_drain_if_needed() -> void:
	if _draining:
		return
	_draining = true
	call_deferred("_drain_queue")

func _drain_queue() -> void:
	while not _queue.is_empty():
		var job0: Variant = _queue.pop_front()
		if typeof(job0) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = job0 as Dictionary
		var sid := String(job.get("save_id", "")).strip_edges()
		var name := String(job.get("skill_name", "")).strip_edges()
		var force := bool(job.get("force", false))
		if sid == "" or name == "":
			continue

		var transport := _transport_override
		var opts := _options_override
		var st0: Variant = _gen.call("generate_for_skill", sid, name, force, transport, opts)
		var rr0: Variant = await st0 if _is_function_state(st0) else st0
		var ok := typeof(rr0) == TYPE_DICTIONARY and bool((rr0 as Dictionary).get("ok", false))
		var path := String((rr0 as Dictionary).get("path", "")).strip_edges() if typeof(rr0) == TYPE_DICTIONARY else ""
		thumbnail_generated.emit(sid, name, ok, path)
	_draining = false

static func find_service(tree: SceneTree) -> VrOfficesSkillLibraryThumbnailService:
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group(_GROUP)
	if nodes.is_empty():
		return null
	return nodes[0] as VrOfficesSkillLibraryThumbnailService

static func _is_function_state(v: Variant) -> bool:
	return typeof(v) == TYPE_OBJECT and v != null and (v as Object).get_class() == "GDScriptFunctionState"
