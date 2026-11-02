# HUD input and Editor Run repair

The reported frozen Debug / unclickable HUD was reproduced with an actual F5 run from the existing Godot Editor. `fishing_hud.gd` failed to parse at line 323, so FishingHUD and dependent gameplay scripts did not initialize even though scene-authored artwork could still appear.

The UI scripts had been authored with one space per indentation level. The user's editor uses tabs with indentation size four. Saving before Run converted the four leading spaces on the deepest HUD statement into one tab while leaving the shallower one-to-three-space prefixes intact. This recreated mixed indentation every time F5 saved the script; correcting only that one line did not survive the next Run. Restarting the editor alone did not solve it.

Normalized the runtime scripts touched by the recent UI work to one tab per block: FishingHUD, CollectionPanel, CollectionFishTile, CollectionBookPreview, FishBoxView and SafeArea. Non-whitespace line content was verified unchanged. No global Editor preferences or gameplay save data were changed. The editor was closed normally and reopened with its saved scene layout, then Run was exercised twice. All six source hashes remained unchanged after the Editor save/run cycles.

Validation artifacts are in `exports/ui-input-qa/`:

- `indentation-baseline.json`: normalized source hashes used for both Run comparisons.
- `hud-final.log`: 107 checks covering touch actions and modal resume behavior.
- `collection-final.log`: 162 checks covering the 3D book, selection, swipes, ribbons and pause handoff.
- `session.log`: 45 session API and pause-boundary checks.
- `mouse.log`: 12 real mouse-input checks on the actual rainforest map, opening/closing shop, cooler, missions, Collection and settings, including fish selection and Resume.
- `editor-final.log`: final editor session; no HUD parse errors after repeated F5. Existing MultiMesh diagnostics from reopening the unrelated garden dressing scene are separate from this script parsing/input repair.

Use canonical tab indentation for these scripts when editing or generating them. Do not reintroduce one-space-per-block formatting; it is incompatible with the current editor's save conversion. The new `tests/desktop_hud_input_test.gd` supplements the existing touch fixtures with actual viewport mouse events.
