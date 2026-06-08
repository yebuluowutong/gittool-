# Git Push / Pull GUI Tool

Windows 系统下的 Git 推送/拉取图形化工具，采用 Google Material Design 风格界面，单文件免安装，双击即用。

## 功能特性

| 功能 | 说明 |
|------|------|
| 推送/拉取 | 一键推送代码到远程仓库或拉取最新代码 |
| 自动重试 | 网络不稳定时推送/拉取自动重试（最多 3 次） |
| 分支选择 | 支持当前分支、main、master 或自定义输入 |
| 文件排除 | 可视化文件树浏览器，可勾选排除不需要推送的文件/目录 |
| 默认全量推送 | 新文件 + 修改全部推送，只需手动排除不需要的部分 |
| 排除持久化 | 排除列表写入 `.gitignore` 的标记区域，下次自动加载 |
| 智能默认 | `.gitignore` 已有规则的文件自动勾选为排除 |
| 自适应 | 自动适配不同屏幕分辨率和 DPI |
| 引导提示 | 首次使用自动弹出使用说明 |
| 环境检测 | 自动检测 Git 仓库和远程地址配置 |

## 快速开始

### 运行

双击 `git-tool.vbs` 静默启动，或双击 `git-tool.exe` 启动（显示控制台窗口）。

### 使用流程

1. 打开工具，默认选择「推送代码 (Push)」
2. 选择目标分支（当前分支 / main / master / 自定义）
3. **默认** → 全量推送所有变更（新文件 + 修改 + 删除）
4. **如需排除文件** → 勾选「选择要排除的文件」→ 点击「选择排除」→ 在文件树中勾选要排除的文件
5. 填写提交信息，点击「执行」

> 排除列表会自动保存到 `.gitignore` 的标记区域（`# === Git Push Tool 排除列表 ===`），下次打开无需重新选择。

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

## 排除机制说明

本工具通过 `git add -A` 全量暂存变更，再对排除文件执行 `git reset HEAD` 撤销暂存，实现「默认全量推送，手动选择排除」的流程。

排除列表持久化到 `.gitignore` 文件的标记区域中：

```gitignore
# 已有的 .gitignore 规则...
node_modules/

# === Git Push Tool 排除列表 ===
dist/output.css
src/temp.js
# === Git Push Tool 结束 ===
```

这样既遵循 Git 标准机制，又不引入额外文件。

## 依赖

- Windows 10 或更高版本
- Git for Windows（已安装并配置 SSH/HTTPS）

## 许可证

本项目基于 Apache License 2.0 开源 — 详见 [LICENSE](LICENSE) 文件。
