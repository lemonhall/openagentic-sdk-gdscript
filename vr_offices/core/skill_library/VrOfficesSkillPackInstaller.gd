extends RefCounted
class_name VrOfficesSkillPackInstaller

const _Validator := preload("res://addons/openagentic/core/OASkillMdValidator.gd")
const _Paths := preload("res://vr_offices/core/skill_library/VrOfficesSharedSkillLibraryPaths.gd")
const _Store := preload("res://vr_offices/core/skill_library/VrOfficesSharedSkillLibraryStore.gd")
const _Fs := preload("res://vr_offices/core/skill_library/VrOfficesSkillLibraryFs.gd")
const _Discover := preload("res://vr_offices/core/skill_library/VrOfficesSkillLibraryDiscovery.gd")
const _ZipUnpack := preload("res://vr_offices/core/skill_library/VrOfficesZipUnpack.gd")

const MAX_ZIP_BYTES := 32 * 1024 * 1024
const MAX_FILES := 2000
const MAX_UNZIPPED_BYTES := 64 * 1024 * 1024
const DISCOVER_DEPTH := 4

func install_zip_for_save(save_id: String, zip_path: String, source: Dictionary) -> Dictionary:
	var sid := save_id.strip_edges()
	if sid == "":
		return {"ok": false, "error": "MissingSaveId"}
	var zp := zip_path.strip_edges()
	if zp == "":
		return {"ok": false, "error": "MissingZipPath"}
	var abs := ProjectSettings.globalize_path(zp)
	if not FileAccess.file_exists(zp) and not FileAccess.file_exists(abs):
		return {"ok": false, "error": "ZipNotFound"}
	var f := FileAccess.open(zp, FileAccess.READ)
	if f == null:
		f = FileAccess.open(abs, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "ZipReadFailed"}
	var zip_bytes := int(f.get_length())
	f.close()
	if zip_bytes > MAX_ZIP_BYTES:
		return {"ok": false, "error": "ZipTooLarge", "bytes": zip_bytes}

	var stage_root := _Paths.staging_root(sid)
	if stage_root == "":
		return {"ok": false, "error": "MissingStageRoot"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stage_root))

	# Use a dedicated unpack directory so callers can store the zip file under staging_root safely.
	var unpack_root := stage_root.rstrip("/") + "/unpacked"
	# Clean unpack root best-effort.
	_Fs.rm_tree(unpack_root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(unpack_root))

	var unzip_res := _ZipUnpack.unzip_to_dir(zp, unpack_root, MAX_FILES, MAX_UNZIPPED_BYTES)
	if not bool(unzip_res.get("ok", false)):
		return unzip_res

	var scan_root := String(unzip_res.get("root", stage_root))
	var subdir := ""
	if source != null:
		subdir = String(source.get("subdir", source.get("path", ""))).strip_edges().rstrip("/")
	if subdir != "":
		if _is_unsafe_relative_dir(subdir):
			return {"ok": false, "error": "UnsafeSubdir", "subdir": subdir}
		var scoped := scan_root.rstrip("/") + "/" + subdir
		var abs_scoped := ProjectSettings.globalize_path(scoped)
		if not DirAccess.dir_exists_absolute(abs_scoped):
			return {"ok": false, "error": "SubdirNotFound", "subdir": subdir}
		scan_root = scoped
	var candidates := _Discover.discover_skill_dirs(scan_root, DISCOVER_DEPTH)

	var installed: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	for dir_path in candidates:
		var md_path := dir_path + "/SKILL.md"
		var vr: Dictionary = _Validator.validate_skill_md_path(md_path)
		if not bool(vr.get("ok", false)):
			rejected.append({"dir": dir_path, "error": String(vr.get("error", "Invalid"))})
			continue
		var name := String(vr.get("name", "")).strip_edges()
		var desc := String(vr.get("description", "")).strip_edges()
		var dst_root := _Paths.library_root(sid)
		if dst_root == "":
			rejected.append({"dir": dir_path, "error": "MissingLibraryRoot"})
			continue
		var dst_dir := dst_root + "/" + name
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dst_dir)):
			rejected.append({"dir": dir_path, "name": name, "error": "AlreadyInstalled"})
			continue

		var cr := _Fs.copy_tree(dir_path, dst_dir)
		if not bool(cr.get("ok", false)):
			rejected.append({"dir": dir_path, "name": name, "error": String(cr.get("error", "CopyFailed"))})
			continue

		var entry := {
			"name": name,
			"description": desc,
			"source": source if source != null else {},
			"installed_at_unix": int(Time.get_unix_time_from_system()),
			"path": dst_dir,
		}
		var wr: Dictionary = _Store.add_skill_entry(sid, entry)
		if not bool(wr.get("ok", false)):
			rejected.append({"dir": dir_path, "name": name, "error": "ManifestWriteFailed"})
			continue
		installed.append(entry)

	return {"ok": installed.size() > 0, "installed": installed, "rejected": rejected}

static func _is_unsafe_relative_dir(p: String) -> bool:
	var s := p.strip_edges()
	if s == "" or s.begins_with("/") or s.begins_with("\\"):
		return true
	if s.find("..") != -1:
		return true
	if s.find(":") != -1:
		return true
	return false
