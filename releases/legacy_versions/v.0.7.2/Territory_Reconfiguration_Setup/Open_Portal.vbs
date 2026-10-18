' ============================================================================
' PIMS Territory Reconfiguration Web Portal - Portable Direct Launcher
' Double-click to open immediately in your web browser with NO command prompt!
' ============================================================================
Option Explicit

Dim WshShell, fso, appDir, launcherPath
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

appDir = fso.GetParentFolderName(WScript.ScriptFullName)
launcherPath = fso.BuildPath(appDir, "launch_portal.vbs")

If fso.FileExists(launcherPath) Then
    WshShell.Run "wscript.exe """ & launcherPath & """", 0, False
Else
    Dim htmlPath
    htmlPath = fso.BuildPath(appDir, "territory_reconfiguration_portal.html")
    If fso.FileExists(htmlPath) Then
        WshShell.Run """" & htmlPath & """", 1, False
    Else
        MsgBox "Cannot find territory_reconfiguration_portal.html!", 16, "Error"
    End If
End If
