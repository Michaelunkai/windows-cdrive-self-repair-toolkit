# windows-cdrive-self-repair-toolkit

Comprehensive Windows PowerShell 5 toolkit for repairing common Windows image, system-file, Windows Update cache, and `C:` drive filesystem issues.

This project was created from the Telegram `/study` packaging of the completed `fixfixfix` mission. The live `C:\Temp\hermes_fixfixfix` launcher was copied into `artifacts/previous-c-temp-hermes_fixfixfix/` instead of moved, because moving it would break the currently installed clipboard one-liner.

## What it does

### Real-time progress mode

Every long native repair command is now run through a live monitor that updates one console status line once per second instead of spamming duplicate lines. The status shows the exact active tool, elapsed time, child PID, alive state, CPU seconds used, RAM, and the latest useful DISM/CBS log line when available. Real tool stdout/stderr is printed as separate permanent lines. The monitor also supports `-CommandTimeoutMinutes` so a broken child process is not allowed to wait forever.


The root launcher runs `scripts/Invoke-WindowsCDriveSelfRepair.ps1`, which:

- elevates to Administrator when needed;
- installs durable `fixfix` and `fixfixfix` functions into the current user's Windows PowerShell profile;
- creates/updates the `Weekly Windows Self Repair` scheduled task;
- optionally creates a restore point;
- runs DISM check/scan/restore health;
- runs SFC system-file repair;
- runs component store cleanup;
- scans `C:` with `chkdsk C: /scan` and `Repair-Volume -DriveLetter C -Scan`;
- performs a bounded light Windows Update cache reset;
- prints timestamped progress for each step.

## Prerequisites

- Windows 10/11.
- Windows PowerShell 5.
- Administrator approval when the UAC prompt appears.
- Enough time: DISM/SFC/CHKDSK can take a long time and should not be interrupted.

## Usage

From Windows PowerShell:

```powershell
& 'F:\study\Windows\System\Administration\Maintenance\Repair\PowerShell\Automation\windows-cdrive-self-repair-toolkit
un-windows-cdrive-self-repair-toolkit.ps1'
```

Install the functions and scheduled task without running the heavy repair pass now:

```powershell
& 'F:\study\Windows\System\Administration\Maintenance\Repair\PowerShell\Automation\windows-cdrive-self-repair-toolkit
un-windows-cdrive-self-repair-toolkit.ps1' -InstallOnly
```

Skip restore point creation if it is slow or disabled:

```powershell
& 'F:\study\Windows\System\Administration\Maintenance\Repair\PowerShell\Automation\windows-cdrive-self-repair-toolkit
un-windows-cdrive-self-repair-toolkit.ps1' -SkipRestorePoint
```

## Important files

- `run-windows-cdrive-self-repair-toolkit.ps1` — stable root launcher and final local entry point.
- `scripts/Invoke-WindowsCDriveSelfRepair.ps1` — full repair implementation.
- `tests/Test-Static.ps1` — PS5 parser/static verification.
- `artifacts/previous-c-temp-hermes_fixfixfix/` — copied-not-moved artifacts from the earlier live `C:\Temp` mission.

## Troubleshooting

- If PowerShell says execution is disabled, run with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <path>`.
- If UAC appears, approve it; repair commands require Administrator.
- If DISM or SFC reports repaired files, run the tool once more after it finishes.
- If `chkdsk` reports it cannot repair online, schedule an offline repair during reboot with `chkdsk C: /f`.
- If Windows Update cache rename is skipped because files are busy, reboot and run again.

## Repository

https://github.com/Michaelunkai/windows-cdrive-self-repair-toolkit

## Verification

Static verification command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'F:\study\Windows\System\Administration\Maintenance\Repair\PowerShell\Automation\windows-cdrive-self-repair-toolkit	ests\Test-Static.ps1'
```


## Fix notes

- The launcher caches its script path at script scope so scheduled-task installation does not depend on `$MyInvocation.MyCommand.Path` from inside a function, which is null in Windows PowerShell 5 in this context.
- The scheduled task is created with the ScheduledTasks API first, avoiding `schtasks.exe /TR` argument splitting where `-NoPause` can be misread as a schtasks option.
