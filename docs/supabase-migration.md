# Google Sheets → Supabase migration

Completed 2 November 2026 (Asia/Bangkok). The new game source reads and writes
Supabase directly. Already-installed games reach the same database through the
existing Apps Script URL, now deployment version 3. No Android release was built
or submitted as part of this change.

Subsequent client update: [automatic catch sync and minimap leader](background-ranking-sync.md).

## Scope and design

Google Sheets held guest identities and leaderboard best catches, not the entire
player save. Move that online boundary while retaining local inventory, money,
progression, collection and offline gameplay. No save reset, new login screen,
Gmail requirement or replacement guest ID is introduced.

| Component | Responsibility |
| --- | --- |
| `social_panel.tscn` / `social_panel.gd` | Authored UI, HTTP lifecycle, retry/backoff and map/Top N selection |
| `ranking_sync.gd` | Delta batches, safe RPC body, durable acknowledgements and bounded view cache |
| `supabase_connection_settings.gd` | Exact HTTPS RPC endpoint validation; old Sheets overrides are ignored |
| `ranking_snapshot.gd` | Shared validation for wire responses and persisted cache |
| `lakebound_private.players` | Original guest ID, name and compatible token hash; no public table access |
| `lakebound_private.scores` | Best catch per player/map/species, integer grams and deterministic tie breaks |
| `public.lakebound_rankings` | Public bounded reads and authenticated transactional uploads |
| Apps Script bridge | Compatibility for installed clients; no gameplay writes to Sheets |

The client contains only a publishable key. Private tables have RLS and no grants
to API roles. Guest authentication remains compatible with the previous
SHA-256(JSON-stringified-token)/padded-base64url digest. Each guest's writes are
serialized independently; a bad row rolls back the whole batch. Query bounds,
catalog membership, weight, timestamp and response limits are enforced.

## Plan and execution

1. **Inventory and backup:** traced every runtime Sheets dependency; located the
   production workbook rather than importing a QA workbook. Saved the original
   Apps Script source and two XLSX snapshots in ignored `services/supabase/.local/`.
2. **Database:** created Lakebound on the existing Free organization in Singapore,
   with automatic RLS enabled and automatic table exposure disabled. Applied the schema,
   RPC and 105-species catalog. Kept writes gated during import.
3. **Import:** preserved **17 player identities** and merged **339 source score
   rows into 329 best records**. Ten repeated player/map/species rows were merged
   by best weight/time/catch ID, with every source row retained in the backup.
   SQL import is atomic and repeatable and refuses credential replacement.
4. **Client:** switched `online.cfg` and runtime networking to Supabase RPC;
   removed the Google redirect path and old runtime classes. Public reads omit
   credentials; uploads retain batching, idempotent retry, cache and local saves.
   Separate cache/ack files trigger a safe first upload after upgrading.
5. **Compatibility and activation:** deployed the bridge at the unchanged old
   URL. Google initially required external-request authorization; the owner
   completed it and the read-only health check passed. The user chose to keep
   version 3. Took a final frozen Sheets snapshot, re-imported, checked exact
   counts and enabled writes in the same transaction. Both routes now share data.
6. **Verification:** completed the checks below, including real anonymous-role
   writes in a rolled-back production transaction. Confirmed fixture absence.

## Results

| Check | Result |
| --- | --- |
| Disposable PostgreSQL migration/RPC/security suite | 29 checks passed |
| Bridge tests | Read/write forwarding, no redirects, validation and error mapping passed |
| All boards vs independent source calculation | 21/21 match: 7 scopes × Top10/50/100 |
| Conditional cache versions | 21/21 passed |
| Read burst | 30/30 passed with 10 workers; maximum 266 ms in this run |
| Direct HTTP median | 172 ms across 21 serial board reads; not a sustained-load SLA |
| Direct and legacy live APIs | Same board; both rejected a wrong token for an imported identity |
| Web | JSON/apikey CORS preflight passed |
| Real production write smoke | Upload, duplicate, wrong token and catch conflict passed; rollback left no fixture |
| Godot 4.7.2 real HTTPS, headless | First board 753 ms; local cache open 16 ms; conditional/map/Top100 passed |
| Godot 4.7.2 real HTTPS, Mobile renderer | First board 389 ms; cache open 18 ms; conditional/map/Top100 passed |
| Godot offline suites | Settings, delta sync, snapshot validation, profile, lifecycle, map ranking, cache, visual settings, social UI, HUD checks passed |
| Layout | Inspected rendered ranking at 960×540; bounds checks also covered 1280×720 and 1600×720 |

Updated stale test assumptions about TabBar's API, catalog map titles and closing
the profile panel; the actual Play action still requires a name. Initial sandbox
runs emitted host certificate-store/signing-directory diagnostics; real HTTPS and
rendered checks ran successfully outside that restriction. No physical Android
device, release AAB or server-side anti-cheat simulation was tested or added.

Evidence: `exports/qa-supabase/{regression,final,recheck,live-godot,live-render}/`,
private `.local/live-results.json`, and the production SQL verification result:
**17 players, 329 scores, 105 species, writes enabled, QA fixture absent**.
See [service contract and recovery](../services/supabase/README.md).

## Operations

Open [the Supabase project](https://supabase.com/dashboard/project/efxjvrywbivyolluvuyp)
for live data. The original spreadsheet is now a backup snapshot; it is not the
current ranking source. Do not import stale names over newer Supabase edits or
switch version 2 back on without reconciling post-cutover data. To change game
appearance open `features/social/social_panel.tscn`; online project configuration
is in `online.cfg`. Keep server credentials out of exported resources.
