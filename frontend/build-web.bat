@echo off
setlocal

cd /d "%~dp0"

echo [1/3] Building Flutter web...
call flutter build web
if errorlevel 1 exit /b 1

echo [2/3] Copying exercise images into web build...
if not exist "build\web\assets\assets\images\exercises" (
  mkdir "build\web\assets\assets\images\exercises"
)
robocopy "assets\images\exercises" "build\web\assets\assets\images\exercises" /E /NFL /NDL /NJH /NJS /NC /NS >nul
if errorlevel 8 exit /b 1

echo [3/3] Web build is ready at frontend\build\web
endlocal
