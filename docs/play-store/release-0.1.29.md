# Lakebound 0.1.29 / code32 — 4 November 2026

Requested ordinary closed Alpha update. Previous0.1.28 observed available to some testers, published3 November08:13. Created Alpha release28. Keep six Early Access changes unsubmitted; no tester/country/managed-publishing changes.

Current-source changes: friends/presence/request acceptance and room invitations, add friends from room members, Cloudflare match WebSocket control with native RTC pose delivery and interpolation, performance improvements including mobile30FPS cap, static preview/offscreen rendering reduction and foliage partitions. Existing Android Google OAuth callback and explicit BagDock layout retained. Cloud synchronization remains disabled in online.cfg. No backend deployment, reset, account action or PWA update performed in this task.

Source regression: Google auth/startup, competition/session, legacy transport, bag/HUD/economy. Added checks for native RTC19, interpolation38, friends UI6, member-friends UI6, invite notice15, thermal performance and offscreen rendering. Backend local npm test9 suites pass, including100 authenticated test sockets/20 rooms; this is local capacity testing, not hosted/mobile certification. Initial legacy tests inherited Cloudflare backend choice and failed mock-route assertions. Fixed QA runner to set LAKEBOUND_MATCH_EDGE=0; isolated legacy/RTC/interpolation reruns pass without weakening assertions or changing production backend selection.

New native GDExtension ARM64 library PT_LOAD segments are16KB-aligned. Upstream1.2.1 has no Android ARM32 library; export warns and ARM32 must use existing bounded fallback. Physical Android32/64/network TURN behavior unverified in this task. Native UDP TURN only; TCP/TLS unavailable in native upstream. Preserve current ABIs. Windows certificate-store diagnostics remain. Exact artifact validated and Alpha submitted as detailed below.

<th>
เพิ่มระบบเพื่อน สถานะออนไลน์ และคำเชิญเข้าห้องแข่งขัน
เพิ่มเพื่อนจากรายชื่อผู้เล่นในห้องได้สะดวกขึ้น
ปรับการเชื่อมต่อและการเคลื่อนไหวของผู้เล่นออนไลน์ให้ต่อเนื่องขึ้น
ลดงานเรนเดอร์นอกจอและปรับประสิทธิภาพสำหรับมือถือ
</th>

Artifact built: exports/android/lakebound-0.1.29-closed.aab;86,566,502 bytes (86.566502 decimal MB), +1,388,984 bytes versus0.1.28. SHA2564bc0adc8525a077da8d9ee429b7e0afee58ab947283be663967f4155350eb624. Code32/name0.1.29/API36/min28/INTERNET+VIBRATE verified. Original certificate confirmed. All bundled ARM64 ELF libraries including WebRTC have16KB PT_LOAD alignment. ZIP integrity, materials/remaps/exclusions and Android OAuth callback checks pass. Both Gradle tasks BUILD SUCCESSFUL. Extracted3348 assetpack files; desktop QA includes separate official Windows RTC host DLLs solely to run native host tests (Android library validated structurally, not executed on desktop).

Source final legacy transport12, bag0fail, HUD36, economy40, HUDsession45 pass with online edge disabled. Extra RTC19/interpolation38, friends6/member-friends6/invite15, thermal/offscreen0fail pass. Source mock transport initial run was stopped while it inherited production backend selection; no user saves or backend data reset. Retained initial diagnostics; final reruns isolated.

Final packed QA exits0: friends UI6, member-friends UI6, invite notice15, gameplay bag0fail, HUD36 at1280/1024/1600. Viewed packed friend invitation modal and1280 bag/gameplay captures; bottom placement and fish/equipment previews correct. QA used mocked identities/local fixtures and did not send invitations to real users. No physical Android/OAuth/TURN cross-network device test in this task. Desktop ETC2 conversion diagnostics remain. Store screenshots are unchanged in this ordinary update.

Final Console:32(0.1.29) only new bundle, previous31 excluded; Alpha release28 saved/submitted. Review page new-install59.3 MB (+1.38 MB), update917 KB; installed size not shown. Device support unchanged. Optional mapping/native debug symbol warnings only. Publishing overview confirms Lakebound0.1.29 — Friends & Online in Changes in review, quick checks running. Six Early Access changes remain unsubmitted. Managed publishing on; not yet approved or published. Proof exports/play-store/0.1.29-submitted.png. Created IAB Console tab kept open; original Brave tab left untouched after connection timeout.
