# 3D loading introduction

The project entry point remains `res://features/loading/loading.tscn`.
It composes a real 3D lakeside scene with an editable white/teal loading UI.
After Start, the same root, camera, character, bobber, animation clock and ambient sound
remain alive. Only `features/menu/main_menu_ui.tscn` is added, with a 0.25-second fade;
the loading controls are hidden. There is no 3D scene reload at this point.
The previous working loading scene and script were copied to
`../exports/loading-3d/backup/` before editing.

## Edit in Godot

- `features/loading/loading.tscn`: title, safe area, progress styles, Start and Retry buttons.
- `features/menu/main_menu_ui.tscn`: the backdrop-free main menu controls. This is the
  threaded destination and includes the gameplay resource dependencies.
- `features/menu/main_menu.tscn`: an inherited version of the same controls, plus the
  shared cinematic with `play_intro = false`, used when returning from gameplay.
- `features/menu/lake_menu_theme.tres`: editable white/teal menu styles and Thai font.
- `features/loading/cinematic/loading_cinematic.tscn`: camera, daylight, lake, dock,
  shoreline props, mountain instances, character, bobber, splash, sound players.
- `Timeline` in that scene uses `cinematic/arrival_motion.tres`: `arrival` contains the
  walk path, camera, full-body poses, grip motion, footsteps and action cues; `waiting`
  contains the planted quiet hold. Both animations remain editable in AnimationPlayer.
- The cinematic root exposes playback speed and bobber motion. Lake color/waves are
  ShaderMaterial properties. Individual pine instances and dock planks are selectable.
- `pine.tscn` is the reusable tree. Pine and mountain OBJ files and WAV cues are original
  lightweight assets created for this feature. Existing character, rod, rock and reed assets
  are reused without editing their source assets.

Sequence: establish 0–0.8 s; walk 0.8–5.0 s; close the trailing step by 5.55 s;
settle/regrip until 5.65 s;
cast anticipation starts 5.65 s; forward-stroke release at 6.77 s; splash at 7.67 s;
waiting at 8.0 s; camera settles at 8.8 s and the waiting loop continues.
Bobber flight reads the release/landing method-key times from the saved animation.

## Natural arrival motion — revised 2026-10-27

The cinematic uses its own baked performance. The original gameplay character, mesh,
imported clips and locomotion controller are reused without editing them. During the
cinematic, the character's gameplay animation players are disabled so the Timeline is
the only owner of the pose. This also removes the frozen fishing upper body during walking.

The 4.9-unit arrival eases into and out of movement, with a 1.0667-unit gait cycle matched
to the smaller cinematic character. The right hand carries the rod while the left arm,
spine and pelvis retain their walking motion. Contact sounds follow gait phase. The first
frame applies a comfortable carry pose immediately, before the first rendered frame.
The last right foot supports the body while the left foot lifts and closes the final step.
The standing fore/aft ankle separation is 9 cm, instead of holding the previous 45 cm
walking stride throughout the cast. The final actor position is (-2, 0.9, 0.1).

Offline leg IK uses a stable forward knee bend plane with slight toe-out; an almost
straight source knee no longer supplies a potentially unstable bend direction. Walking
foot clearance is reduced to avoid a marching pose. Toe contact is held during stance,
and the hips adjust only as needed to stay within the original leg lengths. An offline
skin pass evaluates the actual weighted shoe vertices and corrects floor penetration.
All corrections are baked into the AnimationLibrary at 60 fps, with no runtime IK cost.
The cast preserves the source anticipation, accelerates the forward stroke, then settles
into a quiet breathing hold. The waiting loop keeps the actor root and feet fixed.

The same authored clock drives skeleton, travel, camera, release and splash. The line tip
is evaluated against the current hand pose; the bobber follows a ballistic arc and stops
at water contact, so a later frame cannot restart its flight after the splash.

Rebuild with the installed Godot executable:

