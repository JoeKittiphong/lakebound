# Lakebound Supabase rankings

Google accounts/matches and the fresh player reset are deployed (2 November 2026).
Migrations 003–006 are installed. The reset backed up 18 players / 412 scores and
emptied the active tables; do not rerun it. See [live verification](../../docs/google-login-live-2026-11-02.md).
006 deliberately rejects writes from guest-only legacy builds. Public boards
remain readable; writes require Authorization: Bearer with a Google Supabase JWT
and the matching account-owned profile proof. Do not rerun 001 over the wrappers.

Active project: `efxjvrywbivyolluvuyp`, Singapore, Free plan. Production cutover
completed 2 November 2026. See [migration plan and verification](../../docs/supabase-migration.md).

The Godot client calls `POST /rest/v1/rpc/lakebound_rankings` with `apikey` set
to the **publishable** key in `online.cfg`. Never put a database password,
secret key, service-role key, or management token in a game export.
The legacy Apps Script endpoint still proxies this RPC for reads. Guest-only
installed builds cannot upload after the Google account reset and need the new client.

## Protocol

Read without transmitting a guest identity:

```json
{"payload":{"query":{"scope":"all","limit":10,"version":"optional-cached-version"}}}
```

Authenticated upload (the token stays in the HTTPS body):

```json
{"payload":{"player_id":"32 lowercase hex characters","token":"64 lowercase hex characters","player_name":"Name on first sync or change","catches":[["river","tilapia",2500,1700000000.123,"stable-catch-id"]],"query":{"scope":"river","limit":50}}}
```

At most 100 catches per batch. `query` is optional for intermediate upload
batches. Upload-only acknowledgement: `{"ok":true}`. Ranking response:
`{schema:3,version,rows}`; unchanged view: `{version,not_modified:true}`.
Global rows: `[player_id,name,map,species,weight_g]`; map rows omit `map`.
One best catch per player in each board, ordered by weight descending, time
ascending, player ID and catch ID; map/species resolve remaining exact ties.
Only limits 10, 50 and 100 and the six catalog maps or `all` are accepted.
Weights are integer grams, times have millisecond precision. Scores remain
client-reported, as they were before this migration.

## Database and deployment

Apply `migrations/*.sql` in order in the SQL Editor, as the database owner.
The first migration deliberately starts with writes disabled. Tables are in
`lakebound_private`, with RLS enabled and no API role schema/table privileges.
Only the bounded `public.lakebound_rankings(jsonb)` security-definer RPC is
executable by `anon`/`authenticated`; its fixed empty search path prevents
object shadowing. Keep `lakebound_private` out of exposed Data API schemas.

`players` preserves the original guest ID and Apps Script token digest.
`scores` has one row per player/map/species, foreign keys and bounded values.
`species` is the 105-ID game catalog. `control.writes_enabled` gates cutover.
The RPC authenticates a returning guest before changing their name or scores,
serializes concurrent requests for that guest and commits a whole batch
atomically. Duplicate and worse catches are harmless; errors do not acknowledge
an upload. A separate bounded local cache/acknowledgement namespace makes each
upgraded client re-send its best records once, without changing the player save.

To import a private XLSX backup using the bundled Python runtime:

```text
python services/supabase/import_sheets.py <backup.xlsx>
```

Run the generated `.local/import.sql` as owner. It validates IDs, names,
digests, references, grams and times, merges repeated map/species rows using the
same best-catch order, refuses credential replacement and does not lower newer
scores or overwrite a newer name. The transaction and source SHA-256 manifest
are private local artifacts; `.local/` is ignored and services are excluded
from Godot exports by `services/.gdignore`. Retain the original XLSX as backup.

For a future full cutover: disable writes, deploy the legacy bridge, take a final
Sheets export after old writers stop, import it, compare counts and every board,
then set `lakebound_private.control.writes_enabled=true`. Do not reopen fresh
guest registration before original identities are imported. Existing pending
catches remain in players' local saves while writes are gated.

`build_bridge.py` builds `.local/deploy_bridge.gs` from the private source backup
(or the preserved `google_sheets/Code.gs`) plus `legacy_bridge.gs` and public
configuration. Update the existing Apps Script deployment, keeping its URL,
execute-as owner and existing audience. The owner must authorize Google's
external-request permission once. `checkSupabaseConnection` performs a safe
read-only check. Production is deployment **version 3**, with that authorization
completed. The diagnostic helper is also available in the current editor source.

## Verification

```text
node services/supabase/test_database.cjs
node services/supabase/test_bridge.cjs
python services/supabase/verify_live.py <backup.xlsx>
python services/supabase/verify_cutover.py
python tools/run_tests.py --godot <Godot-console.exe> --tests supabase_settings supabase_ranking_sync ranking_snapshot social_lifecycle social_profile
python tools/run_tests.py --godot <Godot-console.exe> --tests ranking_maps cached_ranking social_visual supabase_settings_visual --rendering-method mobile
python tools/run_tests.py --godot <Godot-console.exe> --tests supabase_live_http
```

The PostgreSQL test starts/stops a disposable loopback cluster, never an installed
database service. Set `PG_BIN` when PostgreSQL is installed elsewhere. Read-only
network tests use `online.cfg`; the Godot live test defaults to its packaged URL,
with optional `LAKEBOUND_QA_URL`. Runner profiles are isolated from real saves.
`live_transaction.sql` tests real production writes under `anon` inside a
transaction that always rolls back, then confirms no fixture remains.
Do not commit or manually omit the rollback during a production smoke test.

## Recovery

Keep both private source backups and the original spreadsheet. Setting
`writes_enabled=false` pauses uploads without losing local pending records.
Before changing active service back to Sheets, reconcile post-cutover Supabase
data first: the archived sheet no longer receives new gameplay writes. Restoring
Apps Script version 2 alone would create divergent boards. A release/package
rollback is separate from a data rollback. Do not delete the Supabase project,
reset identities or replace token digests to address a connectivity problem.

References: [database functions](https://supabase.com/docs/guides/database/functions),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
