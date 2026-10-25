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
- `Timeline` in that scene: `arrival` has the walk path, camera movement and action cues;
  `waiting` has the gentle idle motion. The animation is authored, not built at runtime.
- The cinematic root exposes playback speed and bobber motion. Lake color/waves are
  ShaderMaterial properties. Individual pine instances and dock planks are selectable.
- `pine.tscn` is the reusable tree. Pine and mountain OBJ files and WAV cues are original
  lightweight assets created for this feature. Existing character, rod, rock and reed assets
  are reused without editing their source assets.

Sequence: establish 0–0.8 s; walk 0.8–5.0 s; cast starts 5.3 s; release at 5.72 s;
splash at 6.57 s; waiting at 6.85 s; camera settles at 7.8 s and the waiting loop continues.
Changing method-cue times may require matching the flight timing in `loading_cinematic.gd`.

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
