param()

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataRoot = Join-Path $Root "projects-data"
$TemplatePath = Join-Path $Root "project-auto-template.html"
$LogPath = Join-Path $Root "作品更新紀錄.txt"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

$DefaultProjectTemplate = @'
<!doctype html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="description" content="{{DESCRIPTION_META}}">
  <title>{{TITLE}}｜黃上科建築師事務所</title>
  <link rel="stylesheet" href="style.css?v=100">
  <link rel="icon" href="images/favicon.ico" sizes="any">
  <link rel="icon" type="image/png" href="images/favicon-32.png" sizes="32x32">
  <link rel="apple-touch-icon" href="images/apple-touch-icon.png">
</head>
<body class="detail-page">
  <header class="navbar inner-navbar" id="navbar">
    <a class="brand brand-logo" href="index.html" aria-label="返回首頁">
      <img src="images/skh-logo.png" alt="SKH Design 黃上科建築師事務所">
    </a>
    <button class="menu-toggle" id="menuToggle" aria-label="開啟選單" aria-expanded="false">
      <span></span><span></span><span></span>
    </button>
    <nav class="nav-links" id="navLinks">
      <a href="index.html#projects">作品</a>
      <a href="about-text.html">關於</a>
      <a href="about.html">事務所</a>
      <a href="contact.html">聯絡</a>
    </nav>
  </header>

  <div class="menu-overlay" id="menuOverlay" aria-hidden="true"></div>

  <main>
    <section class="detail-gallery" data-detail-gallery>
      <div class="detail-viewport">
        <div class="detail-track">
{{SLIDES}}
        </div>
      </div>
      <div class="detail-thumbnail-bar" aria-label="作品照片縮圖">
{{THUMBS}}
      </div>
    </section>

    <section class="detail-info">
      <p class="auto-project-english">{{ENGLISH_TITLE}}</p>
      <h1>{{TITLE}}</h1>
      <div class="detail-meta-grid">
{{META}}
      </div>
{{DESCRIPTION_SECTION}}
    </section>
  </main>

  <footer class="site-footer">
    <div class="footer-inner">
      <div class="footer-brand"><img src="images/skh-logo.png" alt="SKH Design 黃上科建築師事務所"></div>
      <div class="footer-info">
        <div class="footer-contact-row footer-contact-static"><img class="footer-icon-img" src="images/icons/location.svg" alt="" aria-hidden="true"><span>宜蘭縣羅東鎮公正路289-4號2樓</span></div>
        <div class="footer-contact-row footer-contact-static"><img class="footer-icon-img" src="images/icons/phone.svg" alt="" aria-hidden="true"><span>電話：(03)961-0816</span></div>
        <div class="footer-contact-row footer-contact-static"><img class="footer-icon-img" src="images/icons/fax.svg" alt="" aria-hidden="true"><span>傳真：(03)961-5912</span></div>
        <div class="footer-contact-row footer-contact-static"><img class="footer-icon-img" src="images/icons/mail.svg" alt="" aria-hidden="true"><span>信箱：koe434@gmail.com</span></div>
      </div>
      <div class="footer-links">
        <a href="index.html#projects">作品</a>
        <a href="about-text.html">關於</a>
        <a href="about.html">事務所</a>
        <a href="contact.html">聯絡</a>
      </div>
    </div>
    <div class="footer-bottom"><span>Architecture · Interior · Planning</span><span>© 2026 SKH DESIGN</span></div>
  </footer>

  <div class="lightbox" id="lightbox" aria-hidden="true">
    <button class="lightbox-close" type="button" aria-label="關閉大圖">×</button>
    <button class="lightbox-zone lightbox-zone-left" type="button" aria-label="上一張照片"></button>
    <button class="lightbox-zone lightbox-zone-right" type="button" aria-label="下一張照片"></button>
    <div class="lightbox-stage"><img class="lightbox-image" src="" alt=""></div>
    <div class="lightbox-counter" aria-live="polite"></div>
  </div>

  <script src="script.js?v=100"></script>
</body>
</html>
'@

function Escape-Html([string]$Text) {
    if ($null -eq $Text) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Read-Info([string]$Path) {
    $result = [ordered]@{}
    $lastKey = $null

    foreach ($raw in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = $raw.TrimEnd()
        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($lastKey -eq "案件介紹" -and $result.Contains($lastKey)) {
                $result[$lastKey] += "`n`n"
            }
            continue
        }

        if ($line -match '^\s*([^：:]+)[：:]\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $result[$key] = $value
            $lastKey = $key
        }
        elseif ($lastKey) {
            $result[$lastKey] = ($result[$lastKey] + "`n" + $line.Trim()).Trim()
        }
    }
    return $result
}

function Is-Yes([string]$Value) {
    if ($null -eq $Value) { return $false }
    return @("是","yes","true","1","y") -contains $Value.Trim().ToLower()
}

