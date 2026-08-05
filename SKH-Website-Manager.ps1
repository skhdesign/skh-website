param()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataRoot = Join-Path $Root "projects-data"
$HomeRoot = Join-Path $Root "home-data"
$Generator = Join-Path $Root "generate-projects.ps1"
$ErrorLog = Join-Path $Root "SKH-Manager-Error.txt"
$Utf8Bom = New-Object System.Text.UTF8Encoding($true)

if (!(Test-Path -LiteralPath $DataRoot)) {
    New-Item -ItemType Directory -Path $DataRoot | Out-Null
}
if (!(Test-Path -LiteralPath $HomeRoot)) {
    New-Item -ItemType Directory -Path $HomeRoot | Out-Null
}

function Log-Error([string]$Text) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $ErrorLog -Value "[$stamp] $Text" -Encoding UTF8
}

function Show-Info([string]$Text) {
    [System.Windows.Forms.MessageBox]::Show(
        $Text, "SKH Website Manager",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Show-Warning([string]$Text) {
    [System.Windows.Forms.MessageBox]::Show(
        $Text, "SKH Website Manager",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
}

function Show-Error([string]$Text) {
    [System.Windows.Forms.MessageBox]::Show(
        $Text, "SKH Website Manager",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Confirm-Action([string]$Text) {
    return [System.Windows.Forms.MessageBox]::Show(
        $Text, "確認",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    ) -eq [System.Windows.Forms.DialogResult]::Yes
}

function Read-Info([string]$Path) {
    $result = [ordered]@{}
    $lastKey = ""

    if (!(Test-Path -LiteralPath $Path)) {
        return $result
    }

    foreach ($raw in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = $raw.TrimEnd()

        if ($line -match '^\s*([^：:]+)[：:]\s*(.*)$') {
            $lastKey = $matches[1].Trim()
            $result[$lastKey] = $matches[2].Trim()
        }
        elseif ($lastKey -eq "案件介紹") {
            $result[$lastKey] = ($result[$lastKey] + "`r`n" + $line).Trim()
        }
    }

    return $result
}

function Write-Info([string]$Folder, [hashtable]$Data) {
    $keys = @(
        "發布","網址代號","排序","案件名稱","英文名稱","完成年度","類型",
        "座落位置","基地面積","總樓地板面積","樓層","結構","案件狀態",
        "首頁顯示","案件介紹"
    )

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($key in $keys) {
        $lines.Add("$key：$($Data[$key])")
    }

    [System.IO.File]::WriteAllText(
        (Join-Path $Folder "info.txt"),
        ($lines -join "`r`n"),
        $Utf8Bom
    )
}

function Get-PhotoFiles([string]$Folder) {
    if (!(Test-Path -LiteralPath $Folder)) { return @() }

    return @(
        Get-ChildItem -LiteralPath $Folder -File |
        Where-Object { $_.Extension.ToLower() -in @(".jpg",".jpeg",".png",".webp") } |
        Sort-Object @{ Expression = {
            if ($_.BaseName.ToLower() -eq "cover") { "000000" }
            elseif ($_.BaseName -match '^\d+$') { "{0:D6}" -f [int]$_.BaseName }
            else { "900000_$($_.Name)" }
        }}
    )
}


function Create-WebsiteBackup {
    $backupRoot = Join-Path (Split-Path -Parent $Root) "SKH-Website-Backups"
    if (!(Test-Path -LiteralPath $backupRoot)) {
        New-Item -ItemType Directory -Path $backupRoot | Out-Null
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $destination = Join-Path $backupRoot $stamp
    New-Item -ItemType Directory -Path $destination | Out-Null

    if (Test-Path -LiteralPath $DataRoot) {
        Copy-Item -LiteralPath $DataRoot -Destination (Join-Path $destination "projects-data") -Recurse -Force
    }
    if (Test-Path -LiteralPath $HomeRoot) {
        Copy-Item -LiteralPath $HomeRoot -Destination (Join-Path $destination "home-data") -Recurse -Force
    }

    foreach ($name in @("index.html","all-projects.html")) {
        $source = Join-Path $Root $name
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }
    }

    Get-ChildItem -LiteralPath $Root -Filter "project-auto-*.html" -File -ErrorAction SilentlyContinue |
        Copy-Item -Destination $destination -Force

    # 只保留最近 20 份備份。
    Get-ChildItem -LiteralPath $backupRoot -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 20 |
        Remove-Item -Recurse -Force

    return $destination
}

# ------------------------------
# Main window
# ------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "SKH Website Manager"
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
$form.MinimumSize = New-Object System.Drawing.Size(1100, 720)
$form.BackColor = [System.Drawing.Color]::FromArgb(246,244,239)
$form.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 10)

$rootLayout = New-Object System.Windows.Forms.TableLayoutPanel
$rootLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$rootLayout.RowCount = 3
$rootLayout.ColumnCount = 1
$rootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 72)))
$rootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$rootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 26)))
$form.Controls.Add($rootLayout)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = [System.Windows.Forms.DockStyle]::Fill
$header.BackColor = [System.Drawing.Color]::FromArgb(48,42,37)
$rootLayout.Controls.Add($header, 0, 0)

$title = New-Object System.Windows.Forms.Label
$title.Text = "SKH WEBSITE MANAGER"
$title.ForeColor = [System.Drawing.Color]::White
$title.Font = New-Object System.Drawing.Font("Segoe UI", 17)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(22, 18)
$header.Controls.Add($title)

$generateButton = New-Object System.Windows.Forms.Button
$generateButton.Text = "產生網站"
$generateButton.Size = New-Object System.Drawing.Size(116, 38)
$generateButton.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$generateButton.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 145), 16)
$generateButton.BackColor = [System.Drawing.Color]::FromArgb(166,128,80)
$generateButton.ForeColor = [System.Drawing.Color]::White
$generateButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$generateButton.FlatAppearance.BorderSize = 0
$header.Controls.Add($generateButton)
$header.Add_Resize({
    $generateButton.Left = $header.ClientSize.Width - $generateButton.Width - 20
})

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "就緒"
$statusLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$statusLabel.Padding = New-Object System.Windows.Forms.Padding(10,4,0,0)
$statusLabel.BackColor = [System.Drawing.Color]::FromArgb(238,234,227)
$rootLayout.Controls.Add($statusLabel, 0, 2)

