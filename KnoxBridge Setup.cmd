@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\user-setup.ps1"
if errorlevel 1 (
  echo.
  echo Setup could not finish. See the message above.
  pause
)
