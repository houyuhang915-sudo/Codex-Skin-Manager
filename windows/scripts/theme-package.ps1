Set-StrictMode -Version 2.0

$DreamSkinBuiltInThemeIds = @(
  'codex-default',
  'salary-cat-office',
  'miku-dream-skin',
  'nailong-sunshine',
  'cyrene-star-rail',
  'blue-archive-ensemble',
  'cartethyia-wuthering-waves',
  'furina-genshin',
  'firefly-star-rail',
  'saber-fate',
  'asuka-eva',
  'rem-rezero',
  'red-horizon',
  'black-gold-stage'
)

function Test-DreamSkinThemeId {
  param([Parameter(Mandatory = $true)][string]$ThemeId)

  return $ThemeId.Length -ge 3 -and $ThemeId.Length -le 64 -and
    $ThemeId -cmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$'
}

function Assert-DreamSkinPng {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][long]$MaximumBytes
  )

  $item = Get-Item -LiteralPath $Path -ErrorAction Stop
  if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "$Label 必须是普通文件，符号链接不受支持。"
  }
  if ($item.Length -le 0 -or $item.Length -gt $MaximumBytes) {
    throw "$Label 为空或超过大小限制。"
  }

  $expected = [byte[]](0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)
  $stream = [IO.File]::OpenRead($Path)
  try {
    $actual = New-Object byte[] 8
    if ($stream.Read($actual, 0, 8) -ne 8) { throw "$Label 不是有效的 PNG 文件。" }
    for ($index = 0; $index -lt 8; $index++) {
      if ($actual[$index] -ne $expected[$index]) { throw "$Label 必须是真实 PNG 文件。" }
    }
  } finally {
    $stream.Dispose()
  }
}

function Get-DreamSkinImageSize {
  param([Parameter(Mandatory = $true)][string]$Path)

  if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    $image = [System.Drawing.Image]::FromFile($Path)
    try {
      return [pscustomobject]@{ Width = $image.Width; Height = $image.Height }
    } finally {
      $image.Dispose()
    }
  }

  $stream = [IO.File]::OpenRead($Path)
  try {
    $header = New-Object byte[] 24
    if ($stream.Read($header, 0, 24) -ne 24 -or
        $header[12] -ne 0x49 -or $header[13] -ne 0x48 -or
        $header[14] -ne 0x44 -or $header[15] -ne 0x52) {
      throw 'PNG 文件缺少标准 IHDR。'
    }
    $width = ([uint32]$header[16] -shl 24) -bor ([uint32]$header[17] -shl 16) -bor
      ([uint32]$header[18] -shl 8) -bor [uint32]$header[19]
    $height = ([uint32]$header[20] -shl 24) -bor ([uint32]$header[21] -shl 16) -bor
      ([uint32]$header[22] -shl 8) -bor [uint32]$header[23]
    if ($width -eq 0 -or $height -eq 0 -or
        $width -gt [int]::MaxValue -or $height -gt [int]::MaxValue) {
      throw 'PNG 图片尺寸无效。'
    }
    return [pscustomobject]@{ Width = [int]$width; Height = [int]$height }
  } finally {
    $stream.Dispose()
  }
}