$mainSplit = New-Object System.Windows.Forms.SplitContainer
$mainSplit.Dock = [System.Windows.Forms.DockStyle]::Fill
$mainSplit.FixedPanel = [System.Windows.Forms.FixedPanel]::Panel1
$mainSplit.SplitterDistance = 310
$mainSplit.Panel1MinSize = 280
$mainSplit.Panel2MinSize = 600
$rootLayout.Controls.Add($mainSplit, 0, 1)

# ------------------------------
# Left panel
# ------------------------------
$left = $mainSplit.Panel1
$left.BackColor = [System.Drawing.Color]::FromArgb(235,230,220)
$left.Padding = New-Object System.Windows.Forms.Padding(14)

$leftLayout = New-Object System.Windows.Forms.TableLayoutPanel
$leftLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$leftLayout.RowCount = 5
$leftLayout.ColumnCount = 2
$leftLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$leftLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$leftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
$leftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$leftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 46)))
$leftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 42)))
$leftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 8)))
$left.Controls.Add($leftLayout)

$projectsLabel = New-Object System.Windows.Forms.Label
$projectsLabel.Text = "案件列表"
$projectsLabel.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 12, [System.Drawing.FontStyle]::Bold)
$projectsLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$projectsLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$leftLayout.Controls.Add($projectsLabel, 0, 0)
$leftLayout.SetColumnSpan($projectsLabel, 2)

$projectList = New-Object System.Windows.Forms.ListBox
$projectList.Dock = [System.Windows.Forms.DockStyle]::Fill
$projectList.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$projectList.DisplayMember = "DisplayName"
$leftLayout.Controls.Add($projectList, 0, 1)
$leftLayout.SetColumnSpan($projectList, 2)

$newButton = New-Object System.Windows.Forms.Button
$newButton.Text = "＋ 新增案件"
$newButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$newButton.Margin = New-Object System.Windows.Forms.Padding(0,6,5,4)
$leftLayout.Controls.Add($newButton, 0, 2)

$deleteButton = New-Object System.Windows.Forms.Button
$deleteButton.Text = "刪除案件"
$deleteButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$deleteButton.Margin = New-Object System.Windows.Forms.Padding(5,6,0,4)
$leftLayout.Controls.Add($deleteButton, 1, 2)

$openFolderButton = New-Object System.Windows.Forms.Button
$openFolderButton.Text = "開啟案件資料夾"
$openFolderButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$openFolderButton.Margin = New-Object System.Windows.Forms.Padding(0,2,0,4)
$leftLayout.Controls.Add($openFolderButton, 0, 3)
$leftLayout.SetColumnSpan($openFolderButton, 2)

# ------------------------------
# Right panel with tabs
# ------------------------------
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = [System.Windows.Forms.DockStyle]::Fill
$tabs.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 10)
$tabs.ItemSize = New-Object System.Drawing.Size(150, 34)
$tabs.SizeMode = [System.Windows.Forms.TabSizeMode]::Fixed
$mainSplit.Panel2.Controls.Add($tabs)

$infoTab = New-Object System.Windows.Forms.TabPage
$infoTab.Text = "案件資料"
$infoTab.BackColor = [System.Drawing.Color]::White
$tabs.TabPages.Add($infoTab)

$photosTab = New-Object System.Windows.Forms.TabPage
$photosTab.Text = "照片管理"
$photosTab.BackColor = [System.Drawing.Color]::White
$tabs.TabPages.Add($photosTab)

$homeTab = New-Object System.Windows.Forms.TabPage
$homeTab.Text = "首頁管理"
$homeTab.BackColor = [System.Drawing.Color]::White
$tabs.TabPages.Add($homeTab)

$homeSplit = New-Object System.Windows.Forms.SplitContainer
$homeSplit.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeSplit.FixedPanel = [System.Windows.Forms.FixedPanel]::Panel1
$homeSplit.SplitterDistance = 370
$homeTab.Controls.Add($homeSplit)

$homeLeftLayout = New-Object System.Windows.Forms.TableLayoutPanel
$homeLeftLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeLeftLayout.Padding = New-Object System.Windows.Forms.Padding(16)
$homeLeftLayout.RowCount = 4
$homeLeftLayout.ColumnCount = 2
$homeLeftLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$homeLeftLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$homeLeftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 58)))
$homeLeftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$homeLeftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
$homeLeftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
$homeSplit.Panel1.Controls.Add($homeLeftLayout)

$homeTitleLabel = New-Object System.Windows.Forms.Label
$homeTitleLabel.Text = "首頁輪播照片`r`n建議尺寸：1920 × 1280 px"
$homeTitleLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeTitleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$homeTitleLabel.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 10, [System.Drawing.FontStyle]::Bold)
$homeLeftLayout.Controls.Add($homeTitleLabel, 0, 0)
$homeLeftLayout.SetColumnSpan($homeTitleLabel, 2)

$homeList = New-Object System.Windows.Forms.ListBox
$homeList.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeList.DisplayMember = "DisplayName"
$homeLeftLayout.Controls.Add($homeList, 0, 1)
$homeLeftLayout.SetColumnSpan($homeList, 2)

$homeNewButton = New-Object System.Windows.Forms.Button
$homeNewButton.Text = "＋ 新增首頁照片"
$homeNewButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeNewButton.Margin = New-Object System.Windows.Forms.Padding(0,6,5,4)
$homeLeftLayout.Controls.Add($homeNewButton, 0, 2)

$homeDeleteButton = New-Object System.Windows.Forms.Button
$homeDeleteButton.Text = "刪除首頁照片"
$homeDeleteButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeDeleteButton.Margin = New-Object System.Windows.Forms.Padding(5,6,0,4)
$homeLeftLayout.Controls.Add($homeDeleteButton, 1, 2)

$homeOpenFolderButton = New-Object System.Windows.Forms.Button
$homeOpenFolderButton.Text = "開啟首頁照片資料夾"
$homeOpenFolderButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeOpenFolderButton.Margin = New-Object System.Windows.Forms.Padding(0,4,0,2)
$homeLeftLayout.Controls.Add($homeOpenFolderButton, 0, 3)
$homeLeftLayout.SetColumnSpan($homeOpenFolderButton, 2)

$homeRight = New-Object System.Windows.Forms.TableLayoutPanel
$homeRight.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeRight.Padding = New-Object System.Windows.Forms.Padding(24)
$homeRight.ColumnCount = 2
$homeRight.RowCount = 6
$homeRight.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
$homeRight.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$homeRight.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48)))
$homeRight.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 56)))
$homeRight.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 56)))
$homeRight.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 56)))
$homeRight.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$homeRight.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 58)))
$homeSplit.Panel2.Controls.Add($homeRight)

