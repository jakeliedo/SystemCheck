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