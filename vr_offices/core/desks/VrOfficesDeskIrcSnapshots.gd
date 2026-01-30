extends RefCounted

static func list_desk_irc_snapshots(desks: Array[Dictionary], nodes_by_id: Dictionary) -> Array:
	var out: Array = []
	for d0 in desks:
		var d := d0 as Dictionary
		if d == null:
			continue
		var did := String(d.get("id", "")).strip_edges()
		var wid := String(d.get("workspace_id", "")).strip_edges()
		var snap := {
			"desk_id": did,
			"workspace_id": wid,
			"desired_channel": "",
			"status": "no_node",
			"ready": false,
			"log_file_user": "",
			"log_file_abs": "",
			"log_lines": [],
		}

		if did != "" and nodes_by_id.has(did):
			var n0: Variant = nodes_by_id.get(did)
			var node := n0 as Node
			if node != null:
				var link := node.get_node_or_null("DeskIrcLink") as Node
				if link != null and link.has_method("get_debug_snapshot"):
					var l0: Variant = link.call("get_debug_snapshot")
					if typeof(l0) == TYPE_DICTIONARY:
						var l := l0 as Dictionary
						snap["desired_channel"] = String(l.get("desired_channel", ""))
						snap["status"] = String(l.get("status", ""))
						snap["ready"] = bool(l.get("ready", false))
						snap["log_file_user"] = String(l.get("log_file_user", ""))
						snap["log_file_abs"] = String(l.get("log_file_abs", ""))
						snap["log_lines"] = l.get("log_lines", [])
				elif link != null:
					if link.has_method("get_status"):
						snap["status"] = String(link.call("get_status"))
					if link.has_method("is_ready"):
						snap["ready"] = bool(link.call("is_ready"))
					if link.has_method("get_desired_channel"):
						snap["desired_channel"] = String(link.call("get_desired_channel"))

		out.append(snap)

	return out

