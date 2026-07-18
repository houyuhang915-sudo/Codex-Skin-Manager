[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][Alias('image')][string]$Image,
  [Parameter(Mandatory = $true)][Alias('id')][string]$Id,
  [Parameter(Mandatory = $true)][Alias('name')][string]$Name,
  [Alias('author')][string]$Author = '',
  [Alias('description')][string]$Description = '',
  [Alias('category')][string]$Category = '自定义',
  [Alias('appearance')][ValidateSet('light', 'dark')][string]$Appearance = 'dark',
  [Alias('accent')][string]$Accent = '#4F9FE8',
  [Alias('secondary')][string]$Secondary = '#70C7B3',
  [Alias('highlight')][string]$Highlight = '#E8995C',
  [Alias('focus')][ValidateRange(0, 100)][int]$Focus = 50,
  [Alias('themes-root')][string]$ThemesRoot = '',
  [Alias('replace')][switch]$Replace
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Find-DreamSkinEngineRoot {
  if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SKIN_ENGINE_ROOT)) {
    return $env:CODEX_SKIN_ENGINE_ROOT
  }
  $stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
  $candidate = Get-ChildItem -LiteralPath $stateRoot -Directory -Filter 'engine-*' `
    -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'scripts\theme-package.ps1') } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
  if ($null -eq $candidate) {
    throw '未找到 Codex 皮肤管理器主题创建组件，请重新安装管理器。'
  }
  return $candidate.FullName
}

$engineRoot = Find-DreamSkinEngineRoot
. (Join-Path $engineRoot 'scripts\theme-package.ps1')

if ($DreamSkinBuiltInThemeIds -ccontains $Id) {
  throw '内置主题 ID 受保护，请使用新的主题 ID。'
}
if ([string]::IsNullOrWhiteSpace($ThemesRoot)) {
  $ThemesRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin\themes'
}

New-DreamSkinThemePackage `
  -SourceImage $Image `
  -ThemeRoot $ThemesRoot `
  -ThemeId $Id `
  -Name $Name `
  -Author $Author `
  -Description $Description `
  -Category $Category `
  -Appearance $Appearance `
  -Accent $Accent `
  -Secondary $Secondary `
  -Highlight $Highlight `
  -HorizontalFocus $Focus `
  -Replace:$Replace

$destination = Join-Path $ThemesRoot $Id
$null = Assert-DreamSkinThemePackage -Path $destination
$stateRoot = Split-Path -Parent $ThemesRoot
[IO.File]::WriteAllText(
  (Join-Path $stateRoot 'theme-library.changed'),
  "$(Get-Date -Format o) $Id`r`n",
  ([System.Text.UTF8Encoding]::new($false, $true))
)

[ordered]@{
  schemaVersion = 1
  status = 'installed'
  themeId = $Id
  name = $Name.Trim()
  themePath = $destination
  themesRoot = $ThemesRoot
  managerRefresh = 'automatic'
} | ConvertTo-Json -Compress
