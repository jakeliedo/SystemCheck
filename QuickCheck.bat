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