' ============================================================================
' PIMS Territory Reconfiguration Web Portal - Generic GUI Installer
' Requires NO Administrator Rights & NO Command Prompt Window
' ============================================================================
Option Explicit

Dim WshShell, fso, srcDir, installDir, deskPath, smDir, ans, res
Dim filesToCopy, fileItem, srcFile, destFile, scDesktop, scStartMenu, scUninstall
Dim iconPath

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

srcDir = fso.GetParentFolderName(WScript.ScriptFullName)
installDir = WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%\PIMS\TerritoryReconfigurationApp")
deskPath = WshShell.SpecialFolders("Desktop")
smDir = WshShell.SpecialFolders("Programs") & "\PIMS"

' 1. Prompt User with Native Setup Dialog
ans = MsgBox("Welcome to PIMS Territory Reconfiguration Web Portal Setup (V.0.5.2)." & vbCrLf & vbCrLf & _
             "Would you like to install the portal onto this laptop?" & vbCrLf & vbCrLf & _
             "• Creates Desktop shortcut with official PIMS icon" & vbCrLf & _
             "• Creates Windows Start Menu shortcuts" & vbCrLf & _
             "• Requires ZERO command prompt to open or use" & vbCrLf & _
             "• Requires NO administrator privileges", _
             vbYesNo + vbInformation, "PIMS Territory Portal Setup")

If ans <> vbYes Then
    WScript.Quit
End If

' 2. Create Application Directory in %LOCALAPPDATA%
On Error Resume Next
If Not fso.FolderExists(WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%\PIMS")) Then
    fso.CreateFolder(WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%\PIMS"))
End If
If Not fso.FolderExists(installDir) Then
    fso.CreateFolder(installDir)
End If

' 3. Copy Application Files
filesToCopy = Array(_
    "territory_reconfiguration_portal.html", _
    "server.py", _
    "launch_portal.vbs", _
    "Open_Portal.vbs", _
    "run_territory_portal.bat", _
    "Run_Portable_Without_Install.bat", _
    "app_icon.ico", _
    "uninstall.vbs", _
    "uninstall.bat", _
    "README_INSTALL.txt" _
)

For Each fileItem In filesToCopy
    srcFile = fso.BuildPath(srcDir, fileItem)
    destFile = fso.BuildPath(installDir, fileItem)
    If fso.FileExists(srcFile) Then
        fso.CopyFile srcFile, destFile, True
    End If
Next

' 4. Create Desktop Shortcut (Launches via wscript - ZERO command prompt window!)
iconPath = fso.BuildPath(installDir, "app_icon.ico")

Set scDesktop = WshShell.CreateShortcut(fso.BuildPath(deskPath, "Territory Reconfiguration Portal.lnk"))
scDesktop.TargetPath = "wscript.exe"
scDesktop.Arguments = """" & fso.BuildPath(installDir, "launch_portal.vbs") & """"
scDesktop.WorkingDirectory = installDir
scDesktop.Description = "PIMS Territory Reconfiguration Portal - SFE Edition"
If fso.FileExists(iconPath) Then
    scDesktop.IconLocation = iconPath & ",0"
End If
scDesktop.Save

' 5. Create Start Menu Shortcuts
If Not fso.FolderExists(smDir) Then
    fso.CreateFolder(smDir)
End If

Set scStartMenu = WshShell.CreateShortcut(fso.BuildPath(smDir, "Territory Reconfiguration Portal.lnk"))
scStartMenu.TargetPath = "wscript.exe"
scStartMenu.Arguments = """" & fso.BuildPath(installDir, "launch_portal.vbs") & """"
scStartMenu.WorkingDirectory = installDir
scStartMenu.Description = "PIMS Territory Reconfiguration Portal - SFE Edition"
If fso.FileExists(iconPath) Then
    scStartMenu.IconLocation = iconPath & ",0"
End If
scStartMenu.Save

Set scUninstall = WshShell.CreateShortcut(fso.BuildPath(smDir, "Uninstall Portal.lnk"))
scUninstall.TargetPath = "wscript.exe"
scUninstall.Arguments = """" & fso.BuildPath(installDir, "uninstall.vbs") & """"
scUninstall.WorkingDirectory = installDir
scUninstall.Description = "Uninstall PIMS Territory Reconfiguration Portal"
scUninstall.Save

On Error GoTo 0

' 6. Verification & Launch Prompt
If fso.FileExists(fso.BuildPath(installDir, "territory_reconfiguration_portal.html")) Then
    res = MsgBox("INSTALLATION COMPLETED SUCCESSFULLY!" & vbCrLf & vbCrLf & _
                 "The Territory Reconfiguration Portal has been installed to:" & vbCrLf & _
                 "  • Desktop: 'Territory Reconfiguration Portal'" & vbCrLf & _
                 "  • Start Menu: Programs > PIMS" & vbCrLf & vbCrLf & _
                 "Would you like to launch the portal now?", _
                 vbYesNo + vbInformation, "Installation Complete")
    If res = vbYes Then
        WshShell.Run "wscript.exe """ & fso.BuildPath(installDir, "launch_portal.vbs") & """", 0, False
    End If
Else
    MsgBox "Installation encountered an issue copying files." & vbCrLf & _
           "Please check folder permissions for:" & vbCrLf & installDir, _
           vbCritical, "Installation Error"
End If
