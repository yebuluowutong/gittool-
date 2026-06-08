# 强制 Git 输出 UTF-8 编码（解决中文乱码）
$env:GIT_TERMINAL_PROMPT = "0"

# 设置控制台代码页为 UTF-8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 屏幕自适应缩放
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$refWidth = 1920
$scaleX = [math]::Max(0.8, [math]::Min(1.2, $screen.WorkingArea.Width / $refWidth))
$refHeight = 1080
$scaleY = [math]::Max(0.8, [math]::Min(1.2, $screen.WorkingArea.Height / $refHeight))
$s = $scaleX

function S($w, $h) { New-Object System.Drawing.Size([int]($w * $s), [int]($h * $s)) }
function P($x, $y) { New-Object System.Drawing.Point([int]($x * $s), [int]($y * $s)) }
function F($sz) { $sz * $s }

[System.Windows.Forms.Application]::EnableVisualStyles()

# Google Material Design 颜色
$bgColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
$cardBg = [System.Drawing.Color]::FromArgb(255, 255, 255)
$primaryColor = [System.Drawing.Color]::FromArgb(26, 115, 232)
$primaryDark = [System.Drawing.Color]::FromArgb(21, 97, 198)
$textPrimary = [System.Drawing.Color]::FromArgb(32, 33, 36)
$textSecondary = [System.Drawing.Color]::FromArgb(95, 99, 104)
$borderColor = [System.Drawing.Color]::FromArgb(232, 234, 237)
$inputBg = [System.Drawing.Color]::FromArgb(248, 249, 250)

# 主窗口
$form = New-Object System.Windows.Forms.Form
$form.Text = "Git Push / Pull"
$form.Size = S 640 810
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10))
$form.BackColor = $bgColor

