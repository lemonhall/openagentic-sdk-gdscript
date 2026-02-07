# 多Agent共享文件系统方案 — GDScript (Godot 4.6) 实现

好，让我基于 **GDScript + Godot 4.6** 重新完整阐述这套方案。

核心架构：**分区所有权 + 版本控制 + CRDT**，三者各管一层。

---

## 一、整体架构概览

```
shared_workspace/
├── agents/
│   ├── agent_a/              ← Agent-A 专属产出区（单写者，无冲突）
│   ├── agent_b/              ← Agent-B 专属产出区
│   └── agent_c/              ← Agent-C 专属产出区
├── handoff/                  ← 交接区（定向传递）
│   ├── a_to_b/
│   ├── b_to_c/
│   └── ...
├── collaborative/            ← 协作区（版本控制 + 乐观锁）
│   ├── .versions/
│   └── current/
└── realtime/                 ← 实时协作区（CRDT，无冲突合并）
    └── .crdt_state/
```

| 区域 | 写权限 | 并发策略 | 适用场景 |
|------|--------|----------|----------|
| `agents/{id}/` | 仅该Agent | 无需控制 | Agent各自的工作产出 |
| `handoff/X_to_Y/` | 仅X | 无需控制 | 明确的文件交接 |
| `collaborative/` | 所有Agent | 版本控制+乐观锁 | 需要轮流编辑的文档 |
| `realtime/` | 所有Agent | CRDT | 需要同时编辑的文档 |

---

## 二、基础层：分区所有权文件系统

```gdscript
# shared_file_system.gd
class_name SharedFileSystem
extends RefCounted

## 多Agent共享文件系统 —— 基础层：分区所有权 + 权限控制

var shared_root: String
var agent_ids: PackedStringArray
var _versioned_fs: VersionedFileSystem
var _crdt_manager: CRDTManager

func _init(root_path: String, ids: PackedStringArray) -> void:
	shared_root = root_path
	agent_ids = ids
	_setup_directories()
	_versioned_fs = VersionedFileSystem.new(shared_root.path_join("collaborative"))
	_crdt_manager = CRDTManager.new(shared_root.path_join("realtime"))


func _setup_directories() -> void:
	var dirs_to_create: PackedStringArray = []

	# 每个Agent的专属区
	for id in agent_ids:
		dirs_to_create.append(shared_root.path_join("agents").path_join(id))

	# 交接区：为每对Agent创建
	for from_id in agent_ids:
		for to_id in agent_ids:
			if from_id != to_id:
				var handoff_dir := shared_root.path_join("handoff").path_join(
					"%s_to_%s" % [from_id, to_id]
				)
				dirs_to_create.append(handoff_dir)

	# 协作区 & 实时区
	dirs_to_create.append(shared_root.path_join("collaborative/.versions"))
	dirs_to_create.append(shared_root.path_join("collaborative/current"))
	dirs_to_create.append(shared_root.path_join("realtime/.crdt_state"))

	for dir_path in dirs_to_create:
		DirAccess.make_dir_recursive_absolute(dir_path)


## ========== 分区所有权：专属区操作 ==========

func write_own(agent_id: String, filename: String, content: String) -> Error:
	"""Agent写入自己的专属区"""
	var path := shared_root.path_join("agents").path_join(agent_id).path_join(filename)
	return _write_file(path, content)


func read_agent_file(agent_id: String, filename: String) -> ReadResult:
	"""任何Agent都可以读取任何Agent的专属区文件"""
	var path := shared_root.path_join("agents").path_join(agent_id).path_join(filename)
	return _read_file(path)


func list_agent_files(agent_id: String) -> PackedStringArray:
	"""列出某个Agent专属区的所有文件"""
	var dir_path := shared_root.path_join("agents").path_join(agent_id)
	return _list_files_recursive(dir_path)


## ========== 分区所有权：交接区操作 ==========

func handoff(from_agent: String, to_agent: String,
			 filename: String, content: String, message: String = "") -> Error:
	"""正式的文件交接"""
	if from_agent == to_agent:
		push_error("不能交接给自己")
		return ERR_INVALID_PARAMETER

	var handoff_dir := shared_root.path_join("handoff").path_join(
		"%s_to_%s" % [from_agent, to_agent]
	)

	# 写入文件本体
	var file_path := handoff_dir.path_join(filename)
	var err := _write_file(file_path, content)
	if err != OK:
		return err

	# 写入交接清单（manifest）
	var manifest := {
		"from": from_agent,
		"to": to_agent,
		"file": filename,
		"message": message,
		"timestamp": Time.get_unix_time_from_system(),
		"timestamp_readable": Time.get_datetime_string_from_system(),
	}
	var manifest_path := handoff_dir.path_join(filename + ".manifest.json")
	return _write_file(manifest_path, JSON.stringify(manifest, "\t"))


func check_handoffs(agent_id: String) -> Array[Dictionary]:
	"""检查有没有别人交接给我的文件"""
	var results: Array[Dictionary] = []

	for from_id in agent_ids:
		if from_id == agent_id:
			continue
		var handoff_dir := shared_root.path_join("handoff").path_join(
			"%s_to_%s" % [from_id, agent_id]
		)
		var files := _list_files_recursive(handoff_dir)
		for f in files:
			if f.ends_with(".manifest.json"):
				var read_result := _read_file(handoff_dir.path_join(f))
				if read_result.ok:
					var parsed = JSON.parse_string(read_result.content)
					if parsed is Dictionary:
						results.append(parsed)

	return results


## ========== 协作区：委托给 VersionedFileSystem ==========

func collab_write(filepath: String, content: String, agent_id: String,
				  message: String = "", expected_version: int = -1) -> Variant:
	"""写入协作区文件（带版本控制）
	   返回 FileVersion 或 ConflictInfo"""
	return _versioned_fs.write_file(filepath, content, agent_id, message, expected_version)


func collab_read(filepath: String) -> Variant:
	"""读取协作区文件，返回 {content, version} 或 null"""
	return _versioned_fs.read_file(filepath)


func collab_history(filepath: String) -> Array[Dictionary]:
	"""查看协作区文件的修改历史"""
	return _versioned_fs.get_history(filepath)


func collab_rollback(filepath: String, to_version: int, agent_id: String) -> Variant:
	return _versioned_fs.rollback(filepath, to_version, agent_id)


## ========== 实时协作区：委托给 CRDTManager ==========

func realtime_get_document(doc_id: String) -> CRDTDocument:
	return _crdt_manager.get_or_create_document(doc_id)


## ========== 通用权限检查（可选的强制层） ==========

func write_with_permission_check(filepath: String, content: String, agent_id: String,
								 message: String = "", expected_version: int = -1) -> Variant:
	"""统一写入入口，自动路由到正确的区域并检查权限"""

	# 专属区
	if filepath.begins_with("agents/"):
		var parts := filepath.split("/")
		if parts.size() < 3:
			return _make_error("路径格式错误")
		var owner_id := parts[1]
		if owner_id != agent_id:
			return _make_error(
				"Agent [%s] 无权写入 Agent [%s] 的专属区" % [agent_id, owner_id]
			)
		var filename := "/".join(parts.slice(2))
		write_own(agent_id, filename, content)
		return {"ok": true, "zone": "private"}

	# 交接区
	if filepath.begins_with("handoff/"):
		var parts := filepath.split("/")
		if parts.size() < 3:
			return _make_error("路径格式错误")
		var dir_name := parts[1]  # 例如 "a_to_b"
		if not dir_name.begins_with(agent_id + "_to_"):
			return _make_error(
				"Agent [%s] 只能写入自己发起的交接区" % agent_id
			)
		var filename := "/".join(parts.slice(2))
		_write_file(shared_root.path_join(filepath), content)
		return {"ok": true, "zone": "handoff"}

	# 协作区
	if filepath.begins_with("collaborative/"):
		var relative := filepath.trim_prefix("collaborative/")
		return collab_write(relative, content, agent_id, message, expected_version)

	# 实时区
	if filepath.begins_with("realtime/"):
		return _make_error("实时区请使用 realtime_get_document() 获取CRDT文档操作")

	return _make_error("未知的文件区域: %s" % filepath)


## ========== 内部工具方法 ==========

func _write_file(path: String, content: String) -> Error:
	# 确保父目录存在
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入文件: %s, 错误: %s" % [path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(content)
	file.close()
	return OK


func _read_file(path: String) -> ReadResult:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ReadResult.new(false, "", FileAccess.get_open_error())
	var content := file.get_as_text()
	file.close()
	return ReadResult.new(true, content, OK)


func _list_files_recursive(dir_path: String, prefix: String = "") -> PackedStringArray:
	var results: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var relative := prefix.path_join(file_name) if prefix != "" else file_name
		if dir.current_is_dir():
			results.append_array(
				_list_files_recursive(dir_path.path_join(file_name), relative)
			)
		else:
			results.append(relative)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _make_error(msg: String) -> Dictionary:
	push_error(msg)
	return {"ok": false, "error": msg}


## 简单的读取结果封装
class ReadResult extends RefCounted:
	var ok: bool
	var content: String
	var error: Error

	func _init(p_ok: bool, p_content: String, p_error: Error) -> void:
		ok = p_ok
		content = p_content
		error = p_error
```

---

## 三、版本控制层：乐观锁 + 历史记录

