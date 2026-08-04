@echo off
setlocal
cd /d "%~dp0"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& { $root='%~dp0'; $g=Join-Path $root 'generate-projects.ps1'; if (!(Test-Path $g)) { throw 'generate-projects.ps1 not found' }; & $g }"
if errorlevel 1 pause
endlocal