# 首次使用引导（使用注册表记录，无需额外文件）
$regPath = "HKCU:\Software\GitToolFirstRun"
if (-not (Test-Path $regPath)) {
    $guideText = @"
欢迎使用 Git Push / Pull 工具！

【功能说明】
• 推送代码：提交本地更改并推送到远程仓库
• 拉取代码：从远程仓库获取最新代码

【使用步骤】
1. 选择操作（推送 / 拉取）
2. 选择目标分支
3. 推送时需填写提交信息
4. 点击"执行"按钮完成操作

【注意事项】
• 确保已安装 Git 并配置 SSH 或 HTTPS
• 仓库需配置远程地址（origin）
• 网络不稳定时推送会自动重试
"@
    [System.Windows.Forms.MessageBox]::Show($guideText, "使用指南", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    New-Item -Path $regPath -Force | Out-Null
    New-ItemProperty -Path $regPath -Name "Version" -Value "1.0" -PropertyType String -Force | Out-Null
}

# 获取仓库路径
$repoPath = (git rev-parse --show-toplevel 2>$null)
if (-not $repoPath) {
    $initRepo = [System.Windows.Forms.MessageBox]::Show("当前目录不是 Git 仓库！`n是否要在此目录初始化 Git 仓库？", "提示", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($initRepo -eq "Yes") {
        git init 2>$null
        if ($LASTEXITCODE -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Git 仓库已初始化！`n请重新运行此工具。", "成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            exit
        } else {
            [System.Windows.Forms.MessageBox]::Show("初始化 Git 仓库失败，请确保已安装 Git。", "错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            exit
        }
    }
    exit
}

# 检查远程仓库配置
$remoteUrl = (git remote get-url origin 2>$null)
if (-not $remoteUrl) {
    $initRemote = [System.Windows.Forms.MessageBox]::Show("当前仓库未配置远程地址（origin）！`n是否要现在配置？", "提示", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($initRemote -eq "Yes") {
        $url = [Microsoft.VisualBasic.Interaction]::InputBox("请输入远程仓库地址：`n（如：https://github.com/user/repo.git）", "配置远程地址")
        if ($url -and $url.Trim()) {
            git remote add origin $url.Trim() 2>$null
            if ($LASTEXITCODE -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("远程地址已配置！`n请重新运行此工具。", "成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } else {
                [System.Windows.Forms.MessageBox]::Show("配置远程地址失败，请重试。", "错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    }
    exit
}

# 配置 git i18n 设置，确保中文输出正确
git config i18n.commitencoding utf-8 2>$null
git config i18n.logoutputencoding utf-8 2>$null

# 获取所有文件并构建目录树
function Get-AllRepoFiles {
    $ignoredPatterns = @()
    $gitignorePath = Join-Path $repoPath ".gitignore"
    if (Test-Path $gitignorePath) {
        $ignoredPatterns = Get-Content $gitignorePath | Where-Object { $_ -and -not $_.StartsWith("#") } | ForEach-Object { $_.Trim() }
    }

    $allItems = Get-ChildItem -Path $repoPath -Recurse -Force |
        Where-Object { $_.FullName -notmatch '[\\/]\.git([\\/]|$)' } |
        Sort-Object @{Expression={$_.PSIsContainer}; Descending=$false}, @{Expression={$_.FullName}; Ascending=$true}

    # 先收集所有目录路径
    $dirSet = @{}
    foreach ($item in $allItems) {
        if ($item.PSIsContainer) {
            $relPath = $item.FullName.Substring($repoPath.Length + 1).Replace('\', '/')
            $dirSet[$relPath] = $true
        }
    }

    $tree = @{}
    foreach ($item in $allItems) {
        $relPath = $item.FullName.Substring($repoPath.Length + 1).Replace('\', '/')
        $parts = $relPath -split '/'
        $current = $tree
        $path = ""
        for ($i = 0; $i -lt $parts.Count; $i++) {
            $path = if ($i -eq 0) { $parts[$i] } else { "$path/$($parts[$i])" }
            $isDir = $dirSet.ContainsKey($path) -or ($i -lt $parts.Count - 1)
            if (-not $current.ContainsKey($parts[$i])) {
                $current[$parts[$i]] = @{ Path = $path; IsDir = $isDir; Children = @{} }
            }
            $current = $current[$parts[$i]].Children
        }
    }
    return @{ Tree = $tree; IgnoredPatterns = $ignoredPatterns }
}

$ignoredFiles = @()

# 从 .gitignore 中加载已有排除列表
$gitignorePath = Join-Path $repoPath ".gitignore"
$script:persistedExcludes = @()
if (Test-Path $gitignorePath) {
    $script:persistedExcludes = Get-Content $gitignorePath |
        Where-Object { $_ -and -not $_.StartsWith("#") -and -not $_.StartsWith("===") } |
        ForEach-Object { $_.Trim().Replace('\', '/') }
}
if ($script:persistedExcludes.Count -gt 0) {
    $lblIgnoreCount.Text = "已排除 $($script:persistedExcludes.Count) 个文件/目录"
    $script:ignoredFiles = $script:persistedExcludes
}

# 写入排除列表到 .gitignore（标记区域）
function Write-ExcludesToGitignore($excludes) {
    $gitignorePath = Join-Path $repoPath ".gitignore"
    $markerStart = "# === Git Push Tool 排除列表 ==="
    $markerEnd   = "# === Git Push Tool 结束 ==="
    $newSection = @($markerStart) + $excludes + @($markerEnd)
    if (Test-Path $gitignorePath) {
        $lines = Get-Content $gitignorePath
        $startIdx = [array]::IndexOf($lines, $markerStart)
        $endIdx   = [array]::IndexOf($lines, $markerEnd)
        if ($startIdx -ge 0 -and $endIdx -gt $startIdx) {
            $before = $lines[0..($startIdx-1)]
            $after  = $lines[($endIdx+1)..($lines.Length-1)]
            $newLines = $before + $newSection + $after
        } else {
            $newLines = $lines + @("") + $newSection
        }
    } else {
        $newLines = $newSection
    }
    [System.IO.File]::WriteAllText($gitignorePath, ($newLines -join "`n") + "`n", [System.Text.Encoding]::UTF8)
}

function Show-UntrackedFileDialog {
    $data = Get-AllRepoFiles
    $tree = $data.Tree
    $ignoredPatterns = $data.IgnoredPatterns

    if ($tree.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("当前仓库没有文件。", "提示", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return @()
    }

    $dlgForm = New-Object System.Windows.Forms.Form
    $dlgForm.Text = "选择要排除的文件"
    $dlgForm.Size = S 500 550
    $dlgForm.StartPosition = "CenterScreen"
    $dlgForm.FormBorderStyle = "FixedDialog"
    $dlgForm.MaximizeBox = $false
    $dlgForm.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10))
    $dlgForm.BackColor = $cardBg

    $lblDlg = New-Object System.Windows.Forms.Label
    $lblDlg.Text = "勾选需要排除的文件（不会提交推送）"
    $lblDlg.Font = New-Object System.Drawing.Font("Segoe UI", $(F 11), [System.Drawing.FontStyle]::Bold)
    $lblDlg.ForeColor = $textPrimary
    $lblDlg.Location = P 15 15
    $lblDlg.Size = S 450 25
    $dlgForm.Controls.Add($lblDlg)

    $imgList = New-Object System.Windows.Forms.ImageList
    $imgList.ImageSize = S 16 16
    $imgList.ColorDepth = "Depth32Bit"

    $bmpFolder = New-Object System.Drawing.Bitmap(16, 16)
    $g = [System.Drawing.Graphics]::FromImage($bmpFolder)
    $g.SmoothingMode = "AntiAlias"
    $folderBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(251, 192, 45))
    $g.FillRectangle($folderBrush, 2, 4, 12, 10)
    $g.FillRectangle($folderBrush, 2, 2, 6, 4)
    $folderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 150, 30), 1)
    $g.DrawRectangle($folderPen, 2, 4, 12, 10)
    $g.DrawRectangle($folderPen, 2, 2, 6, 4)
    $g.Dispose()
    $imgList.Images.Add($bmpFolder)

    $bmpFile = New-Object System.Drawing.Bitmap(16, 16)
    $g = [System.Drawing.Graphics]::FromImage($bmpFile)
    $g.SmoothingMode = "AntiAlias"
    $fileBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 149, 237))
    $filePoints = @(
        (New-Object System.Drawing.Point(3, 1)),
        (New-Object System.Drawing.Point(13, 1)),
        (New-Object System.Drawing.Point(13, 15)),
        (New-Object System.Drawing.Point(3, 15))
    )
    $g.FillPolygon($fileBrush, $filePoints)
    $filePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(65, 105, 225), 1)
    $g.DrawPolygon($filePen, $filePoints)
    $g.Dispose()
    $imgList.Images.Add($bmpFile)

    $treeView = New-Object System.Windows.Forms.TreeView
    $treeView.Location = P 15 50
    $treeView.Size = S 450 400
    $treeView.Font = New-Object System.Drawing.Font("Consolas", $(F 9))
    $treeView.CheckBoxes = $true
    $treeView.FullRowSelect = $true
    $treeView.BorderStyle = "FixedSingle"
    $treeView.ImageList = $imgList
    $dlgForm.Controls.Add($treeView)

    function IsIgnored($path) {
        foreach ($pattern in $ignoredPatterns) {
            $cleanPattern = $pattern.TrimEnd('/')
            if ($path -like $cleanPattern -or $path -like "$cleanPattern/*" -or $path.EndsWith("/$cleanPattern")) {
                return $true
            }
            if ($pattern.Contains('*')) {
                $regex = $pattern -replace '\.', '\.' -replace '\*', '.*'
                if ($path -match "^$regex$" -or $path -match "/$regex$" -or $path -match "^$regex/") {
                    return $true
                }
            }
        }
        return $false
    }

    function Add-TreeNodes($parentNode, $treeData) {
        foreach ($key in ($treeData.Keys | Sort-Object)) {
            $item = $treeData[$key]
            $node = New-Object System.Windows.Forms.TreeNode
            $node.Text = "$key"
            $node.Tag = $item.Path
            if ($item.IsDir) {
                $node.ImageIndex = 0
                $node.SelectedImageIndex = 0
                Add-TreeNodes $node $item.Children
            } else {
                $node.ImageIndex = 1
                $node.SelectedImageIndex = 1
            }
            if (IsIgnored $item.Path -or $script:persistedExcludes -contains $item.Path) {
                $node.Checked = $true
            }
            $parentNode.Nodes.Add($node) | Out-Null
        }
    }

    $rootNode = New-Object System.Windows.Forms.TreeNode
    $rootNode.Text = "仓库文件"
    $rootNode.ImageIndex = 0
    $rootNode.SelectedImageIndex = 0
    Add-TreeNodes $rootNode $tree
    $treeView.Nodes.Add($rootNode) | Out-Null
    $rootNode.Expand()

    $btnDlgOK = New-Object System.Windows.Forms.Button
    $btnDlgOK.Text = "确  定"
    $btnDlgOK.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10), [System.Drawing.FontStyle]::Bold)
    $btnDlgOK.ForeColor = [System.Drawing.Color]::White
    $btnDlgOK.BackColor = $primaryColor
    $btnDlgOK.FlatStyle = "Flat"
    $btnDlgOK.FlatAppearance.BorderSize = 0
    $btnDlgOK.Location = P 350 465
    $btnDlgOK.Size = S 115 32
    $dlgForm.Controls.Add($btnDlgOK)

    $btnDlgCancel = New-Object System.Windows.Forms.Button
    $btnDlgCancel.Text = "取  消"
    $btnDlgCancel.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10))
    $btnDlgCancel.ForeColor = $textSecondary
    $btnDlgCancel.BackColor = "Transparent"
    $btnDlgCancel.FlatStyle = "Flat"
    $btnDlgCancel.FlatAppearance.BorderSize = 0
    $btnDlgCancel.Location = P 220 465
    $btnDlgCancel.Size = S 115 32
    $dlgForm.Controls.Add($btnDlgCancel)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "全选"
    $btnSelectAll.Font = New-Object System.Drawing.Font("Segoe UI", $(F 9))
    $btnSelectAll.ForeColor = $primaryColor
    $btnSelectAll.BackColor = "Transparent"
    $btnSelectAll.FlatStyle = "Flat"
    $btnSelectAll.FlatAppearance.BorderSize = 0
    $btnSelectAll.Location = P 15 465
    $btnSelectAll.Size = S 60 32
    $btnSelectAll.Add_Click({
        foreach ($n in $treeView.Nodes[0].Nodes) { $n.Checked = $true }
    })
    $dlgForm.Controls.Add($btnSelectAll)

    $btnSelectNone = New-Object System.Windows.Forms.Button
    $btnSelectNone.Text = "全不选"
    $btnSelectNone.Font = New-Object System.Drawing.Font("Segoe UI", $(F 9))
    $btnSelectNone.ForeColor = $primaryColor
    $btnSelectNone.BackColor = "Transparent"
    $btnSelectNone.FlatStyle = "Flat"
    $btnSelectNone.FlatAppearance.BorderSize = 0
    $btnSelectNone.Location = P 85 465
    $btnSelectNone.Size = S 70 32
    $btnSelectNone.Add_Click({
        foreach ($n in $treeView.Nodes[0].Nodes) { $n.Checked = $false }
    })
    $dlgForm.Controls.Add($btnSelectNone)

    $btnDlgOK.Add_Click({
        $script:ignoredFiles = @()
        function Get-CheckedPaths($node) {
            foreach ($child in $node.Nodes) {
                if ($child.Checked) { $script:ignoredFiles += $child.Tag }
                Get-CheckedPaths $child
            }
        }
        Get-CheckedPaths $treeView.Nodes[0]
        # 将排除列表写入 .gitignore
        $script:persistedExcludes = $script:ignoredFiles
        Write-ExcludesToGitignore $script:ignoredFiles
        $dlgForm.DialogResult = "OK"
        $dlgForm.Close()
    })
    $btnDlgCancel.Add_Click({ $dlgForm.DialogResult = "Cancel"; $dlgForm.Close() })

    $dlgForm.ShowDialog()
    return $ignoredFiles
}

# ===== 顶部标题区域 =====
$topPanel = New-Object System.Windows.Forms.Panel
$topPanel.Location = P 0 0
$topPanel.Size = S 640 90
$topPanel.BackColor = $cardBg
$form.Controls.Add($topPanel)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Git Push / Pull"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", $(F 16), [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $textPrimary
$lblTitle.Location = P 24 20
$lblTitle.Size = S 400 30
$topPanel.Controls.Add($lblTitle)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "$repoPath"
$lblPath.Font = New-Object System.Drawing.Font("Segoe UI", $(F 9))
$lblPath.ForeColor = $textSecondary
$lblPath.Location = P 24 55
$lblPath.Size = S 600 20
$topPanel.Controls.Add($lblPath)

$line1 = New-Object System.Windows.Forms.Label
$line1.BackColor = $borderColor
$line1.Location = P 0 90
$line1.Size = S 640 1
$form.Controls.Add($line1)

# ===== 卡片容器 - 操作选择 =====
$card1 = New-Object System.Windows.Forms.Panel
$card1.Location = P 24 110
$card1.Size = S 592 85
$card1.BackColor = $cardBg

$lblOp = New-Object System.Windows.Forms.Label
$lblOp.Text = "选择操作"
$lblOp.Font = New-Object System.Drawing.Font("Segoe UI", $(F 11), [System.Drawing.FontStyle]::Bold)
$lblOp.ForeColor = $textPrimary
$lblOp.Location = P 20 14
$lblOp.Size = S 200 25
$card1.Controls.Add($lblOp)

$rbPush = New-Object System.Windows.Forms.RadioButton
$rbPush.Text = "推送代码 (Push)"
$rbPush.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10))
$rbPush.ForeColor = $textPrimary
$rbPush.Location = P 20 45
$rbPush.AutoSize = $true
$rbPush.Checked = $true
$card1.Controls.Add($rbPush)

