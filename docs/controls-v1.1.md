# Controls V1.1

Implemented from the “ปรับปรุงเกมตกปลา” discussion:

- Drag empty screen space on the right to turn the camera and character together.
- Vertical dragging changes camera pitch only. Camera dragging alone does not move the angler. The left joystick still walks, including during fights.
- Camera dragging remains available while waiting and fighting; the bobber and fish stay in world space.
- Keep the existing aiming joystick and release-to-cast gesture. Aim rotates with character yaw.
- Casts onto land are rejected with feedback instead of clamping the target to the front of the pond.
- During fights, pull the joystick down to reel in and push up to release. J/L steer; I reels and K releases on keyboard.
- A straight vertical tension meter sits to the left of the rod joystick.
- During fights the right control shows a reel with an animated spool and crank arm, without a human hand. Down/up retains the original input mapping and reverses rotation; drag magnitude sets speed. Sideways input tilts the reel. Neutral input stops the crank; brake slip can continue paying out the spool. The left walking joystick and ready-state aiming joystick retain their normal appearance.

Editor entry points:

- `features/gameplay/gameplay.tscn`: Gameplay look sensitivity and pitch limits; CameraRig framing.
- `features/fishing/fishing_hud.tscn`: TensionMeter rectangle, labels, joystick placement. The left movement joystick remains visible and usable; catch results disable both joysticks.
- `shared/ui/tension_meter.gd`: specialized segmented meter drawing.
- `shared/ui/virtual_joystick.tscn`: authored Reel child, drawn and animated by `reel_visual.gd`; the input control itself is unchanged.

The proposed keepnet, shop, equipment progression, extra species and maps remain future work.
