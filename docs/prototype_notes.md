# Fishing prototype

Open project.godot in Godot 4.7.2 and press F5. The entry scene is features/loading/loading.tscn.

## Screens and editing

- Loading: features/loading/loading.tscn. Edit Title and LoadPanel in the Local scene tree. loading.gd loads the menu resource on a worker thread and animates the progress display with a minimum viewing duration. This loads packaged resources; it does not download remote content.
- Main menu: features/menu/main_menu.tscn. Change Background.texture, Brand, and PlayCard directly in the Inspector. PlayButton enters the playable fishing pond. LAKEBOUND is a provisional display title.
- Gameplay: features/gameplay/gameplay.tscn. World contains editable dock, lake, bank, trees, and mountains. Player instances actors/player/player.tscn. CameraRig/Camera3D controls the third-person framing.
- Joystick: shared/ui/virtual_joystick.tscn. Base and Knob are actual editable Panel nodes. virtual_joystick.gd handles touch ID tracking, drag capture, mouse preview, deadzone, release outside the control, and focus loss. Synthetic mouse events from touch are ignored.
- Theme: shared/ui/game_theme.tres. Shared panels, buttons, colors, progress bar, and bundled Noto Sans Thai font. Font license is shared/ui/fonts/OFL.txt.
- Water: world/water.gdshader. Shader parameters are editable on World's Lake mesh material.

## Controls and layout

Drag the bottom-left joystick to move. Drag/release the right joystick to aim and cast. Select bait and depth before casting. Strike when the bobber goes under. During a fight, push the right joystick up to reel in, down to pay out line, and left/right to steer the rod; diagonal input combines these actions. Desktop: WASD/arrows move, Space casts/strikes, I/K reels in/releases, J/L steers, R retrieves/cancels. The in-game pond/guide button explains bait and depth preferences. See `fishing_gameplay.md` for architecture, tuning, and validation.

The base UI size is 1280 x 720, canvas_items stretch with expand aspect. HUD/menu regions use anchors plus offsets, with Containers inside cards. Backgrounds use aspect-cover cropping. SafeArea adjusts edge margins for mobile display insets. Gameplay camera follows the character. This prototype uses a bounded dock and bank walk area in player.gd.

## Validation

Godot 4.7.2 imported the assets and parsed scenes. GPU-rendered captures were visually inspected. Automated runtime checks covered loading-to-menu, play/back transitions, touch movement, active-finger preservation under a second touch, release outside joystick, stop after release, keyboard movement, and anchored layout containment at 1280x720, 1600x720, and 1024x768. Actual Android/iOS devices and export packages have not been tested.

## Generated artwork provenance

Generated with the built-in imagegen tool, 2026-10-19. All final image assets are copied into this project, independent of the original generated-image folder. Progress bars and buttons are native Godot controls rather than flattened into artwork.

### features/loading/art/loading_lake.png

Use case: stylized-concept. Asset type: loading screen background for a landscape 3D mobile fishing game. Generate a wide 16:9 image, beautiful stylized low-poly 3D game art, simple faceted geometry, soft sunny morning light, turquoise freshwater lake, forested hills and soft blue mountains, wooden fishing dock foreground leading toward the center-right, one friendly young cartoon angler seen from behind wearing a brown fishing hat, khaki vest and backpack holding a fishing rod. Cozy adventurous natural atmosphere, lush simplified trees, reeds, subtle water ripples. Composition leaves upper left darker forest space for editable game title and bottom 20 percent calm uncluttered water for a real loading bar overlay. Premium casual mobile game visual quality with economical geometry, not photorealistic, not first person. No text, no logos, no UI, no bars, no watermark. The UI will be native editable Godot controls.

### features/menu/art/menu_lake.png

Use case: stylized-concept. Asset type: main menu background plate for a 16:9 landscape mobile 3D fishing game. Beautiful polished stylized low-poly 3D art, soft faceted shapes, turquoise freshwater lake, verdant simplified trees, distant blue mountains and warm afternoon sunshine. Foreground wooden fishing dock, one friendly young cartoon angler with brown hat khaki vest backpack and fishing rod standing full body slightly left of center looking at lake, 3/4 rear view. Small fishing tackle box and simple stool on dock. Camera third person at human upper body height, wide natural lake vista. Leave left upper quarter calmer dark green foliage to place a real game title; keep right third uncluttered lake and sky for a real editable play button and location card overlay. Bottom corners have darker dock/water for legible native UI. Match casual mobile fishing game, cheerful mint teal navy and warm sand palette, simple geometry optimized game art appearance, not photorealistic, no cinematic realism, no text no logo no UI no watermark.