$homeIntro = New-Object System.Windows.Forms.Label
$homeIntro.Text = "首頁照片與作品照片完全分開；案名會自動使用所選作品的案件名稱。"
$homeIntro.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeIntro.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$homeIntro.ForeColor = [System.Drawing.Color]::FromArgb(105,96,88)
$homeRight.Controls.Add($homeIntro, 0, 0)
$homeRight.SetColumnSpan($homeIntro, 2)

$homeProjectLabel = New-Object System.Windows.Forms.Label
$homeProjectLabel.Text = "連結作品"
$homeProjectLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeProjectLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$homeRight.Controls.Add($homeProjectLabel, 0, 1)

$homeProjectCombo = New-Object System.Windows.Forms.ComboBox
$homeProjectCombo.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeProjectCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$homeProjectCombo.DisplayMember = "DisplayName"
$homeRight.Controls.Add($homeProjectCombo, 1, 1)

$homeOrderLabel = New-Object System.Windows.Forms.Label
$homeOrderLabel.Text = "輪播順序"
$homeOrderLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeOrderLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$homeRight.Controls.Add($homeOrderLabel, 0, 2)

$homeOrderBox = New-Object System.Windows.Forms.TextBox
$homeOrderBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeRight.Controls.Add($homeOrderBox, 1, 2)

$homeVisibleLabel = New-Object System.Windows.Forms.Label
$homeVisibleLabel.Text = "顯示狀態"
$homeVisibleLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeVisibleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$homeRight.Controls.Add($homeVisibleLabel, 0, 3)

$homeVisibleCheck = New-Object System.Windows.Forms.CheckBox
$homeVisibleCheck.Text = "顯示於首頁輪播"
$homeVisibleCheck.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeRight.Controls.Add($homeVisibleCheck, 1, 3)

$homePreview = New-Object System.Windows.Forms.PictureBox
$homePreview.Dock = [System.Windows.Forms.DockStyle]::Fill
$homePreview.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$homePreview.BackColor = [System.Drawing.Color]::FromArgb(238,236,232)
$homeRight.Controls.Add($homePreview, 0, 4)
$homeRight.SetColumnSpan($homePreview, 2)

$homeActions = New-Object System.Windows.Forms.FlowLayoutPanel
$homeActions.Dock = [System.Windows.Forms.DockStyle]::Fill
$homeActions.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$homeRight.Controls.Add($homeActions, 0, 5)
$homeRight.SetColumnSpan($homeActions, 2)

$homeImageButton = New-Object System.Windows.Forms.Button
$homeImageButton.Text = "選擇／更換首頁照片"
$homeImageButton.Size = New-Object System.Drawing.Size(180, 40)
$homeActions.Controls.Add($homeImageButton)

$homeSaveButton = New-Object System.Windows.Forms.Button
$homeSaveButton.Text = "儲存首頁設定"
$homeSaveButton.Size = New-Object System.Drawing.Size(150, 40)
$homeSaveButton.Margin = New-Object System.Windows.Forms.Padding(12,0,0,0)
$homeSaveButton.BackColor = [System.Drawing.Color]::FromArgb(166,128,80)
$homeSaveButton.ForeColor = [System.Drawing.Color]::White
$homeSaveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$homeSaveButton.FlatAppearance.BorderSize = 0
$homeActions.Controls.Add($homeSaveButton)

# ------------------------------
# Info tab
# ------------------------------
$infoScroll = New-Object System.Windows.Forms.Panel
$infoScroll.Dock = [System.Windows.Forms.DockStyle]::Fill
$infoScroll.AutoScroll = $true
$infoTab.Controls.Add($infoScroll)

$infoTable = New-Object System.Windows.Forms.TableLayoutPanel
$infoTable.AutoSize = $true
$infoTable.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$infoTable.ColumnCount = 4
$infoTable.RowCount = 9
$infoTable.Padding = New-Object System.Windows.Forms.Padding(24)
$infoTable.Dock = [System.Windows.Forms.DockStyle]::Top
$infoTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 165)))
$infoTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$infoTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 165)))
$infoTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$infoScroll.Controls.Add($infoTable)

$fieldNames = @(
    "案件名稱","英文名稱","網址代號","排序","完成年度","類型",
    "座落位置","基地面積","總樓地板面積","樓層","結構","案件狀態"
)
$fields = [ordered]@{}

for ($i = 0; $i -lt $fieldNames.Count; $i++) {
    $row = [math]::Floor($i / 2)
    $pair = $i % 2
    $labelColumn = if ($pair -eq 0) { 0 } else { 2 }
    $fieldColumn = if ($pair -eq 0) { 1 } else { 3 }

    $lab = New-Object System.Windows.Forms.Label
    $lab.Text = $(if ($fieldNames[$i] -eq "排序") { "顯示順序（數字小在前）" } else { $fieldNames[$i] })
    $lab.Dock = [System.Windows.Forms.DockStyle]::Fill
    $lab.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $lab.Margin = New-Object System.Windows.Forms.Padding(0,8,8,8)
    $infoTable.Controls.Add($lab, $labelColumn, $row)

    $box = New-Object System.Windows.Forms.TextBox
    $box.Dock = [System.Windows.Forms.DockStyle]::Fill
    $box.Margin = New-Object System.Windows.Forms.Padding(0,8,18,8)
    $infoTable.Controls.Add($box, $fieldColumn, $row)
    $fields[$fieldNames[$i]] = $box
}

$optionsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$optionsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$optionsPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$optionsPanel.AutoSize = $true
$optionsPanel.Margin = New-Object System.Windows.Forms.Padding(0,12,0,10)

$publishCheck = New-Object System.Windows.Forms.CheckBox
$publishCheck.Text = "發布到網站"
$publishCheck.AutoSize = $true
$publishCheck.Margin = New-Object System.Windows.Forms.Padding(0,5,30,5)
$optionsPanel.Controls.Add($publishCheck)

$homeCheck = New-Object System.Windows.Forms.CheckBox
$homeCheck.Text = "顯示在首頁作品區"
$homeCheck.AutoSize = $true
$homeCheck.Margin = New-Object System.Windows.Forms.Padding(0,5,30,5)
$optionsPanel.Controls.Add($homeCheck)

