[CmdletBinding()]
param(
    [switch]$InstallOnly,
    [switch]$SkipRestorePoint,
    [switch]$SkipWindowsUpdateReset,
    [switch]$NoPause
)
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$payload = Join-Path $scriptRoot 'scripts\Invoke-WindowsCDriveSelfRepair.ps1'
$argsList = @()
if($InstallOnly){ $argsList += '-InstallOnly' }
if($SkipRestorePoint){ $argsList += '-SkipRestorePoint' }
if($SkipWindowsUpdateReset){ $argsList += '-SkipWindowsUpdateReset' }
if($NoPause){ $argsList += '-NoPause' }
& $payload @argsList
