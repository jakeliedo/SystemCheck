param([string]$ScriptDir = "")
if (-not $ScriptDir) {
    $ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
$ScriptDir = $ScriptDir.TrimEnd('\','/')
Write-Host ""
Write-Host "  Thu muc: $ScriptDir" -ForegroundColor DarkGray
Write-Host ""
New-Item -ItemType Directory -Force -Path "$ScriptDir\reports" | Out-Null
New-Item -ItemType Directory -Force -Path "$ScriptDir\logs"    | Out-Null

Write-Host "  [1/4] Tao shortcut tren Desktop..." -ForegroundColor Cyan
try {
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut("$env:USERPROFILE\Desktop\SystemCheck.lnk")
    $lnk.TargetPath       = "$ScriptDir\SystemCheck.bat"
    $lnk.WorkingDirectory = $ScriptDir
    $lnk.Description      = "Kiem tra loi he thong"
    $lnk.Save()
    Write-Host "  [OK] $env:USERPROFILE\Desktop\SystemCheck.lnk" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Loi shortcut: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "  [2/4] Dat ExecutionPolicy..." -ForegroundColor Cyan
try {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
    Write-Host "  [OK] ExecutionPolicy = RemoteSigned" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Group Policy gioi han - khong sao, dung Bypass" -ForegroundColor Yellow
}

Write-Host "  [3/4] Tao Scheduled Task (auto quet sau khi dang nhap)..." -ForegroundColor Cyan
try {
    $taskName = "SystemCheck-OnStartup"
    $ps1File  = "$ScriptDir\scripts\CheckSystemErrors.ps1"
    $rptFile  = "$ScriptDir\reports\AutoReport.html"
    $logFile  = "$ScriptDir\logs\AutoLog.txt"
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ps1File`" -ReportPath `"$rptFile`" -LogPath `"$logFile`""
    $action   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg
    $trigger  = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force | Out-Null
    Write-Host "  [OK] Task: $taskName" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Khong tao duoc task: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "  [4/4] Hoan tat!" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "  CAI DAT HOAN THANH!" -ForegroundColor White
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  1. Double-click shortcut SystemCheck tren Desktop" -ForegroundColor Gray
Write-Host "  2. Chay SystemCheck.bat (bao cao HTML, can Admin)" -ForegroundColor Gray
Write-Host "  3. Chay QuickCheck.bat  (nhanh, khong can Admin)" -ForegroundColor Gray
Write-Host ""