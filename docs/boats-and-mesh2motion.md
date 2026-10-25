# Mesh2Motion Male and fishing boat

The active player now uses `actors/player/models/mesh2motion_male.glb`, downloaded from the Mesh2Motion Explore library: Human / Male, credited there to Quaternius, CC0. This is the original mannequin-style character and its palette, not the earlier custom textured body. It has 13,757 triangles and the supplied finger rig. The previous custom GLB remains on disk for reference.

The selected twelve clips are Driving, Sitting_Idle, Fishing_Cast, Fishing_Catch, Fishing_Reel, Greeting, Idle_A, Jump_2, Sprint, Swim_Fwd, Swim_Idle, and Walk. Sitting_Idle plays at rest while aboard; Driving plays when the boat moves. Cast, reel and loaded catch/pull behavior retain their existing fishing-controller integration. The scene normalizes the model to approximately the previously selected 2.38-unit character height.

## Playing

Open `features/gameplay/gameplay.tscn`. A blue wooden-deck fishing boat is moored near the starting bank. Walk toward it until the **ขับเรือ** button appears at the upper right. Press it to board.

- Left joystick / WASD: forward, reverse, turn left/right. Camera and orbit controls remain available.
- **ตกปลา**: stop the boat immediately and stand at the bow with the equipped rod. Aim and release the right stick to cast normally; hook, reel and fight work as before.
- **ขับเรือ** while standing: cancel any active fishing session, put the rod away, and return to seated driving.
- **ลงเรือ**: available near a collision-free shore or shallow landing point. It restores player collisions and walking. In open water, approach the bank first.

The empty boat stays moored. Boat movement is blocked by terrain and map bounds; clearance colliders prevent seated/standing occupants passing through obstacles. A low roof/bridge blocks the transition to standing until there is enough headroom. Active catch-result and modal UI prevent boarding/mode changes.

## Editor authoring

`actors/boat/fishing_boat.tscn` contains the hull, deck, bench, motor, helm, collisions and two Marker3D anchors. All are saved and editable before Play. DriverAnchor sets the root for sitting; FishingAnchor sets the standing position. The boat is a reusable CharacterBody3D, with its Pond reference assigned by `gameplay.tscn`.

Inspector exports on FishingBoat control speed, acceleration, steering, boarding radius, minimum water depth and shore-exit search radius. Existing RiverDefinition geometry determines navigable water. Shore exits query the actual player capsule against the physics world before restoring walking.

The rod remains a separate equipment scene attached to hand_r. The boat and replacement character reuse the existing equipment selection and rod-tip line proxy. Surface contact effects create a wake behind the occupied boat while it moves.

`tests/boat_integration_test.gd` exercises walking into boarding range, proximity prompts, seated deformation, driving/steering, standing to fish, casting/hooking/reeling/fighting, returning to driving, shoreline restrictions, low overhead clearance, safe disembarkation and unoccupied mooring. Desktop rendered tests include 1280×720, 1024×768 and 1600×720 HUD layouts. Physical Android touch/performance has not been measured.
