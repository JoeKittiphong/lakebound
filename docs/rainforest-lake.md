# Rainforest lake, 1000 × 500 metres

The first menu region (`river`, preserving existing save/mission identifiers) now opens
`res://features/regions/grand_river.tscn`. Its editable world is
`res://world/rainforest_lake/rainforest_lake.tscn`.

Layout: a central lake, three wooded islands, three satellite pools connected by
boat-depth channels, a southwest arrival jetty, three pedestrian bridges, a north
rock ridge, and a dry shoreline walking trail. The footprint is X −500…500,
Z −250…250. Terrain, collision, fishing, swimming and minimap share
`lake_definition.tres` and its shoreline field. Bridges have a clear central boat
passage; their supports stand near the banks.

## Assets and editor workflow

Original Blender assets and the old `world/river/river_world.tscn` are preserved.
The new atlas combines foliage, twigs, rolled banana sheaths, taro, ferns, grasses,
seaweed and rocks made in this conversation. Existing broadleaf trees, fallen logs,
lotus and timber jetty assets are also reused. Source/export provenance is in
`assets/environment/rainforest_lake/asset_manifest.json`.

The world contains saved terrain MeshInstances, collision shapes, lighting,
facilities, markers and distant forest batches. Detail cells are editable saved
scenes under `world/rainforest_lake/cells/`. Their meshes are shared external `.res`
resources, rather than copies embedded into every cell. Foliage batches store
editable CPU transforms and reconstruct their MultiMesh buffers on entering the
tree, including editor preview; this avoids losing instance transforms when a
scene is authored with the headless renderer.

To regenerate the authored world after changing the layout/builder:

```text
Godot_v4.7.2-stable_win64.exe --headless --path fishing-game --script res://tools/build_rainforest_lake.gd
```

Regeneration replaces generated world/cell/terrain files. Save intentional manual
edits separately or incorporate them into the builder before regenerating.

## Rendering and streaming tuning

- Renderer stays Mobile D3D12, using the installed Godot 4.7.2.
- Terrain: 200 tiles, 40,000 total triangles, always resident with ground collision.
- Tree A geometry: 2,071 / 1,719 / 237 triangles; Tree B: 1,463 / 871 / 306.
- Tree near/mid/far transitions: 55 / 125 metres; far forest ends at 610 metres.
- Small plants: near to 34 m, reduced cards to 67 m. Rocks/large props to 100 m.
- Shared 2048² atlas; alpha scissor 0.42, opaque surviving pixels, double-sided
  foliage, no alpha blend/hash antialiasing. Water retains its separate depth shader.
- Near tree shadows only, directional shadow range 55 m; plant shadows disabled.
- Streaming: 50 m cells, 125 m load radius plus cell extent, 195 m unload radius,
  maximum 44 resident detail cells, one asynchronous request, 2 ms instantiation
  scheduling budget. This is a scheduling target; one indivisible cell can exceed it.
- On mobile, the streamer requests a 30 FPS cap. A cap does not prove a device can
  sustain that frame rate.

Tune streaming exports on `WorldStreaming`, material threshold in
`vegetation_material.tres`, terrain appearance in `terrain.gdshader`, and placement
density/LOD ranges in the authoring tool.

## Validation

Run `tests/rainforest_lake_test.gd` with `LAKEBOUND_QA_DIR` pointing outside the
project and isolated APPDATA/LOCALAPPDATA. The rendered test checks arrival ground,
jetty collision, actual casting/boarding/swimming, all three bridges and boat
passages, fish save migration, alpha scissor, persisted GPU transforms, decreasing
LOD geometry, six rendered benchmark sites and cross-map streaming eviction.
Benchmarks explicitly remove the FPS cap/VSync only in that test process.

`tests/rainforest_fishing_test.gd` exercises a natural resident bite, strike,
fight, landing, keeping the catch and population persistence on the new lake.
Existing fishing-map data and legacy-region save tests cover map projection and
preservation of wallet, tackle, fish identity/weight and mission progress.

Screenshots, machine-specific performance JSON and logs are under the workspace
`exports/rainforest-lake/qa/`, outside the source project. Desktop results must not
be presented as Android measurements: no phone is connected for this task.

Initial desktop run (2026-10-30), before shoreline enrichment: 169 checks, zero failures; NVIDIA GTX 1660 Ti,
1280×720, Mobile D3D12. Six warmed sites measured 514–595 FPS uncapped.
Cross-map travel: p95 2.863 ms, p99 3.843 ms, maximum sampled frame 8.248 ms;
peak 29 resident cells, zero failed loads. Peak cell instantiation was 6.781 ms.
This is desktop headroom, not a mobile FPS guarantee. Separate tests passed
10 full fishing-cycle checks, 43 map-data checks and 7 legacy-save checks.


