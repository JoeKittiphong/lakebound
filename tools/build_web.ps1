param(
    [string]$Godot = 'C:\Users\Zylaah\programmer\godot\Godot_v4.7.2-stable_win64_console.exe',
    [string]$Python = 'C:\Users\Zylaah\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'exports\web'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'exports/cleanup-qa') | Out-Null
# Global script classes and runtime-loaded scenes must be included in each build.
& $Godot --headless --editor --path $projectRoot --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Web import failed.' }
& $Godot --headless --path $projectRoot --script res://tools/audit_export_dependencies.gd
if ($LASTEXITCODE -ne 0) { throw 'Web dependency audit failed.' }
& $Python (Join-Path $PSScriptRoot 'optimize_export.py') --preset Web --apply
if ($LASTEXITCODE -ne 0) { throw 'Web export manifest generation failed.' }
& $Godot --headless --path $projectRoot --export-release Web (Join-Path $outputDir 'index.html')
if ($LASTEXITCODE -ne 0) { throw 'Web export failed.' }
# Keep install metadata/icons available when the PWA is reopened offline.
$workerPath = Join-Path $outputDir 'index.service.worker.js'
$worker = Get-Content -LiteralPath $workerPath -Raw
$worker = $worker.Replace('const CACHED_FILES = [', 'const CACHED_FILES = ["index.manifest.json","index.144x144.png","index.180x180.png","index.512x512.png",')
Set-Content -LiteralPath $workerPath -Value $worker -Encoding utf8
# Exercise the exported pack, not the source tree, using disposable save data.
$checkEnvironment = @{
 APPDATA = (Join-Path $projectRoot 'exports/qa-web/pack-profile')
 LOCALAPPDATA = (Join-Path $projectRoot 'exports/qa-web/pack-profile')
 LAKEBOUND_AUTH = '0'; LAKEBOUND_BACKGROUND_SYNC = '0'; LAKEBOUND_COMPETITION = '0'
}
$previousEnvironment = @{}
try {
 foreach ($key in $checkEnvironment.Keys) {
  $previousEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
  [Environment]::SetEnvironmentVariable($key, $checkEnvironment[$key], 'Process')
 }
 $checkLog = & $Godot --headless --main-pack (Join-Path $outputDir 'index.pck') --script (Join-Path $PSScriptRoot 'check_web_pack.gd') 2>&1
 $checkLog | Set-Content (Join-Path $projectRoot 'exports/web-pack-check.log')
 if ($LASTEXITCODE -ne 0 -or ($checkLog -match 'SCRIPT ERROR|Parse Error|WEB PACK MISSING').Count -gt 0 -or -not ($checkLog -match 'WEB PACK PASS:')) { throw 'Exported Web pack smoke check failed.' }
} finally {
 foreach ($key in $previousEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $previousEnvironment[$key], 'Process') }
}
Write-Host "Web/PWA exported to $outputDir"
