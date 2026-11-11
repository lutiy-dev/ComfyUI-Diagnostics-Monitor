@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title ComfyUI Diagnostics LAB - Install or Update

if not exist "%~dp0install.ps1" (
  echo ERROR: install.ps1 not found next to this launcher.
  pause
  exit /b 2
)

echo.
echo   ComfyUI Diagnostics LAB - Install / Update
echo.
echo   [1] HOME  - RTX 3070 Ti
echo   [2] WORK  - RTX 4090
echo.
choice /C 12 /N /M "Select computer [1/2]: "
if errorlevel 2 (set "MACHINE=WORK") else (set "MACHINE=HOME")

echo.
echo Target: %MACHINE%
echo This will install or upgrade program files for the current user.
echo Your existing diagnostic JSON and JSONL data are stored separately.
echo Close the Dashboard, Collector and Configurator before continuing.
echo No driver, model, registry or ComfyUI settings will be changed.
echo.
choice /C YN /N /M "Continue [Y/N]? "
if errorlevel 2 exit /b 0

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Machine "%MACHINE%" -Upgrade
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" (
  echo.
  echo FAIL: install.ps1 returned exit code %RESULT%.
  echo No automatic uninstall or deletion was attempted.
  pause
  exit /b %RESULT%
)
echo.
echo PASS: installer completed. Open Dashboard from the Start Menu.
pause
exit /b 0
