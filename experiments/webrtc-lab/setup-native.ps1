$ErrorActionPreference='Stop'
$rtcRoot=$PSScriptRoot
$rtcArchive=Join-Path $rtcRoot 'webrtc-native-1.2.1.zip'
if(-not (Test-Path -LiteralPath $rtcArchive)){
 Invoke-WebRequest -Uri 'https://github.com/godotengine/webrtc-native/releases/download/1.2.1-stable/godot-extension-webrtc_native.zip' -OutFile $rtcArchive
}
$rtcHash=(Get-FileHash -LiteralPath $rtcArchive -Algorithm SHA256).Hash
if($rtcHash -ne 'F37D03DA03DA3FF0D092542A04586644F889135CB7A1C3566AD57513203A553B'){throw 'Unexpected native WebRTC archive hash'}
Expand-Archive -LiteralPath $rtcArchive -DestinationPath (Join-Path $rtcRoot 'godot') -Force
Write-Output 'Official webrtc-native 1.2.1 installed in isolated lab project.'
