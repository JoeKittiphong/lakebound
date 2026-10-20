param(
 [string]$Godot = $env:LAKEBOUND_GODOT,
 [string]$JavaHome = $env:JAVA_HOME,
 [string]$GradleCache = $env:GRADLE_USER_HOME,
 [string]$AndroidSdk = $env:ANDROID_SDK_ROOT,
 [string]$OutputPath = '',
 [string]$SigningDirectory = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (!$Godot) {
 $engineCommand = Get-Command godot -ErrorAction SilentlyContinue
 if ($engineCommand) { $Godot = $engineCommand.Source }
}
if (!$AndroidSdk) { $AndroidSdk = $env:ANDROID_HOME }
if (!$Godot -or !(Test-Path -LiteralPath $Godot)) { throw 'Set -Godot or LAKEBOUND_GODOT to the Godot console executable.' }
if (!$JavaHome -or !(Test-Path -LiteralPath (Join-Path $JavaHome 'bin/keytool.exe'))) { throw 'Set -JavaHome or JAVA_HOME to the Android JDK.' }
if (!$AndroidSdk -or !(Test-Path -LiteralPath $AndroidSdk)) { throw 'Set -AndroidSdk, ANDROID_SDK_ROOT, or ANDROID_HOME.' }
if (!$GradleCache) { $GradleCache = Join-Path $env:LOCALAPPDATA 'Lakebound/gradle-cache' }
$projectConfig = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw
$versionMatch = [regex]::Match($projectConfig, '(?m)^config/version="([^"]+)"')
if (!$versionMatch.Success) { throw 'Missing config/version in project.godot.' }
$version = $versionMatch.Groups[1].Value
$presetConfig = Get-Content -LiteralPath (Join-Path $projectRoot 'export_presets.cfg') -Raw
$releasePreset = [regex]::Match($presetConfig, '(?s)\[preset\.(\d+)\]\s*name="Android AAB"')
if (!$releasePreset.Success) { throw 'Missing Android AAB export preset.' }
$optionsPattern = '(?s)\[preset\.' + $releasePreset.Groups[1].Value + '\.options\](.*?)(?=\[preset\.|\z)'
$releaseOptions = [regex]::Match($presetConfig, $optionsPattern).Groups[1].Value
$releaseVersion = [regex]::Match($releaseOptions, '(?m)^version/name="([^"]+)"').Groups[1].Value
if ($releaseVersion -ne $version) { throw 'Android AAB version/name must match config/version in project.godot.' }
if (!$OutputPath) { $OutputPath = "exports/android/lakebound-$version-closed.aab" }
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
New-Item -ItemType Directory -Force -Path (Split-Path $resolvedOutput -Parent) | Out-Null
$originalSigningDir = Join-Path $projectRoot 'signing'
# Prefer the identity used for the first Play upload; never replace it with an editor-created key.
$signingDir = if ($SigningDirectory) { $SigningDirectory } elseif (Test-Path (Join-Path $originalSigningDir 'lakebound-upload.jks')) { $originalSigningDir } else { Join-Path $projectRoot '.signing' }
$keyFile = Join-Path $signingDir 'lakebound-upload.jks'
$secretFile = Join-Path $signingDir 'upload-password.dpapi'
New-Item -ItemType Directory -Force -Path $signingDir | Out-Null
# Keep this folder local and accessible only to the current Windows user.
& icacls $signingDir /inheritance:r /grant:r "$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name):(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not secure signing directory.' }
# Reuse the upload identity already configured in the editor.
$localCredentials = Join-Path $signingDir 'release-credentials.json'
if ((Test-Path $keyFile) -and !(Test-Path $secretFile) -and (Test-Path $localCredentials)) {
 $savedCredentials = Get-Content -LiteralPath $localCredentials -Raw | ConvertFrom-Json
 ConvertTo-SecureString $savedCredentials.password -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -LiteralPath $secretFile
 $savedCredentials = $null
}
if (!(Test-Path $keyFile)) {
 if (Test-Path $secretFile) { throw 'Password exists without key; restore backup before proceeding.' }
 $randomBytes = New-Object byte[] 36
 $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
 $rng.GetBytes($randomBytes)
 $rng.Dispose()
 $plainPassword = [Convert]::ToBase64String($randomBytes)
 ConvertTo-SecureString $plainPassword -AsPlainText -Force | ConvertFrom-SecureString | Set-Content $secretFile
 $env:LAKEBOUND_KEY_PASSWORD = $plainPassword
 try {
  & (Join-Path $JavaHome 'bin/keytool.exe') -genkeypair -noprompt -keystore $keyFile -storetype JKS -alias lakebound-upload -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Lakebound Upload' -storepass:env LAKEBOUND_KEY_PASSWORD -keypass:env LAKEBOUND_KEY_PASSWORD
  if ($LASTEXITCODE -ne 0) { throw 'Upload key creation failed.' }
 } finally { Remove-Item Env:LAKEBOUND_KEY_PASSWORD -ErrorAction SilentlyContinue; $plainPassword = $null }
}
if (!(Test-Path $secretFile)) { throw 'Missing protected upload password; restore the signing backup.' }
$secure = (Get-Content $secretFile -Raw).Trim() | ConvertTo-SecureString
$credential = New-Object System.Management.Automation.PSCredential('upload',$secure)
$buildEnvironment = @{}
foreach ($variableName in @('GODOT_ANDROID_KEYSTORE_RELEASE_PATH', 'GODOT_ANDROID_KEYSTORE_RELEASE_USER', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD', 'GRADLE_USER_HOME', 'JAVA_HOME', 'ANDROID_HOME', 'ANDROID_SDK_ROOT')) {
 $buildEnvironment[$variableName] = [Environment]::GetEnvironmentVariable($variableName, 'Process')
}
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keyFile
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'lakebound-upload'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $credential.GetNetworkCredential().Password
$env:GRADLE_USER_HOME = $GradleCache
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
try {
 & $Godot --headless --path $projectRoot --export-release 'Android AAB' $OutputPath
 if ($LASTEXITCODE -ne 0) { throw 'Release export failed.' }
} finally {
 foreach ($variableName in $buildEnvironment.Keys) {
  [Environment]::SetEnvironmentVariable($variableName, $buildEnvironment[$variableName], 'Process')
 }
 $buildEnvironment = $null
 $credential = $null
}
