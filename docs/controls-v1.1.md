# Controls V1.1

Implemented from the “ปรับปรุงเกมตกปลา” discussion:

- Drag empty screen space on the right to turn the camera and character together.
- Vertical dragging changes camera pitch only. Camera dragging alone does not move the angler. The left joystick still walks, including during fights.
- Camera dragging remains available while waiting and fighting; the bobber and fish stay in world space.
- Keep the existing aiming joystick and release-to-cast gesture. Aim rotates with character yaw.
- Casts onto land are rejected with feedback instead of clamping the target to the front of the pond.
- As soon as bait lands, the right control becomes a reel: pull down to wind in and push up to pay out line. Payout adds slack without pushing the bait away; winding takes up slack, then pulls the bait toward the angler. I reels and K pays out on keyboard.
- Unhooked bait packs away automatically within the configured retrieval reach at the water edge, restoring aim for the next cast. There is no on-screen retrieve button. Hooked fish continue through the fight and catch result.
- On a bite, wind the reel to strike; there are no cast or strike buttons. During fights, left/right steers the rod as before (J/L on keyboard).
- A rectangular tension meter sits above the reel. Fish up to 2kg retain the original 132px bar; larger fish progressively extend it up to 232px at 25kg. `tension_meter.gd` exposes these limits in the Inspector.
- Each species Resource has `tension_pressure`; heavier individuals within a species add more surge pressure. Stronger fish have a wider red warning zone and generate extra actual tension while fresh. The visible red threshold also governs line overload and vibration; brief excursions retain the configured break grace. Fresh/surging fish have more red than green. Fatigue gradually shrinks red, while maintaining yellow tires fish and enables retrieval. Green tension lets fish escape farther.
- Waiting, bite and fight states show the animated spool and crank. Down/up reverses rotation; drag magnitude sets speed. Sideways input tilts the reel. Neutral stops the crank; brake slip during a fight may pay out the spool. The left walking joystick and ready-state aiming joystick retain their normal appearance.

Editor entry points:

- `features/gameplay/gameplay.tscn`: Gameplay look sensitivity and pitch limits; CameraRig framing.
- `features/fishing/fishing_hud.tscn`: TensionMeter rectangle, labels, joystick placement. The left movement joystick remains visible and usable; catch results disable both joysticks.
- `shared/ui/tension_meter.gd`: specialized segmented meter drawing.
- `shared/ui/virtual_joystick.tscn`: authored Reel child, drawn and animated by `reel_visual.gd`; the input control itself is unchanged.

The proposed keepnet, shop, equipment progression, extra species and maps remain future work.

Red-zone feedback: supported mobile devices pulse for 80ms when tension enters the fish-specific red zone and repeat every 0.45s while danger persists. Pulses stop below red or when the fight ends; `haptics_enabled` disables them. Duration and interval live in `FishingTuning`. Desktop tests verify pulse requests and timing; physical vibration requires a supported device.

Layout B aligns the bar to the actual projected reel line guide with a 24px gap. The percent label follows the bar. Weight scales the bar continuously from 132px (up to 2kg) to 232px (25kg and above); there are no discrete size tiers.

Fight control revision: staying in yellow always shortens fish distance, including a gentle retrieve at neutral input. Yellow retrieval is now twice its previous speed, and the yellow window is wider. Harder species have narrower yellow windows, with a deterministic random variation per individual. Unpredictable short surges (roughly 0.65–1.05 seconds, spaced several seconds apart) expand red to 60–66%; yellow retains a minimum 18% of the bar for mobile control. Players must pay out line promptly. The band returns to normal after the surge. Green still allows escape and yellow causes faster fatigue.
