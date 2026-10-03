# FixAll.ps1 - Ghi lai tat ca file bat dung chuan ANSI
$ansi = [System.Text.Encoding]::GetEncoding(1252)
$utf8bom = [System.Text.UTF8Encoding]::new($true)
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "" 
Write-Host "  Ghi lai file bat voi encoding ANSI..." -ForegroundColor Cyan
Write-Host "  Thu muc: $dir" -ForegroundColor DarkGray
Write-Host ""

# ── SystemCheck.bat ─────────────────────────────────────────
$sysCheck = @'
@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1
cls
echo.
echo  ===================================================
echo   SYSTEM ERROR CHECKER v2.0
echo   Kiem tra nguyen nhan may tat bat thuong
echo  ===================================================
echo.
echo  Thoi gian: %date% %time%
echo.
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [LOI] Can quyen Administrator!
    echo  Chuot phai vao file nay, chon Run as administrator
    pause
    exit /b 1
)
echo  [OK] Quyen Administrator: Da xac nhan
if not exist "%~dp0reports" mkdir "%~dp0reports"
if not exist "%~dp0logs"    mkdir "%~dp0logs"
echo.
echo  Chon che do kiem tra:
echo   [1] Loi he thong va Event Log
echo   [2] Phan cung toi da (chi doc)
echo   [3] Stress test CPU va RAM (kiem tra tan nhiet/nguon)
echo.
choice /c 123 /n /m "  Lua chon [1-3]: "
if errorlevel 3 (
    set "CHECK_SCRIPT=%~dp0scripts\StressTest.ps1"
    set "REPORT_PREFIX=StressReport"
    set "LOG_PREFIX=StressLog"
) else if errorlevel 2 (
    set "CHECK_SCRIPT=%~dp0scripts\HardwareCheck.ps1"
    set "REPORT_PREFIX=HardwareReport"
    set "LOG_PREFIX=HardwareLog"
) else (
    set "CHECK_SCRIPT=%~dp0scripts\CheckSystemErrors.ps1"
    set "REPORT_PREFIX=Report"
    set "LOG_PREFIX=Log"
)
set "DT=%date:~6,4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "DT=%DT: =0%"
set "RPT=%~dp0reports\%REPORT_PREFIX%_%DT%.html"
set "LOG=%~dp0logs\%LOG_PREFIX%_%DT%.txt"
echo  [*] Dang quet he thong...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CHECK_SCRIPT%" -ReportPath "%RPT%" -LogPath "%LOG%"
if %errorlevel% neq 0 (
    echo.
    echo  [LOI] Script that bai! Kiem tra PowerShell 5.1+
    pause
    exit /b 1
)
echo.
echo  ===================================================
echo   HOAN THANH!
echo   Bao cao: %RPT%
echo   Log    : %LOG%
echo  ===================================================
echo.
set /p "OPN=  Mo bao cao HTML? (Y/N): "
if /i "%OPN%"=="Y" start "" "%RPT%"
echo.
echo  Nhan phim bat ky de thoat...
pause >nul
endlocal
'@

# ── Setup.bat ────────────────────────────────────────────────
$setup = @'
@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1
cls
echo.
echo  ===================================================
echo   SETUP - Cai dat SystemCheck
echo   Tao shortcut va lich quet tu dong
echo  ===================================================
echo.
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [LOI] Can quyen Administrator!
    echo  Chuot phai vao file nay, chon Run as administrator
    pause
    exit /b 1
)
echo  [OK] Quyen Administrator: Da xac nhan
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Setup.ps1" -ScriptDir "%~dp0"
echo.
echo  Nhan phim bat ky de thoat...
pause >nul
endlocal
'@

# ── QuickCheck.bat ───────────────────────────────────────────
$quick = @'
@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1
set "DAYS=7"
if not "%~1"=="" set "DAYS=%~1"
cls
echo.
echo  -------------------------------------------
echo   QUICK CHECK - Kiem tra nhanh (%DAYS% ngay)
echo   Khong can quyen Admin
echo  -------------------------------------------
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\QuickCheck.ps1" -DaysBack %DAYS%
echo.
pause
endlocal
'@

# ── scripts\Setup.ps1 ────────────────────────────────────────
$setupPS = @'
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
'@

