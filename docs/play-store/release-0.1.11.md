# Lakebound 0.1.11 — Missions and gear

Prepared and submitted 24 October 2026 from the owner's latest source.

- Package com.zylaah.lakebound; version code 12.
- AAB exports/android/lakebound-0.1.11-closed.aab
- Archive 61,280,099 bytes (61.28 MB), 4,669 bytes smaller than 0.1.10.
- SHA256 94d8af480b714a8a988a754674d1327ef787fc4b3b6220676a1da241f22d4fb8
- Original upload certificate verified: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- API 36/min 28; VIBRATE only. Archive validation and ARM64 16KB alignment passed.

Latest source adjusts mission panel/reward presentation and re-enables gear purchases using in-game coins. No player-save reset generation change.

Missions: 76 checks, zero failures. Economy: 40 checks, zero failures. Exact install-time assets extracted from this AAB reached loading -> menu -> gameplay in a desktop headless real-time run using an isolated QA profile. Eleven ObjectDB leaks remain at shutdown. No physical Android validation performed.

Prior 0.1.10 was observed published to testers. Alpha release 11 accepted bundle 12 (0.1.11). Google Play estimated new-install download 35.2 MB, 4.51 KB smaller than prior; update-size display 462 KB. Only optional missing mapping/native debug symbol warnings, no blocking errors. Submitted the single intended release change; publishing overview confirms Changes in review with quick checks running. Managed publishing remains enabled, so this is not yet published. Proof: exports/play-store/0.1.11-submitted.png.
