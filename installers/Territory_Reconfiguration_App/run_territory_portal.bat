@echo off
setlocal
title Territory Reconfiguration Portal - SFE Edition
cd /d "%~dp0"

echo =======================================================================
echo   PIMS Territory Reconfiguration Web Portal - SFE Edition
echo =======================================================================
echo.

:: Check if Python is installed
where python >nul 2>nul
if %errorlevel% equ 0 (
    echo [INFO] Python environment detected.
    echo [INFO] Starting local application server on http://127.0.0.1:8765...
    echo [INFO] A browser window will open automatically.
    echo.
    echo (You can minimize this window. Close it when you wish to stop the server.)
    echo.
    python "%~dp0server.py"
    goto end
)

where py >nul 2>nul
if %errorlevel% equ 0 (
    echo [INFO] Python launcher (py) detected.
    echo [INFO] Starting local application server on http://127.0.0.1:8765...
    echo [INFO] A browser window will open automatically.
    echo.
    echo (You can minimize this window. Close it when you wish to stop the server.)
    echo.
    py "%~dp0server.py"
    goto end
)

:: Standalone Offline SPA Fallback
echo [INFO] Python was not detected on this system.
echo [INFO] Launching Territory Reconfiguration Portal in your default web browser...
start "" "%~dp0territory_reconfiguration_portal.html"
echo.
echo [OK] Portal launched successfully in standalone browser mode!
timeout /t 3 >nul 2>&1
exit /b 0

:end
pause
