# Illustrated map selection previews

## Accepted compact placement

The wide A/B proposals were rejected because they obscured the angler and jetty. The current carousel is a 116-pixel-tall image strip **inside the original right-hand PlayCard**, between its map name and description. Image arrows sit at the sides of the strip and swiping works within the image. The original 380×325 play-card footprint is retained; there is no map artwork in the character/bridge area. The map title, description, play button and fish/mission counts remain together in this original card. The old A/B preview descriptions below describe superseded proposals, not the current layout.

Verified all six map bindings, actual swipes, arrow wrapping and containment of the image within PlayCard at 1280×720, 1600×720 and 1024×768. Current screenshot: `exports/qa-map-carousel/B-banner-1280x720.png` (filename retained from preview harness).

The main menu now selects its actual gameplay region through an illustrated swipe component rather than a dropdown/modal list. The existing play button still enters the selected `RegionCatalog` scene, preserving save namespaces and remembered region selection.

## Two preview layouts

- **A — Cards with side previews** (current default): a large selected image with cropped previous/next image peeks. Makes additional destinations discoverable.
- **B — Wide image**: one wide landscape image, with the same name/navigation controls and play panel. Emphasizes scenery.

`features/menu/map_carousel.tscn` owns the editable image/title/navigation hierarchy. `map_carousel.gd` exposes `layout_style` (0=A, 1=B) in the Inspector. Side previews hide at narrow component widths; arrow buttons and swipes continue working. Main menu layout is authored in `main_menu_ui.tscn`.

Swipe left/right on the picture to choose the next/previous map; use arrows or click a side preview on desktop. Selection wraps between the sixth and first map. Vertical/cancelled gestures do not change the region, and a swipe never starts gameplay automatically. Changing selection updates the image, name, subtitle, fish/mission counts and remembered selected ID. The centered picture fades briefly on change. Press Play to enter the selected region.

## Artwork

Six newly AI-generated, 16:9 landscape illustrations are stored in `assets/ui/maps/`:

| File | Environment |
| --- | --- |
| river.png | Broad freshwater river, rock banks, morning light and wooden jetty |
| lotus_marsh.png | Shallow lotus marsh with pink flowers, reeds and bamboo fishing platform |
| forest_stream.png | Clear forest stream, boulders, cascades and tropical canopy |
| wild_reservoir.png | Deep reservoir, submerged dead tree stumps and limestone hills |
| mangrove_estuary.png | Brackish channel, exposed mangrove roots and distant bay |
| coral_coast.png | Turquoise sea, visible shallow coral, sandy rocks and limestone islands |

These are illustrative destination mood images, not screenshots or promises of exact in-game geometry. Generated with the built-in image tool for this task; the reservoir received a targeted cleanup removing a tiny generated corner mark. Original generated files remain under the Codex generated-images folder. Project copies are self-contained.

PNG sources are retained at original resolution. Godot import limits UI textures to 1024 pixels and uses quality 0.85 lossy compression to reduce exported asset size and runtime texture memory. The generated artwork is separate from existing actual gameplay assets.

## Verification

- `tests/map_carousel_test.gd`: all six art/scene bindings, actual screen-touch left/right gestures, vertical/cancelled gesture rejection, wrapping arrow navigation, selected region + detail consistency, three viewport sizes and both layouts with no overlap between carousel/play controls.
- `tests/startup_flow_test.gd`: loading to main menu, selected region Play, Back navigation and preservation of the live cinematic. Uses a named QA player so onboarding does not block the navigation fixture.
- `tests/regions_integration_test.gd`: the menu-selection section now exercises swipe cards rather than the removed modal selector.
- Captures: `exports/qa-map-carousel/A-cards-*.png`, `B-banner-*.png`, and `map-<region>.png` for all six images in context.

No Android build, physical-device validation or Play Store publication performed for this change. Layout A is integrated as a reversible default while the user chooses a preferred preview.
