# Lakebound 0.1.27 / code 29 — 3 November 2026

Requested ordinary closed Alpha update. Previous 0.1.26 observed available to some testers, published 2 November 03:36. Reused no draft; created Alpha release 26. Early Access six pending changes are outside scope.

Changes: Google PKCE login and account-isolated saves, Supabase ranking, private fishing competitions with quick rooms/time/rule options, exclusive fish claims and shared consumed fish state. Cloud synchronization implementation exists but online.cfg cloud.enabled=false; do not claim enabled cloud backup. No save reset or backend migration performed in this release task. Android OAuth callback bridge is reapplied by export preparation.

Source regression: Google auth/startup, cloud codec/sync, competition/session/transport, Supabase ranking/background ranking/social profile, economy/tutorial, equipment removal, six-map transition, login/competition/gameplay rendering all passed. Additional match options 33, fish ownership 16 and avatar scale 3 checks passed. Isolated profiles; outbound gameplay services disabled for regression.

Limitations: no physical Android OAuth redirect test or simultaneous 2–5 real Google account match in this task. Windows certificate store diagnostic and test teardown leaks remain; no script errors in the completed source suites. Public privacy page is generic (2 October 2026), and current Console policy center reports no issues; Google/Supabase specific disclosure should be reviewed. Existing backend reset/migration work is documented separately and was not rerun.

Submitted to Google review: Alpha release26, original-key code29. Console shows only Lakebound0.1.27 in review with quick checks running; six Early Access changes remain unsubmitted. Managed publishing remains on; approval and publication are not yet complete. Proof: exports/play-store/0.1.27-submitted.png.

Thai release notes:

<th>
เพิ่มการเข้าสู่ระบบด้วย Google และแยกข้อมูลผู้เล่นตามบัญชี
เพิ่มห้องแข่งขันตกปลากับเพื่อน พร้อมตัวเลือกเวลาและกติกา
ปรับระบบอันดับออนไลน์และป้องกันปลาตัวเดียวถูกจับซ้ำในห้องแข่งขัน
</th>

Build correction: initial code28 accepted into Console library but removed from Alpha draft before submission. Found generated release manifest uses mergeOnlyAttributes and drops OAuth callback. prepare_android_auth.cjs now installs a Gradle pre-merge hook to preserve intent children for GodotApp, leaving launcher policy unchanged. verify_release.py now rejects missing callback/exported/singleTask, and correctly rejects initial build. Rebuilt with unused code29. No wrong-key bundle created or uploaded; corrected signing invocation uses original signing directory.

Final artifact: exports/android/lakebound-0.1.27-closed.aab; 85,408,819 bytes (85.408819 decimal MB), +105,454 bytes against0.1.26. SHA25696f2a669afc68c5c409e7262d7b37c32774d463db166ef1ac0ab51fdf6fa85ba. Package com.zylaah.lakebound, name0.1.27/code29, API36/min28, INTERNET/VIBRATE only, original upload certificate confirmed. ZIP/material/remap/exclusion/ARM64 16KB checks and final OAuth callback/exported/singleTask checks pass. Both Gradle tasks report BUILD SUCCESSFUL. Desktop export teardown reports socket bind/StringName diagnostic after successful export.

Extracted3313 exact AAB asset files. Rendered Google startup5 and competition gameplay/session16 assertions pass from final code29 assets; viewed gameplay.png. First run on code28 passed gameplay assertions but capture directory missing; created QA-only directory and final code29 capture and checks succeed. Source suites17 including import, plus3 additional tests, passed. No physical Android test.

Play final review: new-install download58.2 MB (+88.8 KB), unchanged device support. Update download and installed size not shown. Only optional mapping/native symbols warnings. Review table contains only29, previous27 excluded;28 remains library-only and is not in submitted release. Saved and submitted only1 Alpha change. Store screenshots unchanged during this ordinary update.
