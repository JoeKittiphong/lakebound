---
name: update-pwa-web
description: Export and update the Lakebound Godot game as Web/PWA on its existing Netlify site, including pack validation, Google login checks, and installed-app update verification. Use for Lakebound web releases, not Android or Google Play releases.
---

# Lakebound Web/PWA update

Use the user's latest saved game source. An update request normally authorizes building and publishing to the existing site; preserve unrelated work and do not add gameplay changes unless requested. Never reset the working tree or reuse an older ZIP as the latest build.

## Project and destination

- Project: `C:/Users/Zylaah/programmer/mobile game/fishing game/fishing-game`
- Godot: `C:/Users/Zylaah/programmer/godot/Godot_v4.7.2-stable_win64_console.exe` (verify installed version if changed).
- Production: `https://lakebound-zylaah.netlify.app/`
- Dashboard: `https://app.netlify.com/projects/lakebound-zylaah/deploys`
- Site ID: `f419b9ea-3356-40f5-ad80-5649e16f48b7`
- Existing QR encodes the production URL, so ordinary updates keep the same QR.
- Read repository instructions and `docs/web-export.md`; read `docs/google-login.md` when auth changes or login fails. Do not apply the Android release skill to this workflow.

## Build and validate

Run from the project root, using the installed Python/Node runtime if they are absent from PATH:

```powershell
& ./tools/build_web.ps1 *> exports/web-export.log
if ($LASTEXITCODE -ne 0) { throw 'Web build failed; inspect log.' }
& 'C:/Users/Zylaah/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/package_netlify.py
```

`build_web.ps1` imports resources, audits dependencies, regenerates the selected-resource manifest **for the Web preset only**, exports, patches PWA offline metadata, and smoke-tests the actual exported pack with isolated save data. Keep this preflight: a stale export manifest previously omitted auth/global classes and runtime-loaded scenes; export still succeeded while the login UI had dead buttons.

Check `exports/web-export.log` for script/parse/export errors and `exports/web-pack-check.log` for `WEB PACK PASS`. A zero export exit code alone does not prove a playable build. Preserve native renderer/settings and the existing single-thread Web/PWA settings. Do not switch to all-resources export without reviewing source-library sizes.

The output paths have different purposes:

- `exports/web/`: original uncompressed Web files for local preview.
- `exports/netlify/`: deployment files; WASM/PCK are gzip bytes with their original filenames and matching `_headers` rules.
- `exports/lakebound-netlify.zip`: upload this fresh archive, with `index.html` at its root, never the entire repository or a parent folder. Do not serve the precompressed folder without its encoding headers.

For auth/network changes, run `node tools/test_web_oauth.cjs` and relevant suites through `node tools/test_competition.cjs google_auth google_startup competition_transport`. Add `cloud_sync background_ranking` when those services changed. Read test results, not only process status. Tests use isolated profiles; never direct them at the player's real saves.

## Publish

Prefer a purpose-built connected deployment tool when available; otherwise use the logged-in Netlify browser tab. Discover current browser/tab IDs; old IDs are not stable. Follow the browser's current documentation and read its file-upload guidance before uploading.

On Deploys, choose **browse files to upload**, select the fresh ZIP through the file chooser, and wait without refreshing. Netlify auto-publishes this site. Verify the new deploy is **Published/currently published**, not merely Uploading, and verify header processing succeeds. Save a screenshot for the final response and record the deploy link. If upload stalls or fails, inspect the visible error; allow one fresh retry for a transient connection failure, then report the concrete blocker rather than creating repeated stuck deploys.

## Check the live game and PWA

Open production and check startup, entry to the menu, and relevant changed behavior. Godot UI is a canvas: use screenshots and actual supported pointer/keyboard input. Browser DOM text such as “Your browser does not support the canvas tag” is fallback text, not evidence that WebGL failed. Inspect runtime console errors after loading and clicking; missing classes/resources are release failures.

An active old service worker can serve old assets after refresh. Let the page detect the new worker, then close all game/PWA clients and reopen online so it can activate. Preserve unfinished user input and save progress before restarting. **Never clear site data, IndexedDB, or user saves to force an update.** Keep the same origin. Verify session restoration when login changed; distinguish browser emulation from testing an installed app on a real phone.

## Google login invariants and diagnostics

- Web uses same-tab Supabase PKCE through `features/auth/web_oauth.gd`; native Android/Windows callbacks are separate.
- Supabase project: `efxjvrywbivyolluvuyp`. URL configuration currently includes exact production callbacks `https://lakebound-zylaah.netlify.app/` and `/index.html`. Verify configuration before changing it; do not add wildcard preview domains as a workaround.
- Keep the short-lived verifier through navigation; let JavaScriptBridge return before leaving the page. Browser close-request during OAuth navigation must not cancel the pending flow. Explicit Cancel still clears it.
- Callback checks exact origin/path, rejects duplicate/implicit/error responses, expires pending state, consumes it once, and removes auth query parameters. Never print tokens, verifier, callback codes, or credentials in diagnostics.
- Browser Fetch already decompresses responses. These Web HTTPRequest clients use `accept_gzip=false`; otherwise Supabase's gzip response can be decompressed twice and the account/profile RPC fails. Preserve native behavior.
- A working Google account chooser is **not** a completed login check. Verify the return to the game, token exchange, account/profile load, and either the name setup screen for a new player or the signed-in menu for an existing player. Let the user choose their own player name; do not invent one just to finish a test.
- Google OAuth audience was configured in Testing with specific test accounts. If Google itself rejects a different account, report its actual message and inspect audience configuration; do not reset player data, change provider secrets, or make OAuth public merely to bypass the error.

Report what was published, which checks actually passed, and any remaining device-specific validation. Include the production link and screenshot proof. Tell existing PWA users to close/reopen online; avoid guaranteeing immediate updates or cloud-save coverage without checking the current implementation.
