# Fishing recovery, line strength and HUD — 25 October 2026

## Changes

- Removed the controller's unconditional red-tension override at the spool
  boundary, including the old profile-less automatic break there. End-of-spool
  pressure is calculated before the player's control input instead.
- Bounded environmental tension pressure to the usable input range and raised
  manual payout authority. Strong surges can be brought through yellow again.
- Aligned the displayed reel with the touch control's center and added an
  outlined Thai direction guide during fights.
- Line failure now depends on estimated instantaneous kgf exceeding the
  equipped line resource's `strength` for `break_grace`, rather than spending
  time in the moving red UI band. Load includes fish weight, species force,
  surges, winding, stretch, lateral countering, manual payout and the reel brake.
  This is a gameplay force model, not a calibrated physical simulator.
- HUD shows current load / rated kgf. A line overload has a specific warning.
- Persistent cast-block text distinguishes bait depletion, depleted line,
  pending lure recovery, incompatible save, unsupported footing/boat movement,
  and aiming outside the water. Failed casts retain their feedback toast too.
- Added a serialized fish-box widget with vector cooler/fish artwork, retained
  fish count, weight/capacity, fill bar and remaining kg. At 80% capacity it warns
  near-full; at capacity it shows full in red. It uses retained catches, not the
  lifetime journal, so releasing fish does not fill it and selling empties it.

Edit `features/fishing/fishing_hud.tscn` for HUD placement and
`features/fishing/ui/fish_box.tscn` for the box hierarchy/styles. Both expose
their authored nodes in the editor. Line ratings remain resource data under
`data/equipment/`; no rating or player save was reset by this change.

## Verification

Godot 4.7.2, isolated QA user data under `exports/qa-fishing-recovery/`.

- `fishing_recovery`: 64 checks, zero failures. Maximum-size fish from all 16
  species recover through yellow during a forced surge; controller with a
  profile also recovers at the spool limit. Feedback-guided retrieval succeeds
  for all 16 species. Includes bait/line/pending-recovery messages, empty/85%/
  full/cleared box, and a 2 kg fish against 80 kgf versus 0.4 kgf lines. The
  80 kgf line survives sustained red beyond the old break timer; undersized
  line still breaks with the correct explanation.
- `fishing_recovery_visual`: zero failures, rendered at 1280x720 and 2340x1080.
  Actual injected touch press/drag/release produces full payout and recovers
  red through yellow at both sizes. Screenshots inspected for illustration,
  Thai text, capacity, load display and separation from the Back button.
- `mobile_multitouch`: 261 checks, zero failures.
- `fishing_simulation`: 60 checks, zero failures. Updated its forced-break
  fixture to use undersized line; red alone is intentionally no longer enough.
- `fish_catalog_fishing`: all 16 species pass.
- `economy`: 40 checks, zero failures.
- `expansion_flow` and `bait_retrieval`: 16 checks each, zero failures.
- `ui_atlas`: 91 checks, zero failures.
- `tension_haptics`, `rod_tension`, and `playtest_feedback` pass.
- `mobile_fishing_tuning`: fishing assertions pass; one unrelated camera
  clearance assertion (`camera.global_position.y - rig.global_position.y > 2`)
  fails with the current camera configuration. Camera source was not changed
  in this task. This is not a claim of a clean full suite.
- Host root-certificate diagnostic remains. No physical Android-device test or
  new signed Android bundle/Play Console update was performed in this task.

New recovery suites are registered in `tools/run_tests.py`. Visual proof is in
`exports/qa-fishing-recovery/screenshots/` (`bait-empty-*`,
`line-empty-box-full-*`, `fight-recovered-*`).
