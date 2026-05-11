$TaskName = "Habitica Daily Date Updater"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvDir    = Join-Path $ScriptDir ".venv"
$PythonExe  = Join-Path $VenvDir   "Scripts\python.exe"
$PipExe     = Join-Path $VenvDir   "Scripts\pip.exe"
$MainScript = Join-Path $ScriptDir "habitica_update_daily_dates.py"
$EnvScript  = Join-Path $ScriptDir "habitica_env.ps1"

function Write-Header {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  Habitica Daily Date Updater - Setup" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
}

function Setup-Venv {
    Write-Host "-- Virtual Environment --" -ForegroundColor Yellow

    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: python not found on PATH. Install Python 3.10+ and try again." -ForegroundColor Red
        exit 1
    }

    if (Test-Path $VenvDir) {
        Write-Host "  Virtual environment already exists, skipping creation."
    } else {
        Write-Host "  Creating virtual environment..."
        python -m venv $VenvDir
    }

    Write-Host "  Installing requirements..."
    & $PipExe install -q -r (Join-Path $ScriptDir "requirements.txt")
    Write-Host "  Done." -ForegroundColor Green
    Write-Host ""
}

function Install-Task {
    Write-Host "-- Install Scheduled Task --" -ForegroundColor Yellow

    if (-not (Test-Path $EnvScript)) {
        Write-Host "  ERROR: $EnvScript not found. Fill in your credentials first." -ForegroundColor Red
        return
    }

    $timeInput = Read-Host "  Daily run time (HH:MM, default 08:00)"
    if (-not $timeInput) { $timeInput = "08:00" }

    if ($timeInput -notmatch '^\d{1,2}:\d{2}$') {
        Write-Host "  ERROR: Invalid time format. Use HH:MM (e.g. 08:00)." -ForegroundColor Red
        return
    }

    $argument = "-NonInteractive -WindowStyle Hidden -Command `". '$EnvScript'; & '$PythonExe' '$MainScript'`""
    $action   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argument -WorkingDirectory $ScriptDir
    $trigger  = New-ScheduledTaskTrigger -Daily -At $timeInput
    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action   $action `
        -Trigger  $trigger `
        -Settings $settings `
        -RunLevel Limited `
        -Force | Out-Null

    Write-Host "  Scheduled task '$TaskName' installed — runs daily at $timeInput." -ForegroundColor Green
    Write-Host "  Tip: run it once now to verify:" -ForegroundColor DarkGray
    Write-Host "    Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor DarkGray
    Write-Host ""
}

function Uninstall-Task {
    Write-Host "-- Uninstall Scheduled Task --" -ForegroundColor Yellow

    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "  Task '$TaskName' not found — nothing to remove." -ForegroundColor DarkGray
        return
    }

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "  Scheduled task '$TaskName' removed." -ForegroundColor Green
    Write-Host ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

Write-Header
Setup-Venv

while ($true) {
    Write-Host "What would you like to do?" -ForegroundColor Yellow
    Write-Host "  [1] Install scheduled task"
    Write-Host "  [2] Uninstall scheduled task"
    Write-Host "  [3] Exit"
    Write-Host ""

    $choice = Read-Host "Choice"

    switch ($choice) {
        "1"     { Install-Task }
        "2"     { Uninstall-Task }
        "3"     { Write-Host "Bye."; exit }
        default { Write-Host "  Invalid choice, try again.`n" -ForegroundColor Red }
    }
}
