extends SceneTree

const T := preload("res://tests/_test_util.gd")
const OAData := preload("res://vr_offices/core/data/VrOfficesData.gd")

func _init() -> void:
	var prompt := String(OAData.SYSTEM_PROMPT_ZH)
	if not T.require_true(self, prompt.find("RemoteBash") != -1, "SYSTEM_PROMPT_ZH must mention RemoteBash (desk-bound tool)"):
		return
	var old_hardcoded := "工具：Read / Write / Edit / ListFiles / Mkdir / Glob / Grep / WebFetch / WebSearch / TodoWrite / Skill"
	if not T.require_true(self, prompt.find(old_hardcoded) == -1, "SYSTEM_PROMPT_ZH must not hardcode an outdated tool list (it hides RemoteBash)"):
		return
	T.pass_and_quit(self)

