# Lakebound internal release preparation

## Current status — 25 October 2026, 0.1.12

Original-key bundle 13 (0.1.12) accepted and submitted as closed Alpha release 12. Publishing overview confirms Changes in review; managed publishing enabled. AAB 94.51 MB (+54.23% vs 0.1.11), Play new-install estimate 68 MB (+32.8 MB). Regions integration passed 854 checks; exact packed startup reached menu and gameplay. No physical Android test. Shutdown resource leaks remain. See release-0.1.12.md and exports/play-store/0.1.12-submitted.png.

## Current status — 24 October 2026, 0.1.11

Original-key bundle 12 (0.1.11) accepted and submitted as closed Alpha release 11. Publishing overview confirms Changes in review; managed publishing enabled. AAB 61.28 MB; estimated Play new-install download 35.2 MB. Missions 76/economy 40 checks passed; exact packed startup reached gameplay on desktop. No physical Android test; 11 shutdown ObjectDB leaks remain. See release-0.1.11.md and exports/play-store/0.1.11-submitted.png.

## Current status — 24 October 2026, 0.1.10

Exported original-key bundle 11 (0.1.10), verified loading → menu → gameplay from exact extracted AAB assets on desktop, and submitted Alpha release 10 to Google review. AAB 61.28 MB, estimated Play download 35.2 MB. No physical Android test. See release-0.1.10.md and exports/play-store/0.1.10-submitted.png.

## Current status — 24 October 2026, 0.1.9

Bundle 10 (0.1.9), original upload certificate, accepted and submitted as Alpha release 9 with two new actual gameplay screenshots. AAB 60.59 MB; Play estimated download 34.5 MB (6.29 MB smaller than prior). Managed publishing enabled. See release-0.1.9.md for verification limitations and exports/play-store/0.1.9-submitted.png.

## Current status — 21 October 2026, 0.1.8

Disabled all tackle purchase buttons temporarily. Exported signed bundle 9 (0.1.8), Google Play accepted it and Alpha release 8 was submitted for review. Economy suite: 40 checks, zero failures. Managed publishing remains enabled. See release-0.1.8.md and exports/play-store/0.1.8-submitted.png.

## Current status — 21 October 2026, 0.1.7

Bundle 8 (0.1.7) exported with original upload certificate, accepted by Google Play and submitted as Alpha release 7. Includes the owner-requested one-time tester collection/tutorial reset. Managed publishing remains enabled. See release-0.1.7.md and exports/play-store/0.1.7-submitted.png.

## Current status — 21 October 2026, 0.1.6

Signed bundle 7 (0.1.6), original upload certificate, accepted and submitted as closed Alpha release 6. Publishing overview confirms Changes in review. Managed publishing remains enabled. See release-0.1.6.md for verification and the legacy lake-test limitation; screenshot: exports/play-store/0.1.6-submitted.png.

## Current status — 20 October 2026, 0.1.4

Exported signed bundle 5 (0.1.4), Google Play accepted it, and closed Alpha release 5 was submitted for review. Simulation, collection and visual/input tests passed with zero failures. Previous 0.1.3 was approved while this task was running and remains ready to publish; it was not published here. Managed publishing remains enabled. See `release-0.1.4.md` and `exports/play-store/0.1.4-submitted.png`.

## Current status — 20 October 2026, 0.1.3

Bundle 4 (0.1.3) was exported using the original upload certificate, accepted by Google Play and submitted as closed Alpha release 4. Publishing overview confirms the release and both Thai listing text changes are in review (quick checks precede content review). Managed publishing remains enabled. Prior 0.1.2 was observed available to testers before this update; the older review-restart blocker below is historical. See `release-0.1.3.md` and `exports/play-store/0.1.3-submitted.png`.

## Historical preparation log

Latest upload: bundle 3 (0.1.2), closed Alpha release 3, accepted and saved with the fishing build, updated copy and screenshots. Submission is awaiting the user's specific approval to cancel/restart the currently running 0.1.1 review. See `release-0.1.2.md`.

Latest: 0.1.1 / version code 2 was accepted and submitted for closed Alpha review on 20 October 2026, following correction of the financial declaration, category/tags and privacy URL, plus an in-game privacy button. Publishing overview confirms "Changes in review". Managed publishing remains enabled. See `rejection-fix-2026-10-20.md` for evidence and bundle checks.

New Play Console app ID: `4976330388803902985`.
Package: `com.zylaah.lakebound`.
Console: https://play.google.com/console/u/1/developers/6769550037060368877/app/4976330388803902985/app-dashboard

Owner explicitly approved the developer-policy and US-export declarations before app creation. App was created as a free game, default language Thai. User requested the existing tester group.

Google Play processed and accepted version 1 (0.1.0), target API 36, minimum API 28. Review reported no blocking errors, two optional diagnostics warnings (missing deobfuscation mapping and native debug symbols). Estimated new-install download: 32.1 MB. Existing tester list `zylaah` (12 users) was selected and saved, as requested.

Thai store listing saved and verified as ready to send for review on 20 October 2026: app title, 57-character short description, 450-character full description, icon, feature graphic and three actual game screenshots. AI labels applied to the generated icon, feature graphic and menu screenshot containing generated background art.

On 20 October 2026, the release details page was verified to show "available to internal testers", published 19 October at 23:32, supporting 15,660 devices. This was an observed existing published state; no additional publish action was needed in this verification turn.
Internal opt-in URL: https://play.google.com/apps/internaltest/4701391481622503628

## Closed test created 20 October 2026

Track: Alpha, ID `4699681996827955507`, release 1.
Name: `Lakebound 0.1.0 — Closed test`.
Reused existing library bundle version code 1 (0.1.0), without re-uploading or rebuilding. Added Thai closed-test release notes and saved the reviewed release successfully.
Publishing overview confirms this release is saved among 14 changes not yet submitted for review. Existing settings show tester email list `zylaah`, countries Thailand and Japan. Quick pre-review checks are running. No review submission was performed in this task.
The overview also shows a pre-existing Music game category; review/correct that category before submitting the entire change set.
Proof: `exports/play-store/closed-test-created.png`.

Signed AAB: `exports/android/lakebound-0.1.0-internal.aab`.
SHA-256: `f49ede46b04e608022750083b29fbdd250366ce1065197fe14a4e4a25e539c72`.

Local checks passed: Godot import, GPU scene/menu/navigation/movement smoke, 16 KB ARM64 ELF segment alignment, release manifest with no requested permissions, ZIP integrity and signing-file exclusion. `jarsigner -verify` reports jar verified (self-signed certificate/no timestamp and streaming ZIP-order warnings remain); Google Play validation is the final upload check. No physical Android device test has been performed.

Support email, privacy-policy owner/contact and final hosted policy, intended audience and production setup remain unprovided. Do not use the signed-in Google email as a public contact without instruction. This is an internal world-preview prototype, not a completed fishing game or production launch.
