[CmdletBinding()]
param(
    [switch]$InstallOnly,
    [switch]$SkipRestorePoint,
    [switch]$SkipWindowsUpdateReset,
    [switch]$NoPause
)
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$payload = Join-Path $scriptRoot 'scripts\Invoke-WindowsCDriveSelfRepair.ps1'
$payloadArgs = @{}
if($InstallOnly){ $payloadArgs['InstallOnly'] = $true }
if($SkipRestorePoint){ $payloadArgs['SkipRestorePoint'] = $true }
if($SkipWindowsUpdateReset){ $payloadArgs['SkipWindowsUpdateReset'] = $true }
if($NoPause){ $payloadArgs['NoPause'] = $true }
& $payload @payloadArgs
