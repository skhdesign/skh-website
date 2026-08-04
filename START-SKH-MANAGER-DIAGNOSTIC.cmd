@echo off
setlocal
cd /d "%~dp0"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0SKH-Website-Manager.ps1" 1>"%~dp0SKH-Manager-Output.txt" 2>"%~dp0SKH-Manager-Error.txt"
set "RC=%ERRORLEVEL%"
echo Exit code: %RC%
echo.
if not "%RC%"=="0" (
  type "%~dp0SKH-Manager-Error.txt"
)
pause
endlocal
