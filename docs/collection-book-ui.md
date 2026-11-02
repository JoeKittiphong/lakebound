# Playable 3D Collection book

`features/collection/collection_panel.tscn` is the actual Collection modal used by FishingHUD. Its `Motion/Viewport/Stage/Book` instance is the real animated Blender book throughout opening, resting, page turns and closing. No separate open-book background image or replacement paper card is used. The viewport owns an isolated 3D world so gameplay lights, water and sky do not leak into it. Its last rendered open pose remains visible while idle; continuous 3D updates run only during motion or an explicit resize refresh.

The native Control content is positioned from the camera's projection of the model's open paper bounds, so it stays on the physical pages across landscape aspect ratios. The left page contains five fish per row, three rows and fifteen fish per page. Tiles have no visible table/card frames or captions. Unknown species retain silhouettes and question marks. The right page is blank on open, after changing map/filter, and after changing page. Tapping a fish reveals its details; undiscovered fish do not disclose names, bait or depth hints. Existing global collection statistics, per-map personal bests and caught-location navigation are retained without changing the save schema.

## Ribbon editing in Godot

Ribbons are native Button nodes under `Card/Content/MapTabs`, separate from the Blender mesh. Shared ribbon styles live as scene resources; edit those in Inspector to change appearance. Their labels contain names only, with no progress counters. Discovery totals remain in the left-page header.

Select the CollectionPanel root and edit `ribbon_maps` in Inspector to add, remove or reorder categories:

- Empty array: automatically show All plus every map in RegionCatalog.
- `["", "river", "coral_coast"]`: show All, River and Coral Coast in that order.
- An empty string is All. Other entries are map IDs from RegionCatalog. Invalid and duplicate IDs are ignored.

The saved scene exposes the current seven ribbon buttons before Play. Runtime reconciliation only handles the configured variable map list, using the authored first ribbon as the style template. Each panel instance owns its ButtonGroup. Ribbons preserve their artwork and active color while navigation is temporarily disabled during animation.

## Input and transitions

Horizontal touch swipes and mouse drags turn pages. A swipe must travel at least 48 logical pixels and be predominantly horizontal; small taps within 12 pixels select a fish. Vertical drags, canceled contacts and unrelated touch fingers do not select or change pages. Swipes at the first/last page are bounded. Page arrows are not used.

The same book plays `OpenBook` on opening, `TurnPage` on a swipe, and the corresponding clip backwards for previous/close. Page ink briefly fades around the physical page turn; the book background itself never switches representations. Ribbon navigation is guarded while moving. Closing during opening or turning queues a safe close and holds the gameplay pause until the closing clip finishes. Animation finalization is deferred outside AnimationMixer callbacks; callers removing scenes after closed should use queue_free or wait a frame.

## Verification

`tests/collection_book_ui_test.gd` covers real HUD touch opening, five-column frameless tiles, initially blank details, tap/swipe separation, forward/reverse turns, discovery privacy, per-map bests, filters, history-map pause handoff, name-only configurable ribbons, independent button groups and layout at 1280x720, 1600x720 and 1024x768. `mobile_collection_test.gd` additionally checks wide/small/portrait viewport bounds and last-page reachability; these are desktop viewport tests, not a physical phone benchmark. `collection_tabs_test.gd` retains exact region-membership and legacy per-map record checks. `collection_test.gd` covers recording, persistence and every catalog portrait through the pager. Other HUD/session boundary tests retain asynchronous closing semantics.

Screenshots and logs are under `exports/collection-book-ui-qa/`. The colorful fish statistics in those screenshots are isolated QA fixtures and do not modify the player's save.
