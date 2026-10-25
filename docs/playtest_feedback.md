# Playtest fixes — 2026-10-23

- Player Visual scale is 1.18; camera position is (0, 3.8, 7.2). Edit player.tscn and camera_rig.tscn for framing.
- Hold the eye icon left of the reel and drag horizontally to orbit and zoom in. Holding still does not rotate. Release, focus loss, or a modal restores the original view. Character and casting heading stay fixed during inspection.
- A cast requires a gesture that began in READY. Automatic retrieval retains ownership of the old pointer and blocks its movement until release; only a new press can begin aiming. Trailing emulated mouse events from that touch are suppressed. The same applies after cancellation and results.
- Aiming allocates line to horizontal range, then clamps actual depth to remaining capacity. Selecting a depth greater than remaining line no longer collapses the preview onto the player. Less than one metre of line reports the equipment problem when casting.
- Regression: tests/playtest_feedback_test.gd exercises repeated retrieval, new gestures, mouse/touch release, orbit/restore, and depleted/replaced line. Render it without --headless to capture 1280x720, 1600x720, and front-view screenshots in exports/tutorial-qa.
