@echo off
setlocal
cd /d "%~dp0"
title SKH Website Manager
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0SKH-Website-Manager.ps1"
if errorlevel 1 (
  echo.
  echo SKH Website Manager failed to start.
  echo Please send SKH-Manager-Error.txt to ChatGPT.
  pause
)
endlocal
