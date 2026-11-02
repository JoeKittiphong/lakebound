# Web-safe UI icons

The shipped Noto Sans Thai font lacks arrows, check marks and map shapes. Desktop OS fallback hid the missing glyphs; Web exports have no equivalent system fallback. Runtime UTF-8 sources contain no replacement characters.

`shared/ui/fonts/game_font.tres` combines the existing Thai font with an original bitmap glyph atlas: `shared/ui/fonts/symbols/ui_symbols.png` + `ui_symbols.fnt`. The atlas contains 20 symbols (arrows, check, navigation chevrons, close/minus, map markers and punctuation), drawn without any external font or emoji dependency. Ordinary Thai/Latin text keeps the existing font. OS fallback is disabled on the Thai font import so missing future glyphs cannot hide on desktop.

All three shared UI themes, loading font and stored-fish label use the combined resource. Inline text remains editable, searchable and translated normally; icons are rendered from packaged image pixels. Existing standalone SVG/PNG buttons remain image assets. Wallet icons in the HUD are now explicit authored TextureRects rather than nested instance-child overrides, which disappeared in the Web export.

Rebuild artwork: `python tools/build_ui_symbols.py` (Pillow). Rebuild Web/PWA: `./tools/build_web.ps1`. Deploy the entire generated `exports/web` directory together; previously open PWA pages may require closing and reopening to pick up the new build.

Validation on 2026-10-29:
- `tests/web_icons_test.gd`: scans production sources for replacement characters and checks every non-Thai symbol against packaged glyph coverage with OS fallback disabled; renders a glyph sheet.
- Lure progress regression: 238 checks passed, including native joystick input and three landscape aspect ratios.
- HUD session regression: 45 checks passed.
- Release Web export succeeds. Actual in-app Chromium browser renders menu arrows, page indicators, external-link arrow and all map legend glyphs. Evidence in `exports/qa-web-icons/`.

No deployment or physical-phone validation is implied by local Web export/browser checks.