```gdscript
# versioned_file_system.gd
class_name VersionedFileSystem
extends RefCounted

## 带版本控制的文件系统 —— 用于协作区
## 核心机制：乐观并发控制（Optimistic Concurrency Control）
##
## 工作流程：
##   1. Agent 读取文件 → 拿到 (content, version_number)
##   2. Agent 本地修改 content
##   3. Agent 写回时带上 expected_version
##   4. 如果 expected_version != 当前版本 → 冲突！需要合并后重试

var _root: String
var _versions_dir: String
var _current_dir: String

# filepath -> Array[FileVersion]
var _store: Dictionary = {}

# 用 Mutex 保护 _store 的并发访问（Godot中多线程场景）
var _mutex: Mutex


func _init(root_path: String) -> void:
	_root = root_path
	_versions_dir = root_path.path_join(".versions")
	_current_dir = root_path.path_join("current")
	_mutex = Mutex.new()
	DirAccess.make_dir_recursive_absolute(_versions_dir)
	DirAccess.make_dir_recursive_absolute(_current_dir)
	_load_existing_versions()


## 写入文件（带乐观锁）
## expected_version = -1 表示不检查版本（强制写入/新建文件）
## 返回 FileVersion（成功）或 ConflictInfo（冲突）
func write_file(filepath: String, content: String, agent_id: String,
				message: String = "", expected_version: int = -1) -> Variant:
	_mutex.lock()
	var result = _write_file_internal(filepath, content, agent_id, message, expected_version)
	_mutex.unlock()
	return result


func _write_file_internal(filepath: String, content: String, agent_id: String,
						  message: String, expected_version: int) -> Variant:
	var versions: Array = _store.get(filepath, []) as Array
	var current_version: int = 0
	if versions.size() > 0:
		current_version = (versions.back() as FileVersion).version

	# 🔑 乐观锁检查
	if expected_version >= 0 and expected_version != current_version:
		var latest: FileVersion = versions.back() as FileVersion
		var conflict := ConflictInfo.new()
		conflict.your_base_version = expected_version
		conflict.current_version = current_version
		conflict.current_author = latest.author
		conflict.current_content = latest.content
		conflict.your_content = content
		conflict.message = (
			"⚠️ 冲突！Agent [%s] 基于版本 %d 修改，但当前已是版本 %d（被 %s 修改）。"
			% [agent_id, expected_version, current_version, latest.author]
		)
		return conflict

	# 创建新版本
	var new_ver := FileVersion.new()
	new_ver.version = current_version + 1
	new_ver.content = content
	new_ver.author = agent_id
	new_ver.timestamp = Time.get_unix_time_from_system()
	new_ver.message = message if message != "" else "Agent %s 更新" % agent_id
	new_ver.checksum = content.sha256_text().left(12)
	new_ver.parent_version = current_version

	if not _store.has(filepath):
		_store[filepath] = []
	(_store[filepath] as Array).append(new_ver)

	# 写入 current 文件
	var current_path := _current_dir.path_join(filepath)
	DirAccess.make_dir_recursive_absolute(current_path.get_base_dir())
	var file := FileAccess.open(current_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()

	# 保存版本快照
	_save_version_snapshot(filepath, new_ver)

	return new_ver


## 读取文件，返回 Dictionary {"content": String, "version": int} 或 null
func read_file(filepath: String) -> Variant:
	_mutex.lock()
	var versions: Array = _store.get(filepath, []) as Array
	_mutex.unlock()

	if versions.is_empty():
		return null

	var latest: FileVersion = versions.back() as FileVersion
	return {
		"content": latest.content,
		"version": latest.version,
		"author": latest.author,
	}


## 获取文件修改历史
func get_history(filepath: String) -> Array[Dictionary]:
	_mutex.lock()
	var versions: Array = _store.get(filepath, []) as Array
	_mutex.unlock()

	var history: Array[Dictionary] = []
	for v: FileVersion in versions:
		history.append({
			"version": v.version,
			"author": v.author,
			"message": v.message,
			"timestamp": v.timestamp,
			"checksum": v.checksum,
		})
	return history


## 回滚到指定版本
func rollback(filepath: String, to_version: int, agent_id: String) -> Variant:
	_mutex.lock()
	var versions: Array = _store.get(filepath, []) as Array

	var target: FileVersion = null
	for v: FileVersion in versions:
		if v.version == to_version:
			target = v
			break

	if target == null:
		_mutex.unlock()
		push_error("版本 %d 不存在" % to_version)
		return null

	var result = _write_file_internal(
		filepath, target.content, agent_id,
		"回滚到版本 %d（原作者: %s）" % [to_version, target.author],
		-1  # 强制写入
	)
	_mutex.unlock()
	return result


## Diff：比较两个版本
func diff(filepath: String, version_a: int, version_b: int) -> Variant:
	_mutex.lock()
	var versions: Array = _store.get(filepath, []) as Array
	_mutex.unlock()

	var va_content: String = ""
	var vb_content: String = ""
	for v: FileVersion in versions:
		if v.version == version_a:
			va_content = v.content
		if v.version == version_b:
			vb_content = v.content

	# 简单的行级diff
	var lines_a := va_content.split("\n")
	var lines_b := vb_content.split("\n")
	var diff_lines: PackedStringArray = []

	var max_lines := maxi(lines_a.size(), lines_b.size())
	for i in range(max_lines):
		var la: String = lines_a[i] if i < lines_a.size() else ""
		var lb: String = lines_b[i] if i < lines_b.size() else ""
		if la != lb:
			if la != "":
				diff_lines.append("- %s" % la)
			if lb != "":
				diff_lines.append("+ %s" % lb)
		else:
			diff_lines.append("  %s" % la)

	return "\n".join(diff_lines)


func _save_version_snapshot(filepath: String, ver: FileVersion) -> void:
	var safe_name := filepath.replace("/", "__")
	var snapshot_path := _versions_dir.path_join("%s.v%d" % [safe_name, ver.version])
	var file := FileAccess.open(snapshot_path, FileAccess.WRITE)
	if file:
		file.store_string(ver.content)
		file.close()

	# 同时保存元数据
	var meta_path := _versions_dir.path_join("%s.v%d.meta.json" % [safe_name, ver.version])
	var meta := {
		"version": ver.version,
		"author": ver.author,
		"message": ver.message,
		"timestamp": ver.timestamp,
		"checksum": ver.checksum,
		"parent_version": ver.parent_version,
	}
	file = FileAccess.open(meta_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(meta, "\t"))
		file.close()


func _load_existing_versions() -> void:
	# 启动时从磁盘恢复版本历史
	var dir := DirAccess.open(_versions_dir)
	if dir == null:
		return

	# 收集所有 meta 文件
	var meta_files: PackedStringArray = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".meta.json"):
			meta_files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()

	# 按文件名排序确保版本顺序
	meta_files.sort()

	for meta_file in meta_files:
		var meta_path := _versions_dir.path_join(meta_file)
		var f := FileAccess.open(meta_path, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if not parsed is Dictionary:
			continue

		var meta: Dictionary = parsed
		# 从 meta 文件名推断内容文件名
		var content_file := meta_file.trim_suffix(".meta.json")
		var content_path := _versions_dir.path_join(content_file)
		var cf := FileAccess.open(content_path, FileAccess.READ)
		if cf == null:
			continue
		var content := cf.get_as_text()
		cf.close()

		# 还原 filepath
		# content_file 格式: "some__path__file.md.v3"
		var dot_v_pos := content_file.rfind(".v")
		if dot_v_pos < 0:
			continue
		var safe_name := content_file.left(dot_v_pos)
		var filepath := safe_name.replace("__", "/")

		var ver := FileVersion.new()
		ver.version = int(meta.get("version", 0))
		ver.content = content
		ver.author = str(meta.get("author", ""))
		ver.message = str(meta.get("message", ""))
		ver.timestamp = float(meta.get("timestamp", 0.0))
		ver.checksum = str(meta.get("checksum", ""))
		ver.parent_version = int(meta.get("parent_version", 0))

		if not _store.has(filepath):
			_store[filepath] = []
		(_store[filepath] as Array).append(ver)


## ========== 数据类 ==========

class FileVersion extends RefCounted:
	var version: int = 0
	var content: String = ""
	var author: String = ""
	var timestamp: float = 0.0
	var message: String = ""
	var checksum: String = ""
	var parent_version: int = 0

	func to_dict() -> Dictionary:
		return {
			"version": version,
			"author": author,
			"message": message,
			"timestamp": timestamp,
			"checksum": checksum,
		}


class ConflictInfo extends RefCounted:
	var your_base_version: int = 0
	var current_version: int = 0
	var current_author: String = ""
	var current_content: String = ""
	var your_content: String = ""
	var message: String = ""
	var is_conflict: bool = true

	func to_dict() -> Dictionary:
		return {
			"is_conflict": true,
			"your_base_version": your_base_version,
			"current_version": current_version,
			"current_author": current_author,
			"message": message,
		}
```

---

## 四、CRDT层：无冲突实时协作

这是最关键的新增部分。CRDT的核心思想是：**每个Agent可以独立修改，任何顺序合并都能得到一致结果，永远不会冲突。**

我实现两种最实用的CRDT类型：

### 4.1 CRDT基础数据结构

```gdscript
# crdt_types.gd
class_name CRDTTypes

## ========== LWW Register (Last-Writer-Wins 寄存器) ==========
## 适用于：单值字段，如标题、状态、配置项
## 规则：时间戳最大的写入胜出

class LWWRegister extends RefCounted:
	var value: Variant = null
	var timestamp: float = 0.0
	var author: String = ""

	func set_value(new_value: Variant, new_timestamp: float, new_author: String) -> bool:
		"""设置值，返回是否实际更新了"""
		if new_timestamp > timestamp or (new_timestamp == timestamp and new_author > author):
			value = new_value
			timestamp = new_timestamp
			author = new_author
			return true
		return false

	func merge(other: LWWRegister) -> void:
		"""合并另一个寄存器的状态"""
		set_value(other.value, other.timestamp, other.author)

	func to_dict() -> Dictionary:
		return {"value": value, "timestamp": timestamp, "author": author}

	static func from_dict(d: Dictionary) -> LWWRegister:
		var reg := LWWRegister.new()
		reg.value = d.get("value")
		reg.timestamp = float(d.get("timestamp", 0.0))
		reg.author = str(d.get("author", ""))
		return reg


## ========== G-Counter (Grow-only Counter 只增计数器) ==========
## 适用于：统计计数，如"完成的任务数"

class GCounter extends RefCounted:
	# agent_id -> count
	var _counts: Dictionary = {}

	func increment(agent_id: String, amount: int = 1) -> void:
		if not _counts.has(agent_id):
			_counts[agent_id] = 0
		_counts[agent_id] = int(_counts[agent_id]) + amount

	func get_value() -> int:
		var total: int = 0
		for count: int in _counts.values():
			total += count
		return total

	func merge(other: GCounter) -> void:
		for agent_id: String in other._counts:
			if not _counts.has(agent_id):
				_counts[agent_id] = 0
			_counts[agent_id] = maxi(int(_counts[agent_id]), int(other._counts[agent_id]))

	func to_dict() -> Dictionary:
		return _counts.duplicate()

	static func from_dict(d: Dictionary) -> GCounter:
		var counter := GCounter.new()
		counter._counts = d.duplicate()
		return counter


## ========== PN-Counter (正负计数器) ==========
## 适用于：可增可减的计数

class PNCounter extends RefCounted:
	var _positive: GCounter = GCounter.new()
	var _negative: GCounter = GCounter.new()

	func increment(agent_id: String, amount: int = 1) -> void:
		_positive.increment(agent_id, amount)

	func decrement(agent_id: String, amount: int = 1) -> void:
		_negative.increment(agent_id, amount)

	func get_value() -> int:
		return _positive.get_value() - _negative.get_value()

	func merge(other: PNCounter) -> void:
		_positive.merge(other._positive)
		_negative.merge(other._negative)


## ========== OR-Set (Observed-Remove Set 可观察删除集合) ==========
## 适用于：任务列表、标签集合等 —— 可以添加和删除元素，不会冲突

class ORSet extends RefCounted:
	# element_key -> {unique_tag -> {author, timestamp}}
	var _elements: Dictionary = {}
	# 已被移除的 unique_tags
	var _tombstones: Dictionary = {}  # unique_tag -> true
	var _tag_counter: int = 0

	func _generate_tag(agent_id: String) -> String:
		_tag_counter += 1
		return "%s_%d_%d" % [agent_id, Time.get_ticks_msec(), _tag_counter]

	func add(element_key: String, agent_id: String, metadata: Dictionary = {}) -> String:
		"""添加元素，返回唯一标签"""
		var tag := _generate_tag(agent_id)
		if not _elements.has(element_key):
			_elements[element_key] = {}
		var entry := {
			"author": agent_id,
			"timestamp": Time.get_unix_time_from_system(),
			"metadata": metadata,
		}
		(_elements[element_key] as Dictionary)[tag] = entry
		return tag

	func remove(element_key: String) -> void:
		"""删除元素（移除当前所有可见的标签）"""
		if _elements.has(element_key):
			var tags: Dictionary = _elements[element_key]
			for tag: String in tags:
				_tombstones[tag] = true
			_elements.erase(element_key)

	func contains(element_key: String) -> bool:
		if not _elements.has(element_key):
			return false
		var tags: Dictionary = _elements[element_key]
		# 过滤掉已被tombstone的
		for tag: String in tags:
			if not _tombstones.has(tag):
				return true
		return false

	func get_all() -> Array[String]:
		var result: Array[String] = []
		for element_key: String in _elements:
			if contains(element_key):
				result.append(element_key)
		return result

	func get_with_metadata(element_key: String) -> Array[Dictionary]:
		"""获取元素的所有活跃条目（含


好，从CRDT的 `ORSet.get_with_metadata` 接着继续，把剩余的全部补完。

---

## 四（续）、CRDT层：无冲突实时协作

### 4.1 CRDT基础数据结构（续）

```gdscript
# crdt_types.gd （续）

