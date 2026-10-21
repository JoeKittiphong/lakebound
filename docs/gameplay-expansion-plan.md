# Gameplay expansion — 2026-10-21

Approved source: ChatGPT “ออกแบบเนื้อหาเกมตกปลา”, read from its beginning.

## Rules
- Free play, no energy/character levels/skill upgrades or forced missions.
- Coins come from selling catches; buy consumable natural bait, reusable lures,
  rods, reels, line and fish boxes. Equipment has tradeoffs, not upgrade levels.
- Lures are lost on line break, not ordinary unhooking. Recovery is optional:
  earned rewarded ad, diamonds, or discard. No daily ad cap. No automatic ads.
- Line has strength and remaining length; breaking removes deployed line.
  Recovering a lure does not restore line or the fish.
- Lure input: tap, double tap, hold, release after hold; no cooldown/energy.
- Journal records actual map, depth, bait and equipment. Undiscovered names hidden.
- Pond boss is the heaviest actual simulated fish; reveal exact weight, not position.
- Online records must be verified by a server; local records must not be labelled online.

## Implementation sequence / acceptance
1. Snapshot current source/assets to existing GitHub remote, excluding secrets/builds.
2. Add resource-driven catalog, persistent transactional wallet/inventory, equipment,
   fish storage/sales, recovery state; prove save failures and duplicate events are safe.
3. Integrate consumables, line limits/strength/loss, selected equipment into fishing.
4. Add single-button lure actions with real bait movement/depth, keep fish simulation.
5. Add editable equipment/shop/recovery UI, catch journal and actual-population boss.
6. Test complete flows, existing regressions, 16:9 and wider layouts; commit and push.

## External service boundary
User confirmed no AdMob, Play products or backend exist yet. Implement fail-closed
provider interfaces and visible unavailable status. Do not simulate paid purchases,
ad rewards, or online leaderboard entries in the production game. Production launch
requires SDK/provider integration, server receipt/reward verification, credentials,
privacy/consent setup and real Android test transactions. These cannot be certified
by desktop fixtures. Keep these explicitly outstanding rather than claim launch-ready.

## Deferred content
New maps, other animals and their animations are deferred as agreed. Existing fish
catalog and first map stay in use. Prices/tuning are provisional, editable resources.

## Completed local milestone
- [x] Current 0.1.7 source/assets snapshot pushed to the existing remote (`b057f57`).
- [x] Resource-driven catalog: two consumables, three lures, rods/reels/lines/boxes;
  transactional wallet/inventory, weight-limited storage and sales, emergency supplies.
- [x] Natural bait consumption, reusable lures, line capacity/strength/visibility,
  shortened line on actual break, persistent recovery with replay protection.
- [x] Tap/double/hold/release move the actual simulated bait; editable 3D lure visuals
  replace the bobber and the line endpoint follows underwater depth.
- [x] Editable shop/recovery UI, actual catch context/PB data, independent saved
  population, boss name masking/exact weight, boss capture history.
- [x] Desktop validation: 24/24 import/regression entries passed, followed by final
  targeted economy (40), integrated flow (16), and visual (17) checks passing.

See [gameplay-expansion-verification.md](gameplay-expansion-verification.md) for
evidence, controls and remaining service/device limitations. Production commerce
and online Top 10 remain outstanding under the external service boundary above.
