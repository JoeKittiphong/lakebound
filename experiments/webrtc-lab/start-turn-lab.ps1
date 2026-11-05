# Run locally after enabling Cloudflare Realtime TURN. Never paste tokens into chat.
$ErrorActionPreference='Stop'
$rtcKeyId=Read-Host 'Cloudflare TURN Key ID'
$rtcToken=Read-Host 'Cloudflare TURN API token (hidden)' -AsSecureString
$rtcPreviousId=$env:LAKEBOUND_CF_TURN_KEY_ID
$rtcPreviousToken=$env:LAKEBOUND_CF_TURN_API_TOKEN
try {
 $env:LAKEBOUND_CF_TURN_KEY_ID=$rtcKeyId
 $env:LAKEBOUND_CF_TURN_API_TOKEN=[System.Net.NetworkCredential]::new('', $rtcToken).Password
 node (Join-Path $PSScriptRoot 'server.cjs')
} finally {
 $env:LAKEBOUND_CF_TURN_KEY_ID=$rtcPreviousId
 $env:LAKEBOUND_CF_TURN_API_TOKEN=$rtcPreviousToken
 $rtcToken.Dispose()
}