## ========== OR-Set 续 ==========

	func get_with_metadata(element_key: String) -> Array[Dictionary]:
		"""获取元素的所有活跃条目（含元数据）"""
		var result: Array[Dictionary] = []
		if not _elements.has(element_key):
			return result
		var tags: Dictionary = _elements[element_key]
		for tag: String in tags:
			if not _tombstones.has(tag):
				var entry: Dictionary = tags[tag]
				var item := entry.duplicate()
				item["tag"] = tag
				item["element_key"] = element_key
				result.append(item)
		return result

	func merge(other: ORSet) -> void:
		"""合并另一个ORSet —— CRDT的核心：无论合并顺序，结果一致"""
		# 1. 合并 tombstones
		for tag: String in other._tombstones:
			_tombstones[tag] = true

		# 2. 合并 elements
		for element_key: String in other._elements:
			if not _elements.has(element_key):
				_elements[element_key] = {}
			var my_tags: Dictionary = _elements[element_key]
			var other_tags: Dictionary = other._elements[element_key]
			for tag: String in other_tags:
				if not my_tags.has(tag):
					my_tags[tag] = (other_tags[tag] as Dictionary).duplicate()

		# 3. 清理被 tombstone 的条目
		var empty_keys: Array[String] = []
		for element_key: String in _elements:
			var tags: Dictionary = _elements[element_key]
			var dead_tags: Array[String] = []
			for tag: String in tags:
				if _tombstones.has(tag):
					dead_tags.append(tag)
			for tag in dead_tags:
				tags.erase(tag)
			if tags.is_empty():
				empty_keys.append(element_key)
		for key in empty_keys:
			_elements.erase(key)

	func to_dict() -> Dictionary:
		return {
			"elements": _elements.duplicate(true),
			"tombstones": _tombstones.duplicate(),
			"tag_counter": _tag_counter,
		}

	static func from_dict(d: Dictionary) -> ORSet:
		var s := ORSet.new()
		s._elements = (d.get("elements", {}) as Dictionary).duplicate(true)
		s._tombstones = (d.get("tombstones", {}) as Dictionary).duplicate()
		s._tag_counter = int(d.get("tag_counter", 0))
		return s


## ========== LWW-Element-Map (Last-Writer-Wins 字典) ==========
## 适用于：键值对文档，如 JSON 配置、结构化数据
## 每个 key 独立用 LWW 策略解决冲突

class LWWMap extends RefCounted:
	# key -> LWWRegister
	var _registers: Dictionary = {}
	# 已删除的 key -> 删除时间戳
	var _removed: Dictionary = {}

	func set_key(key: String, value: Variant, agent_id: String) -> void:
		var ts := Time.get_unix_time_from_system()
		if not _registers.has(key):
			_registers[key] = LWWRegister.new()
		(_registers[key] as LWWRegister).set_value(value, ts, agent_id)
		# 如果之前被删除过，但现在的写入更新，则"复活"
		if _removed.has(key) and ts > float(_removed[key]):
			_removed.erase(key)

	func remove_key(key: String, _agent_id: String) -> void:
		var ts := Time.get_unix_time_from_system()
		_removed[key] = ts

	func get_key(key: String) -> Variant:
		if _removed.has(key):
			if not _registers.has(key):
				return null
			# 检查是否在删除之后又被写入
			var reg: LWWRegister = _registers[key]
			if reg.timestamp <= float(_removed[key]):
				return null
		if not _registers.has(key):
			return null
		return (_registers[key] as LWWRegister).value

	func get_all_keys() -> Array[String]:
		var result: Array[String] = []
		for key: String in _registers:
			if get_key(key) != null:
				result.append(key)
		return result

	func to_plain_dict() -> Dictionary:
		"""导出为普通字典（丢弃CRDT元数据）"""
		var result: Dictionary = {}
		for key in get_all_keys():
			result[key] = get_key(key)
		return result

	func merge(other: LWWMap) -> void:
		# 合并所有寄存器
		for key: String in other._registers:
			if not _registers.has(key):
				_registers[key] = LWWRegister.new()
			(_registers[key] as LWWRegister).merge(other._registers[key] as LWWRegister)
		# 合并删除记录
		for key: String in other._removed:
			if not _removed.has(key) or float(other._removed[key]) > float(_removed[key]):
				_removed[key] = other._removed[key]

	func to_dict() -> Dictionary:
		var regs: Dictionary = {}
		for key: String in _registers:
			regs[key] = (_registers[key] as LWWRegister).to_dict()
		return {
			"registers": regs,
			"removed": _removed.duplicate(),
		}

	static func from_dict(d: Dictionary) -> LWWMap:
		var m := LWWMap.new()
		var regs: Dictionary = d.get("registers", {})
		for key: String in regs:
			m._registers[key] = LWWRegister.from_dict(regs[key])
		m._removed = (d.get("removed", {}) as Dictionary).duplicate()
		return m


## ========== RGA (Replicated Growable Array) —— 协作文本 ==========
## 适用于：多Agent同时编辑同一段文本
## 这是最复杂但也最强大的CRDT类型

class RGANode extends RefCounted:
	var id: String = ""          # 全局唯一ID: "agent_id:seq"
	var value: String = ""       # 单个字符（或一小段文本）
	var parent_id: String = ""   # 插入在哪个节点之后
	var deleted: bool = false    # 墓碑标记
	var timestamp: float = 0.0
	var author: String = ""

	func to_dict() -> Dictionary:
		return {
			"id": id, "value": value, "parent_id": parent_id,
			"deleted": deleted, "timestamp": timestamp, "author": author,
		}

	static func from_dict(d: Dictionary) -> RGANode:
		var n := RGANode.new()
		n.id = str(d.get("id", ""))
		n.value = str(d.get("value", ""))
		n.parent_id = str(d.get("parent_id", ""))
		n.deleted = bool(d.get("deleted", false))
		n.timestamp = float(d.get("timestamp", 0.0))
		n.author = str(d.get("author", ""))
		return n