$infoTable.Controls.Add($optionsPanel, 0, 6)
$infoTable.SetColumnSpan($optionsPanel, 4)

$descriptionLabel = New-Object System.Windows.Forms.Label
$descriptionLabel.Text = "案件介紹"
$descriptionLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$descriptionLabel.Margin = New-Object System.Windows.Forms.Padding(0,8,8,8)
$infoTable.Controls.Add($descriptionLabel, 0, 7)

$descriptionBox = New-Object System.Windows.Forms.TextBox
$descriptionBox.Multiline = $true
$descriptionBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$descriptionBox.Height = 160
$descriptionBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$descriptionBox.Margin = New-Object System.Windows.Forms.Padding(0,8,18,8)
$infoTable.Controls.Add($descriptionBox, 1, 7)
$infoTable.SetColumnSpan($descriptionBox, 3)

$actionsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$actionsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$actionsPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$actionsPanel.AutoSize = $true
$actionsPanel.Margin = New-Object System.Windows.Forms.Padding(0,12,0,20)

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = "儲存案件資料"
$saveButton.Size = New-Object System.Drawing.Size(145, 40)
$saveButton.BackColor = [System.Drawing.Color]::FromArgb(166,128,80)
$saveButton.ForeColor = [System.Drawing.Color]::White
$saveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$saveButton.FlatAppearance.BorderSize = 0
$actionsPanel.Controls.Add($saveButton)

$goPhotosButton = New-Object System.Windows.Forms.Button
$goPhotosButton.Text = "照片管理"
$goPhotosButton.Size = New-Object System.Drawing.Size(125, 40)
$goPhotosButton.Margin = New-Object System.Windows.Forms.Padding(12,0,0,0)
$actionsPanel.Controls.Add($goPhotosButton)

$infoTable.Controls.Add($actionsPanel, 0, 8)
$infoTable.SetColumnSpan($actionsPanel, 4)

# ------------------------------
# Photos tab
# ------------------------------
$photosSplit = New-Object System.Windows.Forms.SplitContainer
$photosSplit.Dock = [System.Windows.Forms.DockStyle]::Fill
$photosSplit.FixedPanel = [System.Windows.Forms.FixedPanel]::Panel1
$photosSplit.SplitterDistance = 390
$photosTab.Controls.Add($photosSplit)

$photoLeftLayout = New-Object System.Windows.Forms.TableLayoutPanel
$photoLeftLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$photoLeftLayout.Padding = New-Object System.Windows.Forms.Padding(16)
$photoLeftLayout.RowCount = 4
$photoLeftLayout.ColumnCount = 3
$photoLeftLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.33)))
$photoLeftLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.33)))
$photoLeftLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.34)))
$photoLeftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
$photoLeftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$photoLeftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48)))
$photoLeftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48)))
$photosSplit.Panel1.Controls.Add($photoLeftLayout)

$photoLabel = New-Object System.Windows.Forms.Label
$photoLabel.Text = "照片順序"
$photoLabel.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 11, [System.Drawing.FontStyle]::Bold)
$photoLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$photoLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$photoLeftLayout.Controls.Add($photoLabel, 0, 0)
$photoLeftLayout.SetColumnSpan($photoLabel, 3)

$photoList = New-Object System.Windows.Forms.ListBox
$photoList.Dock = [System.Windows.Forms.DockStyle]::Fill
$photoLeftLayout.Controls.Add($photoList, 0, 1)
$photoLeftLayout.SetColumnSpan($photoList, 3)

$addPhotoButton = New-Object System.Windows.Forms.Button
$addPhotoButton.Text = "加入照片"
$addPhotoButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$addPhotoButton.Margin = New-Object System.Windows.Forms.Padding(0,6,5,4)
$photoLeftLayout.Controls.Add($addPhotoButton, 0, 2)

$removePhotoButton = New-Object System.Windows.Forms.Button
$removePhotoButton.Text = "移除照片"
$removePhotoButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$removePhotoButton.Margin = New-Object System.Windows.Forms.Padding(5,6,5,4)
$photoLeftLayout.Controls.Add($removePhotoButton, 1, 2)

$coverButton = New-Object System.Windows.Forms.Button
$coverButton.Text = "設為封面"
$coverButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$coverButton.Margin = New-Object System.Windows.Forms.Padding(5,6,0,4)
$photoLeftLayout.Controls.Add($coverButton, 2, 2)

$upButton = New-Object System.Windows.Forms.Button
$upButton.Text = "上移"
$upButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$upButton.Margin = New-Object System.Windows.Forms.Padding(0,4,5,2)
$photoLeftLayout.Controls.Add($upButton, 0, 3)

$downButton = New-Object System.Windows.Forms.Button
$downButton.Text = "下移"
$downButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$downButton.Margin = New-Object System.Windows.Forms.Padding(5,4,5,2)
$photoLeftLayout.Controls.Add($downButton, 1, 3)

$openPhotosFolderButton = New-Object System.Windows.Forms.Button
$openPhotosFolderButton.Text = "開啟資料夾"
$openPhotosFolderButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$openPhotosFolderButton.Margin = New-Object System.Windows.Forms.Padding(5,4,0,2)
$photoLeftLayout.Controls.Add($openPhotosFolderButton, 2, 3)

$preview = New-Object System.Windows.Forms.PictureBox
$preview.Dock = [System.Windows.Forms.DockStyle]::Fill
$preview.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$preview.BackColor = [System.Drawing.Color]::FromArgb(238,236,232)
$photosSplit.Panel2.Controls.Add($preview)

$currentFolder = $null
$loadingProject = $false

function Clear-Editor {
    foreach ($box in $fields.Values) { $box.Text = "" }
    $publishCheck.Checked = $false
    $homeCheck.Checked = $false
    $descriptionBox.Text = ""
    $photoList.Items.Clear()

    if ($preview.Image) {
        $preview.Image.Dispose()
        $preview.Image = $null
    }

    $script:currentFolder = $null
}

function Refresh-PhotoList {
    $photoList.Items.Clear()
    if (!$script:currentFolder) { return }

    foreach ($file in Get-PhotoFiles $script:currentFolder) {
        [void]$photoList.Items.Add($file.Name)
    }

    if ($photoList.Items.Count -gt 0) {
        $photoList.SelectedIndex = 0
    }
}