# ── scripts\QuickCheck.ps1 ───────────────────────────────────
$quickPS = @'
param([int]$DaysBack = 7)
$start = (Get-Date).AddDays(-$DaysBack)
Write-Host ""
Write-Host "  [HE THONG]" -ForegroundColor Cyan
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "  May tinh : $env:COMPUTERNAME"
Write-Host "  OS       : $($os.Caption)"
Write-Host "  Boot cuoi: $($os.LastBootUpTime.ToString('dd/MM/yyyy HH:mm:ss'))"
$up = (Get-Date) - $os.LastBootUpTime
Write-Host "  Uptime   : $($up.Days)d $($up.Hours)h $($up.Minutes)m"
Write-Host ""
Write-Host "  [TAT MAY - $DaysBack ngay]" -ForegroundColor Cyan
try { $e41   = @(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-Kernel-Power';Id=41;StartTime=$start} -EA Stop).Count } catch { $e41=0 }
try { $e6008 = @(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='EventLog';Id=6008;StartTime=$start} -EA Stop).Count } catch { $e6008=0 }
try { $e6006 = @(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='EventLog';Id=6006;StartTime=$start} -EA Stop).Count } catch { $e6006=0 }
if ($e41   -gt 0) { Write-Host "  TAT DOT NGOT (ID 41) : $e41 LAN! <- NGUYEN NHAN CHINH" -ForegroundColor Red }
else              { Write-Host "  Tat dot ngot (ID 41) : Khong co" -ForegroundColor Green }
if ($e6008 -gt 0) { Write-Host "  DIRTY SHUTDOWN(6008) : $e6008 LAN!" -ForegroundColor Yellow }
else              { Write-Host "  Dirty Shutdown (6008): Khong co" -ForegroundColor Green }
Write-Host "  Tat binh thuong(6006): $e6006 lan" -ForegroundColor Gray
Write-Host ""
Write-Host "  [BSOD]" -ForegroundColor Cyan
$dp = 0
if (Test-Path "$env:SystemRoot\Minidump") {
    $dp = @(Get-ChildItem "$env:SystemRoot\Minidump" -Filter "*.dmp" -EA SilentlyContinue | Where-Object { $_.LastWriteTime -gt $start }).Count
}
if ($dp -gt 0) { Write-Host "  MINIDUMP: $dp FILE! <- CO BSOD" -ForegroundColor Red }
else           { Write-Host "  Minidump : Khong co" -ForegroundColor Green }
Write-Host ""
Write-Host "  [O DIA]" -ForegroundColor Cyan
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object {
    $pct  = [math]::Round($_.Used/($_.Used+$_.Free)*100,1)
    $free = [math]::Round($_.Free/1GB,1)
    $col  = if($pct-gt 90){"Red"}elseif($pct-gt 75){"Yellow"}else{"Green"}
    Write-Host "  O $($_.Name): $free GB trong  ($pct% da dung)" -ForegroundColor $col
}
Write-Host ""
if ($e41-gt 0 -or $dp-gt 0) {
    Write-Host "  KET LUAN: CO VAN DE! Chay SystemCheck.bat de xem bao cao HTML." -ForegroundColor Red
} else {
    Write-Host "  KET LUAN: Khong phat hien van de ro rang." -ForegroundColor Green
}
Write-Host ""
'@

# ── Ghi tat ca file ─────────────────────────────────────────
[System.IO.File]::WriteAllText("$dir\SystemCheck.bat",      $sysCheck, $ansi)
Write-Host "  [OK] SystemCheck.bat" -ForegroundColor Green

[System.IO.File]::WriteAllText("$dir\Setup.bat",            $setup,    $ansi)
Write-Host "  [OK] Setup.bat" -ForegroundColor Green

[System.IO.File]::WriteAllText("$dir\QuickCheck.bat",       $quick,    $ansi)
Write-Host "  [OK] QuickCheck.bat" -ForegroundColor Green

[System.IO.File]::WriteAllText("$dir\scripts\Setup.ps1",    $setupPS,  $utf8bom)
Write-Host "  [OK] scripts\Setup.ps1" -ForegroundColor Green

[System.IO.File]::WriteAllText("$dir\scripts\QuickCheck.ps1", $quickPS, $utf8bom)
Write-Host "  [OK] scripts\QuickCheck.ps1" -ForegroundColor Green

# Xoa file txt cu
Remove-Item "$dir\FixAll.ps1.txt" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  XONG! Tat ca file da duoc ghi dung chuan ANSI." -ForegroundColor White
Write-Host ""
