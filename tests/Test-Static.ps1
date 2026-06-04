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
$payloadText = Get-Content -Raw -LiteralPath (Join-Path $root 'scripts\Invoke-WindowsCDriveSelfRepair.ps1')
$mustContain = @('dism.exe','sfc.exe','chkdsk.exe','Repair-Volume','schtasks.exe','Checkpoint-Computer')
foreach($m in $mustContain){ if($payloadText -notlike "*$m*"){ throw "Missing expected repair primitive: $m" } }
'PASS parse/static verification'
