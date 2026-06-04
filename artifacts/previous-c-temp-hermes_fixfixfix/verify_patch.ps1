$ErrorActionPreference='Stop'
$payload='C:\Temp\hermes_fixfixfix\fixfixfix-permanent.ps1'
$launcher='C:\Temp\hermes_fixfixfix\run-fixfixfix.ps1'
$line="& 'C:\Temp\hermes_fixfixfix\run-fixfixfix.ps1'"
foreach($p in @($payload,$launcher)){
  $tokens=$null; $errs=$null
  [System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$tokens,[ref]$errs) | Out-Null
  if($errs.Count -gt 0){ throw ("PARSE_FAIL $p " + ($errs | ForEach-Object { $_.Message } | Out-String)) }
}
$tokens=$null; $errs=$null
[System.Management.Automation.Language.Parser]::ParseInput($line,[ref]$tokens,[ref]$errs) | Out-Null
if($errs.Count -gt 0){ throw 'LINER_PARSE_FAIL' }
Set-Clipboard -Value $line
$rb=(Get-Clipboard -Raw).TrimEnd("`r","`n")
if($rb -cne $line){ throw 'CLIPBOARD_MISMATCH' }
$bad=Select-String -LiteralPath $payload -Pattern 'Split-Path -LiteralPath \$profilePath -Parent' -SimpleMatch -Quiet
if($bad){ throw 'BAD_SPLITPATH_STILL_PRESENT' }
$sha=[BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($line))).Replace('-','').ToLowerInvariant()
"OK line=$line length=$($line.Length) sha256=$sha bad_splitpath_absent=OK payload_parse=OK launcher_parse=OK liner_parse=OK clipboard=OK"
