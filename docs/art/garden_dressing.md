# Approved garden kit in all playable maps

The twelve plants from `art/environment/garden-12-v01` are imported with the
original generated 1024 × 1024 atlas. Each playable world contains a saved
`GardenDressing` scene instance, with authored spatial MultiMesh batches grouped
under `Shrubs`, `Grasses`, `Flowers` and `Waterside`. No runtime spawning script
is needed to see the new plants in the editor.

| Map | Plants | Spatial render batches |
| --- | ---: | ---: |
| Grand river | 284 | 102 |
| Lotus marsh | 253 | 74 |
| Forest stream | 273 | 84 |
| Wild reservoir | 238 | 90 |
| Mangrove estuary | 260 | 61 |
| Coral coast | 270 | 53 |
| **Total** | **1,578** | **464** |

Open `world/river/garden_dressing.tscn` or the corresponding
`world/regions/<map>/garden_dressing.tscn` to adjust the saved batches. Their
MultiMesh transforms, scale and color are stored in the scene. Each batch has
metadata identifying the source concept and plant count. The twelve individual
editable prefabs are in `world/vegetation/garden/plant_01.tscn` through
`plant_12.tscn`. Meshes and the shared two-sided opaque material live in
`assets/environment/garden/`.

Placement varies by habitat: forest banks favor ferns, small shrubs and
bellflowers; wetlands add sedge-like grasses and a few cattails; coastal banks
use broadleaf clumps, grasses and sparse yellow flowers, with no freshwater
cattails. Bases are sampled against the actual terrain physics mesh, not just
the analytical height function. Rocks, steep slopes, spawn areas, dock
approaches, river crossings and the shoreline walking strip are avoided. The
new vegetation adds no collision shapes.

The plants share one material and atlas. Nearby plants of the same type are
batched in 28 m spatial cells, with visibility ranges of 44–68 m. Dense grass
and flower batches do not cast shadows. This is an authoring and culling
configuration; target-device frame rate has not been measured.

## Rebuilding and QA

1. Re-export the twelve approved meshes using
   `art/environment/garden-12-v01/export_garden_for_game.py` in a background
   Blender process. The normal live Blender session need not be changed.
2. Import `flora_atlas_1024.png` with the project editor.
3. Run `godot --path . --rendering-method gl_compatibility --script
   res://tools/build_garden_dressing.gd` from the project directory. Use a GPU
   renderer: Godot's headless dummy renderer does not retain MultiMesh buffers
   when authoring these scenes. The tool refuses headless execution.
4. Run the registered `garden_dressing` content test, or run
   `res://tests/garden_dressing_test.gd` with the Mobile renderer. It validates
   the saved scene transforms, terrain contact, clearance, habitats, material
   sharing, all six selectable gameplay scene references, and captures each map.
5. `res://tools/smoke_garden_gameplay.gd` starts each real gameplay scene and
   checks for the garden instance and a player standing on solid ground. Use
   isolated APPDATA/LOCALAPPDATA directories for QA so player saves stay separate.

The machine-readable population and mesh counts are in
`garden_placement_report.json`. Latest QA logs and six screenshots are under
`exports/qa-garden/`. The pre-existing water-contact script had mixed leading
tabs and spaces; indentation was normalized without changing its logic so the
real gameplay scenes could be parsed for startup verification.

Verified on Godot 4.7.2: Mobile renderer content QA passed **64 checks** with
six captured maps; gameplay startup passed on **all six maps**, including a
player standing on real ground. The Windows certificate-store diagnostic is
unrelated to these scene, resource and gameplay checks.
