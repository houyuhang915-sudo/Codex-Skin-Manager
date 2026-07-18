Option Explicit

Dim shell, fileSystem, scriptDirectory, managerScript, command, exitCode
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")
scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
managerScript = fileSystem.BuildPath(scriptDirectory, "theme-manager.ps1")
command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File """ & managerScript & """"
exitCode = shell.Run(command, 0, True)
If exitCode <> 0 Then
  MsgBox "Codex Skin Manager failed to start. Exit code: " & exitCode, vbCritical, "Codex Skin Manager"
End If