function Load-Project([string]$Folder) {
    if ($script:loadingProject) { return }
    $script:loadingProject = $true

    try {
        $script:currentFolder = $Folder
        $info = Read-Info (Join-Path $Folder "info.txt")

        foreach ($key in $fields.Keys) {
            if ($key -eq "總樓地板面積" -and !$info[$key] -and $info["建築面積"]) {
                $fields[$key].Text = [string]$info["建築面積"]
            }
            else {
                $fields[$key].Text = [string]$info[$key]
            }
        }

        $publishCheck.Checked = ([string]$info["發布"]).Trim() -eq "是"
        $homeCheck.Checked = ([string]$info["首頁顯示"]).Trim() -eq "是"
        $descriptionBox.Text = [string]$info["案件介紹"]

        Refresh-PhotoList
        $statusLabel.Text = "已載入：" + (Split-Path $Folder -Leaf)
    }
    catch {
        Log-Error $_.Exception.ToString()
        Show-Error ("載入案件失敗：`r`n" + $_.Exception.Message)
    }
    finally {
        $script:loadingProject = $false
    }
}

function Refresh-ProjectList([string]$SelectFolder = "") {
    $projectList.BeginUpdate()

    try {
        $projectList.Items.Clear()

        foreach ($folder in Get-ChildItem -LiteralPath $DataRoot -Directory |
            Where-Object { -not $_.Name.StartsWith("_") } |
            Sort-Object Name) {

            $info = Read-Info (Join-Path $folder.FullName "info.txt")
            $display = if ($info["案件名稱"]) { [string]$info["案件名稱"] } else { $folder.Name }

            $item = New-Object PSObject -Property @{
                DisplayName = $display
                FolderName = $folder.Name
                FullPath = $folder.FullName
            }
            [void]$projectList.Items.Add($item)
        }
    }
    finally {
        $projectList.EndUpdate()
    }

    if ($projectList.Items.Count -eq 0) {
        Clear-Editor
        return
    }

    $target = 0
    if ($SelectFolder) {
        for ($i=0; $i -lt $projectList.Items.Count; $i++) {
            if ($projectList.Items[$i].FolderName -eq $SelectFolder) {
                $target = $i
                break
            }
        }
    }

    $projectList.SelectedIndex = $target
    Load-Project ([string]$projectList.Items[$target].FullPath)
}

function Save-CurrentProject {
    if (!$script:currentFolder) {
        Show-Warning "請先選擇案件。"
        return $false
    }

    $slug = $fields["網址代號"].Text.Trim()
    if ($slug -notmatch '^[a-z0-9][a-z0-9\-]*$') {
        Show-Warning "網址代號只能使用英文小寫、數字與連字號，例如 sanxing-house。"
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($fields["案件名稱"].Text)) {
        Show-Warning "請填寫案件名稱。"
        return $false
    }

    $data = @{
        "發布" = $(if ($publishCheck.Checked) { "是" } else { "否" })
        "首頁顯示" = $(if ($homeCheck.Checked) { "是" } else { "否" })
        "案件介紹" = $descriptionBox.Text.Trim()
    }

    foreach ($key in $fields.Keys) {
        $data[$key] = $fields[$key].Text.Trim()
    }

    Write-Info $script:currentFolder $data
    $folderName = Split-Path $script:currentFolder -Leaf
    Refresh-ProjectList $folderName
    $statusLabel.Text = "已儲存：" + $data["案件名稱"]
    return $true
}

function Get-NextProjectOrder {
    $orders = New-Object System.Collections.Generic.List[int]

    foreach ($folder in Get-ChildItem -LiteralPath $DataRoot -Directory | Where-Object { -not $_.Name.StartsWith("_") }) {
        $existingInfo = Read-Info (Join-Path $folder.FullName "info.txt")
        $value = 0
        if ([int]::TryParse([string]$existingInfo["排序"], [ref]$value)) {
            $orders.Add($value)
        }
    }

    if ($orders.Count -eq 0) { return 10 }
    return (($orders | Measure-Object -Maximum).Maximum + 10)
}


$script:currentHomeFolder = $null
$script:loadingHome = $false

function Get-HomeImage([string]$Folder) {
    return Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.BaseName.ToLower() -eq "hero" -and
            $_.Extension.ToLower() -in @(".jpg",".jpeg",".png",".webp")
        } |
        Select-Object -First 1
}

function Write-HomeInfo([string]$Folder, [string]$ProjectSlug, [string]$Order, [bool]$Visible) {
    $lines = @(
        "顯示：$(if ($Visible) { '是' } else { '否' })"
        "排序：$Order"
        "連結作品：$ProjectSlug"
    )
    [System.IO.File]::WriteAllText((Join-Path $Folder "info.txt"), ($lines -join "`r`n"), $Utf8Bom)
}

function Refresh-HomeProjectCombo([string]$SelectedSlug = "") {
    $homeProjectCombo.Items.Clear()
    foreach ($folder in Get-ChildItem -LiteralPath $DataRoot -Directory |
        Where-Object { -not $_.Name.StartsWith("_") } | Sort-Object Name) {
        $info = Read-Info (Join-Path $folder.FullName "info.txt")
        $titleText = if ($info["案件名稱"]) { [string]$info["案件名稱"] } else { $folder.Name }
        $slugText = if ($info["網址代號"]) { [string]$info["網址代號"] } else { $folder.Name }
        $item = New-Object PSObject -Property @{ DisplayName=$titleText; Slug=$slugText }
        [void]$homeProjectCombo.Items.Add($item)
    }
    if ($homeProjectCombo.Items.Count -gt 0) {
        $target = 0
        if ($SelectedSlug) {
            for ($i=0; $i -lt $homeProjectCombo.Items.Count; $i++) {
                if ($homeProjectCombo.Items[$i].Slug -eq $SelectedSlug) { $target=$i; break }
            }
        }
        $homeProjectCombo.SelectedIndex = $target
    }
}

function Clear-HomeEditor {
    $script:currentHomeFolder = $null
    $homeOrderBox.Text = ""
    $homeVisibleCheck.Checked = $false
    Refresh-HomeProjectCombo
    if ($homePreview.Image) { $homePreview.Image.Dispose(); $homePreview.Image=$null }
}

