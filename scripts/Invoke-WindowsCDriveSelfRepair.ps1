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
    [switch]$NoPause,
    [int]$CommandTimeoutMinutes = 180,
    [switch]$SelfTestProgress
)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$Script:ThisScriptPath = if($PSCommandPath){ $PSCommandPath } elseif($MyInvocation.MyCommand.Path){ $MyInvocation.MyCommand.Path } else { $null }
$Script:RepoRoot = if($Script:ThisScriptPath){ Split-Path -Path (Split-Path -Path $Script:ThisScriptPath -Parent) -Parent } else { $null }
$Script:LiveLineActive = $false
function Clear-LiveLine {
    if($Script:LiveLineActive){
        try { Write-Host ("`r" + (' ' * ([Math]::Max(1,[Console]::WindowWidth - 1))) + "`r") -NoNewline } catch { Write-Host '' }
        $Script:LiveLineActive = $false
    }
}
function Write-Step([string]$Message){
    Clear-LiveLine
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $Message)
}
function Write-LiveLine([string]$Message){
    $text = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $Message
    try {
        $width = [Math]::Max(20,[Console]::WindowWidth - 1)
        if($text.Length -gt $width){ $text = $text.Substring(0,$width-1) }
        Write-Host ("`r" + $text.PadRight($width)) -NoNewline
        $Script:LiveLineActive = $true
    } catch { Write-Host $text; $Script:LiveLineActive = $false }
}

