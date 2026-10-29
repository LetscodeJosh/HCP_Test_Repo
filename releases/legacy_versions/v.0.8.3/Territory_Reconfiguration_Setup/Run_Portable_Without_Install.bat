@echo off
cd /d "%~dp0"
if exist "%~dp0launch_portal.vbs" (
    start "" wscript.exe "%~dp0launch_portal.vbs"
    exit /b 0
)
if exist "%~dp0territory_reconfiguration_portal.html" (
    start "" "%~dp0territory_reconfiguration_portal.html"
    exit /b 0
)
call "%~dp0run_territory_portal.bat"
