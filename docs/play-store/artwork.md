# Lakebound release artwork

Created 19 October 2026 using the built-in image_gen tool. Mechanical size conversion uses `tools/prepare_branding.py` (Pillow); no gameplay screenshot is AI-generated.

## Files
- `shared/branding/icon-source.png`: original generated artwork.
- `shared/branding/icon.png`: 512 x 512 app icon; same artwork as `exports/play-store/icon-512.png`.
- `shared/branding/adaptive_foreground.png` and `adaptive_background.png`: 432 x 432 Android launcher layers.
- `docs/play-store/feature-source.png`: original generated marketing illustration.
- `exports/play-store/feature-1024x500.png`: 1024 x 500 RGB feature graphic, clearly labeled world preview.
- `exports/play-store/01-menu.png`, `02-lakeside.png`, `03-dock.png`: actual desktop GPU renders of the current game at 1280 x 720. Not physical-phone captures.

## Icon prompt
Use case: logo-brand. Create a polished square mobile app icon for a cozy low-poly 3D freshwater fishing game. One bold stylized turquoise and golden freshwater fish leaping in a curved splash above deep teal lake water, soft faceted geometry, warm sunlight, small simple distant green mountain silhouette. Strong single recognizable silhouette and limited details readable at tiny sizes. Center all important subject matter inside central 60% safe area. Full-bleed opaque deep teal background to all four square corners; no rounded corners, no outside shadow, no frame. No text, letters, watermark, UI or badges. Premium friendly game illustration. 1024x1024 square.

## Feature graphic prompt
Use case: ads-marketing. Asset: Google Play feature graphic for Lakebound, a cozy low-poly lake exploration and future fishing game. Wide landscape 2.048:1 composition, target 1024x500. Soft faceted 3D game art, turquoise freshwater lake, green pine trees, layered blue mountains and golden morning sun. Small wooden dock extending from foreground into lake, peaceful empty environment, no fish catching or promised gameplay. Centered elegant bold cream title spelled exactly "LAKEBOUND", smaller clear subtitle "LAKESIDE WORLD PREVIEW" below. All lettering and main dock within center 70% to survive crops. Deep teal, mint, warm sand palette. No badges, no store logo, no UI, no watermark, no promotional claims. Opaque image.

## Specifications checked
- https://support.google.com/googleplay/android-developer/answer/9866151?hl=en
- https://developer.android.com/distribute/google-play/resources/icon-design-specifications
- https://developer.android.com/google/play/requirements/target-sdk
