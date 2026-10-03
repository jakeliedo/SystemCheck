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