## Shoreline enrichment

The footprint and original assets are preserved. The waterbed now has a varying
23–33 m shelf with a nominal 0.80 m depth before descending into the lake. This
adds 107,132 m² of water 0.1–1.2 m deep, versus 23,628 m² for the previous bed
(2 m sampling grid), or 4.53 times as much. Pool centres remain deep habitat.
The three through-channels retain 2.4 m depth and the launch approach has a
2 m navigation pocket. The shallow shelf width/depth are exported definition
properties, not a visual-only water colour change.

Irregular rock groups, taro/ferns/shrubs and emergent grasses frame the banks;
2,177 floating lotus clusters, 977 emergent lotus clusters and 339 reed clumps
populate shallow coves. There are 1,400 flat rocks/boulders (116/188 triangles
per mesh). Floating pads are positioned above the water surface, rather than
using the submerged root height of marsh plants. Darker rock instance colours
add contrast against the sandy waterbed.

A 9 m corridor around the jetty approach and 17 m around each channel centreline
exclude planted props/rocks. A dry shoreline path remains clear. The jetty ramp
is longer and meets the terrain without the former raised collision lip.
Existing physics, fish identity/save revision and map identifiers are retained.

Sparse authored shore silhouettes remain visible at 125–450 m; near detail uses
the existing cell streamer. The saved world metadata includes placement counts
and shelf-area metrics so regression tests do not depend on external QA files.
Source regeneration remains deterministic. Screenshots and the latest rendered
report are in `exports/rainforest-lake/shoreline-qa/` outside the project.


Latest enriched-shoreline desktop run: 177 checks, zero failures; 442–545 FPS uncapped at 1280×720 on GTX 1660 Ti. Travel p95 2.520 ms, p99 3.606 ms, maximum sampled frame 10.128 ms; peak 37 resident cells, zero failed loads. No mobile device was tested.


## Irregular lake and north cliff revision

The old overall ellipse is replaced by an authored asymmetric shoreline polygon,
with separate long coves, narrow headlands and flooded southwest/south banks.
The three satellite basins have different extents (46×28, 82×54 and 72×46 m
semiaxes), additional lobes and intrusive land fingers. Island rims also have
inlets and spits. These are the real terrain/collision/water boundaries, not an
image laid over the old terrain. Navigation and infrastructure clearances remain
protected locally while surrounding unused land becomes water.

`lake_outline`, `pools` and shelf values remain editable in the definition.
The authoring tool bakes them to a 501×251 single-channel float Image resource
(`shoreline_field.res`, about 0.5 MB). Movement and fish use bilinear CPU sampling;
they do not repeatedly evaluate the polygon's segments at runtime. Regenerate
the world after changing outline points so the float field, terrain, collision,
foliage positions and minimap remain consistent.

`NorthernCliffWall` contains 207 saved rock pieces in shared MultiMesh batches,
with saved collision shapes. Two overlapping rock tiers follow the actual north
shore, with 24–34 m pinnacles and projecting low ledges. The inland terrain rises
to the cliff plateau while bridge approaches retain their previous ground.
Original rock meshes stay at 116–300 triangles per individual piece; scaling
instances does not add polygons. Cliff geometry is always resident as a distant
landmark; nearby undergrowth still uses the bounded detail-cell streamer.

Latest screenshots and machine results for this revision are in the workspace
`exports/rainforest-lake/organic-qa/`. The top-down capture uses the real authored
scene with a correctly framed orthographic camera and no fog for inspection.


Final irregular-lake validation: 186 checks, zero failures. Water area 316,148 m², an increase of 64,636 m² over the previous shoreline (25.7%). Desktop 1280×720, GTX 1660 Ti: 460–702 FPS uncapped; travel p95 2.381 ms, p99 3.248 ms, peak 29 resident cells and zero load failures. No mobile measurement.


## Navigable cliff fishing cave

`CliffFishingCave` is a saved, editor-editable child of the lake world, placed in
the north-central cliff at X −4…84, Z −246…−172. The chamber footprint is 88×74 m;
its connected pool is about 50 m across and 4 m deep, with a wide central boat
channel, dry side banks and two close-in moorings. Roof headroom over the tested
boat/bank lanes is more than 10 m. Local markers identify the entrance, moorings
and fishing banks. The usual region spawn stays at the original southwest jetty.