function Test-Admin {
    try { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { return $false }
}
function Get-LastUsefulLogLine([string[]]$Paths, [datetime]$Since){
    foreach($lp in $Paths){
        try {
            if(Test-Path -LiteralPath $lp){
                $lines = Get-Content -LiteralPath $lp -Tail 8 -ErrorAction SilentlyContinue
                for($i=$lines.Count-1; $i -ge 0; $i--){
                    $line = ([string]$lines[$i]).Trim()
                    if($line.Length -gt 0 -and $line -notmatch '^={3,}$'){
                        return (Split-Path -Leaf $lp) + ': ' + $line
                    }
                }
            }
        } catch {}
    }
    return ''
}
function Write-Heartbeat([string]$Name, [datetime]$Start, [string]$Phase, [int]$ChildPid, [double]$CpuStart, [int64]$WsStart, [string[]]$LogPaths){
    $elapsed = [int]((Get-Date) - $Start).TotalSeconds
    $cpuNow = 0.0; $wsNow = 0L; $alive = $true
    try {
        $gp = Get-Process -Id $ChildPid -ErrorAction Stop
        if($gp.CPU -ne $null){ $cpuNow = [double]$gp.CPU }
        $wsNow = [int64]$gp.WorkingSet64
    } catch { $alive = $false }
    $cpuDelta = [Math]::Round(($cpuNow - $CpuStart),1)
    $wsMb = [Math]::Round(($wsNow / 1MB),0)
    $log = Get-LastUsefulLogLine $LogPaths $Start
    if($log.Length -gt 110){ $log = $log.Substring(0,110) }
    if([string]::IsNullOrWhiteSpace($Phase)){ $Phase = 'waiting for tool/log output' }
    $msg = "{0} | {1}s | phase={2} | pid={3} alive={4} cpu+={5}s ram={6}MB" -f $Name,$elapsed,$Phase,$ChildPid,$alive,$cpuDelta,$wsMb
    if(-not [string]::IsNullOrWhiteSpace($log)){ $msg += " | latest-log=" + $log }
    Write-LiveLine $msg
}
function ConvertTo-NativeArgumentString([string[]]$NativeArgs){
    $quoted = @()
    foreach($a in $NativeArgs){
        if($null -eq $a){ continue }
        $s = [string]$a
        if($s -match '[\s\";{}()]'){
            $quoted += '"' + $s.Replace('\\','\\').Replace('"','\"') + '"'
        } else { $quoted += $s }
    }
    return ($quoted -join ' ')
}
function Invoke-Native([string]$Name, [string]$File, [string[]]$NativeArgs, [int]$TimeoutMinutes = $CommandTimeoutMinutes, [string[]]$LogPaths = @()){
    Write-Step ("{0} start: {1} {2}" -f $Name,$File,($NativeArgs -join ' '))
    $start = Get-Date
    $tmpBase = Join-Path $env:TEMP ("hermes-repair-{0}-{1}" -f ([guid]::NewGuid().ToString('N')),$Name.Replace(' ','_').Replace(':','_'))
    $outFile = $tmpBase + '.out.log'
    $errFile = $tmpBase + '.err.log'
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $File
        $psi.Arguments = ConvertTo-NativeArgumentString $NativeArgs
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $null = $proc.Start()
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
    } catch { Write-Step ("{0} failed to start: {1}" -f $Name,$_.Exception.Message); return 9999 }
    $outPos = 0L; $errPos = 0L; $lastBeat = Get-Date; $lastActivity = Get-Date; $lastPhase = "starting"; $cpuStart = 0.0; $wsStart = 0L; try { $gp0=Get-Process -Id $proc.Id -ErrorAction Stop; if($gp0.CPU -ne $null){$cpuStart=[double]$gp0.CPU}; $wsStart=[int64]$gp0.WorkingSet64 } catch {}
    while(-not $proc.HasExited){
        foreach($pair in @(@($outFile,'OUT'),@($errFile,'ERR'))){
            $path = $pair[0]; $tag = $pair[1]
            if(Test-Path -LiteralPath $path){
                $fs = $null
                try {
                    $fs = [IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
                    $posVar = if($tag -eq 'OUT'){ 'outPos' } else { 'errPos' }
                    $oldPos = Get-Variable -Name $posVar -ValueOnly
                    if($fs.Length -gt $oldPos){
                        $fs.Seek($oldPos,[IO.SeekOrigin]::Begin) | Out-Null
                        $sr = New-Object IO.StreamReader($fs)
                        $chunk = $sr.ReadToEnd()
                        Set-Variable -Name $posVar -Value $fs.Position
                        $sr.Close(); $fs = $null
                        foreach($line in ($chunk -split "`r?`n")){
                            if($line.Trim().Length -gt 0){ $lastPhase = $line.TrimEnd(); Write-Step ("{0} {1}: {2}" -f $Name,$tag,$line.TrimEnd()); $lastActivity = Get-Date }
                        }
                    }
                } catch { } finally { if($fs){ $fs.Close() } }
            }
        }
        $now = Get-Date
        if(($now - $lastBeat).TotalSeconds -ge 1){
            Write-Heartbeat $Name $start $lastPhase $proc.Id $cpuStart $wsStart $LogPaths
            $lastBeat = $now
        }
        if($TimeoutMinutes -gt 0 -and ((Get-Date) - $start).TotalMinutes -ge $TimeoutMinutes){
            Clear-LiveLine
            Write-Step ("{0} timeout after {1} minutes; stopping pid={2}" -f $Name,$TimeoutMinutes,$proc.Id)
            try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
            return 124
        }
        Start-Sleep -Milliseconds 100
        try { $proc.Refresh() } catch {}
    }
    foreach($pair in @(@($outFile,'OUT'),@($errFile,'ERR'))){
        $path = $pair[0]; $tag = $pair[1]
        if(Test-Path -LiteralPath $path){
            $fs = $null
            try {
                $fs = [IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
                $posVar = if($tag -eq 'OUT'){ 'outPos' } else { 'errPos' }
                $oldPos = Get-Variable -Name $posVar -ValueOnly
                if($fs.Length -gt $oldPos){
                    $fs.Seek($oldPos,[IO.SeekOrigin]::Begin) | Out-Null
                    $sr = New-Object IO.StreamReader($fs)
                    $chunk = $sr.ReadToEnd()
                    Set-Variable -Name $posVar -Value $fs.Position
                    $sr.Close(); $fs = $null
                    foreach($line in ($chunk -split "`r?`n")){
                        if($line.Trim().Length -gt 0){ Write-Step ("{0} {1}: {2}" -f $Name,$tag,$line.TrimEnd()) }
                    }
                }
            } catch { } finally { if($fs){ $fs.Close() } }
        }
    }
    try { $proc.WaitForExit(); $proc.Refresh() } catch {}
    try {
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        foreach($line in ($stdout -split "`r?`n")){ if($line.Trim().Length -gt 0){ Write-Step ("{0} OUT: {1}" -f $Name,$line.TrimEnd()) } }
        foreach($line in ($stderr -split "`r?`n")){ if($line.Trim().Length -gt 0){ Write-Step ("{0} ERR: {1}" -f $Name,$line.TrimEnd()) } }
    } catch { Write-Step ("{0} output collection skipped: {1}" -f $Name,$_.Exception.Message) }
    $code = $proc.ExitCode
    if($null -eq $code){ $code = -1 }
    $elapsed = [int]((Get-Date) - $start).TotalSeconds
    Clear-LiveLine
    Write-Step ("{0} exit={1} elapsed={2}s" -f $Name,$code,$elapsed)
    foreach($path in @($outFile,$errFile)){ try { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } catch {} }
    return $code
}
function Invoke-BlockLive([string]$Name, [scriptblock]$Block, [int]$TimeoutMinutes = 30){
    Write-Step ("{0} start" -f $Name)
    $start = Get-Date
    $job = Start-Job -ScriptBlock $Block
    $lastBeat = Get-Date
    while($job.State -eq 'Running'){
        $now = Get-Date
        if(($now - $lastBeat).TotalMilliseconds -ge 750){ Write-Heartbeat $Name $start ("job={0}" -f $job.Id); $lastBeat = $now }
        if($TimeoutMinutes -gt 0 -and ((Get-Date) - $start).TotalMinutes -ge $TimeoutMinutes){
            Write-Step ("{0} timeout after {1} minutes; stopping job={2}" -f $Name,$TimeoutMinutes,$job.Id)
            Stop-Job $job -Force -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return 124
        }
        Start-Sleep -Milliseconds 100
        $job = Get-Job -Id $job.Id
    }
    $output = Receive-Job $job -Keep -ErrorAction SilentlyContinue 2>&1
    foreach($line in $output){ if(($line | Out-String).Trim().Length -gt 0){ Write-Step ("{0}: {1}" -f $Name,($line | Out-String).Trim()) } }
    $state = $job.State
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    $elapsed = [int]((Get-Date) - $start).TotalSeconds
    Write-Step ("{0} complete state={1} elapsed={2}s" -f $Name,$state,$elapsed)
    if($state -eq 'Failed'){ return 1 }
    return 0
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
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $principal = New-ScheduledTaskPrincipal -UserId $identity -RunLevel Highest -LogonType Interactive
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force -ErrorAction Stop | Out-Null
        Write-Step "Scheduled task installed: $taskName"
    } catch {
        Write-Step "ScheduledTasks API failed, falling back to schtasks.exe: $($_.Exception.Message)"
        $tr = 'powershell.exe ' + $taskArgs
        $quotedTr = '"' + $tr.Replace('"','\"') + '"'
        & schtasks.exe /Create /F /TN $taskName /SC WEEKLY /D SUN /ST 03:00 /RL HIGHEST /TR $quotedTr | Out-Host
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
    foreach($i in 1..3){ Write-Step ("Windows Update reset wait {0}/3" -f $i); Start-Sleep -Seconds 1 }
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
    Invoke-Native 'DISM checkhealth' 'dism.exe' @('/online','/cleanup-image','/checkhealth') $CommandTimeoutMinutes @((Join-Path $env:windir 'Logs\DISM\dism.log')) | Out-Null
    Invoke-Native 'DISM scanhealth' 'dism.exe' @('/online','/cleanup-image','/scanhealth') $CommandTimeoutMinutes @((Join-Path $env:windir 'Logs\DISM\dism.log')) | Out-Null
    Invoke-Native 'DISM restorehealth' 'dism.exe' @('/online','/cleanup-image','/restorehealth') $CommandTimeoutMinutes @((Join-Path $env:windir 'Logs\DISM\dism.log')) | Out-Null
    Invoke-Native 'SFC scannow' 'sfc.exe' @('/scannow') $CommandTimeoutMinutes @((Join-Path $env:windir 'Logs\CBS\CBS.log')) | Out-Null
    Invoke-Native 'DISM startcomponentcleanup' 'dism.exe' @('/online','/cleanup-image','/startcomponentcleanup') $CommandTimeoutMinutes @((Join-Path $env:windir 'Logs\DISM\dism.log')) | Out-Null
    Invoke-Native 'CHKDSK online scan C:' 'chkdsk.exe' @('C:','/scan') $CommandTimeoutMinutes @() | Out-Null
    Invoke-BlockLive 'Repair-Volume C: scan' { Repair-Volume -DriveLetter C -Scan } 60 | Out-Null
    Reset-WindowsUpdateLite
    Invoke-Native 'DISM analyzecomponentstore' 'dism.exe' @('/online','/cleanup-image','/analyzecomponentstore') $CommandTimeoutMinutes @((Join-Path $env:windir 'Logs\DISM\dism.log')) | Out-Null
}
if($SelfTestProgress){
    Invoke-Native 'SELFTEST live progress 3s' 'powershell.exe' @('-NoProfile','-Command','$end=(Get-Date).AddSeconds(3); while((Get-Date) -lt $end){ Start-Sleep -Milliseconds 100 }; Write-Output SELFTEST_DONE') 1 @() | Out-Null
    Write-Step 'SELFTEST DONE'
    return
}
if(-not (Ensure-AdminRelaunch)){ return }
Install-ProfileFunctions
Install-WeeklyTask
if(-not $InstallOnly){ Invoke-WindowsCDriveRepair } else { Write-Step 'InstallOnly: repair pass not run now' }
Write-Step 'DONE'
if(-not $NoPause){ Write-Host 'Press Enter to close...'; try { [void][Console]::ReadLine() } catch {} }
