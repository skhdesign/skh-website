@echo off
chcp 65001 >nul
title SKH DESIGN - 建立新案件
cd /d "%~dp0"

echo.
echo ========================================
echo   建立新的案件資料夾
echo ========================================
echo.
set /p CASEFOLDER=請輸入案件資料夾名稱（建議英文，例如 sanxing-house）：

if "%CASEFOLDER%"=="" (
  echo 未輸入名稱，已取消。
  pause
  exit /b 1
)

if exist "%~dp0projects-data\%CASEFOLDER%" (
  echo.
  echo 此資料夾已存在：projects-data\%CASEFOLDER%
  pause
  exit /b 1
)

xcopy "%~dp0projects-data\_新增案件範例_請複製" "%~dp0projects-data\%CASEFOLDER%\" /E /I /Y >nul

echo.
echo 已建立：
echo projects-data\%CASEFOLDER%
echo.
echo 接著請：
echo 1. 打開該資料夾的 info.txt
echo 2. 填寫案件資料，將「發布」改成「是」
echo 3. 放入 cover.jpg、01.jpg、02.jpg...
echo 4. 雙擊「更新作品.bat」
echo.
start "" "%~dp0projects-data\%CASEFOLDER%"
pause
