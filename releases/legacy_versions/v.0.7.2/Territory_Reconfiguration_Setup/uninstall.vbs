' ============================================================================
' PIMS Territory Reconfiguration Web Portal - Uninstaller
' ============================================================================
Option Explicit

Dim WshShell, fso, installDir, deskPath, smDir, ans
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

installDir = WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%\PIMS\TerritoryReconfigurationApp")
deskPath = WshShell.SpecialFolders("Desktop")
smDir = WshShell.SpecialFolders("Programs") & "\PIMS"

ans = MsgBox("Are you sure you want to uninstall PIMS Territory Reconfiguration Portal from this laptop?", _
             vbYesNo + vbQuestion, "Uninstall Territory Reconfiguration Portal")

If ans <> vbYes Then
    WScript.Quit
End If

On Error Resume Next

' 1. Remove Desktop Shortcut
Dim deskLnk
deskLnk = fso.BuildPath(deskPath, "Territory Reconfiguration Portal.lnk")
If fso.FileExists(deskLnk) Then
    fso.DeleteFile deskLnk, True
End If

' 2. Remove Start Menu Folder & Shortcuts
If fso.FolderExists(smDir) Then
    fso.DeleteFolder smDir, True
End If

' 3. Remove Installation Files
If fso.FolderExists(installDir) Then
    fso.DeleteFolder installDir, True
End If

On Error GoTo 0

MsgBox "PIMS Territory Reconfiguration Portal has been completely uninstalled from your laptop.", _
       vbInformation, "Uninstall Complete"
