# Lakebound 0.1.16 — server connection fix

Signed AAB version code 17 uploaded and accepted as Alpha release 16 on 27 October 2026. Submitted the single release change; publishing overview confirms Changes in review. Managed publishing remains enabled; not yet published.

## Problem and fix

The server was restarted with a new Quick Tunnel URL. The existing 0.1.15 bundle contains `https://playlist-hosting-andy-producers.trycloudflare.com`, which no longer reaches the running server. The newly prepared bundle points to `https://friendship-donate-ecological-write.trycloudflare.com`.

The ranking screen now includes **การเชื่อมต่อ**. Players can replace the server's HTTPS origin URL and press **บันทึกและเชื่อมต่อ**. The override is saved atomically in `user://server_connection.cfg` and restored when the screen is reopened; it does not replace the profile, guest token, inventory, or catches. DNS failures, timeouts, TLS errors, authentication failures and HTTP errors now have distinct messages.

Existing installed builds cannot acquire this UI by changing files on the computer. Install the new version through the same app distribution channel. Do not uninstall the game or clear its data to change server addresses. Quick Tunnel URLs remain temporary; a stable public endpoint is still needed for long-term releases.

## Artifact

- `exports/android/lakebound-0.1.16-closed.aab`
- 88,517,515 bytes (88.52 MB archive, 84.42 MiB); Play download estimate not available
- SHA-256 `2554e49823b29295fb63a970f584bdaeecabae5dabed92907a043906f8f3aa28`
- Package `com.zylaah.lakebound`, code 17, target SDK 36 / min SDK 28
- Permissions INTERNET and VIBRATE; current endpoint and settings script included in the bundle
- Original upload certificate SHA-256 `22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7`

## Verification

Server settings tests: URL validation, fallback to packaged configuration, durable override, rejecting bad updates without replacing the previous URL, endpoint dialog behavior, identity preservation, applying settings and using them in a new panel instance.

Rendered and inspected settings at 1280×720 and 960×540. Godot's actual client registered a temporary QA guest, sent a catch, received own rank and fetched map-filtered results through the public HTTPS endpoint; offline fallback also passed. AAB ZIP, same-build XML manifest, ARM64 16 KB ELF alignment and public signing certificate checked. `exports/validation-0.1.16.json` contains the artifact verification report.

No physical Android device or Play validation performed. The editor import still emits the existing MultiMesh resource setup diagnostics; the new scripts parse and focused tests pass.

## Thai notes

แก้ไขการเชื่อมต่อกระดานอันดับ เพิ่มหน้าตั้งค่าที่อยู่ server และข้อความแจ้งสาเหตุเมื่อเชื่อมต่อไม่ได้ สามารถเปลี่ยนที่อยู่ server ได้โดยเก็บข้อมูลผู้เล่นและประวัติการตกปลาเดิมไว้


Play submission verification: original certificate rechecked and file SHA256 matched the prepared report. Actual packed menu/social UI differs from 0.1.15 and includes server_connection_settings.gdc. Play download estimate 62 MB (+137 KB); update estimate 866 KB. Only optional mapping/native symbol warnings. Proof: exports/play-store/0.1.16-submitted.png.

