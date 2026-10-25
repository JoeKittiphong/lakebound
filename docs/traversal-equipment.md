# Mesh2Motion character, traversal, and replaceable rods

The active character now uses Mesh2Motion's stock Male model and supports a driveable fishing boat. See [boats-and-mesh2motion.md](boats-and-mesh2motion.md) for that update. The earlier custom body figures below are retained as historical integration notes; controls and replaceable-rod conventions still apply.

Open `actors/player/player.tscn` for the player, `actors/player/angler_model.tscn` for the model/hand grip, and `features/gameplay/gameplay.tscn` to play the river.

The imported `models/fisherman_mesh2motion.glb` contains the textured shorts character and ten clips: Fishing_Cast, Fishing_Catch, Fishing_Reel, Greeting, Idle_A, Jump_2, Sprint, Swim_Fwd, Swim_Idle, Walk. The model replaces the previous 994-triangle placeholder; the new body has 1,096 triangles and a 1024px atlas. Original source assets remain on disk.

## Controls

- WASD/arrows or left stick: move. Shift: sprint. The HUD Run button toggles sprint.
- Space or HUD Jump: jump on land, or push out of the water. Repeated midair presses do not grant another jump.
- H or HUD Wave: greet while grounded and free to move.
- Walking off the bank transitions from wading to swimming automatically. Stop to tread water; swim back onto the bank to leave the water. Bridges and jetties above water do not trigger swimming.
- Rod/reel controls retain their existing behavior. Casting requires ground contact; swimming cancels an active cast/fight and hides the rod.

The movement buttons own their own touch fingers, permitting simultaneous joystick movement and jumping. On desktop they also behave as ordinary buttons. Device validation is still needed for physical Android touch behavior.

## Equipment authoring

`TackleItem.model_scene` selects the rod visual. `light_rod.tres` and `heavy_rod.tres` demonstrate different interchangeable rod scenes. The production profile refresh path updates the equipped visual without duplicating it.

`AnglerModel/RodHand` is a BoneAttachment3D bound to `hand_r` on the imported external Skeleton3D. Adjust its `Grip` Marker3D in the Editor to change the hand alignment. Rods use origin at the grip and local +Y along the shaft. Include a Marker3D named `Tip` at the actual tip. For bending support, use the `FishingRodVisual` base scene/script and its five authored joints. The old Tip node path on Player is retained as the stable line-effect proxy, synchronized after skeleton updates.

The supplied light/heavy rods are simple editable placeholders. Replace each item's model_scene with the final rod scene; the character mesh and animations do not contain permanent rod geometry.

## Tuning and validation

Player Inspector exposes walk/run/swim speeds, jump velocity, gravity, float depth and buoyancy response. AnglerModel exposes walk/run cycle distances and blend time. FishingLocomotion is an authored AnimationTree with a filtered lower-body Walk layer, allowing the character to move while fishing.

The selected character size is 40% larger than the original integration: Visual scale 1.652 (previously 1.18). The capsule is 2.38 units tall with radius 0.42; swim float depth is 1.33. Walk/run cycle distances are 2.8/4.2 to match the longer stride. Camera framing and movement speeds stay at their existing settings.

`traversal_equipment_test.gd` exercises actual river collisions, jumping, landing, two-finger movement+jump, equipment selection, hand and tip tracking, cast/reel/fight transitions, buoyancy, swimming wakes, leaving the water, and input locks. `fisherman_visual_test.gd` renders all ten poses. QA logs and screenshots are written outside the project under `exports/qa-traversal` with isolated save directories. Tests are desktop engine checks, not an Android performance certification.
