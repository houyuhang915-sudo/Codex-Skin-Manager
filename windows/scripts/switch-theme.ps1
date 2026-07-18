[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9-]{1,80}$')]
  [string]$ThemeId,
  [switch]$NoApply
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$EngineRoot = Split-Path -Parent $PSScriptRoot
$ThemesRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin\themes'
$Source = Join-Path $ThemesRoot $ThemeId
$ManifestPath = Join-Path $Source 'theme.json'
. (Join-Path $PSScriptRoot 'config-utf8.ps1')
if (-not (Test-Path -LiteralPath $ManifestPath)) { throw "Theme not found: $ThemeId" }

$Manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Manifest.schemaVersion -ne 2 -or $Manifest.id -cne $ThemeId -or
  $Manifest.image -cne 'background.png' -or $Manifest.preview -cne 'preview.png') {
  throw "Theme $ThemeId does not follow the schema 2 single-image format."
}
foreach ($file in @('background.png', 'preview.png', 'theme.json')) {
  if (-not (Test-Path -LiteralPath (Join-Path $Source $file))) {
    throw "Theme $ThemeId is missing $file."
  }
}

$SelectionPath = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin\selection.json'
$selection = [ordered]@{
  schemaVersion = 1
  themeId = $ThemeId
  selectedAt = (Get-Date).ToUniversalTime().ToString('o')
}
Write-DreamSkinUtf8FileAtomically `
  -Path $SelectionPath `
  -Content (($selection | ConvertTo-Json -Depth 3) + "`r`n")

if ($Manifest.mode -ceq 'original') {
  if (-not $NoApply) {
    & (Join-Path $PSScriptRoot 'pause-dream-skin.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  Write-Host "Selected $($Manifest.name)."
  exit 0
}

$ThemeDir = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin\theme'
New-Item -ItemType Directory -Force -Path $ThemeDir | Out-Null
Get-ChildItem -LiteralPath $ThemeDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
Copy-Item -LiteralPath (Join-Path $Source 'background.png') -Destination $ThemeDir -Force
Copy-Item -LiteralPath (Join-Path $Source 'preview.png') -Destination $ThemeDir -Force
Copy-Item -LiteralPath $ManifestPath -Destination $ThemeDir -Force

if (-not $NoApply) {
  & (Join-Path $PSScriptRoot 'start-dream-skin.ps1') -PromptRestart
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
Write-Host "Selected $($Manifest.name)."
exit 0
