# Collection book: model and animation stage

This stage supplies the approved cream/black/red book as an editable Blender prop and an imported animated Godot model. It is now integrated into the playable Collection modal; see `collection-book-ui.md`. The final design keeps this real 3D book visible as the background, with native fish/details controls over its pages and editable name-only Godot ribbons. It does not switch to a replacement 2D open-book background.

## Source and delivery

- Editable source: `../output/collection-book-model/collection_book_v1.blend`.
- Runtime asset: `assets/props/collection_book/collection_book.glb`.
- Atlas source and packed PNG: `../output/collection-book-model/book_atlas.svg` and `book_atlas.png` (1024x1024).
- Source construction: `../output/collection-book-model/build_book.py` runs through the live Blender bridge in a new scene. It does not clear existing work. Keep `use_active_scene=True` and selection filtering on export so selected objects in unrelated scenes are not included.
- Review animation: `../output/collection-book-model/book-motion.mp4`. Preview stills show closed, opening, open spread and the two halves of a page turn.

The cover emblem, cream paper, ink edges, page-stack stripes and notched red bookmark share one atlas. The pages intentionally have no baked collection labels, statistics or fish cards. Those must remain live UI in the finished collection screen.

## Rig and clips

The entire book is 614 evaluated triangles, 840 source vertices, one skinned mesh, one material surface and 12 bones. All vertices are weighted; maximum influences per vertex is two. Packed texture and both actions are included in the Blender file.

- `OpenBook`: 0.6 seconds, closed to open spread. Front cover and left page stack rotate at the spine, the spine compresses into the open pose, and the book recenters. Reverse this clip for closing.
- `TurnPage`: 0.8 seconds, right to left. A physical double-sided sheet is subdivided across its width and bends through six curl joints. Reverse this clip for the previous page.

Clips are non-looping, start at time zero on export and finish at stable poses. Repeated forward turns may reset the thin leaf from the left resting surface to the right resting surface before the next cycle; in the final UI, swap old/new page artwork at the resting pose so this remains visually continuous. The source actions are separate and editable in Blender's Action Editor. The saved source opens on the full-spread frame of OpenBook.

## Godot review scene

Open `features/collection/collection_book_preview.tscn` and run that scene. It contains the imported model, a dedicated SubViewport, camera, lighting, and four authored touch buttons: Open, Next, Previous, Close. The script coordinates playback; it does not build the scene hierarchy at runtime. Buttons reject navigation while moving. The viewport renders continuously only during motion, then requests a final frame and stops continuous updates.

This is a standalone model review scene, not the final Collection UI or a change to game navigation. For the next stage, introduce a reusable book stage around this imported asset and coordinate its clips with live left/right Control pages. Retain the current Collection modal signals, pause ownership and existing species/map progress data.

## Verification

`tests/collection_book_model_test.gd` checks imported mesh cost, skeleton and clip names, durations and loop settings; real touch playback; cover rotation, page curl, next/previous endpoint poses and closing; render gating; and review control bounds at 1280x720, 1600x720 and 1024x768. Logs and engine stills are in `exports/book-model-qa/`. Blender weight/mesh audit is `../output/collection-book-model/asset-audit.json`. Preview rendering runs in a background Blender child so the visible editor stays available. No physical phone performance claim is made.
