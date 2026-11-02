# Compact gameplay HUD

The authored layout is in `features/fishing/fishing_hud.tscn`, under
`SafeArea/TopBar`. A single right-aligned row contains shop, gold and gems,
cooler weight/capacity, missions, collection and settings. Minimap and tracked
mission retain their original anchors and offsets. The cooler uses weight
because equipment capacity is defined in kilograms.

`features/fishing/ui/game_settings_panel.tscn` contains volume, resume, help and
home. It participates in the existing modal pause lifecycle. Closing settings
restores the previous pause state; home closes it before requesting navigation.
Volume persists in `user://lakebound_settings.cfg` using AtomicConfig.

Collection cards keep a minimum 60px fish portrait area. The portrait itself
opens the same species-filtered catch-history map for discovered fish; the
separate text history button is removed. Locked silhouettes remain inactive.

## Shared artwork

`assets/ui/hud/hud_items.png` is one generated 512×512 RGBA atlas. Shop, fish
coin, gem and red cooler occupy padded 256×256 cells. The four `.tres`
AtlasTextures share the same imported texture and clip filtering at cell edges.
HUD and shop currency chips reuse these resources. No large generated original
or separate raster icon is included in the game project.

- PNG source: 299,416 bytes (292.4 KiB).
- Imported lossless texture: 248,942 bytes (243.1 KiB) on this Godot import.
- Mipmaps disabled; alpha retained. Final Android archive size has not been
  measured for this change.

The settings gear remains a small SVG. Existing collection icon and mission
controls retain their established style.

## Verification

`tests/compact_hud_test.gd` exercises real touch on every action, pause/resume,
help navigation, volume persistence, home transition, shared atlas resources,
and layout captures at 1280×720, 1600×720 and 1024×768. Other focused checks:
`hud_session`, `fishing_recovery`, `fishing_recovery_visual`, `ui_refresh_visual`
and `shop_redesign`. Desktop rendering does not replace Android device QA.