$rbPull = New-Object System.Windows.Forms.RadioButton
$rbPull.Text = "拉取代码 (Pull)"
$rbPull.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10))
$rbPull.ForeColor = $textPrimary
$rbPull.Location = P 170 45
$rbPull.AutoSize = $true
$card1.Controls.Add($rbPull)

$form.Controls.Add($card1)

# ===== 卡片容器 - 分支选择 =====
$currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()

$card2 = New-Object System.Windows.Forms.Panel
$card2.Location = P 24 210
$card2.Size = S 592 120
$card2.BackColor = $cardBg

$lblBranch = New-Object System.Windows.Forms.Label
$lblBranch.Text = "选择分支"
$lblBranch.Font = New-Object System.Drawing.Font("Segoe UI", $(F 11), [System.Drawing.FontStyle]::Bold)
$lblBranch.ForeColor = $textPrimary
$lblBranch.Location = P 20 14
$lblBranch.Size = S 200 25
$card2.Controls.Add($lblBranch)

$rbBranchCur = New-Object System.Windows.Forms.RadioButton
$rbBranchCur.Text = "当前分支"
$rbBranchCur.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10))
$rbBranchCur.ForeColor = $textPrimary
$rbBranchCur.Location = P 20 45
$rbBranchCur.Checked = $true
$card2.Controls.Add($rbBranchCur)