class RGA extends RefCounted:
	## Replicated Growable Array —— 用于协作文本编辑
	## 每个字符（或文本块）是一个节点，通过链表关系排序

	const ROOT_ID: String = "__ROOT__"

	# id -> RGANode
	var _nodes: Dictionary = {}
	# 有序的节点ID列表（缓存，加速遍历）
	var _order: Array[String] = []
	var _seq_counter: int = 0
	var _dirty: bool = true  # _order 是否需要重建

	func _init() -> void:
		# 创建根节点（虚拟头节点）
		var root := RGANode.new()
		root.id = ROOT_ID
		root.value = ""
		root.parent_id = ""
		root.timestamp = 0.0
		_nodes[ROOT_ID] = root

	func _generate_id(agent_id: String) -> String:
		_seq_counter += 1
		return "%s:%d" % [agent_id, _seq_counter]

	func insert_after(after_id: String, text: String, agent_id: String) -> String:
		"""在指定节点之后插入文本，返回新节点ID"""
		if not _nodes.has(after_id):
			push_error("节点 %s 不存在" % after_id)
			return ""

		var node := RGANode.new()
		node.id = _generate_id(agent_id)
		node.value = text
		node.parent_id = after_id
		node.timestamp = Time.get_unix_time_from_system()
		node.author = agent_id
		node.deleted = false

		_nodes[node.id] = node
		_dirty = true
		return node.id

	func insert_at_position(position: int, text: String, agent_id: String) -> String:
		"""在可见文本的第 position 个字符之后插入"""
		var visible := _get_visible_order()
		var after_id: String = ROOT_ID
		if position > 0 and position <= visible.size():
			after_id = visible[position - 1]
		elif position > visible.size():
			after_id = visible.back() if not visible.is_empty() else ROOT_ID
		return insert_after(after_id, text, agent_id)

	func delete_at_position(position: int) -> bool:
		"""删除可见文本的第 position 个字符（墓碑标记）"""
		var visible := _get_visible_order()
		if position < 0 or position >= visible.size():
			return false
		var node_id: String = visible[position]
		(_nodes[node_id] as RGANode).deleted = true
		_dirty = true
		return true

	func delete_range(from_pos: int, to_pos: int) -> int:
		"""删除一个范围 [from_pos, to_pos)，返回实际删除数量"""
		var visible := _get_visible_order()
		var count: int = 0
		for i in range(from_pos, mini(to_pos, visible.size())):
			(_nodes[visible[i]] as RGANode).deleted = true
			count += 1
		if count > 0:
			_dirty = true
		return count

	func get_text() -> String:
		"""获取当前可见文本"""
		var visible := _get_visible_order()
		var parts: PackedStringArray = []
		for node_id in visible:
			parts.append((_nodes[node_id] as RGANode).value)
		return "".join(parts)

	func get_length() -> int:
		return _get_visible_order().size()

	func merge(other: RGA) -> void:
		"""合并另一个RGA的所有节点"""
		for node_id: String in other._nodes:
			if node_id == ROOT_ID:
				continue
			var other_node: RGANode = other._nodes[node_id]
			if not _nodes.has(node_id):
				# 新节点，直接加入
				var copy := RGANode.new()
				copy.id = other_node.id
				copy.value = other_node.value
				copy.parent_id = other_node.parent_id
				copy.deleted = other_node.deleted
				copy.timestamp = other_node.timestamp
				copy.author = other_node.author
				_nodes[node_id] = copy
			else:
				# 已存在的节点，合并删除状态（删除优先）
				var my_node: RGANode = _nodes[node_id]
				if other_node.deleted:
					my_node.deleted = true

		# 同步序列计数器
		_seq_counter = maxi(_seq_counter, other._seq_counter)
		_dirty = true

	func _get_visible_order() -> Array[String]:
		"""获取所有未删除节点的有序列表"""
		if not _dirty and not _order.is_empty():
			# 过滤掉已删除的
			var visible: Array[String] = []
			for nid in _order:
				if _nodes.has(nid) and not (_nodes[nid] as RGANode).deleted:
					visible.append(nid)
			return visible

		_rebuild_order()

		var visible: Array[String] = []
		for nid in _order:
			if not (_nodes[nid] as RGANode).deleted:
				visible.append(nid)
		return visible

	func _rebuild_order() -> void:
		"""重建节点顺序（拓扑排序 + 时间戳排序）"""
		# 构建 parent -> children 映射
		var children: Dictionary = {}  # parent_id -> Array[RGANode]
		for node_id: String in _nodes:
			if node_id == ROOT_ID:
				continue
			var node: RGANode = _nodes[node_id]
			if not children.has(node.parent_id):
				children[node.parent_id] = []
			(children[node.parent_id] as Array).append(node)

		# 对每个 parent 的 children 按 (timestamp DESC, id DESC) 排序
		# 这样后插入的排在前面（紧跟parent之后）
		for parent_id: String in children:
			var arr: Array = children[parent_id]
			arr.sort_custom(func(a: RGANode, b: RGANode) -> bool:
				if a.timestamp != b.timestamp:
					return a.timestamp > b.timestamp
				return a.id > b.id
			)

		# DFS 遍历构建顺序
		_order.clear()
		var stack: Array[String] = [ROOT_ID]
		while not stack.is_empty():
			var current_id: String = stack.pop_back()
			if current_id != ROOT_ID:
				_order.append(current_id)
			# 把 children 逆序压栈（这样先弹出的是排序靠前的）
			if children.has(current_id):
				var child_nodes: Array = children[current_id]
				for i in range(child_nodes.size() - 1, -1, -1):
					stack.append((child_nodes[i] as RGANode).id)

		_dirty = false

	func to_dict() -> Dictionary:
		var nodes_dict: Dictionary = {}
		for node_id: String in _nodes:
			nodes_dict[node_id] = (_nodes[node_id] as RGANode).to_dict()
		return {
			"nodes": nodes_dict,
			"seq_counter": _seq_counter,
		}

	static func from_dict(d: Dictionary) -> RGA:
		var rga := RGA.new()
		var nodes_dict: Dictionary = d.get("nodes", {})
		for node_id: String in nodes_dict:
			if node_id == ROOT_ID:
				continue
			rga._nodes[node_id] = RGANode.from_dict(nodes_dict[node_id])
		rga._seq_counter = int(d.get("seq_counter", 0))
		rga._dirty = true
		return rga
```

---

### 4.2 CRDT文档 & 管理器

```gdscript
# crdt_document.gd
class_name CRDTDocument
extends RefCounted

## 一个CRDT文档 = 多种CRDT类型的组合
## 类似一个"实时协作的结构化文档"
##
## 例如一个项目计划文档：
##   - title (LWWRegister) → 标题，最后修改者胜出
##   - body (RGA) → 正文，多人同时编辑不冲突
##   - tasks (ORSet) → 任务列表，可添加/删除
##   - metadata (LWWMap) → 键值对元数据
##   - progress (PNCounter) → 进度计数

var doc_id: String
var _fields: Dictionary = {}  # field_name -> CRDT实例
var _field_types: Dictionary = {}  # field_name -> type_string
var _last_modified: float = 0.0
var _last_author: String = ""


func _init(p_doc_id: String = "") -> void:
	doc_id = p_doc_id


## ========== 字段定义 ==========

func define_lww_register(field_name: String, initial_value: Variant = null) -> CRDTDocument:
	_fields[field_name] = CRDTTypes.LWWRegister.new()
	_field_types[field_name] = "lww_register"
	if initial_value != null:
		(_fields[field_name] as CRDTTypes.LWWRegister).set_value(
			initial_value, Time.get_unix_time_from_system(), "__init__"
		)
	return self  # 链式调用


func define_rga(field_name: String) -> CRDTDocument:
	_fields[field_name] = CRDTTypes.RGA.new()
	_field_types[field_name] = "rga"
	return self


func define_or_set(field_name: String) -> CRDTDocument:
	_fields[field_name] = CRDTTypes.ORSet.new()
	_field_types[field_name] = "or_set"
	return self


func define_lww_map(field_name: String) -> CRDTDocument:
	_fields[field_name] = CRDTTypes.LWWMap.new()
	_field_types[field_name] = "lww_map"
	return self


func define_pn_counter(field_name: String) -> CRDTDocument:
	_fields[field_name] = CRDTTypes.PNCounter.new()
	_field_types[field_name] = "pn_counter"
	return self


## ========== 字段操作 ==========

func get_field(field_name: String) -> Variant:
	return _fields.get(field_name)


func get_field_type(field_name: String) -> String:
	return _field_types.get(field_name, "")


## 快捷方法：设置 LWW 字段值
func set_value(field_name: String, value: Variant, agent_id: String) -> void:
	var field_type := get_field_type(field_name)
	_last_modified = Time.get_unix_time_from_system()
	_last_author = agent_id

	match field_type:
		"lww_register":
			(_fields[field_name] as CRDTTypes.LWWRegister).set_value(
				value, _last_modified, agent_id
			)
		"lww_map":
			if value is Dictionary:
				var m: CRDTTypes.LWWMap = _fields[field_name]
				for key: String in value:
					m.set_key(key, value[key], agent_id)
			else:
				push_error("LWWMap 字段需要 Dictionary 值")
		_:
			push_error("set_value 不适用于字段类型: %s" % field_type)


## 快捷方法：获取 LWW 字段值
func get_value(field_name: String) -> Variant:
	var field_type := get_field_type(field_name)
	match field_type:
		"lww_register":
			return (_fields[field_name] as CRDTTypes.LWWRegister).value
		"lww_map":
			return (_fields[field_name] as CRDTTypes.LWWMap).to_plain_dict()
		"pn_counter":
			return (_fields[field_name] as CRDTTypes.PNCounter).get_value()
		"rga":
			return (_fields[field_name] as CRDTTypes.RGA).get_text()
		"or_set":
			return (_fields[field_name] as CRDTTypes.ORSet).get_all()
		_:
			return null


## ========== 文档级合并 ==========

func merge(other: CRDTDocument) -> void:
	"""合并另一个文档的所有字段 —— 无冲突！"""
	for field_name: String in other._fields:
		var other_type: String = other._field_types.get(field_name, "")

		if not _fields.has(field_name):
			# 本地没有这个字段，直接采纳
			_fields[field_name] = other._fields[field_name]
			_field_types[field_name] = other_type
			continue

		var my_type: String = _field_types[field_name]
		if my_type != other_type:
			push_warning("字段 '%s' 类型不匹配: %s vs %s，跳过" % [field_name, my_type, other_type])
			continue

		# 按类型调用对应的 merge
		match my_type:
			"lww_register":
				(_fields[field_name] as CRDTTypes.LWWRegister).merge(
					other._fields[field_name] as CRDTTypes.LWWRegister
				)
			"rga":
				(_fields[field_name] as CRDTTypes.RGA).merge(
					other._fields[field_name] as CRDTTypes.RGA
				)
			"or_set":
				(_fields[field_name] as CRDTTypes.ORSet).merge(
					other._fields[field_name] as CRDTTypes.ORSet
				)
			"lww_map":
				(_fields[field_name] as CRDTTypes.LWWMap).merge(
					other._fields[field_name] as CRDTTypes.LWWMap
				)
			"pn_counter":
				(_fields[field_name] as CRDTTypes.PNCounter).merge(
					other._fields[field_name] as CRDTTypes.PNCounter
				)

	if other._last_modified > _last_modified:
		_last_modified = other._last_modified
		_last_author = other._last_author


## ========== 序列化 ==========

func to_dict() -> Dictionary:
	var fields_data: Dictionary = {}
	for field_name: String in _fields:
		var field_type: String = _field_types[field_name]
		match field_type:
			"lww_register":
				fields_data[field_name] = (_fields[field_name] as CRDTTypes.LWWRegister).to_dict()
			"rga":
				fields_data[field_name] = (_fields[field_name] as CRDTTypes.RGA).to_dict()
			"or_set":
				fields_data[field_name] = (_fields[field_name] as CRDTTypes.ORSet).to_dict()
			"lww_map":
				fields_data[field_name] = (_fields[field_name] as CRDTTypes.LWWMap).to_dict()
			"pn_counter":
				# 简化处理
				var pnc: CRDTTypes.PNCounter = _fields[field_name]
				fields_data[field_name] = {
					"positive": pnc._positive.to_dict(),
					"negative": pnc._negative.to_dict(),
				}

	return {
		"doc_id": doc_id,
		"field_types": _field_types.duplicate(),
		"fields": fields_data,
		"last_modified": _last_modified,
		"last_author": _last_author,
	}


