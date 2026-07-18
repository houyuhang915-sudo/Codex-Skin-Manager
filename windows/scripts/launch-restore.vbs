Option Explicit

Dim shell, fileSystem, scriptDirectory, restoreScript, command, index, exitCode
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")
scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
restoreScript = fileSystem.BuildPath(scriptDirectory, "restore-dream-skin.ps1")
command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & restoreScript & """ -RestoreBaseTheme -PromptRestart"
For index = 0 To WScript.Arguments.Count - 1
  command = command & " " & WScript.Arguments(index)
Next
exitCode = shell.Run(command, 0, True)
If exitCode <> 0 Then
  MsgBox "Dream Skin restore failed. Exit code: " & exitCode, vbCritical, "Codex Skin Manager"
End If
