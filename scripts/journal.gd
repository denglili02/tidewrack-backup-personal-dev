extends Node
## Journal — discovered-logs system.
##
## Autoloaded as `Journal`. Records discovered log entry IDs in discovery order
## and exposes helpers for `GameState` to clear or restore them across saves.

## Emitted during live play when a new entry ID is discovered for the first time.
signal entry_added(id: String)
## Emitted whenever the entry list changes (live discovery, load restore, or clear).
signal journal_changed

var _entries: Array[String] = []


func _ready() -> void:
	if is_inside_tree():
		var game_state: Node = get_node_or_null(^"/root/GameState")
		if game_state != null and game_state.has_method("register_journal"):
			game_state.call("register_journal", self)


func discover(id: String) -> void:
	var clean_id: String = id.strip_edges()
	if clean_id.is_empty() or clean_id in _entries:
		return
	_entries.append(clean_id)
	entry_added.emit(clean_id)
	journal_changed.emit()


func entries() -> Array[String]:
	return _entries.duplicate()


func has(id: String) -> bool:
	var clean_id: String = id.strip_edges()
	return not clean_id.is_empty() and clean_id in _entries


func clear() -> void:
	if _entries.is_empty():
		return
	_entries.clear()
	journal_changed.emit()


## Replaces in-memory entry IDs from a parsed save array without firing live
## `entry_added` signals. Missing or non-array data resets to an empty journal.
func restore(raw_entries: Variant) -> void:
	var next_entries: Array[String] = []
	if typeof(raw_entries) == TYPE_ARRAY:
		var source_list: Array = raw_entries
		for item: Variant in source_list:
			if typeof(item) != TYPE_STRING:
				continue
			var raw_id: String = item
			var clean_id: String = raw_id.strip_edges()
			if not clean_id.is_empty() and clean_id not in next_entries:
				next_entries.append(clean_id)

	var changed: bool = next_entries != _entries
	_entries = next_entries
	if changed:
		journal_changed.emit()