function Assert-DreamSkinThemePackage {
  param([Parameter(Mandatory = $true)][string]$Path)

  $directory = Get-Item -LiteralPath $Path -ErrorAction Stop
  if (-not $directory.PSIsContainer -or
      ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw '请选择普通主题文件夹。'
  }

  $manifestPath = Join-Path $directory.FullName 'theme.json'
  $backgroundPath = Join-Path $directory.FullName 'background.png'
  $previewPath = Join-Path $directory.FullName 'preview.png'
  $manifestItem = Get-Item -LiteralPath $manifestPath -ErrorAction Stop
  if ($manifestItem.PSIsContainer -or
      ($manifestItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      $manifestItem.Length -le 0 -or $manifestItem.Length -gt 262144) {
    throw 'theme.json 缺失、为空或超过大小限制。'
  }
  Assert-DreamSkinPng -Path $backgroundPath -Label 'background.png' -MaximumBytes 31457280
  Assert-DreamSkinPng -Path $previewPath -Label 'preview.png' -MaximumBytes 10485760

  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $propertyNames = @($manifest.PSObject.Properties.Name)
  if ($propertyNames -contains 'taskImage') { throw 'schema 2 不使用 taskImage 字段。' }
  if ($manifest.schemaVersion -ne 2) { throw 'schemaVersion 必须为 2。' }
  if (-not (Test-DreamSkinThemeId -ThemeId ([string]$manifest.id))) {
    throw '主题 ID 仅支持 3-64 位小写字母、数字和连字符。'
  }
  if ([string]::IsNullOrWhiteSpace([string]$manifest.name) -or
      ([string]$manifest.name).Length -gt 80) {
    throw '主题名称缺失或过长。'
  }
  if ($manifest.image -cne 'background.png' -or $manifest.preview -cne 'preview.png') {
    throw 'image 和 preview 必须使用标准 PNG 文件名。'
  }
  if ($manifest.avatarOverlay -cne 'show') { throw 'avatarOverlay 必须为 show。' }
  if ($propertyNames -contains 'mode' -and $manifest.mode -ceq 'original') {
    throw '自定义主题不能声明 original 模式。'
  }
  if ($propertyNames -cnotcontains 'style' -or
      [string]::IsNullOrWhiteSpace([string]$manifest.style) -or
      ([string]$manifest.style).Length -gt 64) {
    throw 'style 为必需字段且不能超过 64 个字符。'
  }
  if ($propertyNames -cnotcontains 'appearance' -or
      @('auto', 'light', 'dark') -cnotcontains [string]$manifest.appearance) {
    throw 'appearance 仅支持 auto、light 或 dark。'
  }
  $requiredColors = @(
    'background', 'panel', 'panelAlt', 'accent', 'accentAlt',
    'secondary', 'highlight', 'text', 'muted', 'line'
  )
  foreach ($colorName in $requiredColors) {
    if ($null -eq $manifest.colors -or
        @($manifest.colors.PSObject.Properties.Name) -cnotcontains $colorName -or
        [string]::IsNullOrWhiteSpace([string]$manifest.colors.$colorName)) {
      throw "colors 缺少必需色值：$colorName。"
    }
  }

  $backgroundSize = Get-DreamSkinImageSize -Path $backgroundPath
  $previewSize = Get-DreamSkinImageSize -Path $previewPath
  if ($backgroundSize.Width -lt 1200 -or $backgroundSize.Height -lt 400 -or
      $backgroundSize.Width -gt 12000 -or $backgroundSize.Height -gt 4000 -or
      $backgroundSize.Width -ne ($backgroundSize.Height * 3)) {
    throw 'background.png 必须是 1200x400 到 12000x4000 的精确 3:1 图片。'
  }
  if ($previewSize.Width -lt 600 -or $previewSize.Height -lt 200 -or
      $previewSize.Width -gt 6000 -or $previewSize.Height -gt 2000 -or
      $previewSize.Width -ne ($previewSize.Height * 3)) {
    throw 'preview.png 必须是 600x200 到 6000x2000 的精确 3:1 图片。'
  }

  return [pscustomobject]@{
    Manifest = $manifest
    SourceDirectory = $directory.FullName
  }
}

function Install-DreamSkinThemePackage {
  param(
    [Parameter(Mandatory = $true)]$Package,
    [Parameter(Mandatory = $true)][string]$ThemeRoot,
    [switch]$Replace
  )

  [IO.Directory]::CreateDirectory($ThemeRoot) | Out-Null
  $themeId = [string]$Package.Manifest.id
  $destination = Join-Path $ThemeRoot $themeId
  if (Test-Path -LiteralPath $destination) {
    $destinationItem = Get-Item -LiteralPath $destination
    if (($destinationItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw '目标主题目录不能是符号链接或重解析点。'
    }
  }
  if ((Test-Path -LiteralPath $destination) -and -not $Replace) {
    throw ('“{0}”已经安装。' -f $Package.Manifest.name)
  }

  $token = [guid]::NewGuid().ToString('N')
  $staging = Join-Path $ThemeRoot ".$themeId.importing.$token"
  $backup = Join-Path $ThemeRoot ".$themeId.backup.$token"
  try {
    [IO.Directory]::CreateDirectory($staging) | Out-Null
    foreach ($fileName in @('theme.json', 'background.png', 'preview.png')) {
      Copy-Item -LiteralPath (Join-Path $Package.SourceDirectory $fileName) `
        -Destination (Join-Path $staging $fileName)
    }
    Assert-DreamSkinThemePackage -Path $staging | Out-Null
    if (Test-Path -LiteralPath $destination) {
      Move-Item -LiteralPath $destination -Destination $backup
    }
    try {
      Move-Item -LiteralPath $staging -Destination $destination
      if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
    } catch {
      if ((Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $destination)) {
        Move-Item -LiteralPath $backup -Destination $destination
      }
      throw
    }
  } finally {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    if ((Test-Path -LiteralPath $backup) -and (Test-Path -LiteralPath $destination)) {
      Remove-Item -LiteralPath $backup -Recurse -Force
    }
  }
}

function Convert-DreamSkinHexToRgb {
  param([Parameter(Mandatory = $true)][string]$Hex)

  if ($Hex -cnotmatch '^#[0-9A-Fa-f]{6}$') { throw "颜色格式无效：$Hex" }
  return [pscustomobject]@{
    Red = [Convert]::ToInt32($Hex.Substring(1, 2), 16)
    Green = [Convert]::ToInt32($Hex.Substring(3, 2), 16)
    Blue = [Convert]::ToInt32($Hex.Substring(5, 2), 16)
  }
}

function Write-DreamSkinCroppedPng {
  param(
    [Parameter(Mandatory = $true)][System.Drawing.Image]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][int]$Width,
    [Parameter(Mandatory = $true)][int]$Height,
    [Parameter(Mandatory = $true)][int]$HorizontalFocus
  )

  $sourceRatio = $Source.Width / [double]$Source.Height
  $targetRatio = $Width / [double]$Height
  if ($sourceRatio -gt $targetRatio) {
    $cropHeight = [double]$Source.Height
    $cropWidth = $cropHeight * $targetRatio
    $sourceX = ($Source.Width - $cropWidth) * ([Math]::Min(100, [Math]::Max(0, $HorizontalFocus)) / 100.0)
    $sourceY = 0.0
  } else {
    $cropWidth = [double]$Source.Width
    $cropHeight = $cropWidth / $targetRatio
    $sourceX = 0.0
    $sourceY = ($Source.Height - $cropHeight) / 2.0
  }

  $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $destinationRectangle = New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)
    $graphics.DrawImage(
      $Source,
      $destinationRectangle,
      [single]$sourceX,
      [single]$sourceY,
      [single]$cropWidth,
      [single]$cropHeight,
      [System.Drawing.GraphicsUnit]::Pixel
    )
    $bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

function New-DreamSkinThemePackage {
  param(
    [Parameter(Mandatory = $true)][string]$SourceImage,
    [Parameter(Mandatory = $true)][string]$ThemeRoot,
    [Parameter(Mandatory = $true)][string]$ThemeId,
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Author = '',
    [string]$Description = '',
    [string]$Category = '自定义',
    [ValidateSet('light', 'dark')][string]$Appearance = 'dark',
    [string]$Accent = '#4F9FE8',
    [string]$Secondary = '#70C7B3',
    [string]$Highlight = '#E8995C',
    [ValidateRange(0, 100)][int]$HorizontalFocus = 50,
    [switch]$Replace
  )

  if (-not (Test-DreamSkinThemeId -ThemeId $ThemeId)) {
    throw '主题 ID 仅支持 3-64 位小写字母、数字和连字符。'
  }
  if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Length -gt 80) {
    throw '主题名称需为 1-80 个字符。'
  }
  if ($Description.Length -gt 180) { throw '主题描述不能超过 180 个字符。' }
  if (-not (Test-Path -LiteralPath $SourceImage -PathType Leaf)) { throw '请先选择背景图片。' }
  $sourceItem = Get-Item -LiteralPath $SourceImage
  if (($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      $sourceItem.Length -le 0 -or $sourceItem.Length -gt 52428800) {
    throw '源图片必须是 50 MiB 以内的普通文件。'
  }
  $accentRgb = Convert-DreamSkinHexToRgb -Hex $Accent
  Convert-DreamSkinHexToRgb -Hex $Secondary | Out-Null
  Convert-DreamSkinHexToRgb -Hex $Highlight | Out-Null

  $temporary = Join-Path ([IO.Path]::GetTempPath()) ("codex-skin-" + [guid]::NewGuid().ToString('N'))
  [IO.Directory]::CreateDirectory($temporary) | Out-Null
  try {
    $source = [System.Drawing.Image]::FromFile($SourceImage)
    try {
      Write-DreamSkinCroppedPng -Source $source `
        -Destination (Join-Path $temporary 'background.png') `
        -Width 2400 -Height 800 -HorizontalFocus $HorizontalFocus
      Write-DreamSkinCroppedPng -Source $source `
        -Destination (Join-Path $temporary 'preview.png') `
        -Width 1200 -Height 400 -HorizontalFocus $HorizontalFocus
    } finally {
      $source.Dispose()
    }

    $isDark = $Appearance -ceq 'dark'
    $colors = [ordered]@{
      background = $(if ($isDark) { '#0D1422' } else { '#F4F7F9' })
      panel = $(if ($isDark) { '#151E2E' } else { '#FFFFFF' })
      panelAlt = $(if ($isDark) { '#202B3D' } else { '#EDF3F6' })
      accent = $Accent.ToUpperInvariant()
      accentAlt = $Accent.ToUpperInvariant()
      secondary = $Secondary.ToUpperInvariant()
      highlight = $Highlight.ToUpperInvariant()
      text = $(if ($isDark) { '#F4F7FB' } else { '#25313A' })
      muted = $(if ($isDark) { '#AAB5C4' } else { '#687783' })
      line = "rgba($($accentRgb.Red), $($accentRgb.Green), $($accentRgb.Blue), .28)"
    }
    $tagline = if ([string]::IsNullOrWhiteSpace($Description)) {
      '让喜欢的画面陪你完成今天的工作。'
    } else { $Description }
    $manifest = [ordered]@{
      schemaVersion = 2
      id = $ThemeId
      name = $Name.Trim()
      author = $Author.Trim()
      description = $Description.Trim()
      category = $Category
      style = $ThemeId
      avatarOverlay = 'show'
      appearance = $Appearance
      brandSubtitle = 'CUSTOM THEME'
      tagline = $tagline
      projectPrefix = "$($Name.Trim()) · "
      projectLabel = '选择项目'
      statusText = 'CUSTOM THEME ONLINE'
      quote = "$($Name.Trim()) · 专注创作"
      image = 'background.png'
      preview = 'preview.png'
      colors = $colors
    }
    $json = $manifest | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText(
      (Join-Path $temporary 'theme.json'),
      $json,
      ([System.Text.UTF8Encoding]::new($false, $true))
    )
    $package = Assert-DreamSkinThemePackage -Path $temporary
    Install-DreamSkinThemePackage -Package $package -ThemeRoot $ThemeRoot -Replace:$Replace
  } finally {
    if (Test-Path -LiteralPath $temporary) {
      Remove-Item -LiteralPath $temporary -Recurse -Force
    }
  }
}
