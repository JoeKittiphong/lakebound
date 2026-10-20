# Playable fishing loop

Open `project.godot` in Godot 4.7.2 and press F5, or run `features/gameplay/gameplay.tscn` directly with F6. The existing loading and menu flow is preserved.

## Play

1. Walk to a fishing position using the left joystick (WASD/arrows on desktop).
2. Select bait and depth in the lower center panel. Tilapia prefer dough/worms at 0.5–2.4 m, snakehead prefer lures/worms at 0.6–3.4 m, catfish prefer worms/dough at 3–5.5 m.
3. Drag the right joystick to adjust aim/distance, then release to cast. Alternatively press the cast button or Space. The aim ring indicates the actual target; bait becomes active when its cast arc lands.
4. Watch the bobber. When a fish takes the bait, strike within five seconds using the button or Space. A short mobile vibration notifies only this bite; the battle does not vibrate continuously.
5. During the fight, right-stick up reels in, down pays out line, left/right steers. On desktop use I/K and J/L. Green tension is controllable, yellow suggests caution, red requires release. Holding full reel can break the line; sustained slack can lose the hook. The brake can slip under surges.
6. Walk while fighting to change the line geometry. A landing requires the fish within 2.4 m, sufficiently fatigued, and a controlled line. No HP is displayed.
7. Keep the catch to remove that individual, or release to return the same fish with fatigue, lower hunger, and temporary caution. R or the retrieve button cancels/retrieves without removing a fish.

## Editable scenes and tuning

- `features/gameplay/gameplay.tscn`: existing environment, player/camera, PondEcosystem, FishingController, FishingEffects, HUD scene instance.
- `features/fishing/fishing_hud.tscn`: both joystick instances, anchored regions, tension instrument, bait/depth controls, context buttons, guide, result modal, and its independent 3D fish preview.
- `actors/player/player.tscn`: saved rod joint hierarchy and cast AnimationPlayer. Tension bends the existing joints; scripts do not build the character or HUD at startup.
- `world/pond/fish_visual.tscn`: a species-model host; the old sphere/prism fish hierarchy has been removed. Seven pooled instances display the actual imported Blender meshes near the surface and on landing. Hidden pooled models stop their animation mixers. Each species model and its three looping clips live under `world/pond/models/`.
- `world/pond/models/fish_catalog_preview.tscn`: an editor-visible gallery of all sixteen authored models. Run this scene to preview their normal swimming.
- `data/fish/fish_catalog.gd` and `data/fish/*.tres`: shared sixteen-species catalog, imported model references, visual length, preview tilt, weight ranges, depth preferences, bait types, detection radii, speed, force and struggle frequency. See `fish_models.md` for animation mapping and export notes.
- `PondEcosystem` Inspector: population (30), fixed simulation interval (0.15 s), seed, restock interval (45 s).
- `FishingController` Inspector: reel/release rates, spool capacity, overload/slack grace times, strike window, vibration setting. Runtime `drag_strength` controls the brake.
- `shared/ui/tension_meter.gd`: specialized editor-visible arc instrument; the rest of the HUD is native saved Control nodes. Theme is shared with the existing screens.
- `features/fishing/audio`: small original synthetic bite, reel, and splash cues. The effects node exposes an audio-enabled switch.

## Simulation boundaries

Each fish is a RefCounted record with its own ID, species, weight, position/depth, destination, hunger, fatigue, caution, and behavioral timers. Roaming, resting, feeding, hunting/fleeing, approaching/inspecting bait, and hooked/landed states run separately from rendering. Detection checks real 3D separation, compatible bait, depth tolerance, hunger and caution. No new fish is created by casting. Hidden fish coordinates/energy are not revealed in the normal HUD.

Fish force varies by species, individual mass, remaining energy, and surge/rest phase. The line reacts to fish movement, angler position, steering, reel input, and brake slip. The game uses an intentionally simplified elastic-line model rather than a rigid-body fishing-line solver. Population replacement occurs over time after removal, not immediately on capture. Fish population and catch counters currently last for the current pond session; save/load across restarting the game is not implemented.

## Tests run

`tests/fishing_simulation_test.gd`: 55 assertions, including actual spatial bait detection, wrong bait/depth rejection, natural approaches for all three species, feedback-controlled catches, fatigue/proximity landing constraints, release identity, keep/removal, delayed restocking, missed strikes, overload, slack loss, cancellation, additional seeds and 30/60/120 Hz stepping. Deterministic accelerated tests mute realtime audio.

`tests/fishing_visual_test.gd`: 36 rendered/input assertions at 1280×720, 1600×720, and 1024×768, independent two-finger movement/aim, walking while controlling the rod in battle, cast on genuine release, no accidental cast on focus loss, cast-button/strike integration, tension display, result input blocking (touch and keyboard), release, and 3D catch preview. Screenshots inspected on the desktop Mobile renderer. The real-time pass includes audio playback. Together with the simulation suite, 91 assertions pass.

```powershell
& $godotExe --headless --path $projectPath --script res://tests/fishing_simulation_test.gd
& $godotExe --path $projectPath --script res://tests/fishing_visual_test.gd
```

Tests are in a `.gdignore` folder. Android package export and signature checks are separate from physical-device validation. Actual touch feel, vibration, performance, thermal behavior, audio balance, and display cutouts still need checking on Android/iOS hardware. No store upload is performed by these tests.

The `Android APK Playtest` preset produces `exports/android/lakebound-fishing-playtest.apk` signed with the same upload key as the AAB. Android presets enable the normal VIBRATE permission for bite notifications; Internet/storage/microphone/location permissions remain disabled. APK packaging checks verify the expected fishing resources are included and signing credentials/tests are excluded.


## Water boundary correction
The distant bank, offshore trees and mountains have been removed from gameplay.tscn, leaving open water and the walkable player bank/dock. PondEcosystem exposes water_bounds and dock_clearance in the Inspector. Fighting and released fish are constrained inside the lake and outside the pier footprint. Landing uses the exposed water edge within 6.5 m rod reach (plus 0.8 m landing margin), so fish do not need to be dragged onto the deck. Walking farther inland requires returning toward the edge to land a fish.

## Modern mobile HUD
Gameplay uses authored icon buttons and minimal status pills in features/fishing/fishing_hud.tscn. Top left: collection book and help; top right: back. Bottom center: tap the bait icon to cycle worm/dough/lure; tap depth to open/close the optional selector and slider. Configuration updates the actual controller and the compact dock. Persistent instruction blocks and location statistics are hidden; help contains touch instructions. Notifications expire after 1.8 seconds. Casting switches to a hook icon during a bite. Line length and a colored tension indicator appear only in the relevant fishing states. The catch result retains short keep/release labels to make the decision clear.

Buttons use 64 px logical touch areas, with an 88x80 cast target. Existing 184 px independent walking/rod joysticks and the 3D battle reel are retained. Safe-area padding handles display cutouts; the bait dock does not overlap either joystick at tested sizes. Editor appearance: assets/ui/modern/hud_theme.tres and SVG icons/texture skins in the same directory (about 10 KB source total). The collection uses matching modern surfaces and keeps all sixteen discovery slots, silhouettes and permanent unlocks.

Validation: real Control touch-event paths for bait/depth/collection, three aspect ratios including 20:9 and 4:3, dual joystick plus camera multitouch, bait/depth propagation, bite icon switching, expiring toast, complete battle and result actions, and collection persistence/unlocking. Desktop GPU tests passed; physical Android validation is still required. Existing Play Store builds do not include these source changes.
