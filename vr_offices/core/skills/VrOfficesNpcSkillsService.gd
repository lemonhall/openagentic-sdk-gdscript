extends Node
class_name VrOfficesNpcSkillsService

signal profile_updated(save_id: String, npc_id: String, ok: bool, summary: String)

const _SnapshotScript := preload("res://vr_offices/core/skills/VrOfficesNpcSkillsSnapshot.gd")
const _StoreScript := preload("res://vr_offices/core/skills/VrOfficesNpcSkillsProfileStore.gd")
const _ClientScript := preload("res://vr_offices/core/skills/VrOfficesNpcSkillsSummaryClient.gd")

const _GROUP := "vr_offices_npc_skills_service"
const _MAX_RETRIES := 3
const _MAX_SUMMARY_CHARS := 240

var _oa_override: Node = null
var _queue: Array[Dictionary] = []
var _draining: bool = false

var _snapshot: RefCounted = _SnapshotScript.new()
var _store: RefCounted = _StoreScript.new()
var _client: RefCounted = _ClientScript.new()

func _ready() -> void:
	add_to_group(_GROUP)

func bind_openagentic(oa: Node) -> void:
	_oa_override = oa

func queue_regenerate(save_id: String, npc_id: String, force: bool = false) -> void:
	var sid := save_id.strip_edges()
	var nid := npc_id.strip_edges()
	if sid == "" or nid == "":
		return

	# Coalesce: keep only the latest job per (save_id,npc_id).
	for i in range(_queue.size() - 1, -1, -1):
		var j0: Variant = _queue[i]
		if typeof(j0) != TYPE_DICTIONARY:
			continue
		var j: Dictionary = j0 as Dictionary
		if String(j.get("save_id", "")) == sid and String(j.get("npc_id", "")) == nid:
			_queue.remove_at(i)
	_queue.append({"save_id": sid, "npc_id": nid, "force": force})
	_start_drain_if_needed()

func regenerate_profile(save_id: String, npc_id: String, force: bool = false) -> Dictionary:
	var sid := save_id.strip_edges()
	var nid := npc_id.strip_edges()
	if sid == "" or nid == "":
		return {"ok": false, "error": "MissingContext"}

	var skills0: Variant = _snapshot.call("snapshot_skills", sid, nid)
	var skills: Array[Dictionary] = skills0 as Array[Dictionary] if typeof(skills0) == TYPE_ARRAY else []
	var input_hash := String(_snapshot.call("input_hash", skills))

	var meta0: Variant = _store.call("read_meta", sid, nid)
	var meta: Dictionary = meta0 as Dictionary if typeof(meta0) == TYPE_DICTIONARY else {}
	var existing_hash := String(meta.get("skills_profile_input_hash", "")).strip_edges()
	var existing_summary := String(meta.get("skills_profile_summary", "")).strip_edges()
	if not force and existing_hash != "" and existing_hash == input_hash and existing_summary != "":
		return {"ok": true, "cached": true, "input_hash": input_hash, "summary": existing_summary}

	var gen := await _generate_summary_with_retries(sid, skills)
	if not bool(gen.get("ok", false)):
		meta["skills_profile_input_hash"] = input_hash
		meta["skills_profile_last_error"] = String(gen.get("error", "Error"))
		_store.call("write_meta", sid, nid, meta)
		profile_updated.emit(sid, nid, false, existing_summary)
		return {"ok": false, "error": String(gen.get("error", "Error"))}

	var summary := _clamp_summary(String(gen.get("summary", "")))
	meta["skills_profile_summary"] = summary
	meta["skills_profile_input_hash"] = input_hash
	meta["skills_profile_updated_at_unix"] = int(Time.get_unix_time_from_system())
	meta["skills_profile_last_error"] = ""
	_store.call("write_meta", sid, nid, meta)
	profile_updated.emit(sid, nid, true, summary)
	return {"ok": true, "cached": false, "input_hash": input_hash, "summary": summary}

func get_cached_summary(save_id: String, npc_id: String) -> Dictionary:
	var sid := save_id.strip_edges()
	var nid := npc_id.strip_edges()
	if sid == "" or nid == "":
		return {"ok": false, "error": "MissingContext"}
	var meta0: Variant = _store.call("read_meta", sid, nid)
	var meta: Dictionary = meta0 as Dictionary if typeof(meta0) == TYPE_DICTIONARY else {}
	return {
		"ok": true,
		"summary": String(meta.get("skills_profile_summary", "")).strip_edges(),
		"input_hash": String(meta.get("skills_profile_input_hash", "")).strip_edges(),
		"updated_at_unix": int(meta.get("skills_profile_updated_at_unix", 0)),
		"last_error": String(meta.get("skills_profile_last_error", "")).strip_edges(),
	}

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
		var nid := String(job.get("npc_id", "")).strip_edges()
		var force := bool(job.get("force", false))
		if sid == "" or nid == "":
			continue
		await regenerate_profile(sid, nid, force)
	_draining = false

func _get_openagentic() -> Node:
	if _oa_override != null:
		return _oa_override
	return get_node_or_null("/root/OpenAgentic") as Node

func _generate_summary_with_retries(save_id: String, skills: Array[Dictionary]) -> Dictionary:
	var oa := _get_openagentic()
	if oa == null:
		return {"ok": false, "error": "MissingOpenAgentic"}
	var last_err := ""
	for attempt in range(_MAX_RETRIES):
		var rr: Dictionary = await _client.call("generate_summary_text", oa, save_id, skills, _MAX_SUMMARY_CHARS)
		if bool(rr.get("ok", false)):
			var summary := String(rr.get("text", "")).strip_edges()
			if summary != "":
				return {"ok": true, "summary": summary}
			last_err = "EmptySummary"
		else:
			last_err = String(rr.get("error", "Error"))
		if attempt < _MAX_RETRIES - 1 and get_tree() != null:
			var sec := 0.4 * pow(2.0, float(attempt))
			await get_tree().create_timer(sec).timeout
	return {"ok": false, "error": last_err if last_err != "" else "GenerateFailed"}

func _clamp_summary(s: String) -> String:
	var t := s.strip_edges()
	t = t.replace("\r", " ").replace("\n", " ")
	while t.find("  ") != -1:
		t = t.replace("  ", " ")
	if t.length() > _MAX_SUMMARY_CHARS:
		t = t.substr(0, _MAX_SUMMARY_CHARS)
	return t.strip_edges()
