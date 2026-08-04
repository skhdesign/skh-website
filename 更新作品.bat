@echo off
chcp 65001 >nul
title SKH DESIGN - 更新作品
cd /d "%~dp0"

echo.
echo ========================================
echo   SKH DESIGN 作品自動更新
echo ========================================
echo.
echo 系統正在掃描 projects-data 資料夾...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate-projects.ps1"

if errorlevel 1 (
  echo.
  echo [更新失敗]
  echo 請查看上方紅色錯誤訊息。
  echo 常見原因：info.txt 欄位漏填、網址代號使用中文、沒有照片。
  echo.
  pause
  exit /b 1
)

echo.
echo 更新成功。
echo 接著請打開 GitHub Desktop，執行 Commit 與 Push origin。
echo.
pause
