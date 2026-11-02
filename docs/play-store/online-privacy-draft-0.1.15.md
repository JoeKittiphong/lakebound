# Lakebound — online privacy disclosure draft

Draft for owner review; not published. Confirm contact, retention, deletion process, backups and Cloudflare practices before publishing.

Lakebound's optional online leaderboard sends your chosen display name, a randomly generated player ID, an authentication token and selected best catch statistics to the developer's server over HTTPS. Catch statistics include fish species, fishing region, weight, time and an event identifier. Your display name and ranked catch statistics can be visible to other players. Cloudflare provides the HTTPS tunnel and may process connection data, including IP addresses, according to its own practices. The server uses IP addresses for rate limiting. The server stores a hash of the authentication token rather than the token itself.

Other progress remains on your device; online leaderboard synchronization is not a full cloud backup. A player can continue playing offline when the server is unavailable. Data stored on your device can be removed through Android app settings; this does not automatically remove data already uploaded to the server.

[OWNER TO CONFIRM: retention period for leaderboard data, logs and backups; a working method and contact address for users to request deletion of their online data; how requests are verified and handled; any other recipients or data processing.]