The authoring tool removes the obstructing cliff pieces and detail scatter,
carves the shared terrain/collision bed, then saves a closed vaulted roof,
rock walls, irregular entrance blocks, ceiling formations and three inexpensive
bounce lights. The roof shell is 920 triangles; source rock pieces retain their
original budgets. Nothing constructs the static cave at runtime. Its geometry
and collision stay resident with the landmark cliff so the entrance cannot vanish
when a foliage cell unloads.

Cave geometry, fish and boat depth queries share the same shoreline definition.
Water's sky reflection fades inside the cave rectangle; both the main water and
its duplicated interaction patch inherit these parameters. Other maps retain the
shader's default disabled cave mode. There is no second overlapping water plane.
Boat exits inside the cave require dry ground and use an actual floor ray before
checking standing clearance, rather than putting the player in shallow water.

New games distribute fourteen of the existing 112 fish to the cave. Older saves
relocate up to fourteen fish once (about one eighth of the remaining population),
retaining identity, species, weight and progress, and persist a cave-seeding flag.
This also works for partly fished lakes; it does not refill or reset the pond.

`tests/rainforest_cave_test.gd` covers roof/wall collision, three entrance lanes,
continuous depth, actual boat entry/exit, both dry landings, walking, reboarding,
natural bite/strike/fight/landing/keep and full/depleted save migration. The GPU
run passed 37 checks, including real gameplay camera obstruction and restoration. Results/screenshots are in the workspace
`exports/rainforest-lake/cave-qa/`. Desktop results do not establish mobile FPS.
For an interactive shortcut, run `tools/preview_rainforest_cave.gd`; it loads the
normal authored region and starts aboard the boat just outside the cave.


Final cave validation: 37 checks, zero failures; 584 FPS uncapped at 1280×720 on GTX 1660 Ti, p95 2.784 ms, 270 draw calls and 235605 triangles for the sampled interior view. The map regression passed 186 checks, legacy save regression 7, and camera/movement regression 62. No mobile device was tested. The first region enables a small camera sphere sweep near the cave, avoiding walls/ceiling while preserving its authored distance outside.


## 48-species / 960-fish expansion

The lake's saved region scene now has 48 unique freshwater species and 960 initial
residents (20 per species), up from 28 species / 112 fish. Twenty already authored
catalogue species are added, with their existing models and collection icons;
menu and per-region collection membership match the playable roster. All original
species remain. Species and population are Inspector configuration on the region's
PondEcosystem, rather than fish created in response to a cast.

The lake definition contains 466 saved habitat anchors. Initial fish occupy 128
50 m cells, including the main lake, shallow shelf, three satellite basins and
cave (98 cave residents in the deterministic QA seed). Habitat selection respects
species' minimum depth and jitter remains in water. Roaming rejects water too
shallow for the species. Rebuild anchors with tools/build_lake_fish_habitats.gd;
the full terrain authoring tool also regenerates them after changing the shore.

Existing profiles receive 848 additional fish once, capped at 960 live fish.
Previously kept fish are not refilled: a legacy lake with 40 fish becomes 888,
then stays at that count on reload. A saved pond_revisions dictionary records
this independently of the fish array, so even an empty expanded lake is not
mistaken for an unexpanded save. Profile loading backfills this optional field.
The revision and population commit atomically; a failed write rolls back both
live and saved expansion. Identity, species, weight, wallet, tackle and mission
progress are preserved. Normal gradual restocking remains unchanged.

Only twelve nearby detailed fish models are rendered for this lake; other maps
retain their previous seven-model default. Fish within 95 m of the observer,
near active bait, or approaching/biting continue the 0.15 s ecological tick.
Distant idle fish accumulate time and update every 0.9 s. All 960 logical fish
remain real persistent catchable residents. Water contacts reject fish outside
the local ripple field before allocating per-fish contact state.

Validation includes initial unique IDs/roster/assets/depths, all six habitat
groups, rendering cap, immediate response around distant bait, old/new/depleted/
empty save reloads and failed-save rollback. Test outputs for this revision are
in the workspace exports/rainforest-lake/fish-qa/.

Desktop GTX 1660 Ti at 1280×720: six map sites 361–552 FPS uncapped; cave 434 FPS. Main map 1034 checks, cave 37, population/migration 33, all zero failures. No phone was tested.

The region collection UI passed 69 checks after the roster update; existing fish fight/behavior checks also passed. Expansion species offset is an Inspector setting (28 for this revision), so the addition sequence starts with the newly appended roster.
