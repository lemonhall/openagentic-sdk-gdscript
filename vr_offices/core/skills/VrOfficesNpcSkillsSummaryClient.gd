extends RefCounted
class_name VrOfficesNpcSkillsSummaryClient

const _WorldStateScript := preload("res://vr_offices/core/state/VrOfficesWorldState.gd")

var _world_state: RefCounted = _WorldStateScript.new()

func generate_summary_text(openagentic: Node, save_id: String, skills: Array[Dictionary], max_chars: int) -> Dictionary:
	if openagentic == null:
		return {"ok": false, "error": "MissingOpenAgentic"}
	var provider: Variant = openagentic.get("provider") if openagentic.has_method("get") else null
	var model_v: Variant = openagentic.get("model") if openagentic.has_method("get") else null
	var model := String(model_v).strip_edges() if model_v != null else ""
	if provider == null or model == "":
		return {"ok": false, "error": "ProviderNotConfigured"}

	var prompt := _build_prompt(save_id, skills, max_chars)
	var st: Dictionary = {"done": false, "err": "", "out": ""}
	var on_event := func(ev: Dictionary) -> void:
		var t := String(ev.get("type", ""))
		if t == "text_delta":
			st["out"] = String(st.get("out", "")) + String(ev.get("delta", ""))
		elif t == "done":
			st["done"] = true
			st["err"] = String(ev.get("error", "")).strip_edges()

	var req := {
		"model": model,
		"input": [{"role": "user", "content": prompt}],
		"store": false,
		"stream": true,
	}

	if typeof(provider) == TYPE_OBJECT and (provider as Object).has_method("stream"):
		await provider.stream(req, on_event)
	elif typeof(provider) == TYPE_DICTIONARY:
		var d: Dictionary = provider as Dictionary
		var c0: Variant = d.get("stream", null)
		if typeof(c0) == TYPE_CALLABLE and not (c0 as Callable).is_null():
			await (c0 as Callable).call(req, on_event)
	else:
		return {"ok": false, "error": "InvalidProvider"}

	if not bool(st.get("done", false)):
		return {"ok": false, "error": "NoDoneEvent"}
	var err := String(st.get("err", "")).strip_edges()
	if err != "":
		return {"ok": false, "error": err}
	return {"ok": true, "text": String(st.get("out", "")).strip_edges()}

func _build_prompt(save_id: String, skills: Array[Dictionary], max_chars: int) -> String:
	var cc := _culture_code_for_save(save_id)
	var lang := "中文" if cc == "zh-CN" else "English"
	var lines := PackedStringArray()
	lines.append("你是公司管理者在看一个NPC的技能组合。")
	lines.append("请用%s写一段“能力简介”，面向人类读者，像简历开头那样概括此人擅长什么。" % lang)
	lines.append("要求：不使用列表、不使用Markdown、不加引号，单段文字，最多%d字/字符。" % max_chars)
	lines.append("只输出最终简介，不要输出分析过程。")
	lines.append("")
	lines.append("技能列表：")
	for s0 in skills:
		if typeof(s0) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = s0 as Dictionary
		var name := String(s.get("name", "")).strip_edges()
		var desc := String(s.get("description", "")).strip_edges()
		if name == "":
			continue
		if desc == "":
			lines.append("- %s" % name)
		else:
			lines.append("- %s：%s" % [name, desc])
	if skills.is_empty():
		lines.append("- （无技能）")
	return "\n".join(lines)

func _culture_code_for_save(save_id: String) -> String:
	if _world_state == null:
		return "zh-CN"
	var st0: Variant = _world_state.call("read_state", save_id)
	var st: Dictionary = st0 as Dictionary if typeof(st0) == TYPE_DICTIONARY else {}
	var cc := String(st.get("culture_code", "zh-CN")).strip_edges()
	return cc if cc != "" else "zh-CN"

