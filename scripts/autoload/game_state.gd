extends Node
## GameState — global save/load and story flags.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices and persists them alongside `Journal` entry IDs to user://save.json.

signal state_changed

const SAVE_PATH := "user://save.json"
const DEFAULT_SCENE := "res://scenes/game.tscn"
const SAVE_VERSION := 2

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Path of the scene the player should resume into.
var current_scene: String = DEFAULT_SCENE

var _journal_ref: Node = null
var _pending_journal_entries: Array[String] = []
var _has_pending_journal: bool = false


func _ready() -> void:
	_get_journal()


func register_journal(journal_node: Node) -> void:
	_journal_ref = journal_node
	if _has_pending_journal and _journal_ref != null and _journal_ref.has_method("restore"):
		_journal_ref.call("restore", _pending_journal_entries)
		_pending_journal_entries.clear()
		_has_pending_journal = false


func set_flag(flag_name: String, value: Variant) -> void:
	flags[flag_name] = value
	state_changed.emit()


func get_flag(flag_name: String, default: Variant = false) -> Variant:
	return flags.get(flag_name, default)


func new_game() -> void:
	flags.clear()
	current_scene = DEFAULT_SCENE
	_pending_journal_entries.clear()
	_has_pending_journal = false
	var journal: Node = _get_journal()
	if journal != null and journal.has_method("clear"):
		journal.call("clear")
	state_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var journal_entries: Array[String] = _collect_journal_entries()
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
		"journal": journal_entries,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: could not open save file for reading.")
		return false
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false

	var data: Dictionary = parsed
	var raw_version: Variant = data.get("version", 1)
	var version: int = 1
	if typeof(raw_version) == TYPE_INT:
		var v_int: int = raw_version
		version = v_int
	elif typeof(raw_version) == TYPE_FLOAT:
		var v_float: float = raw_version
		version = int(v_float)

	var loaded_scene: Variant = data.get("scene", DEFAULT_SCENE)
	current_scene = loaded_scene if typeof(loaded_scene) == TYPE_STRING else DEFAULT_SCENE

	var loaded_flags: Variant = data.get("flags", {})
	if typeof(loaded_flags) == TYPE_DICTIONARY:
		var flag_dict: Dictionary = loaded_flags
		flags = flag_dict.duplicate(true)
	else:
		flags = {}

	# Older v1 saves have no "journal" key and intentionally start with an empty journal.
	var raw_journal: Variant = data.get("journal", []) if version >= 2 or data.has("journal") else []
	var clean_journal: Array[String] = _sanitize_journal_entries(raw_journal)

	var journal: Node = _get_journal()
	if journal != null and journal.has_method("restore"):
		_pending_journal_entries.clear()
		_has_pending_journal = false
		journal.call("restore", clean_journal)
	else:
		_pending_journal_entries = clean_journal
		_has_pending_journal = true

	state_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func _get_journal() -> Node:
	if _journal_ref != null and is_instance_valid(_journal_ref):
		return _journal_ref
	if is_inside_tree():
		_journal_ref = get_node_or_null(^"/root/Journal")
		return _journal_ref
	return null


func _collect_journal_entries() -> Array[String]:
	var journal: Node = _get_journal()
	if journal != null and journal.has_method("entries"):
		var raw_entries: Variant = journal.call("entries")
		return _sanitize_journal_entries(raw_entries)
	if _has_pending_journal:
		return _pending_journal_entries.duplicate()
	return []


func _sanitize_journal_entries(raw_entries: Variant) -> Array[String]:
	var clean: Array[String] = []
	if typeof(raw_entries) != TYPE_ARRAY:
		return clean
	var list: Array = raw_entries
	for item: Variant in list:
		if typeof(item) != TYPE_STRING:
			continue
		var raw_id: String = item
		var clean_id: String = raw_id.strip_edges()
		if not clean_id.is_empty() and clean_id not in clean:
			clean.append(clean_id)
	return clean
