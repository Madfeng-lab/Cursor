@echo off
rem One-click start script for backend (Spring Boot) and frontend (Flutter)
rem Usage: start-all.bat

set "ROOT=%~dp0"

rem Start backend in a new cmd window
start "Backend" cmd /k "cd /d "%ROOT%backend" && mvn spring-boot:run"

rem Start frontend in a new cmd window
start "Frontend" cmd /k "cd /d "%ROOT%frontend" && flutter pub get && flutter run -d chrome"

echo Started backend and frontend in separate windows.
pause