function Load-HomeItem([string]$Folder) {
    if ($script:loadingHome) { return }
    $script:loadingHome = $true
    try {
        $script:currentHomeFolder = $Folder
        $info = Read-Info (Join-Path $Folder "info.txt")
        $homeOrderBox.Text = [string]$info["排序"]
        $homeVisibleCheck.Checked = ([string]$info["顯示"]).Trim() -eq "是"
        Refresh-HomeProjectCombo ([string]$info["連結作品"])
        if ($homePreview.Image) { $homePreview.Image.Dispose(); $homePreview.Image=$null }
        $imageFile = Get-HomeImage $Folder
        if ($imageFile) {
            $stream = New-Object System.IO.FileStream($imageFile.FullName,'Open','Read','ReadWrite')
            $sourceImage = [System.Drawing.Image]::FromStream($stream)
            $homePreview.Image = New-Object System.Drawing.Bitmap($sourceImage)
            $sourceImage.Dispose(); $stream.Dispose()
        }
    } finally {
        $script:loadingHome = $false
    }
}

function Refresh-HomeList([string]$SelectFolder = "") {
    $homeList.Items.Clear()
    foreach ($folder in Get-ChildItem -LiteralPath $HomeRoot -Directory | Sort-Object Name) {
        $info = Read-Info (Join-Path $folder.FullName "info.txt")
        $display = "尚未指定作品"
        $projectSlug = [string]$info["連結作品"]
        if ($projectSlug) {
            foreach ($projectFolder in Get-ChildItem -LiteralPath $DataRoot -Directory | Where-Object { -not $_.Name.StartsWith("_") }) {
                $projectInfo = Read-Info (Join-Path $projectFolder.FullName "info.txt")
                $slug = if ($projectInfo["網址代號"]) { [string]$projectInfo["網址代號"] } else { $projectFolder.Name }
                if ($slug -eq $projectSlug) { $display=[string]$projectInfo["案件名稱"]; break }
            }
        }
        $order = if ($info["排序"]) { [string]$info["排序"] } else { "9999" }
        $item = New-Object PSObject -Property @{
            DisplayName="$order｜$display"; FolderName=$folder.Name; FullPath=$folder.FullName
        }
        [void]$homeList.Items.Add($item)
    }
    if ($homeList.Items.Count -eq 0) { Clear-HomeEditor; return }
    $target=0
    if ($SelectFolder) {
        for ($i=0; $i -lt $homeList.Items.Count; $i++) {
            if ($homeList.Items[$i].FolderName -eq $SelectFolder) { $target=$i; break }
        }
    }
    $homeList.SelectedIndex=$target
    Load-HomeItem ([string]$homeList.Items[$target].FullPath)
}

function Get-NextHomeOrder {
    $orders = New-Object System.Collections.Generic.List[int]
    foreach ($folder in Get-ChildItem -LiteralPath $HomeRoot -Directory) {
        $info=Read-Info (Join-Path $folder.FullName "info.txt")
        $value=0
        if ([int]::TryParse([string]$info["排序"],[ref]$value)) { $orders.Add($value) }
    }
    if ($orders.Count -eq 0) { return 10 }
    return (($orders | Measure-Object -Maximum).Maximum + 10)
}

function Save-CurrentHome {
    if (!$script:currentHomeFolder) { Show-Warning "請先新增或選擇首頁照片。"; return $false }
    if ($null -eq $homeProjectCombo.SelectedItem) { Show-Warning "請選擇這張首頁照片要連結的作品。"; return $false }
    if ($null -eq (Get-HomeImage $script:currentHomeFolder)) {
        Show-Warning "請先選擇首頁照片。建議尺寸 1920 × 1280 px。"; return $false
    }
    $orderValue=$homeOrderBox.Text.Trim()
    $parsed=0
    if (![int]::TryParse($orderValue,[ref]$parsed)) {
        Show-Warning "輪播順序請輸入數字，例如 10、20、30。"; return $false
    }
    Write-HomeInfo $script:currentHomeFolder ([string]$homeProjectCombo.SelectedItem.Slug) $orderValue $homeVisibleCheck.Checked
    Refresh-HomeList (Split-Path $script:currentHomeFolder -Leaf)
    $statusLabel.Text="首頁設定已儲存"
    return $true
}

# ------------------------------
# Events
# ------------------------------
$projectList.Add_SelectedIndexChanged({
    if ($script:loadingProject) { return }
    if ($null -eq $projectList.SelectedItem) { return }

    $path = [string]$projectList.SelectedItem.FullPath
    if ($path -and (Test-Path -LiteralPath $path)) {
        Load-Project $path
    }
})

$newButton.Add_Click({
    try {
        $dialog = New-Object System.Windows.Forms.Form
        $dialog.Text = "新增案件"
        $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
        $dialog.ClientSize = New-Object System.Drawing.Size(470, 230)
        $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $dialog.MaximizeBox = $false
        $dialog.MinimizeBox = $false
        $dialog.ShowInTaskbar = $false
        $dialog.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI",10)
        $dialog.BackColor = [System.Drawing.Color]::FromArgb(246,244,239)

        $nameLabel = New-Object System.Windows.Forms.Label
        $nameLabel.Text = "案件名稱"
        $nameLabel.AutoSize = $true
        $nameLabel.Location = New-Object System.Drawing.Point(24,22)
        $dialog.Controls.Add($nameLabel)

        $nameBox = New-Object System.Windows.Forms.TextBox
        $nameBox.Location = New-Object System.Drawing.Point(24,48)
        $nameBox.Size = New-Object System.Drawing.Size(420,28)
        $dialog.Controls.Add($nameBox)

        $slugLabel = New-Object System.Windows.Forms.Label
        $slugLabel.Text = "網址代號（英文小寫，例如 sanxing-house）"
        $slugLabel.AutoSize = $true
        $slugLabel.Location = New-Object System.Drawing.Point(24,92)
        $dialog.Controls.Add($slugLabel)

        $slugBox = New-Object System.Windows.Forms.TextBox
        $slugBox.Location = New-Object System.Drawing.Point(24,118)
        $slugBox.Size = New-Object System.Drawing.Size(420,28)
        $dialog.Controls.Add($slugBox)

        $ok = New-Object System.Windows.Forms.Button
        $ok.Text = "建立"
        $ok.Size = New-Object System.Drawing.Size(90,36)
        $ok.Location = New-Object System.Drawing.Point(254,172)
        $ok.BackColor = [System.Drawing.Color]::FromArgb(166,128,80)
        $ok.ForeColor = [System.Drawing.Color]::White
        $ok.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $ok.FlatAppearance.BorderSize = 0
        $dialog.Controls.Add($ok)

        $cancel = New-Object System.Windows.Forms.Button
        $cancel.Text = "取消"
        $cancel.Size = New-Object System.Drawing.Size(90,36)
        $cancel.Location = New-Object System.Drawing.Point(354,172)
        $dialog.Controls.Add($cancel)

        $dialog.AcceptButton = $ok
        $dialog.CancelButton = $cancel

        $ok.Add_Click({
            $name = $nameBox.Text.Trim()
            $slug = $slugBox.Text.Trim()

            if ([string]::IsNullOrWhiteSpace($name)) {
                Show-Warning "請輸入案件名稱。"
                return
            }

            if ($slug -notmatch '^[a-z0-9][a-z0-9\-]*$') {
                Show-Warning "網址代號只能使用英文小寫、數字與連字號。"
                return
            }

            $folder = Join-Path $DataRoot $slug
            if (Test-Path -LiteralPath $folder) {
                Show-Warning "此網址代號已存在。"
                return
            }

            New-Item -ItemType Directory -Path $folder | Out-Null
            Write-Info $folder @{
                "發布"="否"; "網址代號"=$slug; "排序"=[string](Get-NextProjectOrder); "案件名稱"=$name;
                "英文名稱"=""; "完成年度"=(Get-Date -Format "yyyy"); "類型"="住宅";
                "座落位置"=""; "基地面積"=""; "總樓地板面積"=""; "樓層"="";
                "結構"=""; "案件狀態"="設計中"; "首頁顯示"="是"; "案件介紹"=""
            }

            $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $dialog.Close()
        })

        $cancel.Add_Click({
            $dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $dialog.Close()
        })

        $result = $dialog.ShowDialog($form)
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Refresh-ProjectList $slugBox.Text.Trim()
            $statusLabel.Text = "已建立案件：" + $nameBox.Text.Trim()
        }
    }
    catch {
        Log-Error $_.Exception.ToString()
        Show-Error ("建立案件失敗：`r`n" + $_.Exception.Message)
    }
})

