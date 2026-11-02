# Google Sheets ranking API

Status: deployed as a public Web App and configured as the default in online.cfg.
Live GET/POST and Godot HTTPS checks passed; a 100-client read burst passed 100/100
on the empty leaderboard. See docs/sheets-live-http-results.md for measured limits.
Integration fixtures run separately from production rankings. Real guest credentials
are never stored in source. Client-supplied statistics remain provisional.

Run `node services/google_sheets/test-ranking.cjs` from the game project.
Tests use in-memory Google service doubles; they do not contact Google.

## Ranking reads

`GET <exec-url>?scope=all&limit=10&format=compact`

Scopes: `all` or a map ID. Limits: 10, 50, 100.
The default is compact schema 3: `{schema:3,version,rows}` only. Global row fields
are `[player_id, player_name, map_id, species_id, weight_g]`; map row fields are
`[player_id, player_name, species_id, weight_g]`, since the requested map is known.
The game resolves fish/map display names from its own catalogs. Rank is the row
index plus one. Weight is integer grams. No catch IDs, catch times, credential
hashes, repeated field labels, update times or duplicate scope metadata are sent.
Store each response locally by scope and limit.
When requesting it again, add `version=<previous-version>`. A matching version
returns `{version,not_modified:true}` without ranking rows.
Only send a version if the client still has that exact view's cached rows.
Wait at least 300 seconds before checking again; do not poll per frame.
Use exponential backoff on network failures and `busy_retry` responses.

Explicit `format=full` preserves the original object-row response for debugging.
Per-view content versions stay stable when an edit does not affect that Top N.
The game consumes this protocol through SheetsRankingSync. It accepts only exact
Google /exec URLs. Custom Python/SQL endpoints and their client branch were removed
on 28 October 2026; valid saved Sheets URLs still migrate from the old setting.
The game displays a bounded persisted ranking cache immediately, clearly labeled
as cached while refreshing. Score-free viewers use public GET without registering
a guest. Only requests that actually upload scores or update a ranked name use POST.
Deployed version 2 adds a single-CacheService-read head (30s TTL) for hot GETs;
successful uploads bypass it when returning their freshly recomputed ranking.
See docs/sheets-latency-optimization.md for actual timings and the remaining
>3-second P95 under the 100-request burst.

## Score uploads

`POST <exec-url>` with JSON body:

```json
{
  "player_id": "32 lowercase hexadecimal characters",
  "token": "64 lowercase hexadecimal characters",
  "player_name": "Name on registration or name change only",
  "catches": [
    ["river", "tilapia", 2500, 1793145600, "stable-catch-id"]
  ]
}
```

Upload rows are `[map_id, species_id, weight_g, caught_unix_seconds, catch_id]`.
The name is looked up in the server catalog, never uploaded. Object-form catch
rows remain accepted for compatibility, but supplied fish names are ignored.
Upload at most 100 unacknowledged improvements per batch; first sync may need
several batches. Keep one best record per map/species. Retain pending records
until `{ok:true}` and acknowledge only the records actually sent, so a newer
catch made during upload remains pending. Do not upload again merely because
the user changes ranking filters. With no pending scores or name change, skip
POST entirely. Retries are safe: equal or worse scores do not cause writes.
An upload acknowledgement is exactly `{"ok":true}` (11 UTF-8 bytes), with no leaderboard.
Keep tokens in POST bodies over HTTPS, never URLs or public spreadsheets.
Token digests authenticate returning guest IDs; they do not prove score validity.
Unknown species are rejected against the complete 105-species game catalog. Regenerate
LB_SPECIES from game resources when adding species. There is no account recovery,
server-side catch simulation or public abuse rate limiter in this prototype.

## Refresh and recovery

Run `setupLeaderboard` once after granting Google permissions. This formats the
sheet. The Web App uses SpreadsheetApp.openById, which requires the broader
Google spreadsheets scope; the code only opens the ID saved during setup.
Review that permission before granting it. Setup also
installs the five-minute refresh trigger. `onEdit` marks human edits
in Players/Scores dirty. Programmatic writers must call `markLeaderboardDirty_`
under the same script lock as their writes, as `doPost` does. The six-hour audit
also detects changes made externally without that hook. Run `rebuildLeaderboard`
to force a scan immediately after manual maintenance or row deletion.

Idle timers do not read or write Sheets. Changed inputs are scanned in batches;
only changed ranking views are rewritten. CacheService is optional; an evicted
snapshot reads one API_Cache row. Its two fixed slots per view bound durable
storage to 42 data rows. The `snapshot_manifest` Script Property selects active
rows: do not assume the last row or newest global version selects every view.
It is published only after all changed snapshots and ranking sheets are written.
Do not edit API_Cache or snapshot_manifest manually. Keep the entire spreadsheet
private, including Players and token_hash. Deployment must expose only the
intended Web App API, never the spreadsheet or script properties.

## Integration checks

`testLeaderboardIntegration` creates a separate Google Sheets QA workbook and
runs the actual POST/GET handlers against it. It tests real Sheets persistence,
duplicate/worse uploads, invalid input, wrong tokens, cross-map bests, descending
order, player uniqueness, Top N prefixes and agreement between sheet rows and
API output. Its temporary property state is isolated from production. The QA
workbook is retained and its URL is logged for review. This is an integration
test of handlers and Google Sheets, not an HTTP test of a deployed Web App.

Local tests additionally count Sheets calls and verify cache eviction, write
failures, stable versions, source-row reordering and blank gaps.
Numeric-looking identifiers are escaped as spreadsheet text to preserve leading
zeroes. Timestamp comparisons handle both ISO strings and native Sheets Dates.
Ranking refresh reads only the two public player columns and seven score columns;
token hashes and administrative update times are not read into ranking builds.

Live integration run passed against the isolated QA workbook:
https://docs.google.com/spreadsheets/d/1g5cq6AF_ZlmaAInAAcko7Yi80BmaMX_TWXmtpPkzQto/edit

For the local fixture, full Top100 was 15,581 UTF-8 bytes; schema 3 was 4,236
bytes (73% smaller). Unchanged response: 56 bytes. One authenticated object-form
upload was 257 bytes versus 184 bytes as a tuple (28% smaller). These are JSON
body sizes for the test fixture, excluding HTTP/TLS overhead; actual names,
IDs and batch lengths change the result.

Cache limits: https://developers.google.com/apps-script/reference/cache/cache

For a board-open request, include `query: {scope: "river", limit: 10, version: "optional-cache-version"}`
alongside the score upload. After committing and releasing the write lock, the
handler refreshes changed snapshots and returns the compact ranking in that same
response. With no new score/name, the game uses a read-only GET instead.
See `docs/bounded-history-and-ranking.md` for retention, deferred synchronization,
test coverage and the distinction between 100 requests and Apps Script execution limits.
