# Gameplay expansion verification — 2026-10-21

Engine: installed Godot 4.7.2, Mobile renderer, Windows D3D12 / GTX 1660 Ti.

## Results

- Full `tools/run_tests.py --suite all --output exports/qa-gameplay-expansion`:
  **24/24 entries passed**, including import, 12 headless and 11 render suites.
- Final changes retested directly with isolated QA user data:
  `economy_test.gd`: **40 checks**, `expansion_flow_test.gd`: **16 checks**,
  `expansion_visual_test.gd`: **17 checks**, all passed, no game/script errors.
- Rendered shop, recovery and map panels at **1280×720** and **1600×720**;
  exercised buy/discard buttons, pause restoration, hidden unknown boss names.
- Verified the lure renders its separate authored 3D model at the simulated depth
  and the surface bobber is hidden. Actual tap moves bait without generating fish.
- Existing startup, tutorial, camera, multitouch, collection, all 16 fish species,
  landing/results, fish rendering and water regressions passed.
- Save/reload, reduced line, stale/duplicate reward IDs, insufficient diamonds,
  duplicate purchases/sales, save failure rollback, invalid/future save protection,
  consumable use, replacement line and free continuation supplies were exercised.
- Git whitespace check passed. Signing directories, keys, credentials, builds,
  engine caches and user saves are excluded from source uploads.

The full run's `results.json` and per-suite logs are in the ignored QA directory.
Additional final logs: `exports/qa-expansion-verified/economy-final.log`,
`flow-final.log`, and `exports/qa-expansion-visual/lure-verified.log`.
Screenshots: `exports/qa-expansion-visual/screenshots/`.

## Diagnostics and limits

The sandbox reports Windows root certificate-store access errors and denies scanning
the excluded local signing directory during import. The runner reports these separately
as host diagnostics; it does not suppress script errors.

The startup/navigation fixture also reports 8–9 zero-reference `RefCounted` objects
at process exit under the threaded loader (confirmed with `--verbose`). Functional
navigation assertions pass, but this cleanup warning remains unresolved; do not claim
that the complete run has no warnings.

Desktop fixtures do **not** certify phone performance, real touchscreen/safe areas,
background/process termination behavior, AdMob earned callbacks, Play Billing,
server verification or live Top 10. No real payment/ad/online service is configured.
See [commerce-integration.md](commerce-integration.md) for the remaining launch gates.

## Editor and play entry points

- Run project: Loading → Menu → Play → **กระเป๋า**.
- `features/economy/tackle_panel.tscn`: authored responsive panel, safe area, tabs,
  wallet, storage, journal, map/boss, recovery and emergency supply controls.
- `features/economy/tackle_row.tscn`: authored reusable shop/inventory item row.
- `data/equipment/*.tres`: prices, quantities, line/reel/rod/box and lure tuning.
- `features/fishing/lure_visual.tscn`: editable minnow/frog/soft-plastic geometry.
- `features/gameplay/gameplay.tscn`: composed session with economy enabled;
  existing legacy regression scene retains its original simulation configuration.

No main release version, Android signing identity or Play release was changed.
