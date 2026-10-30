@echo off
cd /d "%~dp0"
if exist "%~dp0Setup.vbs" (
    start "" wscript.exe "%~dp0Setup.vbs"
    exit /b 0
)
call "%~dp0install_territory_portal.bat"
