extends RefCounted
class_name OAStandardTools

const _OATool := preload("res://addons/openagentic/core/OATool.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")
const _OAWorkspaceFs := preload("res://addons/openagentic/core/OAWorkspaceFs.gd")
const _OASkills := preload("res://addons/openagentic/core/OASkills.gd")
const _SessionStoreScript := preload("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")

static func register_into(openagentic: Node) -> void:
	if openagentic == null or not openagentic.has_method("register_tool"):
		return
	for t in tools():
		openagentic.call("register_tool", t)

static func _workspace_fs(ctx: Dictionary) -> OAWorkspaceFs:
	var root := String(ctx.get("workspace_root", "")).strip_edges()
	return _OAWorkspaceFs.new(root)

static func _require_workspace_root(ctx: Dictionary) -> Dictionary:
	var root := String(ctx.get("workspace_root", "")).strip_edges()
	return {"ok": root != "", "root": root}

static func tools() -> Array:
	var out: Array = []

	var read_fn: Callable = func(input: Dictionary, ctx: Dictionary) -> Variant:
		var chk := _require_workspace_root(ctx)
		if not bool(chk.ok):
			return {"ok": false, "error": "MissingWorkspace"}
		var fs := _workspace_fs(ctx)
		var file_path := String(input.get("file_path", input.get("filePath", input.get("path", "")))).strip_edges()
		if file_path == "":
			return {"ok": false, "error": "InvalidInput", "message": "Read: 'file_path' must be a non-empty string"}
		var res: Dictionary = fs.read_text(file_path)
		if not bool(res.get("ok", false)):
			return res

		# Optional line slicing.
		var content := String(res.get("text", ""))
		var offset0: Variant = input.get("offset", null)
		var limit0: Variant = input.get("limit", null)
		if offset0 == null and limit0 == null:
			return {"file_path": file_path, "content": content}

		var offset := int(offset0) if (typeof(offset0) == TYPE_INT or typeof(offset0) == TYPE_FLOAT) else 1
		if offset < 1:
			offset = 1
		var limit := int(limit0) if (typeof(limit0) == TYPE_INT or typeof(limit0) == TYPE_FLOAT) else -1

		var lines := content.split("\n", false)
		var start := offset - 1
		start = clampi(start, 0, max(0, lines.size()))
		var end := lines.size()
		if limit >= 0:
			end = min(lines.size(), start + limit)
		var slice := lines.slice(start, end)
		var numbered := PackedStringArray()
		for i in range(slice.size()):
			numbered.append("%d: %s" % [start + i + 1, slice[i]])
		return {"file_path": file_path, "content": "\n".join(numbered), "total_lines": lines.size(), "lines_returned": slice.size()}

	var read_schema: Dictionary = {
		"type": "object",
		"properties": {
			"file_path": {"type": "string"},
			"filePath": {"type": "string"},
			"path": {"type": "string"},
			"offset": {"type": ["integer", "number"]},
			"limit": {"type": ["integer", "number"]},
		},
	}
	out.append(_OATool.new("Read", "Read a file from the NPC private workspace.", read_fn, read_schema))

	var write_fn: Callable = func(input: Dictionary, ctx: Dictionary) -> Variant:
		var chk := _require_workspace_root(ctx)
		if not bool(chk.ok):
			return {"ok": false, "error": "MissingWorkspace"}
		var fs := _workspace_fs(ctx)
		var file_path := String(input.get("file_path", input.get("filePath", input.get("path", "")))).strip_edges()
		if file_path == "":
			return {"ok": false, "error": "InvalidInput", "message": "Write: 'file_path' must be a non-empty string"}
		var content0: Variant = input.get("content", input.get("text", null))
		if typeof(content0) != TYPE_STRING:
			return {"ok": false, "error": "InvalidInput", "message": "Write: 'content' must be a string"}
		var overwrite := bool(input.get("overwrite", true))
		if not overwrite:
			var rr: Dictionary = fs.resolve(file_path)
			if bool(rr.get("ok", false)) and FileAccess.file_exists(String(rr.get("path", ""))):
				return {"ok": false, "error": "FileExists"}
		return fs.write_text(file_path, String(content0))

	var write_schema: Dictionary = {
		"type": "object",
		"properties": {
			"file_path": {"type": "string"},
			"filePath": {"type": "string"},
			"path": {"type": "string"},
			"content": {"type": "string"},
			"text": {"type": "string"},
			"overwrite": {"type": "boolean"},
		},
		"required": ["content"],
	}
	out.append(_OATool.new("Write", "Create or overwrite a file in the NPC private workspace.", write_fn, write_schema))

	var edit_fn: Callable = func(input: Dictionary, ctx: Dictionary) -> Variant:
		var chk := _require_workspace_root(ctx)
		if not bool(chk.ok):
			return {"ok": false, "error": "MissingWorkspace"}
		var fs := _workspace_fs(ctx)
		var file_path := String(input.get("file_path", input.get("filePath", input.get("path", "")))).strip_edges()
		if file_path == "":
			return {"ok": false, "error": "InvalidInput", "message": "Edit: 'file_path' must be a non-empty string"}

		var old0: Variant = input.get("old", input.get("old_string", input.get("oldString", null)))
		var new0: Variant = input.get("new", input.get("new_string", input.get("newString", null)))
		if typeof(old0) != TYPE_STRING or String(old0) == "":
			return {"ok": false, "error": "InvalidInput", "message": "Edit: 'old' must be a non-empty string"}
		if typeof(new0) != TYPE_STRING:
			return {"ok": false, "error": "InvalidInput", "message": "Edit: 'new' must be a string"}

		var before0: Variant = input.get("before", null)
		var after0: Variant = input.get("after", null)

		var rr: Dictionary = fs.read_text(file_path)
		if not bool(rr.get("ok", false)):
			return rr
		var text := String(rr.get("text", ""))

		var old := String(old0)
		var idx_old := text.find(old)
		if idx_old < 0:
			return {"ok": false, "error": "NotFound", "message": "Edit: 'old' not found"}
		if typeof(before0) == TYPE_STRING and String(before0) != "":
			var idx_b := text.find(String(before0))
			if idx_b < 0 or idx_b >= idx_old:
				return {"ok": false, "error": "InvalidAnchor", "message": "Edit: 'before' must exist before 'old'"}
		if typeof(after0) == TYPE_STRING and String(after0) != "":
			var idx_a := text.find(String(after0))
			if idx_a < 0 or idx_old >= idx_a:
				return {"ok": false, "error": "InvalidAnchor", "message": "Edit: 'after' must exist after 'old'"}

		var replace_all := bool(input.get("replace_all", input.get("replaceAll", false)))
		var count0: Variant = input.get("count", 1)
		var count := 0 if replace_all else (int(count0) if (typeof(count0) == TYPE_INT or typeof(count0) == TYPE_FLOAT) else 1)
		if count < 0:
			count = 1

		var out_text := ""
		var replacements := 0
		if count == 0:
			out_text = text.replace(old, String(new0))
			replacements = text.split(old, false).size() - 1
		else:
			var cur := text
			for _i in range(count):
				var j := cur.find(old)
				if j < 0:
					break
				cur = cur.substr(0, j) + String(new0) + cur.substr(j + old.length())
				replacements += 1
			out_text = cur

		var wr: Dictionary = fs.write_text(file_path, out_text)
		if not bool(wr.get("ok", false)):
			return wr
		return {"ok": true, "file_path": file_path, "replacements": replacements}

	var edit_schema: Dictionary = {
		"type": "object",
		"properties": {
			"file_path": {"type": "string"},
			"filePath": {"type": "string"},
			"path": {"type": "string"},
			"old": {"type": "string"},
			"old_string": {"type": "string"},
			"oldString": {"type": "string"},
			"new": {"type": "string"},
			"new_string": {"type": "string"},
			"newString": {"type": "string"},
			"replace_all": {"type": "boolean"},
			"replaceAll": {"type": "boolean"},
			"count": {"type": "integer"},
			"before": {"type": "string"},
			"after": {"type": "string"},
		},
		"required": ["old", "new"],
	}
	out.append(_OATool.new("Edit", "Apply a precise edit (string replace) to a file in the NPC private workspace.", edit_fn, edit_schema))

	var glob_fn: Callable = func(input: Dictionary, ctx: Dictionary) -> Variant:
		var chk := _require_workspace_root(ctx)
		if not bool(chk.ok):
			return {"ok": false, "error": "MissingWorkspace"}
		var fs := _workspace_fs(ctx)
		var pattern := String(input.get("pattern", "")).strip_edges()
		if pattern == "":
			return {"ok": false, "error": "InvalidInput", "message": "Glob: 'pattern' must be a non-empty string"}
		var root := String(input.get("root", input.get("path", ""))).strip_edges()
		var max_files0: Variant = input.get("max_files", 20000)
		var max_files := int(max_files0) if (typeof(max_files0) == TYPE_INT or typeof(max_files0) == TYPE_FLOAT) else 20000
		max_files = clampi(max_files, 1, 200000)

		var rx := _glob_to_regex(pattern)
		var files: Array[String] = []
		_list_files_recursive(fs, root, files, max_files)
		var matches: Array[String] = []
		for p in files:
			var rel := p
			if root != "" and rel.begins_with(root.rstrip("/") + "/"):
				rel = rel.substr(root.rstrip("/").length() + 1)
			if rx.search(rel) != null:
				matches.append(p)
		matches.sort()
		return {"ok": true, "root": root, "pattern": pattern, "matches": matches, "count": matches.size()}

	var glob_schema: Dictionary = {
		"type": "object",
		"properties": {
			"pattern": {"type": "string"},
			"root": {"type": "string"},
			"path": {"type": "string"},
			"max_files": {"type": "integer"},
		},
		"required": ["pattern"],
	}
	out.append(_OATool.new("Glob", "Find files by glob pattern in the NPC private workspace.", glob_fn, glob_schema))

	var grep_fn: Callable = func(input: Dictionary, ctx: Dictionary) -> Variant:
		var chk := _require_workspace_root(ctx)
		if not bool(chk.ok):
			return {"ok": false, "error": "MissingWorkspace"}
		var fs := _workspace_fs(ctx)
		var query := String(input.get("query", ""))
		if query == "":
			return {"ok": false, "error": "InvalidInput", "message": "Grep: 'query' must be a non-empty string"}

		var file_glob := String(input.get("file_glob", "**/*")).strip_edges()
		if file_glob == "":
			return {"ok": false, "error": "InvalidInput", "message": "Grep: 'file_glob' must be a non-empty string"}
		var root := String(input.get("root", input.get("path", ""))).strip_edges()
		var mode := String(input.get("mode", "content")).strip_edges()
		if mode == "":
			mode = "content"
		if mode != "content" and mode != "files_with_matches":
			return {"ok": false, "error": "InvalidInput", "message": "Grep: 'mode' must be 'content' or 'files_with_matches'"}

		var before_n := int(input.get("before_context", 0))
		var after_n := int(input.get("after_context", 0))
		before_n = max(0, before_n)
		after_n = max(0, after_n)

		var case_sensitive := bool(input.get("case_sensitive", true))
		var re := RegEx.new()
		var pat := query
		if not case_sensitive:
			# Godot 4's RegEx doesn't expose compile flags; use inline modifier.
			if not pat.begins_with("(?i)"):
				pat = "(?i)" + pat
		var err := re.compile(pat)
		if err != OK:
			return {"ok": false, "error": "InvalidRegex"}

		var file_rx := _glob_to_regex(file_glob)
		var files: Array[String] = []
		_list_files_recursive(fs, root, files, 20000)
		files.sort()

		var matches: Array = []
		var files_with: Array[String] = []
		var seen_files: Dictionary = {}
		var max_matches := 5000

		for p in files:
			var rel := p
			if root != "" and rel.begins_with(root.rstrip("/") + "/"):
				rel = rel.substr(root.rstrip("/").length() + 1)
			if file_rx.search(rel) == null:
				continue

			var rr: Dictionary = fs.read_text(p)
			if not bool(rr.get("ok", false)):
				continue
			var text := String(rr.get("text", ""))
			var lines := text.split("\n", false)
			for i in range(lines.size()):
				var line := String(lines[i])
				if re.search(line) == null:
					continue
				if not seen_files.has(p):
					seen_files[p] = true
					files_with.append(p)
				if mode == "files_with_matches":
					continue
				var before_ctx: Variant = null
				var after_ctx: Variant = null
				if before_n > 0:
					before_ctx = lines.slice(max(0, i - before_n), i)
				if after_n > 0:
					after_ctx = lines.slice(i + 1, min(lines.size(), i + 1 + after_n))
				matches.append({"file_path": p, "line": i + 1, "text": line, "before_context": before_ctx, "after_context": after_ctx})
				if matches.size() >= max_matches:
					return {"ok": true, "root": root, "query": query, "matches": matches, "truncated": true}
		if mode == "files_with_matches":
			files_with.sort()
			return {"ok": true, "root": root, "query": query, "files": files_with, "count": files_with.size()}
		return {"ok": true, "root": root, "query": query, "matches": matches, "truncated": false, "total_matches": matches.size()}

	var grep_schema: Dictionary = {
		"type": "object",
		"properties": {
			"query": {"type": "string"},
			"file_glob": {"type": "string"},
			"root": {"type": "string"},
			"path": {"type": "string"},
			"case_sensitive": {"type": "boolean"},
			"mode": {"type": "string"},
			"before_context": {"type": "integer"},
			"after_context": {"type": "integer"},
		},
		"required": ["query"],
	}
	out.append(_OATool.new("Grep", "Search file contents with a regex over the NPC private workspace.", grep_fn, grep_schema))

	var todo_fn: Callable = func(input: Dictionary, ctx: Dictionary) -> Variant:
		var todos0: Variant = input.get("todos", null)
		if typeof(todos0) != TYPE_ARRAY or (todos0 as Array).is_empty():
			return {"ok": false, "error": "InvalidInput", "message": "TodoWrite: 'todos' must be a non-empty list"}
		var todos: Array = todos0 as Array

		var pending := 0
		var in_progress := 0
		var completed := 0
		var cancelled := 0
		for t0 in todos:
			if typeof(t0) != TYPE_DICTIONARY:
				return {"ok": false, "error": "InvalidInput", "message": "TodoWrite: each todo must be an object"}
			var t: Dictionary = t0 as Dictionary
			var content := String(t.get("content", "")).strip_edges()
			var status := String(t.get("status", "")).strip_edges()
			if content == "":
				return {"ok": false, "error": "InvalidInput", "message": "TodoWrite: todo 'content' must be non-empty"}
			if not (status in ["pending", "in_progress", "completed", "cancelled"]):
				return {"ok": false, "error": "InvalidInput", "message": "TodoWrite: invalid status"}
			if status == "pending":
				pending += 1
			elif status == "in_progress":
				in_progress += 1
			elif status == "completed":
				completed += 1
			else:
				cancelled += 1

		# Persist in workspace.
		var chk := _require_workspace_root(ctx)
		if bool(chk.ok):
			var fs := _workspace_fs(ctx)
			fs.write_text("todos.json", JSON.stringify({"todos": todos}) + "\n")

		# Also append into the session event log for replay.
		var sid := String(ctx.get("save_id", "")).strip_edges()
		var nid := String(ctx.get("npc_id", ctx.get("session_id", ""))).strip_edges()
		if sid != "" and nid != "":
			var store = _SessionStoreScript.new(sid)
			store.append_event(nid, {"type": "todo.write", "todos": todos})

		return {"message": "Updated todos", "stats": {"total": todos.size(), "pending": pending, "in_progress": in_progress, "completed": completed, "cancelled": cancelled}}

	var todo_schema: Dictionary = {
		"type": "object",
		"properties": {
			"todos": {
				"type": "array",
				"items": {
					"type": "object",
					"properties": {
						"content": {"type": "string"},
						"status": {"type": "string", "enum": ["pending", "in_progress", "completed", "cancelled"]},
					},
					"required": ["content", "status"],
				},
			},
		},
		"required": ["todos"],
	}
	out.append(_OATool.new("TodoWrite", "Write or update a TODO list for this NPC (persisted in its private workspace).", todo_fn, todo_schema))

	var skill_fn: Callable = func(input: Dictionary, ctx: Dictionary) -> Variant:
		var sid := String(ctx.get("save_id", "")).strip_edges()
		var nid := String(ctx.get("npc_id", ctx.get("session_id", ""))).strip_edges()
		if sid == "" or nid == "":
			return {"ok": false, "error": "MissingContext"}

		var name := String(input.get("name", "")).strip_edges()
		var names: Array[String] = _OASkills.list_skill_names(sid, nid)
		if name == "":
			return {"skills": names}
		if not names.has(name):
			return {"ok": false, "error": "NotFound", "available_skills": names}
		var body := _OASkills.read_skill_md(sid, nid, name, 256 * 1024)
		var base_dir := _OAPaths.npc_skill_dir(sid, nid, name)
		return {
			"title": "Loaded skill: %s" % name,
			"output": ("## Skill: %s\n\n**Base directory**: %s\n\n%s" % [name, base_dir, body]).strip_edges(),
			"metadata": {"name": name, "dir": base_dir},
			"name": name,
			"path": _OAPaths.npc_skill_md_path(sid, nid, name),
		}

	var skill_schema: Dictionary = {"type": "object", "properties": {"name": {"type": "string"}}}
	out.append(_OATool.new("Skill", "Load an NPC Skill by name. Skills live at workspace/skills/<skill-name>/SKILL.md.", skill_fn, skill_schema))

	for t in OAWebTools.tools():
		out.append(t)

	return out

