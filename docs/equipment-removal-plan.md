# Equipment removal plan and implementation

User request1 November2026: pause the pending release, clear reel/line/bait when selecting a different rod, allow removing equipment from the assembled overview, then test/fix and update Alpha with new screenshots.

1. Profile transaction: different owned rod no longer requires an owned compatible reel; reset three attached slots atomically. Individual unequip supports rod/reel/line/bait/box; a box containing fish stays attached. Removing a rod cascades to its attachments. Keep inventory and used spool lengths.
2. Persistence: explicit empty IDs with zero active line; stored_lines contains detached partial spools. Legacy profiles migrate with empty reserve collection. Preserve validation of unknown equipment and impossible spool lengths. Save failure rolls back complete transaction.
3. UI: authored remove actions in inline_equipment_details.tscn plus per-slot remove row in shop_showroom.tscn. Show empty slots/instructions, disable irrelevant actions and prevent casting while incomplete. Update world/first-person/overview models without phantom rods/reels/line/leader.
4. Verification: targeted profile/UI/gameplay regression, legacy saves, pending recovery and failed-save rollback; equipment flow, assembled loadout, economy and tutorial suites; visual captures1280x720,1024x768,2400x1080. During visual review a hidden leader was found being re-shown by refresh(); fixed and added an assertion.
5. Release: rebuild after verification as0.1.26/code27 with original signing key, exact AAB starter/map/removal tests, refresh five actual store screenshots and submit Alpha+listing only. Leave six Early Access changes pending.
Verification complete:677 source assertions and163 exact signed-AAB assertions passed; final responsive screenshots rendered from the AAB. No physical Android test this task. Release submission is the remaining step.

Completed:0.1.26/code27 rebuilt with original identity, exact artifact verified and tested; five refreshed phone screenshots saved and both Alpha/listing submitted. Console proof exports/play-store/0.1.26-submitted.png. Managed publishing remains on and Early Access remains unsubmitted.
