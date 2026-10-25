# Mobile controls and bait shop

- Player Visual scale is 1.4868, 90% of the previous 1.652. Capsule and walk/run stride distances follow the same reduction.
- Walking and running face camera-relative joystick travel, including pulling the stick down. The camera aligns the body only while using the fishing rod.
- `player.tscn` exposes `swim_float_depth = 1.48`. The idle chest bone is within 12 cm of the water surface. Buoyancy rises with the river bed near shore to preserve climbing out.
- The authored MissionPanel Scroll uses `shared/ui/swipe_scroll.gd`: a swipe can start over card text, progress bars, or buttons. Dragging suppresses the button action; a tap still activates it. Scrolling has inertia and stops on tab changes or closing the panel.
- Shop rows show pack quantity and coin price. Existing transactional purchases persist bait and coin balance together; insufficient coins disable buying.

Verification uses the installed Godot 4.7.2, isolated QA saves, rendered desktop windows and injected mobile touch events. This is not a physical Android device test. See `tests/mobile_refinements_test.gd`, `traversal_equipment_test.gd`, `camera_movement_test.gd`, `boat_integration_test.gd` and `economy_test.gd`. Logs and rendered screenshots are under the workspace `exports/qa-traversal` directory.
