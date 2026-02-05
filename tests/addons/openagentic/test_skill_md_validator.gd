extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ValidatorScript := load("res://addons/openagentic/core/OASkillMdValidator.gd")
	if ValidatorScript == null:
		T.fail_and_quit(self, "Missing OASkillMdValidator.gd")
		return

	var good := """---
name: hello-skill
description: Says hello
---

# Hello
"""
	var rr: Dictionary = (ValidatorScript as Script).call("validate_skill_md_text", good)
	if not T.require_true(self, bool(rr.get("ok", false)), "Expected good SKILL.md ok"):
		return
	if not T.require_eq(self, String(rr.get("name", "")), "hello-skill", "name mismatch"):
		return
	if not T.require_eq(self, String(rr.get("description", "")), "Says hello", "description mismatch"):
		return

	var no_frontmatter := "# No frontmatter\n"
	var rr2: Dictionary = (ValidatorScript as Script).call("validate_skill_md_text", no_frontmatter)
	if not T.require_true(self, not bool(rr2.get("ok", true)), "Expected missing frontmatter to fail"):
		return

	var missing_keys := """---
name: only-name
---
"""
	var rr3: Dictionary = (ValidatorScript as Script).call("validate_skill_md_text", missing_keys)
	if not T.require_true(self, not bool(rr3.get("ok", true)), "Expected missing keys to fail"):
		return

	var unsafe_name := """---
name: ../oops
description: bad
---
"""
	var rr4: Dictionary = (ValidatorScript as Script).call("validate_skill_md_text", unsafe_name)
	if not T.require_true(self, not bool(rr4.get("ok", true)), "Expected unsafe name to fail"):
		return

	T.pass_and_quit(self)