function Safe-Slug([string]$Value) {
    $slug = $Value.Trim().ToLower()
    if ($slug -notmatch '^[a-z0-9][a-z0-9\-]*$') {
        throw "網址代號只能使用英文小寫、數字與連字號，例如 sanxing-house。現在填寫的是：$Value"
    }
    return $slug
}

function Photo-SortKey([System.IO.FileInfo]$File) {
    $name = $File.BaseName.ToLower()
    if ($name -eq "cover") { return "000000_cover" }
    if ($name -match '^(\d+)$') { return ("{0:D6}_{1}" -f [int]$matches[1], $name) }
    return "900000_" + $name
}

function Make-Meta([string]$Label, [string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    return '        <div><span>' + (Escape-Html $Label) + '</span><strong>' + (Escape-Html $Value) + "</strong></div>`n"
}

function Replace-AutoBlock([string]$Content, [string]$Cards) {
    $pattern = '(?s)<!-- AUTO_PROJECTS_START -->.*?<!-- AUTO_PROJECTS_END -->'
    $replacement = "<!-- AUTO_PROJECTS_START -->`n        <!-- 此區塊由 SKH Website Manager 自動產生，請勿手動修改 -->`n$Cards        <!-- AUTO_PROJECTS_END -->"
    if ($Content -notmatch $pattern) {
        throw "找不到 AUTO_PROJECTS_START / AUTO_PROJECTS_END 標記。"
    }
    return [regex]::Replace($Content, $pattern, $replacement, 1)
}

$logs = New-Object System.Collections.Generic.List[string]
$logs.Add("更新時間：" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
$logs.Add("")

if (!(Test-Path -LiteralPath $DataRoot)) {
    throw "找不到 projects-data 資料夾。"
}
if (!(Test-Path -LiteralPath $TemplatePath)) {
    Write-Utf8 $TemplatePath $DefaultProjectTemplate
    $logs.Add("已自動修復：project-auto-template.html")
}

$template = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
# 清除已不存在案件所留下的舊自動頁面
Get-ChildItem -LiteralPath $Root -Filter "project-auto-*.html" -File -ErrorAction SilentlyContinue | Remove-Item -Force

$projects = New-Object System.Collections.Generic.List[object]
$seenSlugs = @{}

foreach ($folder in Get-ChildItem -LiteralPath $DataRoot -Directory) {
    if ($folder.Name.StartsWith("_")) { continue }

    $infoPath = Join-Path $folder.FullName "info.txt"
    if (!(Test-Path -LiteralPath $infoPath)) {
        $logs.Add("略過：$($folder.Name)（沒有 info.txt）")
        continue
    }

    $info = Read-Info $infoPath
    if (!(Is-Yes $info["發布"])) {
        $logs.Add("未發布：$($folder.Name)")
        continue
    }

    $title = $info["案件名稱"]
    if ([string]::IsNullOrWhiteSpace($title)) {
        throw "$($folder.Name) 的 info.txt 沒有填寫「案件名稱」。"
    }

    $slugValue = $info["網址代號"]
    if ([string]::IsNullOrWhiteSpace($slugValue)) { $slugValue = $folder.Name }
    $slug = Safe-Slug $slugValue

    if ($seenSlugs.ContainsKey($slug)) {
        throw "網址代號重複：$slug"
    }
    $seenSlugs[$slug] = $true

    $photos = @(Get-ChildItem -LiteralPath $folder.FullName -File | Where-Object {
        $_.Extension.ToLower() -in @(".jpg",".jpeg",".png",".webp")
    } | Sort-Object @{Expression={ Photo-SortKey $_ }})

    if ($photos.Count -eq 0) {
        $logs.Add("警告：$title 沒有照片，暫不產生。")
        continue
    }

    $relativeFolder = "projects-data/" + [uri]::EscapeDataString($folder.Name)
    $cover = $photos[0]
    $coverCandidate = $photos | Where-Object { $_.BaseName.ToLower() -eq "cover" } | Select-Object -First 1
    if ($coverCandidate) { $cover = $coverCandidate }

    $slides = New-Object System.Text.StringBuilder
    $thumbs = New-Object System.Text.StringBuilder
    $photoIndex = 0

    # cover 只顯示一次；若 cover 存在，其他照片接續
    $orderedPhotos = @($cover) + @($photos | Where-Object { $_.FullName -ne $cover.FullName })

    foreach ($photo in $orderedPhotos) {
        $photoIndex++
        $src = $relativeFolder + "/" + [uri]::EscapeDataString($photo.Name)
        [void]$slides.AppendLine('          <figure class="detail-slide"><img src="' + $src + '" alt="' + (Escape-Html $title) + ' 照片 ' + $photoIndex + '" loading="' + ($(if($photoIndex -eq 1){"eager"}else{"lazy"})) + '"></figure>')
        $active = $(if ($photoIndex -eq 1) { " active" } else { "" })
        [void]$thumbs.AppendLine('        <button class="detail-thumb' + $active + '" type="button" aria-label="顯示第 ' + $photoIndex + ' 張照片"><img src="' + $src + '" alt="" loading="lazy"></button>')
    }

    $meta = ""
    $meta += Make-Meta "類型" $info["類型"]
    $meta += Make-Meta "完成年度" $info["完成年度"]
    $meta += Make-Meta "座落位置" $info["座落位置"]
    $meta += Make-Meta "基地面積" $info["基地面積"]
    $totalFloorArea = if ($info["總樓地板面積"]) { $info["總樓地板面積"] } else { $info["建築面積"] }
    $meta += Make-Meta "總樓地板面積" $totalFloorArea
    $meta += Make-Meta "樓層" $info["樓層"]
    $meta += Make-Meta "結構" $info["結構"]
    $meta += Make-Meta "案件狀態" $info["案件狀態"]

    $description = $info["案件介紹"]
    $descriptionSection = ""
    if (![string]::IsNullOrWhiteSpace($description)) {
        $paragraphs = $description -split "(`r?`n){2,}"
        $pHtml = ($paragraphs | ForEach-Object {
            $one = $_.Trim()
            if ($one) { "        <p>" + (Escape-Html $one).Replace("`r`n","<br>").Replace("`n","<br>") + "</p>" }
        }) -join "`n"
        $descriptionSection = @"
      <div class="auto-project-description">
        <h2>PROJECT DESCRIPTION</h2>
$pHtml
      </div>
"@
    }

    $englishTitle = $info["英文名稱"]
    $metaDescription = $title + "，" + $info["座落位置"] + "，黃上科建築師事務所作品。"

    $page = $template
    $page = $page.Replace("{{TITLE}}", (Escape-Html $title))
    $page = $page.Replace("{{ENGLISH_TITLE}}", (Escape-Html $englishTitle))
    $page = $page.Replace("{{DESCRIPTION_META}}", (Escape-Html $metaDescription))
    $page = $page.Replace("{{SLIDES}}", $slides.ToString().TrimEnd())
    $page = $page.Replace("{{THUMBS}}", $thumbs.ToString().TrimEnd())
    $page = $page.Replace("{{META}}", $meta.TrimEnd())
    $page = $page.Replace("{{DESCRIPTION_SECTION}}", $descriptionSection.TrimEnd())

    $outputName = "project-auto-" + $slug + ".html"
    Write-Utf8 (Join-Path $Root $outputName) $page

    $sort = 9999
    [int]::TryParse($info["排序"], [ref]$sort) | Out-Null

    $projects.Add([pscustomobject]@{
        Sort = $sort
        Title = $title
        Year = $info["完成年度"]
        Cover = $relativeFolder + "/" + [uri]::EscapeDataString($cover.Name)
        Url = $outputName
        Home = Is-Yes $info["首頁顯示"]
    })

    $logs.Add("完成：$title → $outputName（$($orderedPhotos.Count) 張照片）")
}

$sorted = @($projects | Sort-Object Sort, Title)
$homeCards = New-Object System.Text.StringBuilder
$allCards = New-Object System.Text.StringBuilder

foreach ($item in $sorted) {
    $card = @"
        <article class="home-grid-item auto-generated-project">
          <a href="$($item.Url)"><img src="$($item.Cover)" alt="$(Escape-Html $item.Title)" loading="lazy"></a>
          <h2><a href="$($item.Url)">｜$(Escape-Html $item.Title)｜</a></h2><p>$(Escape-Html $item.Year)</p>
        </article>
"@
    [void]$allCards.Append($card)
    if ($item.Home) { [void]$homeCards.Append($card) }
}

$indexPath = Join-Path $Root "index.html"
$index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
$homeOutput = $homeCards.ToString()
if ([string]::IsNullOrWhiteSpace($homeOutput)) {
    $homeOutput = "        <div class=`"projects-empty-state`"><p>作品資料整理中</p><span>PROJECTS COMING SOON</span></div>`n"
}
$index = Replace-AutoBlock $index $homeOutput
Write-Utf8 $indexPath $index

$allPath = Join-Path $Root "all-projects.html"
if (Test-Path -LiteralPath $allPath) {
    $all = Get-Content -LiteralPath $allPath -Raw -Encoding UTF8
    $allOutput = $allCards.ToString()
    if ([string]::IsNullOrWhiteSpace($allOutput)) {
        $allOutput = "      <div class=`"projects-empty-state`"><p>作品資料整理中</p><span>PROJECTS COMING SOON</span></div>`n"
    }
    $all = Replace-AutoBlock $all $allOutput
    Write-Utf8 $allPath $all
}

$logs.Add("")
$logs.Add("共產生 $($sorted.Count) 個案件。")
$logs.Add("下一步：開啟 GitHub Desktop，執行 Commit 與 Push origin。")
Write-Utf8 $LogPath ($logs -join "`r`n")

Write-Host ""
Write-Host "========================================" -ForegroundColor DarkYellow
Write-Host "  SKH 作品更新完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor DarkYellow
Write-Host "成功產生 $($sorted.Count) 個案件。" -ForegroundColor White
Write-Host "詳細紀錄：作品更新紀錄.txt" -ForegroundColor White
Write-Host ""