$deleteButton.Add_Click({
    if (!$script:currentFolder) { return }
    $name = Split-Path $script:currentFolder -Leaf

    if (Confirm-Action "確定刪除案件「$name」及其所有照片嗎？") {
        Remove-Item -LiteralPath $script:currentFolder -Recurse -Force
        Refresh-ProjectList
        $statusLabel.Text = "案件已刪除"
    }
})

$openFolderButton.Add_Click({
    if ($script:currentFolder) {
        Start-Process explorer.exe $script:currentFolder
    }
})

$openPhotosFolderButton.Add_Click({
    if ($script:currentFolder) {
        Start-Process explorer.exe $script:currentFolder
    }
})

$saveButton.Add_Click({
    [void](Save-CurrentProject)
})

$goPhotosButton.Add_Click({
    $tabs.SelectedTab = $photosTab
})

$photoList.Add_SelectedIndexChanged({
    if ($preview.Image) {
        $preview.Image.Dispose()
        $preview.Image = $null
    }

    if (!$script:currentFolder -or $null -eq $photoList.SelectedItem) { return }

    $path = Join-Path $script:currentFolder ([string]$photoList.SelectedItem)
    if (Test-Path -LiteralPath $path) {
        try {
            $stream = New-Object System.IO.FileStream($path, 'Open', 'Read', 'ReadWrite')
            $sourceImage = [System.Drawing.Image]::FromStream($stream)
            $preview.Image = New-Object System.Drawing.Bitmap($sourceImage)
            $sourceImage.Dispose()
            $stream.Dispose()
        }
        catch {
            Log-Error $_.Exception.ToString()
        }
    }
})

$addPhotoButton.Add_Click({
    if (!$script:currentFolder) {
        Show-Warning "請先選擇案件。"
        return
    }

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "選擇照片"
    $dialog.Filter = "圖片檔案|*.jpg;*.jpeg;*.png;*.webp"
    $dialog.Multiselect = $true

    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $existing = Get-PhotoFiles $script:currentFolder
        $numbers = @(
            $existing |
            Where-Object { $_.BaseName -match '^\d+$' } |
            ForEach-Object { [int]$_.BaseName }
        )
        $next = if ($numbers.Count -gt 0) { ($numbers | Measure-Object -Maximum).Maximum + 1 } else { 1 }

        foreach ($source in $dialog.FileNames) {
            $ext = [System.IO.Path]::GetExtension($source).ToLower()
            $target = "{0:D2}{1}" -f $next, $ext
            Copy-Item -LiteralPath $source -Destination (Join-Path $script:currentFolder $target)
            $next++
        }

        Refresh-PhotoList
        $statusLabel.Text = "照片已加入"
    }
})

$removePhotoButton.Add_Click({
    if (!$script:currentFolder -or $null -eq $photoList.SelectedItem) { return }

    $name = [string]$photoList.SelectedItem
    if (Confirm-Action "確定移除照片「$name」嗎？") {
        if ($preview.Image) {
            $preview.Image.Dispose()
            $preview.Image = $null
        }
        Remove-Item -LiteralPath (Join-Path $script:currentFolder $name) -Force
        Refresh-PhotoList
    }
})

$coverButton.Add_Click({
    if (!$script:currentFolder -or $null -eq $photoList.SelectedItem) { return }

    $selectedName = [string]$photoList.SelectedItem
    if ($selectedName.ToLower().StartsWith("cover.")) {
        Show-Info "這張照片已經是封面。"
        return
    }

    $selectedPath = Join-Path $script:currentFolder $selectedName
    $selectedExt = [System.IO.Path]::GetExtension($selectedName).ToLower()

    $oldCover = Get-PhotoFiles $script:currentFolder |
        Where-Object { $_.BaseName.ToLower() -eq "cover" } |
        Select-Object -First 1

    if ($oldCover) {
        $index = 99
        do {
            $oldName = "{0:D2}{1}" -f $index, $oldCover.Extension.ToLower()
            $index++
        } while (Test-Path -LiteralPath (Join-Path $script:currentFolder $oldName))

        Rename-Item -LiteralPath $oldCover.FullName -NewName $oldName
    }

    Rename-Item -LiteralPath $selectedPath -NewName ("cover" + $selectedExt)
    Refresh-PhotoList
    $statusLabel.Text = "已設定封面"
})

