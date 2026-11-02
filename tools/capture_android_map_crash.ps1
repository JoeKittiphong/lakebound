param([string]$Adb = (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools/adb.exe'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$output=Join-Path $root 'exports/diagnostics/android-map-crash'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$devices=@(& $Adb devices | Select-String '^([^\s]+)\s+device$' | ForEach-Object {$_.Matches[0].Groups[1].Value})
if ($devices.Count -ne 1) {throw 'Connect exactly one unlocked phone with USB debugging authorized. No app or save data will be removed.'}
$serial=$devices[0]
& $Adb -s $serial logcat -b crash -d -v threadtime | Set-Content -Encoding utf8 (Join-Path $output 'crash.log')
& $Adb -s $serial logcat -d -v threadtime -t 3000 | Set-Content -Encoding utf8 (Join-Path $output 'recent.log')
& $Adb -s $serial shell dumpsys activity exit-info com.zylaah.lakebound | Set-Content -Encoding utf8 (Join-Path $output 'exit-info.txt')
& $Adb -s $serial shell dumpsys meminfo com.zylaah.lakebound | Set-Content -Encoding utf8 (Join-Path $output 'memory.txt')
& $Adb -s $serial shell getprop ro.product.model | Set-Content -Encoding utf8 (Join-Path $output 'device-model.txt')
& $Adb -s $serial shell dumpsys package com.zylaah.lakebound | Select-String 'versionCode=|versionName=' | Set-Content -Encoding utf8 (Join-Path $output 'installed-version.txt')
Write-Output "Read-only Android crash evidence saved to $output"
