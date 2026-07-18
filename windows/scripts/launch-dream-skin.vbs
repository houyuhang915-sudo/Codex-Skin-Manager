Option Explicit

Dim shell, fileSystem, scriptDirectory, startScript, command, index, exitCode
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")
scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
startScript = fileSystem.BuildPath(scriptDirectory, "start-dream-skin.ps1")
command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & startScript & """ -PromptRestart"
For index = 0 To WScript.Arguments.Count - 1
  command = command & " " & WScript.Arguments(index)
Next
exitCode = shell.Run(command, 0, True)
If exitCode <> 0 And exitCode <> 3 Then
  MsgBox "Dream Skin failed to start. Exit code: " & exitCode, vbCritical, "Codex Skin Manager"
End If
