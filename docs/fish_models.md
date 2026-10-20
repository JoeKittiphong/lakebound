# Blender fish integration

The former primitive fish model has been replaced with the approved sixteen
mobile Blender assets. The existing three species keep their IDs and weight,
bait and combat tuning; the other thirteen are added to the shared catalog.
The pond remains at 30 simulated fish and seven pooled visible models.

## Editing

- Open `world/pond/models/fish_catalog_preview.tscn` to inspect all sixteen
  real model instances before Play, or run it to see their default swim cycles.
- Each `world/pond/models/<species>.tscn` wraps its imported GLB with
  `fish_model.gd`. `fish_visual.tscn` is the reusable pond/result/card host.
- Species resources in `data/fish/` expose the model scene, physical visual
  length, preview tilt, bait/depth preferences, weight and fight tuning.
- `data/fish/fish_catalog.gd` is shared by the pond and collection. The default
  pond duplicates the catalog array so Inspector/test overrides do not mutate
  the shared list. Existing collection saves need no migration.

## Models and export

All sixteen meshes total 5,832 triangles. Each complete fish is 250–468
triangles, uses one mesh, one material and one 512x512 painted atlas. Both eyes,
fins and whiskers are included. Geometry subdivision, solidify, extra eye
layers and geometric fin-ray details are absent from the game assets.

The source export helper is `../art/fish/godot-export/export_fish.py`, relative
to this Godot project root. It exports only a temporary active scene and the
selected asset, with exactly three named NLA clips. The studio root's placement
and the ray's presentation tilt are excluded. Centering, uniform scale and
forward-axis conversion are baked into the mesh and armature rest data together;
scaled/rotated skinned parents are avoided. Imported fish are one unit long
along Godot -Z, with +Y up, then scaled by each species resource in the pond.

GLBs are under `world/pond/models/glb/` with engine-generated import UIDs kept.
Imports use 24-fps animation, named skins, two-sided opaque materials and no
generated LOD/shadow mesh or light-baking geometry. Godot recognizes the `_loop`
suffix and imports `hover`, `swim`, and `fast_swim` as looping clips, with
durations of 3, 2 and 1 seconds respectively.

## Runtime animation

| Fish state | Animation |
| --- | --- |
| Roaming / approaching | Swim; approach is quicker |
| Resting / feeding / inspecting / biting | Hover |
| Hunting / fleeing | Fast swim |
| Hooked | Fast swim while energetic; hover when fatigued |
| Landed | Slow hover |

Transitions blend over 0.14 seconds by default. Fish identities offset clip
phase, so a visible group does not move in unison. Hidden pooled models disable
their AnimationPlayer; collection cards freeze a pose and render once. The
catch-result preview gently hovers while shown and stops when the result closes.
The existing fight simulation still controls fish position, heading and energy;
no unmade fight/jump animation is claimed or synthesized.

## Validation

- `tests/fish_models_test.gd`: 530 checks covering the catalog, GLB triangles,
  texture size, skinning, canonical length, all clips/loops, state mapping,
  real tail-bone motion, hidden-pool pausing and preview modes.
- `tests/fish_catalog_fishing_test.gd`: naturally attract, hook, land and release
  each of the sixteen species using their configured bait and depth.
- Existing 60-check simulation regression uses an isolated original three-species
  population, while the full-catalog suite exercises the new production roster.
- Existing collection persistence/touch/modal checks and rendered input/fishing
  regression pass. GPU captures at 1280x720 and wider layouts are saved in
  `exports/qa-fish-models/` with logs and the import audit.

Validated on the installed Godot 4.7.2 desktop Mobile renderer. Android hardware
performance and new APK/AAB packaging were not tested in this integration.
