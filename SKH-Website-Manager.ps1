param()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataRoot = Join-Path $Root "projects-data"
$Generator = Join-Path $Root "generate-projects.ps1"
$ErrorLog = Join-Path $Root "SKH-Manager-Error.txt"
$Utf8Bom = New-Object System.Text.UTF8Encoding($true)

if (!(Test-Path -LiteralPath $DataRoot)) {
    New-Item -ItemType Directory -Path $DataRoot | Out-Null
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
        "座落位置","基地面積","建築面積","樓層","結構","案件狀態",
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
$infoTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 100)))
$infoTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$infoTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 100)))
$infoTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$infoScroll.Controls.Add($infoTable)

$fieldNames = @(
    "案件名稱","英文名稱","網址代號","排序","完成年度","類型",
    "座落位置","基地面積","建築面積","樓層","結構","案件狀態"
)
$fields = [ordered]@{}

for ($i = 0; $i -lt $fieldNames.Count; $i++) {
    $row = [math]::Floor($i / 2)
    $pair = $i % 2
    $labelColumn = if ($pair -eq 0) { 0 } else { 2 }
    $fieldColumn = if ($pair -eq 0) { 1 } else { 3 }

    $lab = New-Object System.Windows.Forms.Label
    $lab.Text = $fieldNames[$i]
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
$homeCheck.Text = "顯示在首頁"
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
            $fields[$key].Text = [string]$info[$key]
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
                "發布"="否"; "網址代號"=$slug; "排序"="10"; "案件名稱"=$name;
                "英文名稱"=""; "完成年度"=(Get-Date -Format "yyyy"); "類型"="住宅";
                "座落位置"=""; "基地面積"=""; "建築面積"=""; "樓層"="";
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

$generateButton.Add_Click({
    if ($script:currentFolder) {
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
})

[void]$form.ShowDialog()
