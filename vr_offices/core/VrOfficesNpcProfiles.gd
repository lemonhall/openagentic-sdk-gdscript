extends RefCounted

var model_paths: Array[String] = []
var culture_code: String = "zh-CN"
var culture_names_by_code: Dictionary = {}

var available_indices: Array[int] = []
var index_by_model_path: Dictionary = {}

func _init(model_paths_in: Array[String], culture_names_in: Dictionary, culture_code_in: String) -> void:
	model_paths = model_paths_in
	culture_names_by_code = culture_names_in
	culture_code = culture_code_in
	reset()

func reset() -> void:
	available_indices.clear()
	index_by_model_path.clear()
	for i in range(model_paths.size()):
		available_indices.append(i)
		index_by_model_path[model_paths[i]] = i

func can_add() -> bool:
	return not available_indices.is_empty()

func reserve_model(model_path: String) -> void:
	var idx := profile_index_for_model(model_path)
	if idx < 0:
		return
	if available_indices.has(idx):
		available_indices.erase(idx)

func release_model(model_path: String) -> void:
	var idx := profile_index_for_model(model_path)
	if idx < 0:
		return
	if not available_indices.has(idx):
		available_indices.append(idx)

func take_random_index() -> int:
	if available_indices.is_empty():
		return -1
	var j := randi_range(0, available_indices.size() - 1)
	var idx := int(available_indices[j])
	available_indices.remove_at(j)
	return idx

func profile_index_for_model(model_path: String) -> int:
	if index_by_model_path.has(model_path):
		return int(index_by_model_path[model_path])
	return -1

func set_culture(code: String) -> void:
	if culture_names_by_code.has(code):
		culture_code = code

func name_for_profile(profile_index: int) -> String:
	var names: Array = culture_names_by_code.get(culture_code, culture_names_by_code.get("en-US", []))
	if profile_index >= 0 and profile_index < names.size():
		return String(names[profile_index])
	return "NPC %d" % (profile_index + 1)

