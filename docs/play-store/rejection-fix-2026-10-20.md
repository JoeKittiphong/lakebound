# Play Console rejection correction — 20 October 2026

Google issue ID: `4985618854380322649`.
The notice cites Play Console Requirements: an app category or declared feature requires an organization account. The notice does not identify a specific checkbox.

## Findings and changes
- Financial declaration incorrectly selected "Rewards, points, frequent-flyer miles, and other incentives". The current source/build has none. Deselected it, selected "My app doesn't provide any financial features", and saved.
- Health declaration already selects no health features; government declaration already selects No. These were inspected and preserved.
- Data safety already selects no collection/sharing; current offline game source and release manifest agree. Preserved.
- Store category was Music. Corrected to Game / Simulation and saved.
- Removed unrelated tags for strategy, farming, role-playing and business; retained Simulation.
- Privacy policy pointed to the support homepage. Verified the existing public `/privacy` page and saved its direct URL: https://zylaah-support.netlify.app/privacy
- Added an editor-editable privacy button to the game menu that opens the same public policy in the external browser, without adding network permissions. Bumped release to 0.1.1 / version code 2.

## Build validation

Godot import and GPU-rendered menu/play/movement/back smoke checks passed; menu checked at 1280x720 and 1600x720. Signed `exports/android/lakebound-0.1.1-closed.aab` using the original upload identity, matching certificate SHA-256 `22148E753332B6E25C4CF63A54E1D1604F2A48FC2ECB77245921C1A4DC6994B7` from the first accepted bundle.
Bundle SHA-256: `b65c6b36a2337b2e50db58e9986088d9b5daba3ffd228d739d92e4caf8ada43b`.
Release manifest: package unchanged, code 2, version 0.1.1, API 36, no requested permissions. ARM64 ELF load segments aligned to 16 KB; no signing credentials included in the bundle. Physical Android device/browser handoff remains untested.

Policy reference: https://support.google.com/googleplay/android-developer/answer/10788890

These corrections match the app's actual behavior; they do not guarantee approval. The game remains a world-exploration prototype without fishing mechanics. Avoid claiming completed fishing gameplay in listing/release notes.

## Submission result

Continued after the user's explicit request to proceed. Google Play accepted bundle 2 (0.1.1), with two non-blocking diagnostics warnings (missing mapping/native symbols), and no loss of device support.
Saved closed Alpha release 2, `Lakebound 0.1.1 — Closed test`, excluded old bundle 1, then submitted the 14 pending changes and confirmed the submission dialog. Publishing overview now lists the release and corrected category/privacy settings under "Changes in review". Quick checks are running; content review starts automatically when they complete. Managed publishing remains enabled as previously configured. Approval and availability to closed testers are still pending.
Proof: `exports/play-store/closed-test-resubmitted.png`.