function Move-Photo([int]$Direction) {
    if (!$script:currentFolder -or $null -eq $photoList.SelectedItem) { return }

    $selectedName = [string]$photoList.SelectedItem
    if ($selectedName.ToLower().StartsWith("cover.")) {
        Show-Warning "封面固定在第一張，不需要移動。"
        return
    }

    $files = @(Get-PhotoFiles $script:currentFolder | Where-Object { $_.BaseName.ToLower() -ne "cover" })
    $currentIndex = -1

    for ($i=0; $i -lt $files.Count; $i++) {
        if ($files[$i].Name -eq $selectedName) {
            $currentIndex = $i
            break
        }
    }

    if ($currentIndex -lt 0) { return }

    $targetIndex = $currentIndex + $Direction
    if ($targetIndex -lt 0 -or $targetIndex -ge $files.Count) { return }

    $temp = $files[$currentIndex]
    $files[$currentIndex] = $files[$targetIndex]
    $files[$targetIndex] = $temp

    $tempNames = @()
    for ($i=0; $i -lt $files.Count; $i++) {
        $tempName = "__skh_tmp_$i$($files[$i].Extension.ToLower())"
        Rename-Item -LiteralPath $files[$i].FullName -NewName $tempName
        $tempNames += $tempName
    }

    for ($i=0; $i -lt $tempNames.Count; $i++) {
        $ext = [System.IO.Path]::GetExtension($tempNames[$i])
        $newName = "{0:D2}{1}" -f ($i + 1), $ext
        Rename-Item -LiteralPath (Join-Path $script:currentFolder $tempNames[$i]) -NewName $newName
    }

    Refresh-PhotoList
}

$upButton.Add_Click({ Move-Photo -1 })
$downButton.Add_Click({ Move-Photo 1 })


$homeList.Add_SelectedIndexChanged({
    if ($script:loadingHome -or $null -eq $homeList.SelectedItem) { return }
    $path=[string]$homeList.SelectedItem.FullPath
    if ($path -and (Test-Path -LiteralPath $path)) { Load-HomeItem $path }
})

$homeNewButton.Add_Click({
    $folderName="hero-" + (Get-Date -Format "yyyyMMddHHmmssfff")
    $folder=Join-Path $HomeRoot $folderName
    New-Item -ItemType Directory -Path $folder | Out-Null
    Write-HomeInfo $folder "" ([string](Get-NextHomeOrder)) $true
    Refresh-HomeList $folderName
})

$homeDeleteButton.Add_Click({
    if (!$script:currentHomeFolder) { return }
    if (Confirm-Action "確定刪除這張首頁輪播照片及設定嗎？`r`n作品案件與作品照片不會受到影響。") {
        if ($homePreview.Image) { $homePreview.Image.Dispose(); $homePreview.Image=$null }
        Remove-Item -LiteralPath $script:currentHomeFolder -Recurse -Force
        Refresh-HomeList
    }
})

$homeOpenFolderButton.Add_Click({
    if ($script:currentHomeFolder) { Start-Process explorer.exe $script:currentHomeFolder }
    else { Start-Process explorer.exe $HomeRoot }
})

$homeImageButton.Add_Click({
    if (!$script:currentHomeFolder) { Show-Warning "請先按「＋ 新增首頁照片」。"; return }
    $dialog=New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title="選擇首頁輪播照片（建議 1920 × 1280 px）"
    $dialog.Filter="圖片檔案|*.jpg;*.jpeg;*.png;*.webp"
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($oldImage in Get-ChildItem -LiteralPath $script:currentHomeFolder -File -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName.ToLower() -eq "hero" }) {
            Remove-Item -LiteralPath $oldImage.FullName -Force
        }
        $ext=[System.IO.Path]::GetExtension($dialog.FileName).ToLower()
        $target=Join-Path $script:currentHomeFolder ("hero"+$ext)
        Copy-Item -LiteralPath $dialog.FileName -Destination $target -Force
        if ($homePreview.Image) { $homePreview.Image.Dispose(); $homePreview.Image=$null }
        $stream=New-Object System.IO.FileStream($target,'Open','Read','ReadWrite')
        $sourceImage=[System.Drawing.Image]::FromStream($stream)
        $homePreview.Image=New-Object System.Drawing.Bitmap($sourceImage)
        if ($sourceImage.Width -ne 1920 -or $sourceImage.Height -ne 1280) {
            Show-Info "照片已加入。`r`n目前尺寸：$($sourceImage.Width) × $($sourceImage.Height) px`r`n建議使用 1920 × 1280 px。"
        }
        $sourceImage.Dispose(); $stream.Dispose()
    }
})

$homeSaveButton.Add_Click({ [void](Save-CurrentHome) })

$generateButton.Add_Click({
    if ($tabs.SelectedTab -eq $homeTab -and $script:currentHomeFolder) {
        if (!(Save-CurrentHome)) { return }
    }
    elseif ($script:currentFolder) {
        if (!(Save-CurrentProject)) { return }
    }

    if (!(Test-Path -LiteralPath $Generator)) {
        Show-Error "找不到 generate-projects.ps1。"
        return
    }

    try {
        $statusLabel.Text = "正在備份並產生網站..."
        $backupPath = Create-WebsiteBackup
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        $process = New-Object System.Diagnostics.ProcessStartInfo
        $process.FileName = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $process.Arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $Generator + '"'
        $process.WorkingDirectory = $Root
        $process.UseShellExecute = $false
        $process.RedirectStandardOutput = $true
        $process.RedirectStandardError = $true
        $process.CreateNoWindow = $true

        $running = [System.Diagnostics.Process]::Start($process)
        $output = $running.StandardOutput.ReadToEnd()
        $errorOutput = $running.StandardError.ReadToEnd()
        $running.WaitForExit()

        if ($running.ExitCode -ne 0) {
            throw ($errorOutput + "`r`n" + $output)
        }

        $statusLabel.Text = "網站產生完成"
        Show-Info "網站已成功產生，並已建立自動備份。`r`n`r`n備份位置：`r`n$backupPath`r`n`r`n下一步請開啟 GitHub Desktop，執行 Commit 與 Push origin。"
    }
    catch {
        Log-Error $_.Exception.ToString()
        $statusLabel.Text = "產生網站失敗"
        Show-Error ("產生網站失敗：`r`n" + $_.Exception.Message)
    }
    finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

$form.Add_Shown({
    Refresh-ProjectList
    Refresh-HomeList
})

[void]$form.ShowDialog()
