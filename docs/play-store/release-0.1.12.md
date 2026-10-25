# Lakebound 0.1.12 — New fishing regions

Prepared 25 October 2026 from the owner's current source, following the requested size trial and authorization to update Alpha.

- Package com.zylaah.lakebound; version code 13, version 0.1.12.
- AAB exports/android/lakebound-0.1.12-closed.aab
- Archive 94,511,775 bytes (94.51 MB), +33,231,676 bytes (+54.23%) vs 0.1.11.
- SHA256 90a37358c37833f9cd42f2ac46787f35957d9f40de774e641a7adbfc8a7a85cf
- Original upload certificate SHA256: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- Same-build manifest/ZIP/secret exclusion/ARM64 16KB alignment passed. API 36/min 28; VIBRATE only.

Current source has six selectable fishing regions with regional fish and missions, updated selector and collection UI. No gameplay edits or save-reset generation changes made for release.

Regions integration: 854 checks, zero failures. Test shutdown reported two ObjectDB leaks and one resource still in use; sandbox host certificate-store diagnostic also appeared. Exact AAB install-time assets extracted to exports/qa-installed-0.1.12 reached loading -> menu -> grand river, exit 0, using an isolated QA profile. Nine ObjectDB leaks on startup-test shutdown remain. Original startup fixture timed out because current loading screen now waits for Start and embeds its menu; revised QA-only fixture follows that actual flow. No physical Android test performed.

Prior Alpha 0.1.11 was observed available to testers, published 24 October 14:55. Alpha release 12 accepted bundle 13 (0.1.12) with no blocking errors; only optional missing mapping/native symbol warnings. Google Play estimated new-install download 68 MB (+32.8 MB vs previous). Submitted the single intended release change. Publishing overview confirms Changes in review with quick checks running. Managed publishing remains enabled; not yet published. Proof: exports/play-store/0.1.12-submitted.png.
