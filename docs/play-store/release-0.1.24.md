# Lakebound 0.1.24 — Map Crash Fix

1 November 2026: original-key code25 accepted as closed Alpha release24 and submitted. Console confirms Alpha0.1.24 alone in review (quick checks running). Six Early Access changes remain unsubmitted. Managed publishing is on, so approval still requires publishing. Proof: exports/play-store/0.1.24-submitted.png. Previous0.1.23 observed published1 November06:17 and available to some testers.

## Changes

Includes the missing line-material fix documented in ../android-map-crash-materials.md: realme RMX3840 Android16 Play0.1.23 reported missing braid.tres immediately before VkThread SIGSEGV. DetailedReelVisual now preloads all four materials and guards failed duplication. Also includes MultiMesh reload serialization fixes preserving authored plants and runtime GDScript warning cleanup. No save reset, renderer/ABI, countries, tester or Early Access changes.

## Artifact and Play sizes

- exports/android/lakebound-0.1.24-closed.aab
- 81,233,009 bytes (81.23 decimal MB), +1,161,361 bytes versus0.1.23 (80,071,648 bytes).
- SHA256: d00476237c56e0c3d0a16389696b914114378c6467004d16191f3ad0ebba7fb2
- Original upload certificate: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- Play new-install estimate54.2 MB (+1.2 MB), update1.92 MB; installed size not shown.
- No device support losses/additions reported relative to previous release. Optional mapping/native debug-symbol warnings only.

## Verification and limits

Build successful, no script/resource errors. Exact-AAB verifier passes package/version25/API36/min28, INTERNET+VIBRATE only, ZIP integrity, secrets/test/docs exclusions, ARM64 16KB alignment, and all four line-material resources/remap targets. Same-build manifest supplied and public certificate confirmed with keytool. The material check was corrected to inspect both base/assets and assetPackInstallTime/assets, while preserving failure for missing materials/targets.

Source renderer tests: equipment_catalog481, multimesh_reload6216, missions76 checks (6773 total), zero failures, no script errors. Exact signed AAB extracted2640 files for desktop D3D12 Mobile QA: all eight reel families with all four materials, then all six maps with braid equipped (76 checks); menu-to-map navigation, old scene cleanup and retry/back failure behavior (26 checks). All102 exact-package assertions pass and both processes exit0. Logs: exports/qa-0.1.24/*.log. Only host Windows certificate diagnostic and desktop ETC2 conversion warnings remain.

Separately recorded isolated debug APK QA passed76 checks on physical RMX3840 Android16, Vulkan Mobile/Adreno710, using the same material fix (workspace output/android-map-crash/device/qa_run.log). That is not a test of a Play-installed0.1.24 build. No new installation on the user's phone, save clearing or live-endpoint QA was performed in this release task.

## Thai release notes

<th>
แก้ทรัพยากรสายเบ็ดที่ขาดซึ่งทำให้เข้าแผนที่ไม่สำเร็จในบางกรณี
ปรับความเสถียรของการโหลดฉากและพืชประกอบแผนที่
</th>