$lblCurBranch = New-Object System.Windows.Forms.Label
$lblCurBranch.Text = "($currentBranch)"
$lblCurBranch.Font = New-Object System.Drawing.Font("Consolas", $(F 9))
$lblCurBranch.ForeColor = $primaryColor
$lblCurBranch.Location = P 125 47
$lblCurBranch.Size = S 200 20
$card2.Controls.Add($lblCurBranch)

$rbBranchMain = New-Object System.Windows.Forms.RadioButton
$rbBranchMain.Text = "main"
$rbBranchMain.Font = New-Object System.Drawing.Font("Consolas", $(F 10))
$rbBranchMain.ForeColor = $textPrimary
$rbBranchMain.Location = P 220 45
$card2.Controls.Add($rbBranchMain)

$rbBranchMaster = New-Object System.Windows.Forms.RadioButton
$rbBranchMaster.Text = "master"
$rbBranchMaster.Font = New-Object System.Drawing.Font("Consolas", $(F 10))
$rbBranchMaster.ForeColor = $textPrimary
$rbBranchMaster.Location = P 330 45
$card2.Controls.Add($rbBranchMaster)

$rbBranchOther = New-Object System.Windows.Forms.RadioButton
$rbBranchOther.Text = "自定义"
$rbBranchOther.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10))
$rbBranchOther.ForeColor = $textPrimary
$rbBranchOther.Location = P 20 75
$rbBranchOther.Size = S 70 25
$rbBranchOther.UseVisualStyleBackColor = $true
$card2.Controls.Add($rbBranchOther)

