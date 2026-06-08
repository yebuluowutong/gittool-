# Git Push / Pull GUI Tool

Windows 系统下的 Git 推送/拉取图形化工具，采用 Google Material Design 风格界面，单文件免安装，双击即用。

## 功能特性

| 功能 | 说明 |
|------|------|
| 推送/拉取 | 一键推送代码到远程仓库或拉取最新代码 |
| 自动重试 | 网络不稳定时推送/拉取自动重试（最多 3 次） |
| 分支选择 | 支持当前分支、main、master 或自定义输入 |
| 文件筛选 | 可视化文件树浏览器，可勾选忽略指定文件/目录 |
| 智能默认 | 符合 .gitignore 规则的文件默认勾选忽略 |
| 自适应 | 自动适配不同屏幕分辨率和 DPI |
| 引导提示 | 首次使用自动弹出使用说明 |
| 环境检测 | 自动检测 Git 仓库和远程地址配置 |

## 快速开始

### 运行

直接双击 `git-tool.exe` 即可，无需安装。

### 编译

如需自行编译，安装 PS2EXE 模块后执行：

```powershell
Install-Module -Name PS2EXE -Force
Invoke-PS2EXE -inputFile "push.ps1" -outputFile "git-tool.exe" -noConsole -title "Git Push / Pull"
```

## 技术实现

- **框架**: PowerShell + Windows Forms
- **编码**: UTF-8 BOM
- **打包**: PS2EXE-GUI v0.5.0.33
- **适配**: 基于 1920x1080 基准分辨率自动缩放（0.8~1.2x）

## 依赖

- Windows 10 或更高版本
- Git for Windows（已安装并配置 SSH/HTTPS）

## 许可证

本项目基于 Apache License 2.0 开源 — 详见 [LICENSE](LICENSE) 文件。
