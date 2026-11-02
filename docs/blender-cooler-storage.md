# Blender ice cooler and stored 3D fish

Replaced the procedural green storage box with the red Thai ice cooler from the open Blender 3.6.23 scene:

`output/ice-cooler-model/thai_ice_cooler.blend` (workspace parent of this Godot project).

Exported only the original body/lid meshes and their materials, without the source camera/lights or animations. Temporary export copies were removed; the live scene still has its original seven objects, active object, selection and opening animation. The original .blend was not overwritten.

## Assets and cost

- `assets/props/thai_ice_cooler/cooler_body.glb`: 1,112 evaluated triangles, 85,468 bytes, four used materials.
- `assets/props/thai_ice_cooler/cooler_lid.glb`: 132 evaluated triangles, 12,900 bytes, two used materials.
- Cooler total: 1,244 evaluated triangles, 98,368 bytes of GLB files; source mesh and materials preserved.

The lid mesh is exported closed at a local zero origin. Its authored Godot parent pivot is `(0, 4.12, -1.96)` with uniform model scale 8. The opening animation reaches -105 degrees around X and plays backwards on closing. Original source opening actions remain in Blender.

## Editable Godot scenes

- `features/fishing/ui/storage_box_model.tscn`: imported Body and Lid, lid pivot, ice surface, eight authored `FishSlots` positions, open/close AnimationPlayer.
- `features/fishing/ui/stored_fish_display.tscn`: reusable 3D fish holder, selection marker, index label. `fit_size` in its script is exposed to the Inspector.
- `features/fishing/ui/fish_storage_panel.tscn`: preview camera, lights, viewport, controls, capacity, pagination and selected-fish details.

The header offers three authored cameras: A original diagonal, B high angle (default, matching the supplied reference), C overhead. `set_view()` switches the active camera; automatic framing centers the complete body/lid mesh bounds with a 3% margin and adapts to viewport aspect ratio. All UI lives outside the preview rectangle. Disable `auto_frame_cooler` for fully manual camera sizing, or adjust `framing_margin` in the Inspector. The right detail panel has text and Sell / Sell All / Release buttons, with no duplicate fish illustration. Weight is a numeric total/capacity only; the progress bar has been removed.

Sell All explicitly confirms the whole inventory across every page and uses the existing atomic `profile.sell_catches()` transaction. Cancelling or failed saving preserves fish and coins; successful sales clear the displayed meshes and survive reloading. A pending sale snapshots the catches to prevent accidentally confirming a changed inventory. `tests/cooler_choices_test.gd` verifies all three cameras at two aspect ratios, unobstructed viewport/picking, bulk sale/cancel/rollback/exact total/reload. Preview choices are captured in `exports/qa-cooler-choices/`.

## Cooler on the loading-screen jetty

`assets/props/thai_ice_cooler/thai_ice_cooler.tscn` is a reusable, real-scale closed cooler, separate from the enlarged inventory preview. `features/loading/cinematic/loading_cinematic.tscn` instances it at `Dock/IceCooler` and removes the old procedural TackleBox/TackleLid and their unused meshes.

The cooler sits inside the bridge footprint at dock-local `(-0.72, -0.0045393, 1.85)` with a -0.3808 degree Z tilt matching the real planks. The prior box was outside the deck width. `tests/loading_cooler_test.gd` ray-intersects the rendered bridge triangles at the center and four footprint points, rather than relying on the coarse collision box. All five base-to-plank offsets are below 0.001 mm in this saved placement (test tolerance 2 mm). The imported model's actual bottom agrees with its local origin. Contact and full-scene captures are under `exports/qa-loading-cooler/`; actual loading UI captures are in its `actual-loading/` subfolder.

## Stored catches

Each visible entry instantiates its actual `FishCatalog` species `model_scene`. The normal pond animation is frozen, the mesh is laid on its side, turned 180 degrees toward the player for an upright view, and fitted using transformed mesh AABBs. The holder exposes display_turn_degrees in the Inspector. Fish sit on the ice, remain below the rim and do not overlap adjacent compartments. Small labels and a selected marker identify the chosen fish. The right-side detail illustration remains available alongside the real models inside the cooler.

The box shows eight real models per page and supports all stored catches through the existing pager. This is a fitted inventory preview rather than a physically accurate kilogram-to-length simulation. Empty positions contain no fish models; selecting the same species reuses its existing model. The old 2D inventory viewport and texture plane were removed. Input ray-tests the actual 3D mesh bounds rather than a flat inventory image.

Selling/releasing still uses the original atomic inventory transactions. A successful transaction refreshes the displayed models. Source-map population restoration, stale selection protection and persistence were retained. The viewport stops rendering when the lid has finished closing. No gameplay save format, capacity, fish weight or catch history was changed by this feature.

`tools/author_storage_box.py` now validates/preserves the authored scenes instead of regenerating the old green box when the broader UI generation tool runs.

## Verification

- `tests/cooler_storage_test.gd`: imported Blender body/lid, opening angle, mesh fit above ice/below rim, close-up camera bounds for all fish, bottom weight bar and picking at 1280Ã—720, 1600Ã—720 and 1024Ã—768, page two, sale refresh, empty cleanup and disabled closed viewport. All catalog species have usable real meshes that fit the holder. Zero failures.
- `tests/ui_refresh_visual_test.gd`: real gameplay opening/closing and pausing, screen-touch 3D picking, pagination, selling, confirmed release, source population restoration, reload, stale selection, failed-save rollback and legacy catches. 137 checks, zero failures.
- Captures: `exports/qa-cooler/cooler-*.png`; real gameplay captures in `exports/qa-cooler-gameplay/`.
- No physical Android device test or Android release build performed for this change. Existing host certificate-store diagnostics remain unrelated to rendering/storage.

Reference layout update: the 3D preview occupies the full body height. Page controls, help and transaction messages are in the right detail column; the numeric weight is in the header. No UI strip overlays or takes space below the cooler preview. Camera B is the default.

Latest requested layout: only camera A remains. The selector and cameras B/C are removed. Framing uses opening_focus_bounds (the mouth and fish volume), allowing the lid/body outside this close-up to extend past the viewport while the opening and all fish stay visible. Ice and fish are raised 0.25 preview units, still below the rim, so the near wall does not hide the fish. Numeric slot labels are raised for visibility. Tests now check this single-camera opening framing and bulk-sale behavior.
