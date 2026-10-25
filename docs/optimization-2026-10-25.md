# Optimization continuation — 25 October 2026

Local work after `76e53e4`; no push or PR update.

## Completed code changes

- MissionHUD caches tracker text/progress until `AnglerProfile.changed`. The
  notification timer still advances each ready frame and pauses during modals.
  Rebinding disconnects the previous profile; FishingHUD disconnects on exit.
- TackleCatalog and MissionCatalog lazily index authored IDs. Lookups retain the
  same resource instances, ordered catalog arrays and unknown-ID null result.
- FishingEffects reuses its candidate array and removes out-of-range/deep fish
  before sorting. The visual budget, active-fish priority, ID tie breaker,
  animation, depth cutoff and distance cutoff remain unchanged.
- Profile rollback snapshots copy mutable domains deeply, but only copy the
  outer containers of append-only catch/journal/boss history and receipts, and
  replace-only pond snapshots. Existing records are never mutated in place by
  transactions. Empty histories retain the original deep-copy path. Any future
  operation that edits historical records in place must clone that record first
  or restore deep copying for that domain.

Save schema, file paths, synchronous atomic commit/rollback and durable journal
ordering remain unchanged. Writes are still synchronous: this change does not
claim to eliminate serialization or disk latency, or introduce background IO.

## Measurements and interpretation

Godot 4.7.2 on Windows, the same HUD scenarios as phase 2; 100 warmup updates,
5 samples × 2,000 updates. Current-run before/after HUD CPU medians:

| Stored fish | Before µs/update | After µs/update (safety run) |
|---:|---:|---:|
| 0 | 29.512 | 23.1725 |
| 200 | 29.008 | 22.09 |

These are host microbenchmarks, not Android FPS or a statistically controlled
GPU comparison. Assertions enforce **zero** mission tracker rebuilds and box
weight scans during 10,000 unchanged updates, and exactly one on invalidation.

The transaction probe measures optimized and deep-copy snapshots of identical
profiles in the same process, five samples each. At 2,000 journal entries the
safety run measured 142 µs versus 8,243 µs for deep copying. The 389,380-byte save
still took about 40 ms to serialize/write; preserving synchronous durable commit
is deliberate. Timing varies with host load; operation counts and rollback
correctness are the regression gates, not fixed time limits.

Fish selection comparisons use the legacy full-sort implementation as an oracle.
For 112 fish, the three test layouts sort 112, 38 and 1 candidates respectively,
with exactly the same visible records and ordering, including an active fish
outside the normal distance cutoff. All-visible populations still sort 112.

Rendered Ready/Fight probes remain 526/549 draw calls. This slice reduces CPU
work; it does not claim draw-call or GPU gains. The river already contains
serialized MultiMesh batches. Additional terrain/prop/shadow/LOD changes require
Android device profiling and visual budgets rather than blindly merging meshes
or lowering texture quality. No Android device measurements were available in
this run, and no new signed bundle was built.

## Verification

Evidence directory: `exports/qa-optimize-final/` (ignored QA output).
- `before`: original HUD timing.
- `core`: HUD/session, missions, economy, fishing simulation and fish behavior.
- `render`: optimization probe, water depth/pool rendering, mission UI,
  multitouch and frame counters; all pass. Water depth screenshot inspected.
- `safety`: optimization, economy, missions, catch settlement, legacy region
  saves and HUD operation-count checks; all pass.
- `measurements`: repeated timing and cache checks; all pass.
- `final`: latest optimization assertions (including catch/Keep rollback) and
  HUD cache plus persistent-signal cleanup checks; both pass.
- `headless`: 28/29 pass; only the pre-existing camera-clearance assertion in
  mobile_fishing_tuning fails, as in phase 1/2. No new failure was found.

The existing `mobile_fishing_tuning` camera-clearance assertion is tracked in
phase 1/2; this slice does not change camera geometry or weaken its assertion.
The slow full-river walking suite and Android device/release gates are separate
from the completed CPU optimizations above.
