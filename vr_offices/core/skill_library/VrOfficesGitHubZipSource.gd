extends RefCounted
class_name VrOfficesGitHubZipSource

const _OAMediaHttp := preload("res://addons/openagentic/core/OAMediaHttp.gd")

static func parse_owner_repo(repo_url: String) -> Dictionary:
	var u := repo_url.strip_edges()
	if u.ends_with(".git"):
		u = u.substr(0, u.length() - 4)
	u = u.rstrip("/")
	var idx := u.find("github.com/")
	if idx == -1:
		return {"ok": false, "error": "NotGitHub"}
	var tail := u.substr(idx + "github.com/".length())
	var parts := tail.split("/", false)
	if parts.size() < 2:
		return {"ok": false, "error": "BadRepoUrl"}
	var owner := String(parts[0]).strip_edges()
	var repo := String(parts[1]).strip_edges()
	if owner == "" or repo == "":
		return {"ok": false, "error": "BadRepoUrl"}
	return {"ok": true, "owner": owner, "repo": repo, "repo_url": "https://github.com/%s/%s" % [owner, repo]}

static func codeload_zip_url(owner: String, repo: String, ref: String) -> String:
	var o := owner.strip_edges()
	var r := repo.strip_edges()
	var rf := ref.strip_edges()
	return "https://codeload.github.com/%s/%s/zip/refs/heads/%s" % [o, r, rf]

static func download_repo_zip(repo_url: String, transport: Callable = Callable()) -> Dictionary:
	var parsed: Dictionary = parse_owner_repo(repo_url)
	if not bool(parsed.get("ok", false)):
		return parsed
	var owner := String(parsed.get("owner", "")).strip_edges()
	var repo := String(parsed.get("repo", "")).strip_edges()
	var tried := ["main", "master"]
	for ref in tried:
		var url := codeload_zip_url(owner, repo, ref)
		var resp: Dictionary = await _OAMediaHttp.request(HTTPClient.METHOD_GET, url, {"accept": "application/zip"}, PackedByteArray(), 30.0, transport)
		if not bool(resp.get("ok", false)):
			continue
		var status := int(resp.get("status", 0))
		if status == 200:
			var body: PackedByteArray = resp.get("body", PackedByteArray())
			return {"ok": true, "owner": owner, "repo": repo, "repo_url": String(parsed.get("repo_url", "")), "ref": ref, "url": url, "zip": body}
		if status == 404:
			continue
		# Non-404 error: stop and surface.
		return {"ok": false, "error": "HttpError", "status": status, "url": url}
	return {"ok": false, "error": "NotFound", "status": 404}

