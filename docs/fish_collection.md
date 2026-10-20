# Fish collection

Open **สมุดสะสมปลา** beside the ecology/help button at the upper left before casting. The modal pauses gameplay and closes with its button, Escape, or Android Back.

Each successful landing records one catch, before the keep/release decision. Escaped fish do not count. Catching the same released individual again counts as another successful catch. The collection tracks discovery, count, total weight, maximum weight, minimum weight and last weight, in kilograms. There is no fish-length measurement yet.

The persistent `FishCollection` Autoload saves immediately to `user://fish_collection.cfg`, using a temporary file followed by rename. Failures are shown in the result and collection screens. Unreadable or unsupported save files are preserved rather than overwritten. Existing catches from earlier versions cannot be reconstructed.

Edit `features/collection/collection_panel.tscn` for layout, and `collection_row.tscn` for each species card. `data/fish/fish_catalog.gd` supplies the same sixteen species resources to both the collection and pond. Existing tilapia, snakehead and catfish IDs are preserved, so earlier saved catch statistics remain associated with the same fish.

The collection uses a responsive inventory grid with generated painted fish icons. All sixteen 256×176 icon regions (within padded 256×256 cells) share one 1024×1024 transparent atlas, `assets/fish/icons/fish_collection_atlas.png`. Each species resource exposes `collection_icon` in the Inspector, referencing an editable AtlasTexture resource in the same folder. Undiscovered species appear dark. Cards use TextureRect nodes instead of sixteen separate 3D viewports; the catch result retains its animated 3D fish. Touching a card selects it and shows detailed statistics below the grid. Edit card styling and image framing in `collection_row.tscn`.

Full resolution generated sources and prompts stay outside the Godot project under `../art/fish/collection-icons/`. Rebuild the runtime atlas with `tools/pack_fish_icons.ps1` using that folder's manifest. Each cell includes padding; aspect ratios are preserved and texture filtering clips each region to prevent bleed.

Validation: collection integration, repeat saves/reload, keep/release counting, save failure, modal open/close, rendered 1280×720 and 1600×720; fishing simulation (60 checks) and input/visual regression passed. Tests use an isolated save path or disable recording, so simulated catches do not populate player statistics. Physical Android validation remains outstanding.

Collection journal skin: generated textures in assets/ui/collection/journal_skin.png (1024x512), shared by editable StyleBoxTexture resources for the panel, normal/selected slots, details panel and buttons. Full resolution source and prompt: ../art/fish/collection-ui/. Edit collection_panel.tscn and collection_row.tscn to adjust layout. Modal z_index is 20. Undiscovered icons remain dimmed but readable. Tests send touch events to the real open/close buttons, verify stats and scrolling, and validate grid visibility and close-button bounds at 1280x720, 1600x720 and 1920x864. These desktop touch simulations do not confirm physical Android behavior. Existing Play Store bundles precede the generated icon/UI assets; a new Android build and Play release are required for mobile users to receive them.

Compact discovery layout: all 16 slots fit a four-column, four-row grid at tested landscape sizes. Header shows only the journal title, unlocked count and close button. Locked cards hide their name and show a true alpha silhouette plus a question mark, including when tapped. First successful landing unlocks the full color icon and name using the existing persistent catch records. Only selecting an unlocked card shows a single short line with count and best weight. Grid sizing shrinks to the available height; no extra icon textures are stored for silhouettes (shared canvas shader).

The current collection skin uses the modern SVG surfaces and hud_theme.tres in assets/ui/modern, matching gameplay. Earlier generated brass journal surfaces are retained as previous artwork and are no longer referenced by the collection scenes.

Collection cards now display only the species' best caught weight and catch count directly beneath the unlocked icon. Cards are passive panels: tapping does not select a card or reveal a detail section. Locked cards still show only silhouette and question mark. All 16 cards remain visible in the grid; catch persistence, unlocks and 3 tested screen sizes pass.
