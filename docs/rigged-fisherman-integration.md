# Rigged fisherman in Godot

The playable character now uses `actors/player/models/fisherman_rigged.glb`, the user's Blender character retargeted in Mesh2Motion. The previous Mesh2Motion mannequin remains on disk as a fallback source.

The imported mesh has 4,873 triangles, one skin, and one embedded 512px albedo texture. Its twelve animations cover idle, walk, sprint, jump, greeting, swimming forward/idle, fishing cast/catch/reel, driving and sitting idle.

`tools/prepare_rigged_fisherman.py` rebuilds the game asset from `retopology/ultralow/mesh2motion/current_rig_tpose_12_animations_20261025.glb`. It removes the `_RT` animation suffix and maps Mixamo joint names to the game's existing joint names. It preserves skin indices, transforms, weights, geometry and animation samples.

Open `actors/player/angler_model.tscn` to adjust the imported Asset, RodHand/Grip and the fishing locomotion blend tree. The model scale normalizes height to the existing 2.142-unit player collision. Asset's vertical offset aligns the sole with the root. Grip has 100x scale because this rig's skeleton units are centimeters; its saved rotation aligns the rod with the fishing hand. This keeps selectable rods and the line's animated tip working.

The user's posed Blender rig was preserved in `current_rig_20261025.blend`. A temporary export copy turned the existing T-pose into its bind pose before retargeting, preventing the previous arm twist.

Validation: installed Godot 4.7.2, actual rendered gameplay and 12 pose previews, character integration, traversal/equipment, boat integration and distance-matched walking tests. Swimming keeps the chest at the water and can exit the bank. Boarding seats the character; fishing stands on deck. QA logs/screenshots are in workspace `exports/qa-traversal/rigged-*` and `exports/qa-traversal/screenshots/`. Device performance has not been measured on Android hardware.
