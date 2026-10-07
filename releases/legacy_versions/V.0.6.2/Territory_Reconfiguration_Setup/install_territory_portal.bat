@echo off
setlocal EnableDelayedExpansion
title Territory Reconfiguration Portal - Standalone Laptop Setup

echo =======================================================================
echo   PIMS Territory Reconfiguration Web Portal - Setup Wizard
echo   Version: V.0.5.2 (SFE Laptop Edition)
echo =======================================================================
echo.
echo Installing Territory Reconfiguration Portal onto your laptop...
echo.

set "INSTALL_DIR=%LOCALAPPDATA%\PIMS\TerritoryReconfigurationApp"

echo [1/4] Preparing application directory...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo [2/4] Copying application assets and icons...
copy /Y "%~dp0territory_reconfiguration_portal.html" "%INSTALL_DIR%\" >nul
copy /Y "%~dp0server.py" "%INSTALL_DIR%\" >nul
copy /Y "%~dp0launch_portal.vbs" "%INSTALL_DIR%\" >nul
copy /Y "%~dp0Open_Portal.vbs" "%INSTALL_DIR%\" >nul
copy /Y "%~dp0run_territory_portal.bat" "%INSTALL_DIR%\" >nul
copy /Y "%~dp0Run_Portable_Without_Install.bat" "%INSTALL_DIR%\" >nul
if exist "%~dp0app_icon.ico" copy /Y "%~dp0app_icon.ico" "%INSTALL_DIR%\" >nul
if exist "%~dp0uninstall.vbs" copy /Y "%~dp0uninstall.vbs" "%INSTALL_DIR%\" >nul
if exist "%~dp0uninstall.bat" copy /Y "%~dp0uninstall.bat" "%INSTALL_DIR%\" >nul
if exist "%~dp0README_INSTALL.txt" copy /Y "%~dp0README_INSTALL.txt" "%INSTALL_DIR%\" >nul

echo [3/4] Creating Windows Desktop and Start Menu shortcuts (Zero-Command-Prompt)...
set "ICON_PARAM="
if exist "%INSTALL_DIR%\app_icon.ico" set "ICON_PARAM=$sc.IconLocation = '%INSTALL_DIR%\app_icon.ico,0';"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $desk = [Environment]::GetFolderPath('Desktop'); $sc = $ws.CreateShortcut(\"$desk\Territory Reconfiguration Portal.lnk\"); $sc.TargetPath = 'wscript.exe'; $sc.Arguments = '\"%INSTALL_DIR%\launch_portal.vbs\"'; $sc.WorkingDirectory = '%INSTALL_DIR%'; %ICON_PARAM% $sc.Description = 'PIMS Territory Reconfiguration Portal - SFE Edition'; $sc.Save()"

set "SM_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\PIMS"
if not exist "%SM_DIR%" mkdir "%SM_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $sc = $ws.CreateShortcut(\"%SM_DIR%\Territory Reconfiguration Portal.lnk\"); $sc.TargetPath = 'wscript.exe'; $sc.Arguments = '\"%INSTALL_DIR%\launch_portal.vbs\"'; $sc.WorkingDirectory = '%INSTALL_DIR%'; %ICON_PARAM% $sc.Description = 'PIMS Territory Reconfiguration Portal - SFE Edition'; $sc.Save()"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $sc = $ws.CreateShortcut(\"%SM_DIR%\Uninstall Portal.lnk\"); $sc.TargetPath = 'wscript.exe'; $sc.Arguments = '\"%INSTALL_DIR%\uninstall.vbs\"'; $sc.WorkingDirectory = '%INSTALL_DIR%'; $sc.Description = 'Uninstall Territory Reconfiguration Portal'; $sc.Save()"

echo [4/4] Verifying installation files...
if exist "%INSTALL_DIR%\territory_reconfiguration_portal.html" (
    echo.
    echo =======================================================================
    echo   INSTALLATION COMPLETED SUCCESSFULLY!
    echo =======================================================================
    echo.
    echo   Installed Location:
    echo   %INSTALL_DIR%
    echo.
    echo   Desktop Shortcut:
    echo   "Territory Reconfiguration Portal" (Opens directly in browser - NO cmd!)
    echo.
    echo   Start Menu:
    echo   Programs > PIMS > Territory Reconfiguration Portal
    echo.
    echo =======================================================================
    echo.
    set /p LAUNCH="Would you like to launch the Territory Reconfiguration Portal now? (Y/N): "
    if /i "!LAUNCH!"=="Y" (
        start "" wscript.exe "%INSTALL_DIR%\launch_portal.vbs"
    )
) else (
    echo.
    echo [ERROR] Installation could not copy application files.
    echo Please check write permissions for: %INSTALL_DIR%
)

echo.
pause
