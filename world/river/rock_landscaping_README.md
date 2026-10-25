# Rock landscaping

Integrated in river_world.tscn as RockLandscaping, using the saved rock_landscaping.tscn scene. No runtime scatter script.

152 authored placements: Land 38, Shore 38, Shallow 38, Deep 38. All 19 recently created assets appear twice in each habitat: original mobile rock, seven reference-video rocks, six concept rocks, two clusters and three separate pebbles.

Positions use RiverDefinition habitat depths plus actual terrain collision ray samples. Bases partly embedded; uniform varied scale and yaw. Spacing follows each model footprint. Central 24 m river corridor, bridge, ford, spawn, initial mooring and jetty areas have explicit clearance buffers. Legacy Rocks container (76 old ledge, cluster and ford pebble instances) removed. Terrain, plants, bridge, jetty and gameplay markers preserved. Only the new rock library is placed in this map.

Edit individual placement transforms under RockLandscaping/Land, Shore, Shallow or Deep in the editor. Asset scenes retain static physics shapes. Manifest: rock_landscaping_manifest.json. Deterministic authoring utility: res://tools/build_rock_landscaping.gd (writes saved scene, not used at runtime).

Validation:
- rock_landscaping_test.gd: 771 checks passed; all 19 assets in every zone, depth classification, crossing/access/boat corridor clearance, retained colliders. Rendered actual map views of all four habitats.
- boat_integration_test.gd: 52 checks passed, boarding/driving/fishing/disembarking.
- river_integration_test.gd: 26 checks passed, bank/bridge/ford traversal and fishing loop.
- No physical phone frame-rate benchmark performed.

Screenshots: exports/qa-traversal/screenshots/rocks_map_land.png, rocks_map_shore.png, rocks_map_shallow.png, rocks_map_deep.png, rocks_map_spawn.png, rocks_map_overview.png.
