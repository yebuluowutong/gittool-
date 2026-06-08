# PS2EXE 编译脚本
# 用法：运行此脚本即可编译 git-tool.exe

cd "D:\trea\trea-main"

# 编译参数说明：
# -inputFile       输入的 PowerShell 脚本路径
# -outputFile      输出的 exe 文件路径
# -noConsole       无控制台窗口（GUI 模式）
# -title           exe 文件标题信息
# -version         exe 文件版本
# -description     exe 文件描述
# -company         公司名称
# -product         产品名称
# -iconFile        exe 图标文件路径（可选）
# -requireAdmin    需要管理员权限运行
# -supportOS       支持 Windows 10/11 风格
# -noOutput        不输出任何信息
# -noError         不输出错误信息
# -credentialGUI   使用 GUI 方式获取凭据
# -debug           编译为调试版本

Invoke-PS2EXE `
    -inputFile "push.ps1" `
    -outputFile "git-tool.exe" `
    -noConsole `
    -title "Git Push / Pull" `
    -version "1.0.0.3" `
    -description "Git Push / Pull GUI Tool" `
    -company "" `
    -product "Git Push / Pull"

Write-Host "编译完成！生成文件：git-tool.exe"
