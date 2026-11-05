# Tidewrack — Game Design Document

Concise and living. For story canon see [`narrative-bible.md`](narrative-bible.md);
for schedule see [`milestones.md`](milestones.md).

## Pillars

1. **The fog keeps its secrets.** Discovery is slow, earned, and atmospheric.
2. **Words over combat.** The game is exploration + reading + choices. No fail
   states, no timers, no death.
3. **A place you tend.** The lighthouse is a home and a job; verbs are keeper's
   verbs — light the lamp, log the night, work the radio.

## Core loop

Explore a location → find a document, recording, or object → read/hear it in a
branching conversation → make a choice that sets a flag → the world (and later,
who answers you) responds. Repeat across locations toward the water.

## Systems

| System | State | Notes |
|--------|-------|-------|
| Branching dialogue | ✅ vertical slice | JSON graphs, choices set flags. |
| Save / load        | ✅ vertical slice | Single slot, `user://save.json (`v2`: `scene`, `flags`, `journal`)`. |
| Menus + settings   | ✅ vertical slice | Title, pause, volume, fullscreen. |
| Player movement    | ✅ vertical slice | Top-down; wall collision pending. |
| Journal            | ⏳ demo    → launch        | Tracks discovered log lDs in discovery order; persists across save, load, and Continue. |
| Second location    | ⏳ demo           | The lamp room. |
| Controller + remap  | ⏳ demo          | Currently keyboard-only, built-in actions. |
| Localization        | ⏳ press build    | String extraction + translation tables. |
| Accessibility       | ⏳ press build    | Text scale, dyslexia-friendly font, no-flash. |
| Steam integration   | ⏳ launch         | Achievements, cloud saves. |
### Journal & Save Persistence (`SAVE_VERSION = 2`)

Discovered journal entry IDs owned by `Journal` ([`scripts/journal.gd`](../scripts/journal.gd)) persist across `GameState.save_game()`, `GameState.load_game()`, and main-menu **Continue** through `user://save.json` ([`scripts/autoload/game_state.gd`](../scripts/autoload/game_state.gd)):

* **Dedicated save field**: `save_game()` writes discovered entry IDs as an ordered string array under `"journal"` alongside `"version": 2`, `"scene"`, and `"flags"`, keeping narrative choice booleans (`skeptic`, `believer`, `trusted_edith`, `radioed_tom`) separate from log discovery state.
* **Legacy `v1` save behavior**: Older saves with `"version": 1` (or no `"journal"` key) load `scene` and `flags` unchanged and initialize `Journal` to an empty list (`[]`) without inferring or backfilling entries from story flags.
* **Session lifecycle**: `GameState.new_game()` clears in-memory journal entries so prior runs never bleed into a fresh playthrough, and `Journal.restore()` hydrates saved IDs on load/Continue, emitting `journal_changed` for UI refreshes without re-firing live `entry_added` cues.


## Interaction design

Proximity-based: walk near an object, a prompt appears, press Enter. Dialogue
uses a typewriter reveal with press-to-skip; choices are keyboard-navigable and
focus the first option automatically. Movement is locked during conversation.

## Art & audio direction

Placeholder primitives today. Target: muted, desaturated palette (slate, kelp,
lamp-gold as the one warm accent — `#ffd466`); hand-painted 2D; a sound bed of
foghorn, surf, and radio static carrying most of the mood. Concept art and
final assets are produced per-milestone (see the tracker's `art` label).

## Out of scope (YAGNI)

No inventory economy, no crafting, no procedural generation, no multiplayer.
