' ============================================================================
' PIMS Territory Reconfiguration Web Portal - Silent Launcher
' No Command Prompt / Terminal Window Required
' ============================================================================
Option Explicit

Dim WshShell, fso, appDir, serverPy, htmlPortal, http, isRunning, foundPy

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

appDir = fso.GetParentFolderName(WScript.ScriptFullName)
serverPy = fso.BuildPath(appDir, "server.py")
htmlPortal = fso.BuildPath(appDir, "territory_reconfiguration_portal.html")

' 1. Check if local server is already running on http://127.0.0.1:8765
isRunning = False
On Error Resume Next
Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")
If Not http Is Nothing Then
    http.setTimeouts 500, 500, 500, 500
    http.open "GET", "http://127.0.0.1:8765/api/status", False
    http.send
    If Err.Number = 0 And http.status = 200 Then
        isRunning = True
    End If
    Set http = Nothing
End If
Err.Clear
On Error GoTo 0

If isRunning Then
    ' Server already running, just open the browser directly
    WshShell.Run "http://127.0.0.1:8765/", 1, False
    WScript.Quit
End If

' 2. Try launching server.py in background via pythonw (GUI mode, 0 = hidden window)
foundPy = False

' Check 2a: Try pythonw.exe in PATH
On Error Resume Next
Err.Clear
WshShell.Run "pythonw.exe """ & serverPy & """", 0, False
If Err.Number = 0 Then
    foundPy = True
End If
Err.Clear

' Check 2b: Try pyw.exe in PATH if pythonw wasn't found
If Not foundPy Then
    WshShell.Run "pyw.exe """ & serverPy & """", 0, False
    If Err.Number = 0 Then
        foundPy = True
    End If
    Err.Clear
End If

' Check 2c: Search known user & system Python installations for pythonw.exe
If Not foundPy Then
    Dim localAppData, userPythonDir
    localAppData = WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%")
    userPythonDir = fso.BuildPath(localAppData, "Programs\Python")
    
    If fso.FolderExists(userPythonDir) Then
        Dim subFolder
        For Each subFolder In fso.GetFolder(userPythonDir).SubFolders
            Dim candidate
            candidate = fso.BuildPath(subFolder.Path, "pythonw.exe")
            If fso.FileExists(candidate) Then
                WshShell.Run """" & candidate & """ """ & serverPy & """", 0, False
                If Err.Number = 0 Then
                    foundPy = True
                    Exit For
                End If
                Err.Clear
            End If
        Next
    End If
End If

' Check 2d: Program Files Python
If Not foundPy Then
    Dim pf, pfDir
    pf = WshShell.ExpandEnvironmentStrings("%ProgramFiles%")
    If fso.FolderExists(pf) Then
        For Each subFolder In fso.GetFolder(pf).SubFolders
            If InStr(1, subFolder.Name, "Python", 1) > 0 Then
                candidate = fso.BuildPath(subFolder.Path, "pythonw.exe")
                If fso.FileExists(candidate) Then
                    WshShell.Run """" & candidate & """ """ & serverPy & """", 0, False
                    If Err.Number = 0 Then
                        foundPy = True
                        Exit For
                    End If
                    Err.Clear
                End If
            End If
        Next
    End If
End If
On Error GoTo 0

' 3. If Python was found and started, server.py will automatically open the browser.
' If Python is NOT installed on this laptop, launch standalone HTML directly in default browser!
If Not foundPy Then
    If fso.FileExists(htmlPortal) Then
        WshShell.Run """" & htmlPortal & """", 1, False
    Else
        MsgBox "Could not locate territory_reconfiguration_portal.html" & vbCrLf & "Please reinstall the portal.", 16, "PIMS Territory Portal"
    End If
End If