static func _glob_to_regex(pattern: String) -> RegEx:
	# Supports *, ?, ** with / separators.
	var p := pattern
	var esc := ""
	var i := 0
	while i < p.length():
		var ch := p[i]
		if ch == "*":
			if i + 1 < p.length() and p[i + 1] == "*":
				esc += ".*"
				i += 2
				continue
			esc += "[^/]*"
		elif ch == "?":
			esc += "."
		elif ch in [".", "(", ")", "[", "]", "{", "}", "+", "^", "$", "|", "\\"]:
			esc += "\\" + ch
		else:
			esc += ch
		i += 1
	var re := RegEx.new()
	re.compile("^%s$" % esc)
	return re

static func _list_files_recursive(fs: OAWorkspaceFs, rel_root: String, out: Array[String], max_files: int) -> void:
	# BFS to avoid recursion depth.
	var queue: Array[String] = []
	var root := rel_root.strip_edges().rstrip("/")
	queue.append(root)
	while not queue.is_empty() and out.size() < max_files:
		var cur := queue.pop_front()
		var lst: Dictionary = fs.list_dir(cur)
		if not bool(lst.get("ok", false)):
			continue
		var entries0: Variant = lst.get("entries", [])
		if typeof(entries0) != TYPE_ARRAY:
			continue
		var entries: Array = entries0 as Array
		for e0 in entries:
			if typeof(e0) != TYPE_DICTIONARY:
				continue
			var e: Dictionary = e0 as Dictionary
			var name := String(e.get("name", ""))
			if name == "":
				continue
			var is_dir := bool(e.get("is_dir", false))
			var child := name if cur == "" else ("%s/%s" % [cur, name])
			if is_dir:
				queue.append(child)
			else:
				out.append(child)
				if out.size() >= max_files:
					return