$txtBranch = New-Object System.Windows.Forms.TextBox
$txtBranch.Location = P 95 75
$txtBranch.Size = S 160 22
$txtBranch.Font = New-Object System.Drawing.Font("Consolas", $(F 10))
$txtBranch.BorderStyle = "FixedSingle"
$txtBranch.ForeColor = $textPrimary
$txtBranch.BackColor = [System.Drawing.Color]::White
$txtBranch.Multiline = $false
$card2.Controls.Add($txtBranch)
$txtBranch.BringToFront()

$form.Controls.Add($card2)

# ===== 卡片容器 - 排除文件 =====
$cardIgnore = New-Object System.Windows.Forms.Panel
$cardIgnore.Location = P 24 345
$cardIgnore.Size = S 592 80
$cardIgnore.BackColor = $cardBg

$lblIgnore = New-Object System.Windows.Forms.Label
$lblIgnore.Text = "排除文件"
$lblIgnore.Font = New-Object System.Drawing.Font("Segoe UI", $(F 11), [System.Drawing.FontStyle]::Bold)
$lblIgnore.ForeColor = $textPrimary
$lblIgnore.Location = P 20 8
$lblIgnore.Size = S 300 20
$cardIgnore.Controls.Add($lblIgnore)

$lblIgnoreDesc = New-Object System.Windows.Forms.Label
$lblIgnoreDesc.Text = "默认全量推送（新文件+修改），可手动勾掉不需要推送的文件"
$lblIgnoreDesc.Font = New-Object System.Drawing.Font("Segoe UI", $(F 8))
$lblIgnoreDesc.ForeColor = $textSecondary
$lblIgnoreDesc.Location = P 20 28
$lblIgnoreDesc.Size = S 480 16
$cardIgnore.Controls.Add($lblIgnoreDesc)

$cbIgnoreUntracked = New-Object System.Windows.Forms.CheckBox
$cbIgnoreUntracked.Text = "选择要排除的文件"
$cbIgnoreUntracked.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10))
$cbIgnoreUntracked.ForeColor = $textPrimary
$cbIgnoreUntracked.Location = P 20 46
$cbIgnoreUntracked.AutoSize = $true
$cbIgnoreUntracked.Checked = $true
$cbIgnoreUntracked.UseVisualStyleBackColor = $true
$cardIgnore.Controls.Add($cbIgnoreUntracked)

