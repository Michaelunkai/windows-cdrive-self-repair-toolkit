$ErrorActionPreference='Stop'
$paths=@('C:\Temp\hermes_fixfixfix\fixfixfix-permanent.ps1','C:\Temp\hermes_fixfixfix\run-fixfixfix.ps1')
foreach($p in $paths){
  if(!(Test-Path -LiteralPath $p)){ throw "MISSING $p" }
  $tokens=$null; $errs=$null
  [System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$tokens,[ref]$errs) | Out-Null
  if($errs.Count -gt 0){ throw ("PARSE_FAIL $p " + ($errs | ForEach-Object { $_.Message } | Out-String)) }
}
$cmd=Get-Content -Raw -LiteralPath 'C:\Temp\hermes_fixfixfix\SHORT-LINER.txt'
$cmd=$cmd.TrimEnd("`r","`n")
$tokens=$null; $errs=$null
[System.Management.Automation.Language.Parser]::ParseInput($cmd,[ref]$tokens,[ref]$errs) | Out-Null
if($errs.Count -gt 0){ throw ("LINER_PARSE_FAIL " + ($errs | ForEach-Object { $_.Message } | Out-String)) }
Set-Clipboard -Value $cmd
$rb=(Get-Clipboard -Raw).TrimEnd("`r","`n")
if($rb -cne $cmd){ throw 'CLIPBOARD_MISMATCH' }
$sha=[BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($cmd))).Replace('-','').ToLowerInvariant()
"OK line=$cmd length=$($cmd.Length) sha256=$sha payload_parse=OK launcher_parse=OK liner_parse=OK clipboard=OK"
