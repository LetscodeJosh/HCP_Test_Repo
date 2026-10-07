@echo off
setlocal EnableDelayedExpansion
title Uninstall Territory Reconfiguration Portal

echo =======================================================================
echo   PIMS Territory Reconfiguration Portal - Uninstaller
echo =======================================================================
echo.
echo This will remove the Territory Reconfiguration Portal and its shortcuts
echo from your laptop.
echo.
set /p CONFIRM="Are you sure you want to uninstall? (Y/N): "
if /i not "!CONFIRM!"=="Y" (
    echo.
    echo Uninstallation cancelled.
    pause
    exit /b 0
)

echo.
echo [1/3] Removing desktop and start menu shortcuts...
set "DESK_SHORTCUT=%USERPROFILE%\Desktop\Territory Reconfiguration Portal.lnk"
if exist "%DESK_SHORTCUT%" del /f /q "%DESK_SHORTCUT%" >nul 2>&1

set "SM_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\PIMS"
if exist "%SM_DIR%" (
    del /f /q "%SM_DIR%\*.*" >nul 2>&1
    rd /s /q "%SM_DIR%" >nul 2>&1
)

echo [2/3] Cleaning up application files...
set "INSTALL_DIR=%LOCALAPPDATA%\PIMS\TerritoryReconfigurationApp"

:: Attempt to remove files in install directory
if exist "%INSTALL_DIR%" (
    :: Run delayed deletion script so uninstaller can delete itself
    start "" /b cmd /c "timeout /t 1 >nul 2>&1 & rd /s /q \"%INSTALL_DIR%\" >nul 2>&1"
)

echo [3/3] Finalizing removal...
echo.
echo =======================================================================
echo   Territory Reconfiguration Portal has been successfully uninstalled.
echo =======================================================================
echo.
pause
