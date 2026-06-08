Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
scriptPath = fso.GetParentFolderName(WScript.ScriptFullName) & "\push.ps1"
If Not fso.FileExists(scriptPath) Then
    MsgBox "�Ҳ��� push.ps1 �ļ�", 16, "����"
    WScript.Quit
End If
cmd = "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & scriptPath & """"
shell.Run cmd, 0, False