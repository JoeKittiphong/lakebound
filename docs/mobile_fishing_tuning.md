# Mobile playtest tuning

Implemented the three requested adjustments:

1. Camera rig pitch is limited to -10° … +15° (previous maximum +40°).
   Its follow update also clamps existing/out-of-range pitch. At the positive
   limit the camera remains about 2.1 m above the rig origin. Terrain checks cover
   both river banks at five sections, three bank distances and twelve yaw angles.
2. Species yellow windows use twice the previous base width. Individual fight
   zones retain at least 18% of the bar, including surges. Surge red boundaries
   are now 0.34–0.40 so red does not consume the usable yellow window. The HUD and
   simulation share these same boundaries; this is not a cosmetic recolor.
3. `FishingTuning.yellow_retrieve_multiplier` is 3.6, previously 1.8. Only yellow
   retrieval uses it. Matched numeric tests compare distance gain at neutral and
   positive reel input and confirm a 2× increase; green/red movement is unchanged.

Checks: `mobile_fishing_tuning_test.gd`, fish behavior, fishing simulation,
rod/tension visuals, camera movement and mobile multitouch. The rendered review
captures the maximum camera pitch and the fight HUD at 1280×720, 1600×720 and
1024×768. Logs and screenshots are under workspace `exports/qa-character/`.

These checks run on desktop Godot; another physical-phone playtest is still
needed to evaluate comfort on the user's actual devices.
