<#
.SYNOPSIS
  Comprehensive Windows + C: drive repair launcher for Windows PowerShell 5.
.DESCRIPTION
  Installs durable fixfix/fixfixfix functions, creates a weekly self-repair scheduled task,
  and optionally runs the repair pass now. Designed to be safer than a huge pasted EncodedCommand:
  keep the real payload in this repository and run the small root launcher.
#>
[CmdletBinding()]
param(
    [switch]$InstallOnly,
    [switch]$SkipRestorePoint,
    [switch]$SkipWindowsUpdateReset,
    [switch]$NoPause
)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$Script:ThisScriptPath = if($PSCommandPath){ $PSCommandPath } elseif($MyInvocation.MyCommand.Path){ $MyInvocation.MyCommand.Path } else { $null }
$Script:RepoRoot = if($Script:ThisScriptPath){ Split-Path -Path (Split-Path -Path $Script:ThisScriptPath -Parent) -Parent } else { $null }
function Write-Step([string]$Message){ Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) }
function Test-Admin {
    try { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { return $false }
}
function Invoke-Native([string]$Name, [string]$File, [string[]]$Args){
    Write-Step $Name
    & $File @Args
    $code = $LASTEXITCODE
    Write-Step ("{0} exit={1}" -f $Name,$code)
    return $code
}
function Ensure-AdminRelaunch {
    if(Test-Admin){ return $true }
    $self = $MyInvocation.ScriptName
    if([string]::IsNullOrWhiteSpace($self)){ $self = $PSCommandPath }
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$self)
    if($InstallOnly){ $argList += '-InstallOnly' }
    if($SkipRestorePoint){ $argList += '-SkipRestorePoint' }
    if($SkipWindowsUpdateReset){ $argList += '-SkipWindowsUpdateReset' }
    if($NoPause){ $argList += '-NoPause' }
    Write-Step 'Requesting Administrator elevation'
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    return $false
}
function Install-ProfileFunctions {
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path -Path $profilePath -Parent
    if($profileDir -and !(Test-Path -LiteralPath $profileDir)){ New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
    if(!(Test-Path -LiteralPath $profilePath)){ New-Item -ItemType File -Force -Path $profilePath | Out-Null }
    $existing = Get-Content -Raw -LiteralPath $profilePath -ErrorAction SilentlyContinue
    if($null -eq $existing){ $existing = '' }
    $begin = '# BEGIN HERMES FIXFIXFIX'
    $end = '# END HERMES FIXFIXFIX'
    $pattern = '(?s)\r?\n?' + [regex]::Escape($begin) + '[\s\S]*?' + [regex]::Escape($end) + '\r?\n?'
    $existing = [regex]::Replace($existing,$pattern,'')
    $block = @'
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
    Repair-Volume -DriveLetter C -Scan 2>$null
}
# END HERMES FIXFIXFIX
'@
    Set-Content -LiteralPath $profilePath -Encoding UTF8 -Value ($existing.TrimEnd() + "`r`n" + $block + "`r`n")
    Write-Step "Profile functions installed: $profilePath"
}
function Install-WeeklyTask {
    $taskName = 'Weekly Windows Self Repair'
    if([string]::IsNullOrWhiteSpace($Script:RepoRoot)){ Write-Step 'Scheduled task skipped: script path could not be resolved'; return }
    $runner = Join-Path $Script:RepoRoot 'run-windows-cdrive-self-repair-toolkit.ps1'
    if(!(Test-Path -LiteralPath $runner)){ Write-Step "Scheduled task skipped: runner missing: $runner"; return }
    $taskArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $runner + '" -NoPause -SkipWindowsUpdateReset'
    try {
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgs
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
        Write-Step "Scheduled task installed: $taskName"
    } catch {
        Write-Step "ScheduledTasks API failed, falling back to schtasks.exe: $($_.Exception.Message)"
        $tr = 'powershell.exe ' + $taskArgs
        & schtasks.exe /Create /F /TN $taskName /SC WEEKLY /D SUN /ST 03:00 /RL HIGHEST /TR $tr | Out-Host
        if($LASTEXITCODE -eq 0){ Write-Step "Scheduled task installed: $taskName" } else { Write-Step "Scheduled task failed: schtasks exit=$LASTEXITCODE" }
    }
}
function Try-RestorePoint {
    if($SkipRestorePoint){ Write-Step 'Restore point skipped by flag'; return }
    try {
        Write-Step 'Creating system restore point (best effort)'
        Checkpoint-Computer -Description 'Before Hermes Windows Self Repair' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
    } catch { Write-Step ("Restore point skipped: " + $_.Exception.Message) }
}
function Reset-WindowsUpdateLite {
    if($SkipWindowsUpdateReset){ Write-Step 'Windows Update light reset skipped by flag'; return }
    Write-Step 'Windows Update cache health light reset (bounded)'
    foreach($svc in @('bits','wuauserv','cryptsvc')){
        $null = sc.exe query $svc 2>$null
        $null = sc.exe stop $svc 2>$null
    }
    Start-Sleep -Seconds 3
    $sd = Join-Path $env:windir 'SoftwareDistribution'
    $cat = Join-Path $env:windir 'System32\catroot2'
    foreach($path in @($sd,$cat)){
        if(Test-Path -LiteralPath $path){
            $new = $path + '.bak-hermes-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
            try { Rename-Item -LiteralPath $path -NewName (Split-Path -Leaf $new) -ErrorAction Stop; Write-Step "Renamed cache: $path" } catch { Write-Step "Cache rename skipped: $path - $($_.Exception.Message)" }
        }
    }
    foreach($svc in @('cryptsvc','wuauserv','bits')){ $null = sc.exe start $svc 2>$null }
}
function Invoke-WindowsCDriveRepair {
    Try-RestorePoint
    Invoke-Native 'DISM checkhealth' 'dism.exe' @('/online','/cleanup-image','/checkhealth') | Out-Null
    Invoke-Native 'DISM scanhealth' 'dism.exe' @('/online','/cleanup-image','/scanhealth') | Out-Null
    Invoke-Native 'DISM restorehealth' 'dism.exe' @('/online','/cleanup-image','/restorehealth') | Out-Null
    Invoke-Native 'SFC scannow' 'sfc.exe' @('/scannow') | Out-Null
    Invoke-Native 'DISM startcomponentcleanup' 'dism.exe' @('/online','/cleanup-image','/startcomponentcleanup') | Out-Null
    Invoke-Native 'CHKDSK online scan C:' 'chkdsk.exe' @('C:','/scan') | Out-Null
    try { Write-Step 'Repair-Volume C: scan'; Repair-Volume -DriveLetter C -Scan } catch { Write-Step ("Repair-Volume skipped: " + $_.Exception.Message) }
    Reset-WindowsUpdateLite
    Invoke-Native 'DISM analyzecomponentstore' 'dism.exe' @('/online','/cleanup-image','/analyzecomponentstore') | Out-Null
}
if(-not (Ensure-AdminRelaunch)){ return }
Install-ProfileFunctions
Install-WeeklyTask
if(-not $InstallOnly){ Invoke-WindowsCDriveRepair } else { Write-Step 'InstallOnly: repair pass not run now' }
Write-Step 'DONE'
if(-not $NoPause){ Write-Host 'Press Enter to close...'; try { [void][Console]::ReadLine() } catch {} }
