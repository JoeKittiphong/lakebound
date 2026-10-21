# Service integration boundary

The game can be played without services. No paid currency is granted from a UI
button, client timer, failed ad request or unavailable product. There is no daily
ad cap in the game. Actual ad availability is provider-controlled.

`CommerceGateway` is deliberately unavailable until a trusted platform adapter is
installed. It is a contract, not an implemented AdMob/Google Play SDK integration.

## Rewarded recovery
1. `request_recovery(recovery_id)` presents a rewarded ad only when SDK reports ready.
2. Bind the ad/server custom data to account + recovery_id and a unique ad event.
3. Server verifies the provider's earned reward evidence. Dismissal, load failure,
   cancellation and network errors are not rewards.
4. Only after verification emit `reward_completed(receipt, recovery_id)`.
5. Profile accepts only the matching current pending recovery and a new receipt;
   one atomic save restores one lure and records receipt, leaving line/fish unchanged.
6. A stale response for an already discarded/different lure must never restore it.

No third-party network calls or SDK permissions are added in this change.

## Diamonds
`request_purchase(product_id)` must use configured Google Play products, validated
account binding, server-side receipt verification, idempotent credit and purchase
acknowledgement/consumption handling. Do not treat a raw client callback as proof.
Emit `purchase_completed(receipt, diamonds)` only for verified successful purchases;
map the diamond quantity from a server-owned product catalog, never client input.
Pending/cancelled/refunded purchases need explicit backend handling.

The local profile's receipt deduplication is a second guard, not a secure ledger.
Client save files are editable. Before real money launches, the authoritative
diamond balance, purchase ledger and reward entitlement must live on the server;
reconcile safely across reinstall, multiple devices, crashes and retries.

## Online Top 10
Not implemented/connected in this milestone. The UI explicitly labels local records
and unavailable online service. A future server must own fish/cast sessions or verify
enough authoritative simulation evidence to reject fabricated weights/catches. Sending
a client-reported weight and checking species limits alone does not prevent cheating.
Records need account, map, species, weight, verified catch ID, actual gear/depth/bait;
query top ten per map and per map/species with a stable tie-break and personal best.

## Launch gates still required
- Create service accounts, IDs/products, backend and trusted verification adapter.
- Add SDKs, app configuration and privacy/consent behavior appropriate to the release.
- Test real Android sandbox purchases, earned/cancelled/no-fill/offline ad cases,
  delayed and duplicate callbacks, restore/reinstall/multiple devices, save failures.
- Test real leaderboard validation, rate limits, authentication and tamper rejection.
- Measure frame time, memory, real touch/safe areas and long-session saves on phones.

No signing keys, provider secrets or server credentials belong in this repository.