$lblIgnoreCount = New-Object System.Windows.Forms.Label
$lblIgnoreCount.Text = ""
$lblIgnoreCount.Font = New-Object System.Drawing.Font("Consolas", $(F 9))
$lblIgnoreCount.ForeColor = $textSecondary
$lblIgnoreCount.Location = P 185 48
$lblIgnoreCount.Size = S 220 20
$cardIgnore.Controls.Add($lblIgnoreCount)

$btnIgnoreSelect = New-Object System.Windows.Forms.Button
$btnIgnoreSelect.Text = "选择排除"
$btnIgnoreSelect.Font = New-Object System.Drawing.Font("Segoe UI", $(F 9))
$btnIgnoreSelect.ForeColor = [System.Drawing.Color]::White
$btnIgnoreSelect.BackColor = $primaryColor
$btnIgnoreSelect.FlatStyle = "Flat"
$btnIgnoreSelect.FlatAppearance.BorderSize = 0
$btnIgnoreSelect.Location = P 400 44
$btnIgnoreSelect.Size = S 90 28
$btnIgnoreSelect.Cursor = "Hand"
$btnIgnoreSelect.Visible = $true
$lblIgnoreCount.Text = "点击选择要排除的文件"
$btnIgnoreSelect.Add_Click({
    $ignored = Show-UntrackedFileDialog
    if ($ignored.Count -gt 0) {
        $lblIgnoreCount.Text = "已排除 $($ignored.Count) 个文件/目录"
    } else {
        $lblIgnoreCount.Text = ""
    }
})
$cardIgnore.Controls.Add($btnIgnoreSelect)

$form.Controls.Add($cardIgnore)

# ===== 卡片容器 - 提交信息 =====
$card3 = New-Object System.Windows.Forms.Panel
$card3.Location = P 24 415
$card3.Size = S 592 140
$card3.BackColor = $cardBg

$lblCommit = New-Object System.Windows.Forms.Label
$lblCommit.Text = "提交信息"
$lblCommit.Font = New-Object System.Drawing.Font("Segoe UI", $(F 11), [System.Drawing.FontStyle]::Bold)
$lblCommit.ForeColor = $textPrimary
$lblCommit.Location = P 20 12
$lblCommit.Size = S 200 20
$card3.Controls.Add($lblCommit)

$txtCommit = New-Object System.Windows.Forms.TextBox
$txtCommit.Location = P 20 38
$txtCommit.Size = S 552 85
$txtCommit.Font = New-Object System.Drawing.Font("Consolas", $(F 10))
$txtCommit.BorderStyle = "FixedSingle"
$txtCommit.BackColor = $inputBg
$txtCommit.Multiline = $true
$txtCommit.AcceptsReturn = $true
$txtCommit.AcceptsTab = $true
$txtCommit.ScrollBars = "Vertical"
$card3.Controls.Add($txtCommit)

$form.Controls.Add($card3)

# ===== 卡片容器 - 执行日志 =====
$card4 = New-Object System.Windows.Forms.Panel
$card4.Location = P 24 570
$card4.Size = S 592 140
$card4.BackColor = $cardBg
$form.Controls.Add($card4)

$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Text = "执行日志"
$lblOutput.Font = New-Object System.Drawing.Font("Segoe UI", $(F 11), [System.Drawing.FontStyle]::Bold)
$lblOutput.ForeColor = $textPrimary
$lblOutput.Location = P 20 12
$lblOutput.Size = S 200 20
$card4.Controls.Add($lblOutput)

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = "Vertical"
$txtOutput.ReadOnly = $true
$txtOutput.Font = New-Object System.Drawing.Font("Consolas", $(F 9))
$txtOutput.ForeColor = $textSecondary
$txtOutput.BackColor = $inputBg
$txtOutput.BorderStyle = "FixedSingle"
$txtOutput.Location = P 20 38
$txtOutput.Size = S 552 90
$card4.Controls.Add($txtOutput)

# ===== 底部按钮 =====
$btnPanel = New-Object System.Windows.Forms.Panel
$btnPanel.Location = P 0 710
$btnPanel.Size = S 640 60
$btnPanel.BackColor = $cardBg
$form.Controls.Add($btnPanel)

