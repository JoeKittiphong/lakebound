# Motion debug findings and next implementation plan

2026-11-03: Current editor-run game processes started 18:11:29, after remote_angler.gd was changed at 18:10:14. Older exports/qa-two-player logs contain startup messages only and do not establish current live motion behavior. No live packet telemetry has yet been collected.

Diagnostic: node tools/test_competition.cjs match_motion_debug uses actual RemoteAngler at 60 FPS, 3 m/s, zero latency/loss, two-second sends. Six-second replay results:

| Scenario | Maximum position error | Mean error |
| --- | ---: | ---: |
| Straight constant speed | 0.00 m | 0.00 m |
| Stop at 0.5 s | 4.50 m | 0.75 m |
| Turn 90 degrees at 0.5 s | 6.36 m | 1.06 m |

These are synthetic results, not measurements of live users. They demonstrate a defect even before real jitter: long unobserved direction changes plus long prediction produce overshoot and correction. Previous tests covered constant speed and arrival of stop packets, but missed the unobserved interval before the next stop/turn packet. Session sending also ignores a speed-only change at unchanged position/yaw, so a stop at a sampled point can be suppressed until idle heartbeat.

Proposed implementation (not applied yet):

1. Add opt-in bounded motion tracing: actual send/receive interval, accepted sequence, speed/velocity, prediction age, correction distance and reset reason. No auth tokens, names or packet bodies. Capture a two-client walk-stop-turn session and replay its timing.
2. Increase movement updates to 3 Hz (333 ms), retaining sparse stationary heartbeat. Include speed changes in dirty detection so a stop cannot be suppressed. One rate limiter owns the interval across service/session; use room policy instead of duplicated two-second constants. Coalesce changes until the next permitted tick.
3. With tighter timing, replace long 2.2-second prediction with a short interpolation window approximately 150–250 ms and capped prediction approximately 350–500 ms for underruns. Tune from recorded arrival jitter. Preserve velocity, short yaw arc, immediate spawn/teleport, and animation speed independent from correction offsets.
4. Update capacity admission BEFORE enabling 3 Hz. Conservative Supabase send+fanout estimate at five players is 5*5*3=75 events/sec per full room versus 12.5 at 0.5 Hz. Current four-room budget is incompatible with that rate. Start with ONE active room at five players, reserve control headroom and revise rolling event reservations (for example 90 events/sec including margin, instead of current 15 per room). Validate current provider limits/account usage before choosing final numbers. Existing reservations must remain accounted for; do not refund or rewrite past usage. Room snapshot must carry revised rate. This trades concurrency for responsiveness and increases monthly quota consumption.
5. Verify irregular stop/turn between sends, variable FPS, latency/jitter, loss, delayed/out-of-order packets, prolonged idle then walking, strafe, blocked movement and reconnect. Assert bounded position error/correction speed and outbound event budgets, then manually compare two live clients using telemetry. Passing constant-speed tests alone is insufficient.

If four simultaneous five-player rooms must remain available on the same Free Realtime budget, 3 Hz is not compatible with the conservative event estimate. Alternatives require a plan upgrade, lower concurrent capacity, or a different movement transport; this is a product tradeoff rather than an interpolation tuning parameter.
