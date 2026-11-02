# Circular local minimap and fish scan

The gameplay HUD now uses a circular local map with the player fixed at its center. Default coverage is a 100-metre horizontal radius (200 metres across). There is no visible numeric range label. North remains up and the center heading arrow follows the real player's visual heading, including the boat driver's orientation. Walking and boating move the terrain under the center marker rather than moving the marker around a full-region overview.

## Editable scene

Open `features/map/minimap.tscn`. The authored hierarchy contains the local Terrain TextureRect, circle/marker shaders, cream-and-black rim, north tick/label, separate ScanButton and short scan feedback label. The widget remains 196x202 logical pixels, preserving its existing separation from ranking, missions and the upper action row. Decorative controls ignore input; the circular map remains a Button opening the existing full map. Its transparent corners do not behave like an invisible rectangular button. ScanButton is a separate 48x48 touch target and does not trigger the map's pressed action.

The root exports `radius_m`, `scan_duration`, `pulse_duration` and `update_interval`. Defaults are 100 metres, six seconds, 0.75 seconds and 0.1 seconds respectively. Artwork is in `assets/ui/minimap/`; shader materials are local to each instance. There is no extra minimap 3D camera or SubViewport.

`local_minimap_view.gd` projects world XZ around the player's current XZ using the same scale on both axes. The terrain shader samples the existing region map resource over that 200x200-metre square and clips it to a circle. Near region boundaries, out-of-bounds UVs use a plain outside color instead of clamping the player away from center or wrapping the opposite shore into view. Red dots, favorites and destination markers are circle-clipped too. Full-map pan, zoom, saved history and navigation remain in the existing FishingMapPanel/FishingMapView implementation.

## Real fish echoes

FishingHUD supplies the session's actual PondEcosystem to the minimap. Pressing Scan captures the existing fish within the circular XZ radius, shows a brief scan pulse and displays their positions as red dots for six active-gameplay seconds. No population is spawned or modified by scanning, and no discovery, currency, stamina or save state is changed. Repeated scans are free and have no cooldown. An empty result briefly says 'ไม่พบปลา'.

Detected fish are followed at the minimap update interval while the echo lasts. A population-change membership index removes kept fish immediately without an O(population x detected-fish) membership check every frame. Dots outside the current radius are culled; newly entering fish require another scan. Map rebinding clears echoes. Hiding the HUD during a paused modal also suspends the visible scan timer. At expiry, echoes disappear instead of becoming permanent or stale.

FishState.position.y represents depth, so range and projection deliberately use XZ. The range includes its 100-metre boundary and rejects non-finite positions. The normal game state disables scanning whenever the existing minimap is disabled.

## Validation

`tests/minimap_scan_test.gd` exercises the actual rainforest scene and deterministic cases at/just outside the radius, diagonal square corners, invalid positions, moving fish, kept fish, scan expiry, empty results, map rebinding, UV boundaries, player centering, actual boat boarding/movement/heading, touch and mouse scan input, full-map opening and three viewport sizes. `tests/compact_hud_test.gd` checks the surrounding HUD controls. `tests/fishing_map_visual_test.gd` retains full-map/history/navigation and boat-control coverage.

Screenshots and logs are in `exports/minimap-scan-qa/`. The live shore scan capture uses the real initialized fish population; deterministic test fish only exist in the isolated QA process. Physical phone performance has not been measured.