$line2 = New-Object System.Windows.Forms.Label
$line2.BackColor = $borderColor
$line2.Location = P 0 0
$line2.Size = S 640 1
$btnPanel.Controls.Add($line2)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "执  行"
$btnRun.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10), [System.Drawing.FontStyle]::Bold)
$btnRun.ForeColor = [System.Drawing.Color]::White
$btnRun.BackColor = $primaryColor
$btnRun.FlatStyle = "Flat"
$btnRun.FlatAppearance.BorderSize = 0
$btnRun.Location = P 475 12
$btnRun.Size = S 120 36
$btnRun.Cursor = "Hand"
$btnPanel.Controls.Add($btnRun)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "取  消"
$btnCancel.Font = New-Object System.Drawing.Font("Segoe UI", $(F 10))
$btnCancel.ForeColor = $primaryColor
$btnCancel.BackColor = [System.Drawing.Color]::Transparent
$btnCancel.FlatStyle = "Flat"
$btnCancel.FlatAppearance.BorderSize = 0
$btnCancel.Location = P 355 12
$btnCancel.Size = S 100 36
$btnCancel.Cursor = "Hand"
$btnPanel.Controls.Add($btnCancel)

# 悬停效果
$btnRun.Add_MouseEnter({ $btnRun.BackColor = $primaryDark })
$btnRun.Add_MouseLeave({ if ($btnRun.Enabled) { $btnRun.BackColor = $primaryColor } })
$btnCancel.Add_MouseEnter({ $btnCancel.BackColor = $inputBg })
$btnCancel.Add_MouseLeave({ $btnCancel.BackColor = [System.Drawing.Color]::Transparent })

# 排除文件复选框切换
$cbIgnoreUntracked.Add_CheckedChanged({
    if ($cbIgnoreUntracked.Checked) {
        $btnIgnoreSelect.Visible = $true
        $lblIgnoreCount.Text = "点击选择要排除的文件"
        # 勾选时：将已有排除列表写入 .gitignore
        if ($script:ignoredFiles.Count -gt 0) {
            Write-ExcludesToGitignore $script:ignoredFiles
        }
    } else {
        $btnIgnoreSelect.Visible = $false
        $lblIgnoreCount.Text = ""
        $script:ignoredFiles = @()
        # 取消时：清除 .gitignore 中的工具标记区域
        Write-ExcludesToGitignore @()
    }
})



