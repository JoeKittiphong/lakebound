# Automatic catch sync and minimap leader

Implemented 2 November 2026, following the Supabase migration.

## Player behavior

- Each newly saved catch queues an immediate Supabase check, with the Ranking
  panel closed or open. Failed local saves and duplicate catch delivery never
  trigger an upload. Coin/inventory changes do not trigger ranking requests.
- Improved best records are uploaded; smaller catches perform a public ranking
  check without resending scores or guest credentials. The database remains a
  best-record leaderboard, not an unbounded log of every fish.
- Requests run asynchronously, one at a time. Catches arriving while a request
  is running queue a follow-up against the newest saved bests. Acknowledging an
  older catch cannot acknowledge a newer one accidentally.
- Network failures retain work, mark cached leaders and retry with backoff up
  to 60 seconds. Pending improvements survive closing the app because the local
  profile is the durable outbox. On next startup the service resumes from it.
- Each map entry fetches its leader. While that map's HUD is present, a timer
  checks every 60 seconds for changes by other players. Each local catch checks
  immediately. This is event-driven HTTP plus a bounded refresh, not a Realtime
  subscription or a request every frame.
- The card below the minimap shows the map's number-one player and weight.
  Cached data is labelled `แคช`; a failed first fetch is distinct from an empty
  leaderboard. Tapping the card opens that map's Ranking panel. Gameplay resumes
  when it closes. The mission tracker sits beside the card to avoid overlap.

## Ownership and editable scenes

`AnglerProfile.catch_recorded` fires only after a new catch's profile commit.
`RankingOnline` is an Autoload of `features/social/ranking_online.tscn`; it survives
scene changes and processes network/timer events while the game is paused. Its
HTTP response limit, disabled redirects, retry timer and refresh timer are saved
in the scene. Refresh interval and retry base are exported on its script.

The service owns background `RankingSync` and dedicated
`user://supabase-background-{sync,views}.cfg` files. It never rebuilds an in-flight
batch's pending signatures. `SocialPanel` uses public reads when the service is
active, with its own view cache, and refreshes when an upload completes. Its old
upload path remains a fallback when background synchronization is disabled.
Changing connection settings also updates the persistent service.

Open `features/social/map_leader_badge.tscn` to edit the card's colors, typography
and contents. It is instanced as `SafeArea/RankingButton` in
`features/fishing/fishing_hud.tscn`, below `Minimap`. Adjust that instance for
position/size and `SafeArea/MissionTracker` for the neighboring mission panel.
The label hierarchy is authored and visible before running the game.

## Verification

- `background_ranking`: 20 checks passed, including closed-panel automatic
  upload, smaller-fish check, coalescing concurrent catches, offline retries,
  latest-best acknowledgement, failed save, duplicate event, restart recovery,
  map switch, separate map caches and stopping periodic reads on HUD exit.
- `map_leader_visual`: layout, real touch input through label children, current
  map selection, pause/resume, empty/error/cache states passed at 1280×720,
  1600×720 and 960×540. Initial mission overlap was corrected and retested.
- `background_ranking_live`: actual Supabase HTTPS map-leader read and binding
  of the real leader's name/weight passed without opening Ranking. The QA
  profile had no catches and was not registered or uploaded.
- Existing `supabase_live_http`, `supabase_ranking_sync`, `catch_settlement`,
  `social_lifecycle`, `compact_hud` and `hud_session` checks passed.

Artifacts: `exports/qa-background-rankings/{service,visual-final,live,initial}/`.
The offline test runner sets `LAKEBOUND_BACKGROUND_SYNC=0` so fixtures cannot
upload to production. Tests that exercise the service explicitly enable it and
use a mock transport or a score-free public read. Live checks require outbound
HTTPS; sandbox-only runs may report host certificate/signing-folder diagnostics.

No physical Android validation or new AAB export was performed. Installed builds
need an updated client to gain automatic catch events and the new HUD; the
previous Apps Script compatibility bridge cannot add these client behaviors.
