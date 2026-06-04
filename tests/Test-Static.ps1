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
'PASS parse/static verification plus regression checks'