$btnRun.Add_Click({
    $isPush = $rbPush.Checked
    $targetBranch = ""

    if ($rbBranchCur.Checked) { $targetBranch = $currentBranch }
    elseif ($rbBranchMain.Checked) { $targetBranch = "main" }
    elseif ($rbBranchMaster.Checked) { $targetBranch = "master" }
    elseif ($rbBranchOther.Checked) {
        $targetBranch = $txtBranch.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($targetBranch)) {
            [System.Windows.Forms.MessageBox]::Show("请输入分支名", "提示", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
    }

    if ($isPush) {
        $commitMsg = $txtCommit.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($commitMsg)) {
            [System.Windows.Forms.MessageBox]::Show("请输入提交信息", "提示", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
    }

    $btnRun.Enabled = $false
    $btnRun.BackColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
    $btnRun.Cursor = "WaitCursor"
    $txtOutput.Text = "执行中，请稍候...`n"
    # 立即刷新界面文字，否则按钮禁用和提示文字被后续阻塞操作卡住无法显示
    [System.Windows.Forms.Application]::DoEvents()

    # === 异步执行 git 操作（runspace），避免阻塞 UI ===
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $psJob = [System.Management.Automation.PowerShell]::Create()
    $psJob.Runspace = $runspace

    # 使用单引号 here-string，内部 $ 为字面量，由 runspace 解析
    $runspaceScript = @'
param($Branch, $CommitMsg, $IsPush, $IgnoreUntracked, $IgnoredFiles, $RepoPath)

Set-Location $RepoPath

function Switch-Branch($target) {
    $current = (git rev-parse --abbrev-ref HEAD).Trim()
    if ($target -ne $current) {
        $result = (git checkout $target 2>&1) | Out-String
        if ($LASTEXITCODE -ne 0) { return $result }
    }
    return $null
}

function Do-Push($branch, $commitMsg, $ignoreUntracked, $ignoredFiles) {
    $output = ""
    $err = Switch-Branch $branch
    if ($err) { return "切换分支失败:`n$err" }

    if ($ignoreUntracked -and $ignoredFiles.Count -gt 0) {
        git add -A
        foreach ($f in $ignoredFiles) {
            git reset HEAD -- $f 2>$null | Out-Null
        }
        $output += "[排除文件] 以下文件未添加到提交：`n"
        foreach ($f in $ignoredFiles) { $output += "  - $f`n" }
    } else {
        git add -A
    }

    $commitMsgFile = Join-Path $env:TEMP "git-commit-msg-$([Guid]::NewGuid().ToString()).txt"
    [System.IO.File]::WriteAllText($commitMsgFile, $commitMsg, [System.Text.Encoding]::UTF8)
    $commitResult = (git commit -F $commitMsgFile 2>&1) | Out-String
    Remove-Item $commitMsgFile -Force -ErrorAction SilentlyContinue
    $output += $commitResult

    $retry = 0; $maxRetry = 3
    do {
        if ($retry -gt 0) { $output += "`n==== 第 $retry 次重试 ====`n" }
        $pushResult = (git push -u origin $branch 2>&1) | Out-String
        $output += $pushResult
        if ($LASTEXITCODE -eq 0) { return $output }
        $retry++
    } while ($retry -le $maxRetry)

    $output += "`n[错误] 推送失败，已达最大重试次数"
    return $output
}

function Do-Pull($branch) {
    $output = ""
    $err = Switch-Branch $branch
    if ($err) { return "切换分支失败:`n$err" }

    $retry = 0; $maxRetry = 3
    do {
        if ($retry -gt 0) { $output += "`n==== 第 $retry 次重试 ====`n" }
        $pullResult = (git pull origin $branch 2>&1) | Out-String
        $output += $pullResult
        if ($LASTEXITCODE -eq 0) { return $output }
        $retry++
    } while ($retry -le $maxRetry)

    $output += "`n[错误] 拉取失败，已达最大重试次数"
    return $output
}

if ($IsPush) {
    return Do-Push $Branch $CommitMsg $IgnoreUntracked $IgnoredFiles
} else {
    return Do-Pull $Branch
}
'@
    [void]$psJob.AddScript($runspaceScript)
    [void]$psJob.AddParameter("Branch", $targetBranch)
    [void]$psJob.AddParameter("CommitMsg", $commitMsg)
    [void]$psJob.AddParameter("IsPush", $isPush)
    [void]$psJob.AddParameter("IgnoreUntracked", $cbIgnoreUntracked.Checked)
    [void]$psJob.AddParameter("IgnoredFiles", $script:ignoredFiles)
    [void]$psJob.AddParameter("RepoPath", (Get-Location).Path)

    $asyncResult = $psJob.BeginInvoke()

    # 定时器轮询检查异步执行是否完成
    $pollTimer = New-Object System.Windows.Forms.Timer
    $pollTimer.Interval = 300

    # 将异步对象提升到脚本级变量，确保闭包引用不会被 GC 回收
    $script:_asyncJob = $psJob
    $script:_asyncRunspace = $runspace
    $script:_asyncResult = $asyncResult
    $script:_asyncTimer = $pollTimer
    $script:_asyncStart = [DateTime]::Now

    $pollTimer.Add_Tick({
        $r = $script:_asyncResult
        $t = $script:_asyncTimer
        if (-not $r) { return }

        if ($r.IsCompleted) {
            $t.Stop()
            $t.Dispose()
            try {
                $result = $script:_asyncJob.EndInvoke($r)
            } catch {
                $result = "[错误] 执行异常: $_"
            } finally {
                $script:_asyncJob.Dispose()
                $script:_asyncRunspace.Dispose()
                $script:_asyncJob = $null
                $script:_asyncRunspace = $null
                $script:_asyncResult = $null
                $script:_asyncTimer = $null
            }

            $txtOutput.Text = $result
            $btnRun.Enabled = $true
            $btnRun.BackColor = $primaryColor
            $btnRun.Cursor = "Hand"

            if ($result -match "\[错误\]") {
                [System.Windows.Forms.MessageBox]::Show("操作失败，请查看日志详情", "失败", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            } else {
                [System.Windows.Forms.MessageBox]::Show("操作成功！", "成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        } elseif (([DateTime]::Now - $script:_asyncStart).TotalSeconds -gt 120) {
            # 超时兜底：120 秒未完成则强制结束
            $t.Stop()
            $t.Dispose()
            try {
                if (-not $script:_asyncResult.IsCompleted) {
                    $script:_asyncJob.Stop()
                }
                $script:_asyncJob.Dispose()
                $script:_asyncRunspace.Dispose()
            } catch { }
            $script:_asyncJob = $null
            $script:_asyncRunspace = $null
            $script:_asyncResult = $null
            $script:_asyncTimer = $null

            $txtOutput.Text = "[错误] 操作超时（120 秒），请检查网络连接或 Git 仓库状态"
            $btnRun.Enabled = $true
            $btnRun.BackColor = $primaryColor
            $btnRun.Cursor = "Hand"
            [System.Windows.Forms.MessageBox]::Show("操作超时，请检查网络连接或 Git 仓库状态", "超时", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    $pollTimer.Start()
})

$btnCancel.Add_Click({ $form.Dispose(); [System.Environment]::Exit(0) })

$result = $form.ShowDialog()
[System.Environment]::Exit(0)
