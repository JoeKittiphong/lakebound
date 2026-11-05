# WebRTC in Lakebound

Current default room backend was subsequently moved to Cloudflare: see [competition-cloudflare.md](competition-cloudflare.md). The Supabase signaling/TURN/admission details below remain the legacy rollback path. The native peer transport and platform limitations still apply to both backends.

Implemented 2026-11-03 for the existing Supabase project and Cloudflare TURN app `Lakebound-WebRTC-Lab`. The game uses WebRTC for cosmetic movement only. Supabase still owns Google identity, room admission, synchronized starts, fish ownership and scores. No dedicated game server or local broker is needed to play.

## Runtime

- `online.cfg [webrtc] enabled=true`; `LAKEBOUND_WEBRTC=0` disables the feature for diagnosis. The authored `features/competition/match_webrtc.tscn` owns separate HTTPRequest nodes for signaling and credentials.
- `lakebound-turn` Edge Function validates the Google access token through Supabase Auth, validates profile proof and live room membership through the existing RPC, then returns temporary ICE credentials. Permanent Cloudflare credentials exist only in Supabase Secrets and an encrypted Windows DPAPI lab backup; none are exported with the game.
- Temporary credentials expire after one hour; server cache expires after 55 minutes. Credentials are reused within the same user/room/round. Issuance is serialized with an advisory lock, capped at 200 attempts per UTC day globally and three attempts per user/room/round, with a 60-second retry floor. This limits credential issuance, not arbitrary traffic through an already issued TURN credential; monitor provider usage.
- `lakebound_rtc` is authenticated HTTP signaling. The server stamps sender identity/session rather than trusting a client-supplied sender. Room/round/session boundaries, bounded batches and inbox cursors isolate connections. SDP/ICE messages expire after 90 seconds; registrations expire after 75 seconds. Polling is normally once per three seconds when connected and once per second while negotiating, under the existing RPC limiter. Positions never pass through this signaling table.
- Peers form a mesh within the existing 2–5 player room. Channel: `lakebound-pose`, negotiated ID 0, unordered, zero retransmits. The receiver binds pose ID to the authenticated link, validates pose fields and rejects duplicate sequences across RTC/Broadcast routes.
- When every active member's channel is open, the game sends poses at up to 20 Hz and sends **zero pose Broadcasts**. Remote rendering uses an 80 ms buffer and maximum 200 ms prediction.
- If any channel is unavailable, the game uses the room's existing reserved Broadcast interval, never 20 Hz. After migration 016 new rooms/rematches use two seconds; pre-existing fast rounds keep 334 ms. Rendering switches back to the existing 180 ms buffer/450 ms prediction. Failed/stalled links get fresh signaling sessions, bounded to three restarts per round. A superseded login stops fighting the new session.
- Migration 016 expands admission to four rooms/twenty players and reserves fifteen events/sec for each new round's two-second fallback. Historical reservations remain intact and a legacy fast room blocks extra rooms until it ends/rematches. See [capacity plan and usage limits](competition-capacity.md); 300 monthly users is a planning target, not unlimited free play.

## Platform support and limits

The official `godotengine/webrtc-native` 1.2.1 GDExtension is vendored under `addons/webrtc_native`, including third-party license notices. Windows native is tested with Godot 4.7.2. The package includes Android libraries; actual Android devices and the deployed Web/PWA have not been validated in this change and no store/web release was published.

The upstream native build uses libjuice and does **not** support TURN TCP/TLS. Its native ICE config therefore retains STUN/UDP TURN endpoints only. The browser implementation retains TCP/TLS endpoints too. Networks blocking UDP may fall back to the existing Supabase transport on native. Native logs can show Cloudflare TURN permission warnings while candidate probing even if a direct connection succeeds; those warnings are not proof of a successful TURN relay. Upstream configuration was checked in https://github.com/godotengine/webrtc-native/blob/1.2.1-stable/src/WebRTCLibPeerConnection.cpp .

## Deployed services

- Migration `202611030015_match_webrtc.sql`: private peer/session signaling tables, private temporary credential cache, authenticated signaling RPC and service-role-only cache RPC. Migration `202611030016_match_capacity.sql` is also deployed: four rooms/twenty seats, reduced fallback reservation and owner-only capacity report. Existing rooms, fish and scores are retained.
- Edge Function `lakebound-turn` is deployed in `efxjvrywbivyolluvuyp` with custom auth enabled in the handler. The legacy-JWT-only gateway setting is off as recommended for this custom-auth handler; unauthenticated users still fail inside the handler before any Cloudflare request.
- Secrets: `LAKEBOUND_CF_TURN_KEY_ID`, `LAKEBOUND_CF_TURN_API_TOKEN`, `LAKEBOUND_PUBLISHABLE_KEY`. The function uses the existing built-in server role only on the server for private cache access.
- Rollback: set `[webrtc] enabled=false`, restart clients. Existing Broadcast transport and all authoritative game RPCs remain available. Do not delete the private cache/peers while clients are actively using them.

## Validation

- Database: 181 checks passed, including sender spoofing rejection, outsider denial, round/session isolation, private table/function permissions, issuance tickets and cache reuse, plus original fish/score rules.
- Edge Function: mocked HTTP-contract test verifies RPC argument wrapping, Google/room checks, cache reuse, temporary-only response and unavailable-secret behavior. Live Google account requests also verified successful issuance after deployment.
- Game RTC suite: 19 checks passed using a five-player native mesh (twenty directed DataChannels), including bound player ID, 20 Hz route selection, zero duplicate Broadcast poses, both reserved fallback intervals, native UDP filtering, browser TCP preservation and bounded reconnect.
- Other affected client suites: interpolation 38, options 33, session 19, transport 12, fish ownership 16 passed.
- Live end-to-end: two saved Google accounts joined and started a real round through Supabase, negotiated native DataChannels via the deployed signaling RPC and obtained ICE credentials via the deployed Edge Function. Each sent/received 96 RTC poses, selected a 0.05 s send interval, with no service error. There were 16 received Broadcast poses during startup negotiation. Reports: `exports/qa-two-player/rtc-player1.json`, `rtc-player2.json`.
- Final live rerun: 95/96 RTC poses received by the two accounts, zero received Broadcast poses and no service error. The second endpoint returned to the 334 ms fallback when the first probe exited, as expected. The reports above contain this latest run.
- Cloudflare forced-relay browser test: both sides reported `relay ↔ relay` and exchanged over 78,000 packets. Both lab sessions were then stopped. This proves actual Cloudflare TURN service, separately from the same-machine native game's direct-link test. It does not replace a native cross-network/mobile test.

Commands:

```powershell
node services/supabase/test_matches.cjs
node --test services/supabase/test_turn_function.cjs
node tools/test_competition.cjs match_webrtc match_interpolation match_options competition_session competition_transport match_fish
```

The opt-in `tests/match_rtc_live_probe.gd` uses real saved Google accounts, joins/starts an actual round and leaves it available to resume. Only run with `LAKEBOUND_RTC_LIVE_PROBE=1`, separate APPDATA per account and `LAKEBOUND_WEBRTC=1`. It never submits fish catches or changes economy progress. `LAKEBOUND_MOTION_DEBUG=1` prints bounded route/gap metrics without credentials.
