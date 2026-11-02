# Lakebound UI refresh — 2026-10-27

## Scope and design

Implemented from the chat “ออกแบบ UI เกมตกปลา” and the follow-up instruction to
keep the movement joystick, jump, greeting, fishing joystick, and fishing rod.
Their scenes, placement, input scripts, and rod models were preserved. The
existing world, camera, and fishing mechanics are retained.

- HUD: minimap and compact mission tracker at upper left; shop/wallet, fish box,
  journal/help/mission shortcuts at upper right; bait/depth beside the right
  control. Fight mode hides preparation controls and shows the vertical tension
  meter immediately left of the original fishing control. Modal panels hide the
  underlying HUD, retain the session pause, and reset stale touch ownership.
- Shop: responsive illustrated product cards, six category choices, actual pack
  prices, owned counts, equipment specifications, buy/equip actions, and touch
  swipe scrolling that suppresses accidental purchases. Each of the 19 catalog
  items has its own editable SVG illustration. New equipment uses the existing
  authored rod models and existing lure simulation types. The redundant storage
  and boss/online tabs have been removed; the shop contains equipment and journal.
- Fish box: the cooler itself is the inventory, with eight selectable cells
  rendered on the interior tray. There is no separate list below a decorative
  model. The case has a separate lid, handles, latches and authored drop/bounce/
  open animation. Touches are projected onto the interior plane to select actual
  fish; selected cells receive a gold border. Pagination exposes every stored
  catch beyond the first eight. Both render viewports stop when the case closes.
- Map boss information: the full map displays a crown at the real boss location
  and an information card. Tapping the crown opens its details. The active map
  uses the live ecosystem; other maps use their saved populations and are marked
  as saved data. Unvisited maps do not invent a boss or position. Undiscovered
  species keep their hidden name, and victory counts are specific to each map.
- Fish actions: select a real stored catch, see its species/weight/value, sell
  individually, or confirm release to its source water. Stale selections cannot
  dispose another fish. Save failures roll back fish, currency, and population
  together. New kept catches retain a simulation snapshot; legacy catches can
  still be released using their known species/weight and source population.
  Cross-map release updates the saved source map and leaves the active map alone.
  Catch history and collection records remain intact.

## Added equipment

| ID | Item | Price | Gameplay configuration |
| --- | --- | ---: | --- |
| `medium_rod` | Balanced rod | 150 | 8 kgf; existing light rod scene |
| `long_reel` | High-capacity reel | 320 | 110 m; 2.9 m/s |
| `clear_line` | Clear line | 75 | 8 kgf; 80 m; visibility 0.75 |
| `spinner` | Spinner | 180 | Reusable swimming lure |
| `floating_lure` | Surface lure | 200 | Reusable floating lure |

Existing catalog IDs and prices were retained, so old inventory saves continue
to load. Purchases use the existing atomic profile persistence.

## Editable scenes and configuration

- `features/fishing/fishing_hud.tscn`: HUD placement and spacing.
- `features/economy/tackle_panel.tscn`: shop shell and tabs.
- `features/economy/tackle_row.tscn`: repeated product card layout.
- `features/fishing/ui/fish_storage_panel.tscn`: storage layout, preview camera,
  lighting, and detail controls.
- `features/fishing/ui/storage_box_model.tscn`: cooler meshes/materials and
  opening/closing animation tracks.
- `features/fishing/ui/stored_fish_slot.tscn`: repeated fish slot.
- `features/map/fishing_map_panel.tscn`: map UI and boss information card.
- `features/map/fishing_map_view.gd`: crown projection, drawing and selection.
- `data/equipment/*.tres`: editable product images, prices, and specifications.
- `assets/ui/shop/*.svg`: individual product illustrations.

The saved scenes expose their authored hierarchy before Play. Scripts bind data
and bind variable contents to reusable card/slot scenes. The authoring helper
`tools/author_storage_box.py` regenerates the cooler meshes and inset slot layout;
`tools/author_ui_refresh.py` also regenerates product cards and illustrations.
Review their output before using them after manual design changes.

## Verification

Godot 4.7.2. Regression suites passed: `economy`, `shop_redesign`, `hud_session`,
`catch_settlement`, `refactor_boundaries`, `traversal_equipment`,
`mobile_multitouch`, `expansion_visual`, and `ui_refresh_visual`.

The revised UI integration fixture now checks 137 conditions, including real button
transactions, source population restoration, reloads, failed-save rollback,
cross-map and legacy releases, swipe-without-purchase, modal handoff, animation
completion, native touches on interior compartments, pagination, real boss map
positions, unknown/saved regions, and layout at 1280×720, 1600×720, and 1024×768.
Latest screenshots and reports are in `exports/qa-storage-revision/final/`;
`cross-feature-results.json` preserves the map and shop regression run. The
separate smoke report is in `exports/qa-storage-revision/smoke/`.
These run on the project's Mobile renderer (Direct3D 12 on this desktop host).
The inventory texture is explicitly bound to its actual nested viewport instance
to avoid instanced ViewportTexture resolution artifacts. The preview uses a color
ambient source so every cooler face is lit without a sky resource.

The water script's inconsistent indentation was normalized without changing its
logic. Imports run in editor recovery mode so the user's cached editor tabs/tool
scripts cannot affect a test run; runtime suites load the actual game scripts.
Host certificate-store/signing-directory diagnostics are kept separately from
game errors.

Native editor capture was attempted but the capture helper timed out. Source
scene hierarchies and rendered game output were verified. Physical Android
thumb reach and device safe-area behavior still need an on-device play session;
the automated touch checks use Godot's real input routing on desktop.
