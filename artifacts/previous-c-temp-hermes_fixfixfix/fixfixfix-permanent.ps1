$ErrorActionPreference = 'Continue'
function Write-Step([string]$m){ Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) }
function global:fixfix {
    Write-Step 'DISM scanhealth'
    dism.exe /online /cleanup-image /scanhealth
    Write-Step 'DISM restorehealth'
    dism.exe /online /cleanup-image /restorehealth
    Write-Step 'DISM startcomponentcleanup'
    dism.exe /online /cleanup-image /startcomponentcleanup
}
function global:fixfixfix {
    fixfix
    Write-Step 'SFC scannow'
    sfc.exe /scannow
    Write-Step 'CHKDSK online scan C:'
    chkdsk.exe C: /scan
}
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path -Path $profilePath -Parent
if($profileDir -and !(Test-Path -LiteralPath $profileDir)){ New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
if(!(Test-Path -LiteralPath $profilePath)){ New-Item -ItemType File -Force -Path $profilePath | Out-Null }
$existing = Get-Content -Raw -LiteralPath $profilePath -ErrorAction SilentlyContinue
if($null -eq $existing){ $existing = '' }
$existing = [regex]::Replace($existing,'(?s)\r?\n?# BEGIN HERMES FIXFIXFIX[\s\S]*?# END HERMES FIXFIXFIX\r?\n?','')
$profileBlock = @'
# BEGIN HERMES FIXFIXFIX
function global:fixfix {
    dism.exe /online /cleanup-image /scanhealth
    dism.exe /online /cleanup-image /restorehealth
    dism.exe /online /cleanup-image /startcomponentcleanup
}
function global:fixfixfix {
    fixfix
    sfc.exe /scannow
    chkdsk.exe C: /scan
}
# END HERMES FIXFIXFIX
'@
Set-Content -LiteralPath $profilePath -Encoding UTF8 -Value ($existing.TrimEnd() + "`r`n" + $profileBlock + "`r`n")
Write-Step "Profile functions installed: $profilePath"
$taskName = 'Weekly Windows Self Repair'
$taskCmd = 'dism.exe /online /cleanup-image /restorehealth && sfc.exe /scannow && dism.exe /online /cleanup-image /startcomponentcleanup && chkdsk.exe C: /scan'
$arg = '/c ' + $taskCmd
schtasks.exe /Create /F /TN $taskName /SC WEEKLY /D SUN /ST 03:00 /RL HIGHEST /TR "cmd.exe $arg" | Out-Host
Write-Step "Scheduled task installed: $taskName"
fixfixfix
Write-Step 'DONE'
