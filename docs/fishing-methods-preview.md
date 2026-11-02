# Fishing methods journal preview

Replaced the shop's long journal text with an authored `fishing_methods_view.tscn` component. The first row has six real region tabs. The left side is a three-column gallery of species actually caught in the selected region. Each tile shows only a large fish picture and its name; catch count and best-weight subtitles were removed. Details stay hidden until the player clicks a fish. Selecting a species opens a per-capture selector on the right, latest first, so bait/equipment/settings always come from the same capture rather than combining records.

The detail area separates bait, line, rod and reel into named fields; settings show bite depth, reel brake and cast distance where recorded. Bait IDs resolve through TackleCatalog, with purchase-pack quantities omitted from the method label. The viewer never substitutes current equipment into an old record and does not mutate the journal. Empty maps show an honest empty state.

Existing catch records store bait/rod/reel/line display names and bite depth. **They do not yet record the optional `settings.drag_strength` and `settings.cast_distance` fields.** This preview displays “ไม่ได้บันทึก” for those missing values. No catch-recording or save schema changes were made in this task. The preview samples demonstrate the intended populated layout and are explicitly marked as simulated; they are never written to the player's save.

## Open in Godot

- `features/economy/fishing_methods_view.tscn`: editable region tabs, fish list and detail cards, embedded in TacklePanel's Journal tab.
- `features/economy/method_fish_row.tscn`: reusable fish-list entry.
- `tests/previews/fishing_methods_preview.tscn`: run with F6 for the clearly labelled standalone example.

`tests/fishing_methods_test.gd` verifies per-map filtering, repeated-species grouping, per-capture gear/depth, missing legacy settings, zero values, no save mutation, empty states, two viewport sizes, and the actual shop-tab binding/removal of the old text view. Captures are in `exports/qa-fishing-methods/`. No Android release built or uploaded.
