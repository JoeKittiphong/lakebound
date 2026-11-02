param(
    [string]$Godot = 'C:\Users\Zylaah\programmer\godot\Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'exports\web'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
& $Godot --headless --path $projectRoot --export-release Web (Join-Path $outputDir 'index.html')
if ($LASTEXITCODE -ne 0) { throw 'Web export failed.' }
# Keep install metadata/icons available when the PWA is reopened offline.
$workerPath = Join-Path $outputDir 'index.service.worker.js'
$worker = Get-Content -LiteralPath $workerPath -Raw
$worker = $worker.Replace('const CACHED_FILES = [', 'const CACHED_FILES = ["index.manifest.json","index.144x144.png","index.180x180.png","index.512x512.png",')
Set-Content -LiteralPath $workerPath -Value $worker -Encoding utf8
Write-Host "Web/PWA exported to $outputDir"
