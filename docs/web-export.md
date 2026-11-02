# Lakebound Web/PWA

## Netlify deployment

Production URL: https://lakebound-zylaah.netlify.app/

Dashboard: https://app.netlify.com/projects/lakebound-zylaah/overview

Project ID: `f419b9ea-3356-40f5-ad80-5649e16f48b7` (team Rookie Boys).
Published 2026-10-28 using Netlify Drop, deploy `6ae1e84e6dd1ae6ebf067ee3`.
Verified the production HTTPS URL in the in-app browser: downloaded the compressed
engine/pack, rendered the intro, saved a local name, entered the river gameplay
and dismissed the tutorial. Proof: `exports/qa-web/netlify-live.jpg`.
Disabled the optional Powered by Netlify badge in project settings to prevent
overlap with the game controls; existing open pages require a fresh load.

After building, run `python tools/package_netlify.py` and upload
`exports/lakebound-netlify.zip` to this existing project's deploy dropzone.
It contains only built game files, with gzip-compressed `.wasm` and `.pck` served
under their original names using `_headers` Content-Encoding rules. HTML and
service worker are revalidated; all files must be deployed together. The original
`exports/web/` remains uncompressed for local previews. The upload archive is
about 67.4 MB. Do not deploy the repository or signing/server folders.

## Configuration and build

The `Web` preset exports to `exports/web/index.html`. It uses single-threaded
WebAssembly, Compatibility/WebGL 2.0, adaptive canvas sizing, desktop and mobile
texture variants, landscape orientation and a standalone PWA. Android keeps its
existing Mobile renderer. Export excludes tests, tools, server source, credentials
and the same obsolete art excluded by the Android release.

Run from the project directory (Godot 4.7.2 with matching Web export templates):

```powershell
./tools/build_web.ps1 -Godot 'C:\path\to\Godot_console.exe'
python tools/serve_web.py
```

Open http://localhost:8062/index.html. The preview binds only to localhost and
explicitly serves `.js` as JavaScript and `.wasm` as WebAssembly. The build script
also adds PWA metadata and icons to the generated service worker's offline cache.
Use the script for final builds; exporting from the editor alone omits that extra
cache step. Generated files remain outside source control.

## Verification on 2026-10-28

- Release Web export completed without export errors/warnings.
- Real headless Chromium/Edge rendered the intro and all six fishing maps.
  Each map entered and returned to the menu without Godot runtime errors.
- Touch start, player naming, virtual joystick and rod casting were exercised.
- Saved name and player ID survived a page reload using IndexedDB `/userfs`.
- After a second online load, the active service worker cached `.wasm` and `.pck`.
  With networking disabled, the game reloaded, entered the river and cast a line
  using touch input at an 844 x 390 landscape viewport.
- Live read-only browser fetch to the configured Google Apps Script returned
  HTTP 200, schema 3, with readable CORS response. Initial sandbox denial was
  `ERR_NETWORK_ACCESS_DENIED`; the unrestricted probe succeeded.
- Web requests now use `text/plain;charset=UTF-8` for JSON bodies to avoid the
  unsupported Apps Script OPTIONS preflight. Native requests keep JSON MIME type.
  Live leaderboard writes were deliberately not exercised with test player data.
- Existing regression checks passed: `sheets_ranking_sync`, `sheets_settings`,
  `social_lifecycle`, `loading_flow`. The isolated native runner reported host
  certificate/signing-directory sandbox diagnostics separately from test failures.
- A separate persistent Chrome test profile reported a valid Lakebound manifest
  and no PWA installability errors. This checks eligibility, not an actual install.

Evidence: `exports/web-export.log`, `exports/qa-web/browser-summary.json`,
`exports/qa-web/live-ranking-and-installability.json`,
`exports/qa-web/regression/results.json` and the screenshots in `exports/qa-web/`.
The repeatable read-only browser probe is `tools/check_web_ranking.cjs`; it needs
Playwright and installed Chrome (`LAKEBOUND_PLAYWRIGHT` can specify its module).

## Hosting and phone acceptance plan

1. Upload the entire `exports/web/` directory together, preserving names and paths,
   to an HTTPS host. Serve `.wasm` as `application/wasm`, `.js` as
   `application/javascript`, and the manifest as JSON. Enable gzip/Brotli transport
   compression for `.wasm`, `.pck`, `.js` and JSON. Do not cache HTML/service-worker
   scripts indefinitely; publish files atomically so clients do not mix versions.
   Cross-origin isolation headers are unnecessary for this single-thread build.
2. Load once, then reopen online to allow the default Godot worker to control the
   page and cache the game payload. Confirm Cache Storage contains both `.wasm`
   and `.pck` before relying on offline play. Browser storage can be evicted;
   clearing site data deletes this device's save. Native Android saves are separate.
3. Android Chrome: use the browser's Install/Add to Home screen command. iPhone:
   open in Safari and use Share > Add to Home Screen. Test launch from the icon,
   landscape layout, keyboard entry, safe areas, multitouch and interruption/resume.
4. On physical Android and iPhone, complete a catch, keep/release it, reload and
   verify progress; test ranking sync with a designated real test account and
   confirm offline statistics remain usable. Compare frame rate, memory, heat
   and startup time on representative lower-end phones.
5. Install an update over an existing cached build and verify both the updated
   assets and existing player save before public rollout.

## Limits and remaining work

This is a working local Web/PWA candidate, not a physical-device certification.
No public HTTPS site or mobile home-screen installation was performed. Browser
emulation does not prove iPhone Safari behavior, device FPS, memory or thermal
stability. Live leaderboard writes and a complete catch/settlement cycle remain
acceptance checks. Some existing emoji/icon glyphs render as missing-glyph boxes.

The uncompressed game pack is about 130 MB and the WebAssembly engine about
39.5 MB (decimal). Both texture families are included for browser coverage. This
requires a substantial initial download and cache space; configure compression
and measure transfer size on the actual host before public release. A local gzip-6
estimate for the pack, engine and loader totals about 67.2 MB; the preview server
does not compress responses. Details are in `exports/qa-web/transfer-size.json`.
A later asset
audit or separate quality builds can reduce it, after verifying dynamic fish/model
loads. Scene-only export was rejected during testing because imported runtime
dependencies were missing; do not switch it back without packed-resource tests.