```powershell
& $godotExe --headless --path . --script res://tools/build_loading_motion.gd
```

The builder writes the saved AnimationLibrary, rather than constructing animations during
startup. Its constants and `cast_source_time()` control timing and the offline pose blend.
After editing cue times directly in Godot, flight timing follows those cues automatically;
after editing the builder, rebuild to update the corresponding body poses and sound keys.

Current validation artifacts are in `exports/qa-loading-legs/`; the previous motion
library and builder are preserved in its `before/` folder. The older
`exports/qa-loading-motion/` preview represents the superseded stance.

- `tests/loading_leg_pose_test.gd`: 1,634 sampled poses at 120 Hz across arrival and
  the complete waiting loop, 11 checks passed. Checks cover skinned soles, continuous
  support, knee direction, standing stance, leg continuity, foot crossing and toe slip.
  Lowest sole clearance was 0.31 mm; the highest supporting sole was 5.19 mm above
  the reference deck plane. Closing-step support drift was 0.16 mm horizontally.
- `tests/loading_motion_test.gd`: 43 checks passed, including first-visible-frame pose,
  planted ankles, forward release, continuous flight, a stalled frame, return-to-menu,
  and 0.5×, 1× and 2× playback.
- Loading/retry passed 10 checks; startup → menu → gameplay → return passed 16 checks.
- Rendered and inspected 33 front/side/game-angle poses, a 196-frame continuous
  capture, and loading/menu views at 1280×720, 1600×720 and 1024×768 on Mobile/D3D12.
  `loading_legs_fixed.gif` is the 20 fps close-up review capture.

The Windows certificate-store diagnostic and the pre-existing eight-object shutdown
warning remain recorded in the loading/startup logs; the leg and motion suites exit cleanly.
These checks use the installed desktop engine, not a physical Android device.

The loader requests the existing menu and its gameplay dependencies after two frames.
Progress reflects resource progress; it can reach 100% while the intro finishes. Start is
enabled only after both are ready. A press (or Enter/Space via `ui_accept`) reveals the
menu controls on the live scene. Play then opens gameplay; Back returns directly to the
waiting composition with the same main menu controls.
Retry preserves the cinematic, resets the load UI, and requests the destination again.

## Validation — 2026-10-25

Godot 4.7.2, existing Mobile renderer / D3D12, GTX 1660 Ti:

- Engine imports and parses the new scenes, meshes, shaders and sounds.
- `tests/startup_flow_test.gd`: 15 passing checks for ready gating, explicit Start, preservation of the actual
  cinematic/camera instances, menu → gameplay → menu, and waiting on return.
- `tests/loading_flow_test.gd`: 10 passing checks for early tap, wrong resource type, retry, waiting-loop
  continuity and repeated Start presses creating exactly one menu overlay.
- `tests/loading_cinematic_visual_test.gd`: captures establish/walk/cast/wait and
  the menu reveal and 1280×720, 1600×720, 1024×768 layouts. Screenshots were visually inspected.
- Waiting view: 254 draw calls / 117,683 rendered primitives on this desktop capture.
  This is not an Android performance measurement.
- A skeleton signal during gameplay teardown exposed a deferred rod-tip update on a
  detached player. `_sync_rod_tip()` now skips detached nodes; the navigation rerun has
  no script/runtime errors.

Logs and screenshots are in `../exports/loading-3d/`. The host reports an inaccessible
certificate store, and Godot reports 8 ObjectDB instances at process shutdown; these
remain recorded in the logs. Audio streams loop natively and are stopped on exit;
the headless tests allow the audio mixer to drain before quitting. One concurrent
retry run exceeded its 20-second readiness deadline; running the suite separately
passed in approximately 10 seconds. Use sequential integration runs for this project.
Import also reports the inaccessible existing signing
directory. Native editor screenshots timed out, so editor interaction and physical
Android touch/performance have not been verified. Saved scene trees are fully authored.
