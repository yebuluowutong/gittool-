# Git Push / Pull GUI Tool

Windows 系统下的 Git 推送/拉取图形化工具，采用 Google Material Design 风格界面，单文件免安装，双击即用。

## 功能特性

| 功能 | 说明 |
|------|------|
| 推送/拉取 | 一键推送代码到远程仓库或拉取最新代码 |
| 自动重试 | 网络不稳定时推送/拉取自动重试（最多 3 次） |
| 分支选择 | 支持当前分支、main、master 或自定义输入 |
| 自适应 | 自动适配不同屏幕分辨率和 DPI |
| 引导提示 | 首次使用自动弹出使用说明 |
| 环境检测 | 自动检测 Git 仓库和远程地址配置 |

## 快速开始

### 运行

双击 `git-tool.vbs` 静默启动，或右键 `push.ps1` → 使用 PowerShell 运行。

### 使用流程

1. 打开工具，默认选择「推送代码 (Push)」
2. 选择目标分支（当前分支 / main / master / 自定义）
3. 填写提交信息，点击「执行」


## 技术实现

- **框架**: PowerShell + Windows Forms
- **编码**: UTF-8 BOM
- **适配**: 基于 1920x1080 基准分辨率自动缩放（0.8~1.2x）

## 依赖

- Windows 10 或更高版本
- Git for Windows（已安装并配置 SSH/HTTPS）

## 许可证

本项目基于 Apache License 2.0 开源 — 详见 [LICENSE](LICENSE) 文件。
