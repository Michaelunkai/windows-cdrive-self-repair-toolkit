
$ErrorActionPreference='Stop'
$inner='C:\Temp\hermes_fixfixfix\inner.ps1'
$outer='C:\Temp\hermes_fixfixfix\outer.ps1'
$liner='C:\Temp\hermes_fixfixfix\liner.txt'
foreach($p in @($inner,$outer)){
  $tokens=$null; $errs=$null
  [System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$tokens,[ref]$errs) | Out-Null
  if($errs.Count -gt 0){ throw ("PARSE_FAIL $p " + ($errs | ForEach-Object { $_.Message } | Out-String)) }
}
$cmd=Get-Content -Raw -LiteralPath $liner
$cmd=$cmd.TrimEnd("`r","`n")
$bytes=[Text.Encoding]::UTF8.GetBytes($cmd)
$sha=[BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)).Replace('-','').ToLowerInvariant()
Set-Clipboard -Value $cmd
$rb=Get-Clipboard -Raw
$rb=$rb.TrimEnd("`r","`n")
if($rb -cne $cmd){ throw 'CLIPBOARD_READBACK_MISMATCH' }
"OK length=$($cmd.Length) sha256=$sha inner_parse=OK outer_parse=OK clipboard=OK file=$liner"
