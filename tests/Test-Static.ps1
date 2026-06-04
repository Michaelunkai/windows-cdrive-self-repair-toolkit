$ErrorActionPreference='Stop'
$root = Split-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -Parent
$files = @(
    (Join-Path $root 'run-windows-cdrive-self-repair-toolkit.ps1'),
    (Join-Path $root 'scripts\Invoke-WindowsCDriveSelfRepair.ps1')
)
foreach($f in $files){
    if(!(Test-Path -LiteralPath $f)){ throw "Missing file: $f" }
    $tokens=$null; $errs=$null
    [System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$tokens,[ref]$errs) | Out-Null
    if($errs.Count -gt 0){ throw ("Parse failed: $f " + ($errs | ForEach-Object { $_.Message } | Out-String)) }
}
$payloadPath = Join-Path $root 'scripts\Invoke-WindowsCDriveSelfRepair.ps1'
$launcherText = Get-Content -Raw -LiteralPath (Join-Path $root 'run-windows-cdrive-self-repair-toolkit.ps1')
if($launcherText -match '\$argsList\s*=\s*@\(\)' -or $launcherText -match '& \$payload @argsList'){
    throw 'Root launcher uses string-array switch splatting; use hashtable splatting'
}
$payloadText = Get-Content -Raw -LiteralPath $payloadPath
$mustContain = @('dism.exe','sfc.exe','chkdsk.exe','Repair-Volume','Register-ScheduledTask','Checkpoint-Computer')
foreach($m in $mustContain){ if($payloadText -notlike "*$m*"){ throw "Missing expected repair primitive: $m" } }
if($payloadText -match 'Split-Path\s+-Path\s+\$MyInvocation\.MyCommand\.Path\s+-Parent'){
    throw 'Unsafe function-scope MyInvocation.MyCommand.Path Split-Path pattern still present'
}
if($payloadText -match '\$tr\s*=.*-NoPause'){
    throw 'Unsafe schtasks /TR string construction with -NoPause still present'
}
if($payloadText -notmatch '\$Script:RepoRoot'){
    throw 'Script path is not cached at script scope'
}
if($payloadText -match 'New-ScheduledTaskPrincipal -UserId \$env:USERNAME'){
    throw 'Unsafe scheduled task principal uses bare username'
}
if($payloadText -match 'Register-ScheduledTask[\s\S]*?\| Out-Null' -and $payloadText -notmatch 'Register-ScheduledTask[\s\S]*?-ErrorAction Stop[\s\S]*?\| Out-Null'){
    throw 'Register-ScheduledTask is missing ErrorAction Stop'
}
if($payloadText -notmatch 'function Invoke-Native[\s\S]*System.Diagnostics.Process[\s\S]*Write-Heartbeat'){
    throw 'Native repair commands are not wrapped with live heartbeat progress'
}
if($payloadText -notmatch 'Write-LiveLine'){
    throw 'Live status must update a single console line instead of spamming duplicate lines'
}
if($payloadText -notmatch 'Get-LastUsefulLogLine'){
    throw 'Live status must include latest tool log context'
}
if($payloadText -match 'no-new-output=') {
    throw 'Generic no-new-output spam must not be used as progress'
}
if($payloadText -match 'Start-Sleep -Seconds 3'){
    throw 'Silent multi-second sleep still present'
}
if($payloadText -notmatch 'CommandTimeoutMinutes'){
    throw 'Command timeout parameter missing'
}
if($payloadText -notmatch 'SelfTestProgress'){
    throw 'SelfTestProgress verification mode missing'
}
if($launcherText -notmatch 'SelfTestProgress'){
    throw 'Root launcher does not forward SelfTestProgress'
}
'PASS parse/static verification plus live-progress regression checks'
