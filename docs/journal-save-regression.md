# Journal & Save/Continue Regression

Use the five test sections below to verify [`scripts/autoload/game_state.gd`](../scripts/autoload/game_state.gd) and [`scripts/journal.gd`](../scripts/journal.gd) before merging `fix/journal-save-persistence`.

## Case 1: `v2` Save, Cold Quit, and Continue Round-Trip

Verifies that discovered journal entry IDs, active scene path, and story flags all survive a full save, quit-to-desktop, relaunch, and **Continue** cycle in exact discovery order without re-triggering live discovery popups.

* **Preconditions**: Delete any existing `user://save.json`, launch a fresh build, and start a **New Game**.
* **Steps**: Set at least two story flags via `GameState.set_flag()` (for example, `believer = true` and `radioed_tom = true`), discover two logs in order (`Journal.discover("edith_log_01")`, then `Journal.discover("edith_log_02")`), call `GameState.save_game()`, quit the executable completely, relaunch to the title menu, and select **Continue** (`GameState.load_game()`).
* **Expected outcome**: `user://save.json` contains `"version": 2` and `"journal": ["edith_log_01", "edith_log_02"]`; after **Continue**, `Journal.entries()` returns `["edith_log_01", "edith_log_02"]` in that exact order, `GameState.flags` retains `{"believer": true, "radioed_tom": true}`, `current_scene` matches the saved scene, and `Journal.journal_changed` + `GameState.state_changed` emit once while `Journal.entry_added` does **not** fire during load.
* **Failure signal**: `Journal.entries()` comes back empty after relaunch, entry ordering changes, story flags drop or mutate, or HUD/audio listeners bound to `entry_added` replay discovery cues on **Continue**.

## Case 2: Legacy `v1` Save Migration Without Flag Backfill

Verifies that pre-journal `SAVE_VERSION = 1` saves (including JSON float version `1.0` from `JSON.parse_string()`) load all existing story flags and room paths cleanly while starting from an empty journal.

* **Preconditions**: Write a `v1` save payload to `user://save.json` with no `"journal"` key — for example, `{"version": 1, "scene": "res://scenes/game.tscn", "flags": {"trusted_edith": true, "skeptic": true}}`.
* **Steps**: Boot the game (or dirty `Journal` in memory first with `Journal.discover("temp_entry")`), verify `GameState.has_save()` is `true`, and invoke `GameState.load_game()` via **Continue**.
* **Expected outcome**: `load_game()` returns `true`, `GameState.get_flag("trusted_edith")` and `GameState.get_flag("skeptic")` remain `true`, `GameState.flags` gains no synthetic keys, and `Journal.entries()` is strictly `[]` (clearing any prior in-memory `"temp_entry"` rather than backfilling from `flags`).
* **Failure signal**: Any journal entry is synthesized from `trusted_edith` or `skeptic`, `version: 1` fails float-to-int parsing, or `flags` loses keys on a subsequent `save_game()`.

## Case 3: Same-Session State Isolation Across New Game and Unsaved Continue

Verifies that in-memory `Journal._entries` never bleeds from an active play session into a fresh **New Game** or an unsaved **Continue** reload within the same process.

* **Preconditions**: Save a baseline run containing `Journal.entries() == ["edith_log_01"]` in `user://save.json`.
* **Steps**: During live play, call `Journal.discover("edith_log_unsaved")` *without* saving, return to the title screen, and click **Continue** (`load_game()`); next, discover `"edith_log_unsaved"` again, return to the title screen, and click **New Game** (`new_game()`).
* **Expected outcome**: On **Continue**, `"edith_log_unsaved"` is discarded and `Journal.entries()` matches disk (`["edith_log_01"]`); on **New Game**, `GameState.flags` is `{}`, `current_scene` resets to `"res://scenes/game.tscn"`, and `Journal.entries()` is `[]`.
* **Failure signal**: `"edith_log_unsaved"` remains visible after clicking **Continue**, or `"edith_log_01"` / `"edith_log_unsaved"` carries over into **New Game**.

## Case 4: Duplicate IDs, Malformed JSON Types, and Corrupt Save Handling

Verifies Godot 4 typed `Array[String]` safety against duplicate, blank, or non-string JSON values, and confirms that truncated or malformed `user://save.json` files (such as `FB-005` in `playtests/feedback_log.csv`) fail cleanly without corrupting live session state.

* **Preconditions**: Start an active session with `GameState.set_flag("believer", true)` and `Journal.discover("edith_log_01")`.
* **Steps**: First, call `Journal.discover("")`, `Journal.discover("   ")`, and `Journal.discover(" edith_log_01 ")`; second, load a `save.json` containing `"scene": 42`, `"flags": ["bad"]`, and `"journal": ["edith_log_02", "", "  ", 99, null, "edith_log_02", " edith_log_03 "]`; third, overwrite `user://save.json` with a truncated JSON string (`{"version": 2, "scene": "res://scenes/`) and call `GameState.load_game()`.
* **Expected outcome**: Blank and whitespace-only `discover()` calls are ignored and `" edith_log_01 "` deduplicates against `"edith_log_01"`; the malformed-field save loads without a Godot 4 typed-array assignment error, falling back to `DEFAULT_SCENE`, `flags == {}`, and `Journal.entries() == ["edith_log_02", "edith_log_03"]`; the truncated save logs an error, returns `false`, and leaves the active in-memory `flags` and `Journal.entries()` untouched.
* **Failure signal**: Godot throws a runtime type error assigning untyped `Array` data to `Array[String]` or non-`String` data to `current_scene`, duplicate/empty IDs appear in `Journal.entries()`, or a failed `load_game()` wipes current in-memory state.

## Case 5: Autoload Registration Order and Deferred Restore Handoff

Verifies that `GameState` and `Journal` synchronize saved entries regardless of which autoload initializes first in `project.godot` (or when `GameState` runs standalone in headless tests before `Journal` attaches).

* **Preconditions**: Write a valid `v2` save to `user://save.json` with `"journal": ["edith_log_01", "edith_log_02"]`, and instantiate `GameState` before `Journal` is present at `/root/Journal`.
* **Steps**: Call `GameState.load_game()` while `Journal` is still unmounted, verify `GameState.save_game()` while still unmounted, and then mount `Journal` (or call `GameState.register_journal(journal)` as `Journal._ready()` does).
* **Expected outcome**: While `Journal` is unmounted, `GameState` caches `["edith_log_01", "edith_log_02"]` in `_pending_journal_entries` so an intermediate `save_game()` still writes `"journal": ["edith_log_01", "edith_log_02"]` rather than `[]`; as soon as `Journal` registers with `GameState`, `_pending_journal_entries` flushes into `Journal.restore()`, `Journal.entries()` immediately returns `["edith_log_01", "edith_log_02"]`, and `_has_pending_journal` resets to `false`.
* **Failure signal**: Loading before `Journal._ready()` silently drops saved journal entries, or saving while `Journal` is unmounted overwrites `"journal"` on disk with `[]`.
