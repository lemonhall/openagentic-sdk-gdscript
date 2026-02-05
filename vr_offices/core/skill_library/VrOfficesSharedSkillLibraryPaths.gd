extends RefCounted
class_name VrOfficesSharedSkillLibraryPaths

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

static func library_root(save_id: String) -> String:
	var sid := save_id.strip_edges()
	if sid == "":
		return ""
	return "%s/shared/skill_library" % _OAPaths.save_root(sid)

static func manifest_path(save_id: String) -> String:
	var root := library_root(save_id)
	if root == "":
		return ""
	return root + "/index.json"

static func staging_root(save_id: String) -> String:
	var sid := save_id.strip_edges()
	if sid == "":
		return ""
	return "%s/shared/skill_library_staging" % _OAPaths.save_root(sid)

static func thumbnail_path(save_id: String, skill_name: String) -> String:
	var root := library_root(save_id)
	var name := skill_name.strip_edges()
	if root == "" or name == "":
		return ""
	return root.rstrip("/") + "/" + name + "/thumbnail.png"
