param(
 [Parameter(Mandatory=$true)][string]$Godot,
 [string]$Python = $env:LAKEBOUND_PYTHON
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (Test-Path (Join-Path $projectRoot 'android/build/src/main')) {
 & node (Join-Path $PSScriptRoot 'prepare_android_auth.cjs')
 if ($LASTEXITCODE -ne 0) { throw 'Android OAuth callback bridge preparation failed.' }
}
if (!$Python) {
 $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
 if ($pythonCommand) { $Python = $pythonCommand.Source }
}
if (!$Python) { throw 'Set -Python or LAKEBOUND_PYTHON to the Python interpreter.' }
$reportDir = Join-Path $projectRoot 'exports/cleanup-qa'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
& $Python (Join-Path $PSScriptRoot 'apply_texture_budget.py') --check
if ($LASTEXITCODE -ne 0) { throw 'Texture budget changed: apply it and reimport before exporting.' }
foreach ($phase in @('import','dependencies')) {
 $arguments = @('--headless','--path',('"' + $projectRoot + '"'))
 if ($phase -eq 'import') { $arguments += @('--editor','--recovery-mode','--import','--quit') }
 else { $arguments += @('--script','res://tools/audit_export_dependencies.gd') }
 $arguments += @('--log-file',('"' + (Join-Path $reportDir ("prepare-$phase.log")) + '"'))
 $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
 if ($process.ExitCode -ne 0) { throw "Godot export preflight failed: $phase" }
}
& $Python (Join-Path $PSScriptRoot 'optimize_export.py') --apply
if ($LASTEXITCODE -ne 0) { throw 'Could not generate a complete export manifest.' }