static func from_dict(d: Dictionary) -> CRDTDocument:
	var doc := CRDTDocument.new(str(d.get("doc_id", "")))
	doc._last_modified = float(d.get("last_modified", 0.0))
	doc._last_author = str(d.get("last_author", ""))
	doc._field_types = (d.get("field_types", {}) as Dictionary).duplicate()

	var fields_data: Dictionary = d.get("fields", {})
	for field_name: String in doc._field_types:
		var field_type: String = doc._field_types[field_name]
		var field_data: Dictionary = fields_data.get(field_name, {})
		match field_type:
			"lww_register":
				doc._fields[field_name] = CRDTTypes.LWWRegister.from_dict(field_data)
			"rga":
				doc._fields[field_name] = CRDTTypes.RGA.from_dict(field_data)
			"or_set":
				doc._fields[field_name] = CRDTTypes.ORSet.from_dict(field_data)
			"lww_map":
				doc._fields[field_name] = CRDTTypes.LWWMap.from_dict(field_data)
			"pn_counter":
				var pnc := CRDTTypes.PNCounter.new()
				pnc._positive = CRDTTypes.GCounter.from_dict(field_data.get("positive", {}))
				pnc._negative = CRDTTypes.GCounter.from_dict(field_data.get("negative", {}))
				doc._fields[field_name] = pnc

	return doc
```

---

### 4.3 CRDT管理器（持久化 + 同步）

```gdscript
# crdt_manager.gd
class_name CRDTManager
extends RefCounted

## 管理所有CRDT文档的生命周期、持久化、同步

var _root: String
var _state_dir: String
var _documents: Dictionary = {}  # doc_id -> CRDTDocument
var _mutex: Mutex


func _init(root_path: String) -> void:
	_root = root_path
	_state_dir = root_path.path_join(".crdt_state")
	_mutex = Mutex.new()
	DirAccess.make_dir_recursive_absolute(_state_dir)
	_load_all_documents()


func get_or_create_document(doc_id: String) -> CRDTDocument:
	_mutex.lock()
	if not _documents.has(doc_id):
		_documents[doc_id] = CRDTDocument.new(doc_id)
	var doc: CRDTDocument = _documents[doc_id]
	_mutex.unlock()
	return doc


func get_document(doc_id: String) -> CRDTDocument:
	_mutex.lock()
	var doc: CRDTDocument = _documents.get(doc_id)
	_mutex.unlock()
	return doc


func list_documents() -> PackedStringArray:
	_mutex.lock()
	var ids := PackedStringArray()
	for key: String in _documents:
		ids.append(key)
	_mutex.unlock()
	return ids


