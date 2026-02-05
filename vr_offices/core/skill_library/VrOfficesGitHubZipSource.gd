extends RefCounted
class_name VrOfficesGitHubZipSource

const _OAMediaHttp := preload("res://addons/openagentic/core/OAMediaHttp.gd")

static func parse_github_source_url(url: String) -> Dictionary:
	var u := url.strip_edges()
	if u == "":
		return {"ok": false, "error": "MissingUrl"}
	var q := u.find("?")
	if q != -1:
		u = u.substr(0, q)
	var h := u.find("#")
	if h != -1:
		u = u.substr(0, h)
	if u.ends_with(".git"):
		u = u.substr(0, u.length() - 4)
	u = u.rstrip("/")
	var idx := u.find("github.com/")
	if idx == -1:
		return {"ok": false, "error": "NotGitHub"}

	var tail := u.substr(idx + "github.com/".length())
	var parts0 := tail.split("/", false)
	var parts: Array[String] = []
	for p0 in parts0:
		parts.append(String(p0).uri_decode())
	if parts.size() < 2:
		return {"ok": false, "error": "BadRepoUrl"}
	var owner := String(parts[0]).strip_edges()
	var repo := String(parts[1]).strip_edges()
	if owner == "" or repo == "":
		return {"ok": false, "error": "BadRepoUrl"}

	var ref := ""
	var subdir := ""
	if parts.size() >= 4 and (parts[2] == "tree" or parts[2] == "blob"):
		ref = String(parts[3]).strip_edges()
		if parts.size() > 4:
			var rest := parts.slice(4)
			subdir = "/".join(rest).strip_edges()
			if parts[2] == "blob" and subdir.to_lower().ends_with("skill.md"):
				subdir = subdir.get_base_dir()
	# Normalize: no trailing slash.
	subdir = subdir.rstrip("/")

	return {
		"ok": true,
		"owner": owner,
		"repo": repo,
		"repo_url": "https://github.com/%s/%s" % [owner, repo],
		"ref": ref,
		"subdir": subdir,
		"requested_url": url.strip_edges(),
	}

static func codeload_zip_url(owner: String, repo: String, ref: String) -> String:
	var o := owner.strip_edges()
	var r := repo.strip_edges()
	var rf := ref.strip_edges()
	return "https://codeload.github.com/%s/%s/zip/refs/heads/%s" % [o, r, rf]

static func download_repo_zip(repo_url: String, transport: Callable = Callable(), proxy_http: String = "", proxy_https: String = "") -> Dictionary:
	var parsed: Dictionary = parse_github_source_url(repo_url)
	if not bool(parsed.get("ok", false)):
		return parsed
	var owner := String(parsed.get("owner", "")).strip_edges()
	var repo := String(parsed.get("repo", "")).strip_edges()
	var requested_ref := String(parsed.get("ref", "")).strip_edges()
	var tried := [requested_ref] if requested_ref != "" else ["main", "master"]
	var opts := {"proxy_http": proxy_http, "proxy_https": proxy_https}
	var last_err: Dictionary = {}
	for ref in tried:
		if String(ref).strip_edges() == "":
			continue
		var url := codeload_zip_url(owner, repo, ref)
		var resp: Dictionary = await _OAMediaHttp.request(HTTPClient.METHOD_GET, url, {"accept": "application/zip"}, PackedByteArray(), 30.0, transport, opts)
		if not bool(resp.get("ok", false)):
			if str(resp.get("error", "")).strip_edges() == "BadProxy":
				return resp
			last_err = resp
			continue
		var status := int(resp.get("status", 0))
		if status == 200:
			var body: PackedByteArray = resp.get("body", PackedByteArray())
			return {
				"ok": true,
				"owner": owner,
				"repo": repo,
				"repo_url": String(parsed.get("repo_url", "")),
				"requested_url": String(parsed.get("requested_url", "")),
				"ref": ref,
				"subdir": String(parsed.get("subdir", "")),
				"url": url,
				"zip": body,
			}
		if status == 404:
			if requested_ref != "":
				return {"ok": false, "error": "RefNotFound", "ref": requested_ref, "url": url, "status": status}
			continue
		# Non-404 error: stop and surface.
		return {"ok": false, "error": "HttpError", "status": status, "url": url}
	if not last_err.is_empty():
		return last_err
	return {"ok": false, "error": "NotFound", "status": 404}
