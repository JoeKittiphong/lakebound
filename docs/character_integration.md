# Textured angler integration

The active character has since been replaced by the Mesh2Motion shorts model with
ten clips, jumping, swimming and interchangeable hand-held rods. See
[traversal-equipment.md](traversal-equipment.md) for current setup and controls.
The asset and gait figures below document the previous 994-triangle prototype.

The active player now instances `actors/player/angler_model.tscn`. Open that scene
to adjust the imported asset's scale/rotation; open `character_preview.tscn` for an
editable, lit inspection stage. Collision, camera movement and existing input
bindings remain owned by `player.tscn` / `player.gd`.

## Asset

- Body: 994 triangles, one material, one 512 × 512 color atlas.
- Test rod: 128 triangles, separate material; body + rod = 1,122 triangles.
- 26 bones, including two rod bones and two finger-group bones.
- Atlas transfers facial marks from the supplied source and paints a teal shirt,
  dark trousers/gloves, belt and brown boots. Clothing adds no geometry.
- Source: `retopology/ultralow/character_994_textured_game.blend`, outside the Godot
  project. Game asset: `actors/player/models/angler_994.glb`.
- Original 50K mesh and previous Blender files are preserved.

## Actions and gameplay

| State/input | Action |
| --- | --- |
| Ready, stationary | Idle |
| Movement | Walk_InPlace (accepted walk, reverse playback for backward travel) |
| Cast signal | Cast, retimed to the controller's actual cast duration |
| Waiting / bite, no reeling | Fishing_Idle |
| Reeling unhooked bait | Reel |
| Bite → fight | Hook_Set |
| Fight with tension | Fish_Pull |
| Catch result | Celebrate |
| Lost fish | Lost |

Transitions crossfade. Cancel clears the cast lock immediately. Movement during
fishing uses the editor-authored `FishingLocomotion` AnimationTree to filter the
accepted walk's leg tracks over the rod action. Tests sample an entire gait cycle
and verify a shin's actual pose changes, in addition to checking action names. The existing
line effect's Marker3D follows the imported animated `rod_tip` bone rather than
the former placeholder rod.

`AnglerModel.blend_time` and `fishing_idle_speed` are Inspector properties. The
imported AnimationPlayer contains all nine clips for manual inspection.

## Distance-matched walking

The walk now has a longer planted-foot pass. `walk_cycle_distance` is calibrated
to 1.995 metres per full left/right cycle at the current model scale. This is
the user's requested travel multiplier: full-speed cadence matches the earlier
2.0 m/s version while movement remains 3.8 m/s. The actual foot swing is unchanged,
so this setting intentionally allows more ground travel per visible step. Playback
rate is `actual_ground_speed * clip_length / walk_cycle_distance`, using horizontal
displacement after collisions and walking-boundary constraints. A blocked player
returns to idle. Analog movement, wading and fight movement consequently use the
same distance-based gait timing. The fishing AnimationTree applies this rate only
to its leg branch, retaining the authored rod-action timing.

Default travel speeds are now 3.8 m/s walking and 1.2 m/s fighting. Both remain
Inspector properties on the player. Walk source:
`retopology/ultralow/character_994_stride_matched.blend`.

`tests/walk_sync_test.gd` checks the planted-foot travel, several ground speeds,
fishing leg playback, reversing and wall-blocked movement. The sampled stance
travels 0.4714 m against 0.4725 m of matched ground travel (about 1.1 mm difference
for the sampled bone, not a guarantee of zero skin/toe sliding in every pose).
`tests/walk_visual_test.gd` renders the moving character against a checkered floor.

## Verification

Executed with local Godot 4.7.2. The rendered checks use the project's existing
Forward Mobile renderer on the desktop GPU.

- `tests/character_integration_test.gd`: asset/skin/texture counts, all nine clips,
  idle/walk/cast/cancel/wait/reel/hook/fight/result/lost/reset, fishing locomotion,
  cast-duration synchronization and rod-tip attachment.
- `tests/character_preview_test.gd`: rendered all nine actions in Godot.
- Existing camera movement, actual scene mouse/touch movement, mobile multitouch,
  bait retrieval and fishing simulation suites passed.
- Reports, logs and engine screenshots: `exports/qa-character/` at workspace root.
- Test runs use isolated APPDATA/LOCALAPPDATA under that QA folder.

This verifies the desktop integration, not Android/device frame rate. Fingers
remain a coarse grouped grip and the face is static. No new Android package was
built or published.