func save_document(doc_id: String) -> Error:
	"""持久化单个文档到磁盘"""
	_mutex.lock()
	var doc: CRDTDocument = _documents.get(doc_id)
	_mutex.unlock()

	if doc == null:
		return ERR_DOES_NOT_EXIST

	var path := _state_dir.path_join(doc_id + ".crdt.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(doc.to_dict(), "\t"))
	file.close()
	return OK


func save_all() -> void:
	_mutex.lock()
	var ids := _documents.keys()
	_mutex.unlock()
	for doc_id: String in ids:
		save_document(doc_id)


func merge_remote_document(doc_id: String, remote_data: Dictionary) -> CRDTDocument:
	"""接收远程Agent的文档状态并合并"""
	var remote_doc := CRDTDocument.from_dict(remote_data)

	_mutex.lock()
	if not _documents.has(doc_id):
		_documents[doc_id] = remote_doc
	else:
		(_documents[doc_id] as CRDTDocument).merge(remote_doc)
	var result: CRDTDocument = _documents[doc_id]
	_mutex.unlock()

	# 合并后自动持久化
	save_document(doc_id)
	return result


func _load_all_documents() -> void:
	var dir := DirAccess.open(_state_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".crdt.json"):
			var path := _state_dir.path_join(fname)
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var parsed = JSON.parse_string(file.get_as_text())
				file.close()
				if parsed is Dictionary:
					var doc := CRDTDocument.from_dict(parsed)
					_documents[doc.doc_id] = doc
		fname = dir.get_next()
	dir.list_dir_end()
```

---

## 五、Agent工具接口层

这一层是给Agent的LLM调用的tool/function接口，把底层复杂性封装成简单的动作：

```gdscript
# agent_fs_tools.gd
class_name AgentFSTools
extends RefCounted

## Agent可调用的文件系统工具集
## 每个方法对应一个 tool/function，供LLM调用

var _fs: SharedFileSystem
var _agent_id: String


func _init(fs: SharedFileSystem, agent_id: String) -> void:
	_fs = fs
	_agent_id = agent_id


## ========== 专属区工具 ==========

func tool_save_to_my_workspace(filename: String, content: String) -> Dictionary:
	"""保存文件到我的专属工作区"""
	var err := _fs.write_own(_agent_id, filename, content)
	if err == OK:
		return {"success": true, "


好，从 `agent_fs_tools.gd` 的 `tool_save_to_my_workspace` 方法接着继续，把剩余全部补完。

---

## 五（续）、Agent工具接口层

```gdscript
# agent_fs_tools.gd
class_name AgentFSTools
extends RefCounted

## Agent可调用的文件系统工具集
## 每个方法对应一个 tool/function，供LLM调用

var _fs: SharedFileSystem
var _agent_id: String


func _init(fs: SharedFileSystem, agent_id: String) -> void:
	_fs = fs
	_agent_id = agent_id


## ========== 专属区工具 ==========

func tool_save_to_my_workspace(filename: String, content: String) -> Dictionary:
	"""保存文件到我的专属工作区"""
	var err := _fs.write_own(_agent_id, filename, content)
	if err == OK:
		return {"success": true, "path": "agents/%s/%s" % [_agent_id, filename]}
	return {"success": false, "error": "写入失败: %s" % error_string(err)}


func tool_read_from_workspace(agent_id: String, filename: String) -> Dictionary:
	"""读取任意Agent工作区的文件（只读）"""
	var result := _fs.read_agent_file(agent_id, filename)
	if result.ok:
		return {"success": true, "content": result.content}
	return {"success": false, "error": "读取失败: %s" % error_string(result.error)}


func tool_list_workspace_files(agent_id: String) -> Dictionary:
	"""列出某个Agent工作区的所有文件"""
	var files := _fs.list_agent_files(agent_id)
	return {"success": true, "agent_id": agent_id, "files": Array(files)}


## ========== 交接区工具 ==========

func tool_handoff_file(to_agent: String, filename: String,
					   content: String, message: String = "") -> Dictionary:
	"""把文件正式交接给另一个Agent"""
	var err := _fs.handoff(_agent_id, to_agent, filename, content, message)
	if err == OK:
		return {
			"success": true,
			"message": "文件 '%s' 已交接给 %s" % [filename, to_agent],
			"path": "handoff/%s_to_%s/%s" % [_agent_id, to_agent, filename],
		}
	return {"success": false, "error": "交接失败: %s" % error_string(err)}


func tool_check_my_handoffs() -> Dictionary:
	"""检查有没有别人交接给我的文件"""
	var handoffs := _fs.check_handoffs(_agent_id)
	return {
		"success": true,
		"count": handoffs.size(),
		"handoffs": handoffs,
	}


func tool_read_handoff(from_agent: String, filename: String) -> Dictionary:
	"""读取别人交接给我的文件"""
	var path := "handoff/%s_to_%s/%s" % [from_agent, _agent_id, filename]
	var full_path := _fs.shared_root.path_join(path)
	var file := FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "文件不存在或无法读取"}
	var content := file.get_as_text()
	file.close()
	return {"success": true, "content": content, "from": from_agent}


## ========== 协作区工具（版本控制） ==========

func tool_collab_read(filepath: String) -> Dictionary:
	"""读取协作区文件（返回内容和版本号）"""
	var result = _fs.collab_read(filepath)
	if result == null:
		return {"success": false, "error": "文件 '%s' 不存在" % filepath}
	return {
		"success": true,
		"content": result["content"],
		"version": result["version"],
		"author": result["author"],
		"tip": "修改后请使用 collab_write 并传入此 version 号",
	}


func tool_collab_write(filepath: String, content: String,
					   message: String, expected_version: int = -1) -> Dictionary:
	"""写入协作区文件（带版本控制）
	   expected_version: 你基于哪个版本修改的，-1表示新建文件"""
	var result = _fs.collab_write(filepath, content, _agent_id, message, expected_version)

	if result is VersionedFileSystem.ConflictInfo:
		var conflict: VersionedFileSystem.ConflictInfo = result
		return {
			"success": false,
			"is_conflict": true,
			"your_base_version": conflict.your_base_version,
			"current_version": conflict.current_version,
			"current_author": conflict.current_author,
			"current_content": conflict.current_content,
			"your_content": conflict.your_content,
			"error": conflict.message,
			"suggestion": (
				"请先用 collab_read 获取最新版本（v%d），"
				+ "将你的修改与最新内容合并后，再用 collab_write 提交，"
				+ "并将 expected_version 设为 %d"
			) % [conflict.current_version, conflict.current_version],
		}

	if result is VersionedFileSystem.FileVersion:
		var ver: VersionedFileSystem.FileVersion = result
		return {
			"success": true,
			"version": ver.version,
			"checksum": ver.checksum,
			"message": "成功写入版本 %d" % ver.version,
		}

	return {"success": false, "error": "未知错误"}


func tool_collab_history(filepath: String) -> Dictionary:
	"""查看协作区文件的修改历史"""
	var history := _fs.collab_history(filepath)
	return {"success": true, "filepath": filepath, "history": history}


func tool_collab_rollback(filepath: String, to_version: int) -> Dictionary:
	"""回滚协作区文件到指定版本"""
	var result = _fs.collab_rollback(filepath, to_version, _agent_id)
	if result is VersionedFileSystem.FileVersion:
		var ver: VersionedFileSystem.FileVersion = result
		return {
			"success": true,
			"new_version": ver.version,
			"message": "已回滚到版本 %d" % to_version,
		}
	return {"success": false, "error": "回滚失败"}


## ========== 实时协作区工具（CRDT） ==========

func tool_realtime_create_document(doc_id: String, schema: Dictionary) -> Dictionary:
	"""创建一个实时协作文档
	   schema 示例: {"title": "lww_register", "body": "rga", "tasks": "or_set"}"""
	var doc := _fs.realtime_get_document(doc_id)

	for field_name: String in schema:
		var field_type: String = schema[field_name]
		match field_type:
			"lww_register":
				doc.define_lww_register(field_name)
			"rga":
				doc.define_rga(field_name)
			"or_set":
				doc.define_or_set(field_name)
			"lww_map":
				doc.define_lww_map(field_name)
			"pn_counter":
				doc.define_pn_counter(field_name)
			_:
				return {"success": false, "error": "未知字段类型: %s" % field_type}

	_fs._crdt_manager.save_document(doc_id)
	return {
		"success": true,
		"doc_id": doc_id,
		"fields": schema,
		"message": "实时协作文档已创建",
	}


func tool_realtime_set_field(doc_id: String, field_name: String, value: Variant) -> Dictionary:
	"""设置实时文档的 LWW/LWWMap 字段"""
	var doc := _fs.realtime_get_document(doc_id)
	var field_type := doc.get_field_type(field_name)

	if field_type == "":
		return {"success": false, "error": "字段 '%s' 不存在" % field_name}

	if field_type not in ["lww_register", "lww_map"]:
		return {
			"success": false,
			"error": "set_field 仅适用于 lww_register/lww_map，当前类型: %s" % field_type,
		}

	doc.set_value(field_name, value, _agent_id)
	_fs._crdt_manager.save_document(doc_id)
	return {"success": true, "field": field_name, "value": value}


func tool_realtime_get_field(doc_id: String, field_name: String) -> Dictionary:
	"""读取实时文档的字段值"""
	var doc := _fs._crdt_manager.get_document(doc_id)
	if doc == null:
		return {"success": false, "error": "文档 '%s' 不存在" % doc_id}

	var value = doc.get_value(field_name)
	return {
		"success": true,
		"field": field_name,
		"type": doc.get_field_type(field_name),
		"value": value,
	}


func tool_realtime_edit_text(doc_id: String, field_name: String,
							 operation: String, args: Dictionary) -> Dictionary:
	"""编辑实时文档的 RGA 文本字段
	   operation: "insert" | "delete" | "replace" | "get"
	   args (insert):  {"position": int, "text": String}
	   args (delete):  {"from": int, "to": int}
	   args (replace): {"from": int, "to": int, "text": String}
	   args (get):     {}
	"""
	var doc := _fs.realtime_get_document(doc_id)
	var field = doc.get_field(field_name)

	if not field is CRDTTypes.RGA:
		return {"success": false, "error": "字段 '%s' 不是 RGA 文本类型" % field_name}

	var rga: CRDTTypes.RGA = field

	match operation:
		"insert":
			var pos: int = int(args.get("position", rga.get_length()))
			var text: String = str(args.get("text", ""))
			var node_id := rga.insert_at_position(pos, text, _agent_id)
			_fs._crdt_manager.save_document(doc_id)
			return {
				"success": true,
				"operation": "insert",
				"node_id": node_id,
				"current_text": rga.get_text(),
				"length": rga.get_length(),
			}

		"delete":
			var from: int = int(args.get("from", 0))
			var to: int = int(args.get("to", 0))
			var count := rga.delete_range(from, to)
			_fs._crdt_manager.save_document(doc_id)
			return {
				"success": true,
				"operation": "delete",
				"deleted_count": count,
				"current_text": rga.get_text(),
				"length": rga.get_length(),
			}

		"replace":
			var from: int = int(args.get("from", 0))
			var to: int = int(args.get("to", 0))
			var text: String = str(args.get("text", ""))
			rga.delete_range(from, to)
			rga.insert_at_position(from, text, _agent_id)
			_fs._crdt_manager.save_document(doc_id)
			return {
				"success": true,
				"operation": "replace",
				"current_text": rga.get_text(),
				"length": rga.get_length(),
			}

		"get":
			return {
				"success": true,
				"operation": "get",
				"text": rga.get_text(),
				"length": rga.get_length(),
			}

		_:
			return {"success": false, "error": "未知操作: %s" % operation}


func tool_realtime_modify_set(doc_id: String, field_name: String,
							  operation: String, element: String,
							  metadata: Dictionary = {}) -> Dictionary:
	"""操作实时文档的 ORSet 集合字段
	   operation: "add" | "remove" | "list" | "contains"
	"""
	var doc := _fs.realtime_get_document(doc_id)
	var field = doc.get_field(field_name)

	if not field is CRDTTypes.ORSet:
		return {"success": false, "error": "字段 '%s' 不是 ORSet 类型" % field_name}

	var or_set: CRDTTypes.ORSet = field

	match operation:
		"add":
			var tag := or_set.add(element, _agent_id, metadata)
			_fs._crdt_manager.save_document(doc_id)
			return {
				"success": true,
				"operation": "add",
				"element": element,
				"tag": tag,
				"all_elements": or_set.get_all(),
			}

		"remove":
			or_set.remove(element)
			_fs._crdt_manager.save_document(doc_id)
			return {
				"success": true,
				"operation": "remove",
				"element": element,
				"all_elements": or_set.get_all(),
			}

		"list":
			return {
				"success": true,
				"operation": "list",
				"elements": or_set.get_all(),
				"count": or_set.get_all().size(),
			}

		"contains":
			return {
				"success": true,
				"operation": "contains",
				"element": element,
				"exists": or_set.contains(element),
			}

		_:
			return {"success": false, "error": "未知操作: %s" % operation}


func tool_realtime_counter(doc_id: String, field_name: String,
						   operation: String, amount: int = 1) -> Dictionary:
	"""操作实时文档的 PNCounter 计数器
	   operation: "increment" | "decrement" | "get"
	"""
	var doc := _fs.realtime_get_document(doc_id)
	var field = doc.get_field(field_name)

	if not field is CRDTTypes.PNCounter:
		return {"success": false, "error": "字段 '%s' 不是 PNCounter 类型" % field_name}

	var counter: CRDTTypes.PNCounter = field

	match operation:
		"increment":
			counter.increment(_agent_id, amount)
			_fs._crdt_manager.save_document(doc_id)
			return {"success": true, "operation": "increment", "value": counter.get_value()}

		"decrement":
			counter.decrement(_agent_id, amount)
			_fs._crdt_manager.save_document(doc_id)
			return {"success": true, "operation": "decrement", "value": counter.get_value()}

		"get":
			return {"success": true, "operation": "get", "value": counter.get_value()}

		_:
			return {"success": false, "error": "未知操作: %s" % operation}


func tool_realtime_get_document_snapshot(doc_id: String) -> Dictionary:
	"""获取整个实时文档的快照（所有字段的当前值）"""
	var doc := _fs._crdt_manager.get_document(doc_id)
	if doc == null:
		return {"success": false, "error": "文档 '%s' 不存在" % doc_id}

	var snapshot: Dictionary = {}
	var field_types: Dictionary = {}

	for field_name: String in doc._field_types:
		field_types[field_name] = doc._field_types[field_name]
		snapshot[field_name] = doc.get_value(field_name)

	return {
		"success": true,
		"doc_id": doc_id,
		"field_types": field_types,
		"snapshot": snapshot,
	}


## ========== 生成 Tool 定义（供LLM使用） ==========

func get_tool_definitions() -> Array[Dictionary]:
	"""返回所有工具的定义，可直接用于 LLM 的 tools 参数"""
	return [
		{
			"name": "save_to_my_workspace",
			"description": "保存文件到你的专属工作区。其他Agent可以读取但不能修改。",
			"parameters": {
				"type": "object",
				"properties": {
					"filename": {"type": "string", "description": "文件名，如 'report.md'"},
					"content": {"type": "string", "description": "文件内容"},
				},
				"required": ["filename", "content"],
			},
		},
		{
			"name": "read_from_workspace",
			"description": "读取任意Agent工作区的文件。",
			"parameters": {
				"type": "object",
				"properties": {
					"agent_id": {"type": "string", "description": "目标Agent的ID"},
					"filename": {"type": "string", "description": "文件名"},
				},
				"required": ["agent_id", "filename"],
			},
		},
		{
			"name": "list_workspace_files",
			"description": "列出某个Agent工作区的所有文件。",
			"parameters": {
				"type": "object",
				"properties": {
					"agent_id": {"type": "string", "description": "目标Agent的ID"},
				},
				"required": ["agent_id"],
			},
		},
		{
			"name": "handoff_file",
			"description": "把文件正式交接给另一个Agent。对方可通过 check_my_handoffs 查看。",
			"parameters": {
				"type": "object",
				"properties": {
					"to_agent": {"type": "string", "description": "接收方Agent的ID"},
					"filename": {"type": "string", "description": "文件名"},
					"content": {"type": "string", "description": "文件内容"},
					"message": {"type": "string", "description": "交接说明"},
				},
				"required": ["to_agent", "filename", "content"],
			},
		},
		{
			"name": "check_my_handoffs",
			"description": "检查有没有其他Agent交接给你的文件。",
			"parameters": {"type": "object", "properties": {}},
		},
		{
			"name": "collab_read",
			"description": "读取协作区文件。返回内容和版本号，修改后写回时需要带上版本号。",
			"parameters": {
				"type": "object",
				"properties": {
					"filepath": {"type": "string", "description": "协作区内的文件路径"},
				},
				"required": ["filepath"],
			},
		},
		{
			"name": "collab_write",
			"description": "写入协作区文件（带版本控制）。如果有冲突会返回错误，需要先读取最新版本合并后重试。",
			"parameters": {
				"type": "object",
				"properties": {
					"filepath": {"type": "string", "description": "协作区内的文件路径"},
					"content": {"type": "string", "description": "文件内容"},
					"message": {"type": "string", "description": "本次修改说明"},
					"expected_version": {
						"type": "integer",
						"description": "你基于哪个版本修改的。-1表示新建文件。",
					},
				},
				"required": ["filepath", "content", "message"],
			},
		},
		{
			"name": "collab_history",
			"description": "查看协作区文件的修改历史。",
			"parameters": {
				"type": "object",
				"properties": {
					"filepath": {"type": "string", "description": "文件路径"},
				},
				"required": ["filepath"],
			},
		},
		{
			"name": "realtime_create_document",
			"description": "创建实时协作文档。多个Agent可同时编辑，永远不会冲突。schema定义字段和类型。",
			"parameters": {
				"type": "object",
				"properties": {
					"doc_id": {"type": "string", "description": "文档ID"},
					"schema": {
						"type": "object",
						"description": "字段定义。可用类型: lww_register(单值), rga(文本), or_set(集合), lww_map(键值对), pn_counter(计数器)",
					},
				},
				"required": ["doc_id", "schema"],
			},
		},
		{
			"name": "realtime_set_field",
			"description": "设置实时文档的 lww_register 或 lww_map 字段值。",
			"parameters": {
				"type": "object",
				"properties": {
					"doc_id": {"type": "string", "description": "文档ID"},
					"field_name": {"type": "string", "description": "字段名"},
					"value": {"description": "要设置的值"},
				},
				"required": ["doc_id", "field_name", "value"],
			},
		},
		{
			"name": "realtime_edit_text",
			"description": "编辑实时文档的RGA文本字段。支持 insert/delete/replace/get 操作。多Agent同时编辑不会冲突。",
			"parameters": {
				"type": "object",
				"properties": {
					"doc_id": {"type": "string", "description": "文档ID"},
					"field_name": {"type": "string", "description": "RGA字段名"},
					"operation": {
						"type": "string",
						"enum": ["insert", "delete", "replace", "get"],
					},
					"args": {
						"type": "object",
						"description": "insert: {position, text}, delete: {from, to}, replace: {from, to, text}, get: {}",
					},
				},
				"required": ["doc_id", "field_name", "operation"],
			},
		},
		{
			"name": "realtime_modify_set",
			"description": "操作实时文档的ORSet集合字段。支持 add/remove/list/contains。",
			"parameters": {
				"type": "object",
				"properties": {
					"doc_id": {"type": "string", "description": "文档ID"},
					"field_name": {"type": "string", "description": "ORSet字段名"},
					"operation": {
						"type": "string",
						"enum": ["add", "remove", "list", "contains"],
					},
					"element": {"type": "string", "description": "元素值"},
					"metadata": {"type": "object", "description": "附加元数据（可选）"},
				},
				"required": ["doc_id", "field_name", "operation"],
			},
		},
		{
			"name": "realtime_counter",
			"description": "操作实时文档的PNCounter计数器。支持 increment/decrement/get。",
			"parameters": {
				"type": "object",
				"properties": {
					"doc_id": {"type": "string", "description": "文档ID"},
					"field_name": {"type": "string", "description": "计数器字段名"},
					"operation": {
						"type": "string",
						"enum": ["increment", "decrement", "get"],
					},
					"amount": {"type": "integer", "description": "数量，默认1"},
				},
				"required": ["doc_id", "field_name", "operation"],
			},
		},
		{
			"name": "realtime_get_document_snapshot",
			"description": "获取整个实时协作文档的当前快照（所有字段的值）。",
			"parameters": {
				"type": "object",
				"properties": {
					"doc_id": {"type": "string", "description": "文档ID"},
				},
				"required": ["doc_id"],
			},
		},
	]


## ========== Tool 调用分发器 ==========

func dispatch_tool_call(tool_name: String, arguments: Dictionary) -> Dictionary:
	"""统一的工具调用入口，根据 tool_name 分发到对应方法"""
	match tool_name:
		"save_to_my_workspace":
			return tool_save_to_my_workspace(
				str(arguments.get("filename", "")),
				str(arguments.get("content", ""))
			)
		"read_from_workspace":
			return tool_read_from_workspace(
				str(arguments.get("agent_id", "")),
				str(arguments.get("filename", ""))
			)
		"list_workspace_files":
			return tool_list_workspace_files(str(arguments.get("agent_id", "")))
		"handoff_file":
			return tool_handoff_file(
				str(arguments.get("to_agent", "")),
				str(arguments.get("filename", "")),
				str(arguments.get("content", "")),
				str(arguments.get("message", ""))
			)
		"check_my_handoffs":
			return tool_check_my_handoffs()
		"read_handoff":
			return tool_read_handoff(
				str(arguments.get("from_agent", "")),
				str(arguments.get("filename", ""))
			)
		"collab_read":
			return tool_collab_read(str(arguments.get("filepath", "")))
		"collab_write":
			return tool_collab_write(
				str(arguments.get("filepath", "")),
				str(arguments.get("content", "")),
				str(arguments.get("message", "")),
				int(arguments.get("expected_version", -1))
			)
		"collab_history":
			return tool_collab_history(str(arguments.get("filepath", "")))
		"collab_rollback":
			return tool_collab_rollback(
				str(arguments.get("filepath", "")),
				int(arguments.get("to_version", 0))
			)
		"realtime_create_document":
			return tool_realtime_create_document(
				str(arguments.get("doc_id", "")),
				arguments.get("schema", {}) as Dictionary
			)
		"realtime_set_field":
			return tool_realtime_set_field(
				str(arguments.get("doc_id", "")),
				str(arguments.get("field_name", "")),
				arguments.get("value")
			)
		"realtime_get_field":
			return tool_realtime_get_field(
				str(arguments.get("doc_id", "")),
				str(arguments.get("field_name", ""))
			)
		"realtime_edit_text":
			return tool_realtime_edit_text(
				str(arguments.get("doc_id", "")),
				str(arguments.get("field_name", "")),
				str(arguments.get("operation", "")),
				arguments.get("args", {}) as Dictionary
			)
		"realtime_modify_set":
			return tool_realtime_modify_set(
				str(arguments.get("doc_id", "")),
				str(arguments.get("field_name", "")),
				str(arguments.get("operation", "")),
				str(arguments.get("element", "")),
				arguments.get("metadata", {}) as Dictionary
			)
		"realtime_counter":
			return tool_realtime_counter(
				str(arguments.get("doc_id", "")),
				str(arguments.get("field_name", "")),
				str(arguments.get("operation", "")),
				int(arguments.get("amount", 1))
			)
		"realtime_get_document_snapshot":
			return tool_realtime_get_document_snapshot(
				str(arguments.get("doc_id", ""))
			)
		_:
			return {"success": false, "error": "未知工具: %s" % tool_name}
```

---

## 六、启动与使用示例

```gdscript
# main_orchestrator.gd
extends Node

## 多Agent系统的主协调器 —— 启动和使用示例

var shared_fs: SharedFileSystem
var agent_tools: Dictionary = {}  # agent_id -> AgentFSTools


func _ready() -> void:
	_setup_shared_filesystem()
	_demo_workflow()


func _setup_shared_filesystem() -> void:
	var agent_ids: PackedStringArray = ["researcher", "analyst", "writer"]
	var workspace_root := "user://shared_workspace"

	# 初始化共享文件系统
	shared_fs = SharedFileSystem.new(workspace_root, agent_ids)

	# 为每个Agent创建工具实例
	for id in agent_ids:
		agent_tools[id] = AgentFSTools.new(shared_fs, id)

	print("✅ 共享文件系统初始化完成: %s" % workspace_root)
	print("   Agents: %s" % ", ".join(agent_ids))


func _demo_workflow() -> void:
	print("\n========== 演示工作流 ==========\n")

	var researcher: AgentFSTools = agent_tools["researcher"]
	var analyst: AgentFSTools = agent_tools["analyst"]
	var writer: AgentFSTools = agent_tools["writer"]

	# --- 阶段1：各自工作，保存到专属区 ---
	print("--- 阶段1: 各自工作 ---")

	var r1 := researcher.dispatch_tool_call("save_to_my_workspace", {
		"filename": "raw_data.md",
		"content": "# 调研数据\n\n- 发现1: AI Agent协作效率提升40%\n- 发现2: CRDT可消除冲突",
	})
	print("Researcher 保存: %s" % r1)

	var r2 := analyst.dispatch_tool_call("save_to_my_workspace", {
		"filename": "analysis.md",
		"content": "# 分析报告\n\n数据表明协作系统的关键在于并发控制...",
	})
	print("Analyst 保存: %s" % r2)

	# --- 阶段2


    好，从阶段2接着继续，把演示工作流和最终总结全部补完。

---

## 六（续）、启动与使用示例

```gdscript
# main_orchestrator.gd （续）

	# --- 阶段2：文件交接 ---
	print("\n--- 阶段2: 文件交接 ---")

	# Researcher 把调研数据交接给 Analyst
	var r3 := researcher.dispatch_tool_call("handoff_file", {
		"to_agent": "analyst",
		"filename": "raw_data.md",
		"content": "# 调研数据\n\n- 发现1: AI Agent协作效率提升40%\n- 发现2: CRDT可消除冲突",
		"message": "调研完成，请分析这些数据",
	})
	print("Researcher → Analyst 交接: %s" % r3)

	# Analyst 检查收到的交接
	var r4 := analyst.dispatch_tool_call("check_my_handoffs", {})
	print("Analyst 检查交接: 收到 %d 个文件" % r4["count"])
	for h: Dictionary in r4["handoffs"]:
		print("  来自 %s: %s — %s" % [h["from"], h["file"], h["message"]])

	# Analyst 读取交接文件
	var r5 := analyst.dispatch_tool_call("read_handoff", {
		"from_agent": "researcher",
		"filename": "raw_data.md",
	})
	print("Analyst 读取交接文件: %s" % ("成功" if r5["success"] else "失败"))

	# --- 阶段3：协作区 —— 版本控制协作 ---
	print("\n--- 阶段3: 协作区（版本控制） ---")

	# Analyst 创建协作文档
	var r6 := analyst.dispatch_tool_call("collab_write", {
		"filepath": "project_plan.md",
		"content": "# 项目计划 v1\n\n## 目标\n协作系统设计\n\n## 分工\n待定",
		"message": "创建项目计划初稿",
		"expected_version": -1,  # 新建
	})
	print("Analyst 创建协作文档: v%d" % r6["version"])

	# Writer 读取并修改
	var r7 := writer.dispatch_tool_call("collab_read", {
		"filepath": "project_plan.md",
	})
	print("Writer 读取: v%d" % r7["version"])

	var updated_content: String = r7["content"].replace(
		"## 分工\n待定",
		"## 分工\n- Researcher: 数据收集\n- Analyst: 数据分析\n- Writer: 报告撰写"
	)
	var r8 := writer.dispatch_tool_call("collab_write", {
		"filepath": "project_plan.md",
		"content": updated_content,
		"message": "补充分工信息",
		"expected_version": r7["version"],  # 基于v1修改
	})
	print("Writer 写入: v%d" % r8["version"])

	# 模拟冲突：Researcher 也基于 v1 修改（但此时已经是 v2 了）
	var stale_content: String = r7["content"].replace(
		"## 目标\n协作系统设计",
		"## 目标\n多Agent协作文件系统设计"
	)
	var r9 := researcher.dispatch_tool_call("collab_write", {
		"filepath": "project_plan.md",
		"content": stale_content,
		"message": "修改目标描述",
		"expected_version": 1,  # ⚠️ 过期版本！
	})
	print("Researcher 写入（冲突）: %s" % ("冲突！" if r9.get("is_conflict", false) else "成功"))
	if r9.get("is_conflict", false):
		print("  原因: %s" % r9["error"])
		print("  建议: %s" % r9["suggestion"])

		# Researcher 正确处理冲突：读取最新版本，合并修改，重新提交
		var r9b := researcher.dispatch_tool_call("collab_read", {
			"filepath": "project_plan.md",
		})
		var merged_content: String = (r9b["content"] as String).replace(
			"## 目标\n协作系统设计",
			"## 目标\n多Agent协作文件系统设计"
		)
		var r9c := researcher.dispatch_tool_call("collab_write", {
			"filepath": "project_plan.md",
			"content": merged_content,
			"message": "合并冲突后修改目标描述",
			"expected_version": r9b["version"],
		})
		print("  Researcher 合并后重新提交: v%d ✅" % r9c["version"])

	# 查看历史
	var r10 := analyst.dispatch_tool_call("collab_history", {
		"filepath": "project_plan.md",
	})
	print("\n协作文档历史:")
	for entry: Dictionary in r10["history"]:
		print("  v%d [%s] %s" % [entry["version"], entry["author"], entry["message"]])

	# --- 阶段4：实时协作区 —— CRDT 无冲突协作 ---
	print("\n--- 阶段4: 实时协作区（CRDT） ---")

	# 创建一个实时协作的任务看板
	var r11 := analyst.dispatch_tool_call("realtime_create_document", {
		"doc_id": "task_board",
		"schema": {
			"title": "lww_register",
			"description": "rga",
			"tasks": "or_set",
			"config": "lww_map",
			"completed_count": "pn_counter",
		},
	})
	print("创建实时文档: %s" % r11)

	# 多个Agent同时操作 —— 不会冲突！

	# Analyst 设置标题
	analyst.dispatch_tool_call("realtime_set_field", {
		"doc_id": "task_board",
		"field_name": "title",
		"value": "Q1 项目任务看板",
	})
	print("Analyst 设置标题 ✅")

	# Writer 同时编辑描述文本
	writer.dispatch_tool_call("realtime_edit_text", {
		"doc_id": "task_board",
		"field_name": "description",
		"operation": "insert",
		"args": {"position": 0, "text": "这是我们的协作任务看板。"},
	})
	print("Writer 插入描述文本 ✅")

	# Researcher 也同时在描述末尾追加
	researcher.dispatch_tool_call("realtime_edit_text", {
		"doc_id": "task_board",
		"field_name": "description",
		"operation": "insert",
		"args": {"position": 999, "text": "所有成员请及时更新任务状态。"},
	})
	print("Researcher 追加描述文本 ✅")

	# 查看合并后的文本
	var r12 := analyst.dispatch_tool_call("realtime_edit_text", {
		"doc_id": "task_board",
		"field_name": "description",
		"operation": "get",
		"args": {},
	})
	print("合并后的描述: \"%s\"" % r12["text"])

	# 三个Agent同时添加任务（ORSet，永远不冲突）
	researcher.dispatch_tool_call("realtime_modify_set", {
		"doc_id": "task_board",
		"field_name": "tasks",
		"operation": "add",
		"element": "收集用户反馈数据",
		"metadata": {"priority": "high", "assignee": "researcher"},
	})

	analyst.dispatch_tool_call("realtime_modify_set", {
		"doc_id": "task_board",
		"field_name": "tasks",
		"operation": "add",
		"element": "分析竞品方案",
		"metadata": {"priority": "medium", "assignee": "analyst"},
	})

	writer.dispatch_tool_call("realtime_modify_set", {
		"doc_id": "task_board",
		"field_name": "tasks",
		"operation": "add",
		"element": "撰写技术文档",
		"metadata": {"priority": "high", "assignee": "writer"},
	})

	# 列出所有任务
	var r13 := analyst.dispatch_tool_call("realtime_modify_set", {
		"doc_id": "task_board",
		"field_name": "tasks",
		"operation": "list",
		"element": "",
	})
	print("当前任务列表 (%d 个):" % r13["count"])
	for task: String in r13["elements"]:
		print("  • %s" % task)

	# 完成一个任务 → 计数器+1
	researcher.dispatch_tool_call("realtime_counter", {
		"doc_id": "task_board",
		"field_name": "completed_count",
		"operation": "increment",
	})
	var r14 := analyst.dispatch_tool_call("realtime_counter", {
		"doc_id": "task_board",
		"field_name": "completed_count",
		"operation": "get",
	})
	print("已完成任务数: %d" % r14["value"])

	# 获取完整快照
	var r15 := analyst.dispatch_tool_call("realtime_get_document_snapshot", {
		"doc_id": "task_board",
	})
	print("\n📋 任务看板完整快照:")
	print(JSON.stringify(r15["snapshot"], "\t"))

	print("\n========== 演示完成 ==========")
```

---

## 七、Agent与LLM集成示例

```gdscript
# agent_llm_bridge.gd
extends Node

## 将文件系统工具接入LLM的tool calling流程

var _tools: AgentFSTools
var _agent_id: String


func _init(fs: SharedFileSystem, agent_id: String) -> void:
	_agent_id = agent_id
	_tools = AgentFSTools.new(fs, agent_id)


func get_system_prompt() -> String:
	"""生成包含文件系统说明的系统提示词"""
	return """你是Agent "%s"，你拥有一个共享文件系统，可以与其他Agent协作。

## 文件系统说明

### 1. 专属工作区 (agents/%s/)
- 只有你能写入，其他Agent只能读取
- 用于保存你的工作产出、草稿、中间结果

### 2. 交接区 (handoff/)
- 用 handoff_file 把文件正式交给另一个Agent
- 用 check_my_handoffs 查看别人交给你的文件

### 3. 协作区 (collaborative/) —— 版本控制
- 多人轮流编辑的文档
- ⚠️ 写入时必须带上 expected_version（从 collab_read 获取）
- 如果发生冲突，需要读取最新版本、合并修改后重试

### 4. 实时协作区 (realtime/) —— CRDT无冲突
- 多人可以同时编辑，永远不会冲突
- 文本编辑用 realtime_edit_text
- 列表/集合用 realtime_modify_set
- 计数器用 realtime_counter
- 单值字段用 realtime_set_field

## 选择策略
- 自己的草稿/中间结果 → 专属工作区
- 明确交给某人的成果 → 交接区
- 需要轮流审阅修改的正式文档 → 协作区（版本控制）
- 需要多人同时编辑的看板/列表/实时文档 → 实时协作区（CRDT）
""" % [_agent_id, _agent_id]


func get_tools_for_llm() -> Array[Dictionary]:
	"""获取工具定义，传给LLM API的 tools 参数"""
	return _tools.get_tool_definitions()


func handle_tool_call(tool_name: String, arguments_json: String) -> String:
	"""处理LLM返回的tool call，返回结果JSON字符串"""
	var arguments = JSON.parse_string(arguments_json)
	if not arguments is Dictionary:
		return JSON.stringify({"success": false, "error": "参数解析失败"})

	var result := _tools.dispatch_tool_call(tool_name, arguments)
	return JSON.stringify(result)


## 完整的LLM对话循环示例（伪代码，需要接入你的LLM API）
func run_agent_turn(user_message: String) -> String:
	# 1. 构建消息
	var messages: Array[Dictionary] = [
		{"role": "system", "content": get_system_prompt()},
		{"role": "user", "content": user_message},
	]

	# 2. 调用LLM（这里是伪代码，替换成你的实际API调用）
	var max_tool_rounds: int = 10
	var final_response: String = ""

	for _round in range(max_tool_rounds):
		# var llm_response = await call_llm_api(messages, get_tools_for_llm())
		#
		# if llm_response.has("tool_calls"):
		#     for tool_call in llm_response["tool_calls"]:
		#         var result = handle_tool_call(
		#             tool_call["function"]["name"],
		#             tool_call["function"]["arguments"]
		#         )
		#         messages.append({"role": "tool", "content": result, ...})
		#     continue  # 继续下一轮
		# else:
		#     final_response = llm_response["content"]
		#     break
		pass

	return final_response
```

---

## 八、架构总结

```
┌─────────────────────────────────────────────────────────────────┐
│                        Agent LLM Bridge                         │
│  (系统提示词 + tool definitions + tool call dispatch)           │
├─────────────────────────────────────────────────────────────────┤
│                       AgentFSTools                              │
│  (统一工具接口层：每个方法 = 一个 LLM tool)                      │
├──────────┬──────────────┬──────────────┬────────────────────────┤
│ 专属区    │   交接区      │   协作区      │     实时协作区          │
│ (直写)   │  (单向传递)   │ (版本控制)    │     (CRDT)             │
│          │              │              │                        │
│ agents/  │  handoff/    │collaborative/│     realtime/          │
│ {id}/    │  X_to_Y/     │ .versions/   │     .crdt_state/       │
│          │              │ current/     │                        │
├──────────┴──────────────┼──────────────┼────────────────────────┤
│  SharedFileSystem       │VersionedFS   │  CRDTManager           │
│  (分区所有权 + 路由)     │(乐观锁+历史)  │  (CRDTDocument)        │
│                         │              │  ├ LWWRegister          │
│                         │              │  ├ RGA (文本)           │
│                         │              │  ├ ORSet (集合)         │
│                         │              │  ├ LWWMap (键值对)      │
│                         │              │  └ PNCounter (计数器)   │
└─────────────────────────┴──────────────┴────────────────────────┘
                              │
                     Godot FileAccess / DirAccess
                              │
                         磁盘文件系统
```

### 三层策略各管什么：

| 层 | 解决什么问题 | 机制 | 冲突处理 |
|---|---|---|---|
| **分区所有权** | 大部分写操作根本不会冲突 | 每个Agent只写自己的区域 | 从结构上消除冲突 |
| **版本控制** | 需要轮流编辑的正式文档 | 乐观锁 + 版本号 | 检测冲突 → Agent合并重试 |
| **CRDT** | 需要同时编辑的实时文档 | 数学保证的无冲突合并 | 自动合并，永远不冲突 |

### 选择哪一层的决策树：

```
这个文件会被多个Agent写入吗？
├── 否 → 专属区（agents/{id}/）
└── 是 → 需要同时编辑吗？
    ├── 否（轮流编辑）→ 协作区（版本控制）
    └── 是（同时编辑）→ 实时协作区（CRDT）
        ├── 纯文本 → RGA
        ├── 列表/集合 → ORSet
        ├── 键值配置 → LWWMap
        ├── 单值字段 → LWWRegister
        └── 计数统计 → PNCounter
```

### 文件清单（需要创建的GDScript文件）：

```
res://shared_fs/
├── shared_file_system.gd      # 主入口，分区所有权 + 路由
├── versioned_file_system.gd   # 版本控制层
├── crdt_types.gd              # CRDT数据结构（LWW/RGA/ORSet/LWWMap/PNCounter）
├── crdt_document.gd           # CRDT文档（多种CRDT字段的组合）
├── crdt_manager.gd            # CRDT管理器（持久化 + 同步）
├── agent_fs_tools.gd          # Agent工具接口（LLM tool calling）
└── agent_llm_bridge.gd        # LLM集成桥接
```

这就是完整方案。核心思想是**用分区所有权消除90%的冲突，用版本控制处理轮流编辑，用CRDT处理真正的同时编辑**，三层各司其职，互不干扰。