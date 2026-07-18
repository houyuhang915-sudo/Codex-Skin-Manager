Set-StrictMode -Version 2.0

$DreamSkinThemeSkillRelativeFiles = @(
  'SKILL.md',
  'agents\openai.yaml',
  'scripts\create-theme.mjs',
  'scripts\create-theme-windows.ps1',
  'references\theme-format.md'
)

function Get-DreamSkinThemeSkillTarget {
  $codexHome = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    $env:CODEX_HOME
  } else {
    Join-Path $HOME '.codex'
  }
  return Join-Path $codexHome 'skills\codex-skin-theme-creator'
}

function Get-DreamSkinThemeSkillSource {
  param([Parameter(Mandatory = $true)][string]$EngineRoot)
  return Join-Path $EngineRoot 'skill\codex-skin-theme-creator'
}

function Test-DreamSkinThemeSkillCurrent {
  param([Parameter(Mandatory = $true)][string]$EngineRoot)

  $source = Get-DreamSkinThemeSkillSource -EngineRoot $EngineRoot
  $target = Get-DreamSkinThemeSkillTarget
  foreach ($relativePath in $DreamSkinThemeSkillRelativeFiles) {
    $sourceFile = Join-Path $source $relativePath
    $targetFile = Join-Path $target $relativePath
    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf) -or
        -not (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
      return $false
    }
    if ((Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash -cne
        (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash) {
      return $false
    }
  }
  return $true
}

function Install-DreamSkinThemeSkill {
  param([Parameter(Mandatory = $true)][string]$EngineRoot)

  $source = Get-DreamSkinThemeSkillSource -EngineRoot $EngineRoot
  if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md') -PathType Leaf)) {
    throw "主题创建 Skill 不完整：$source"
  }
  $target = Get-DreamSkinThemeSkillTarget
  $parent = Split-Path -Parent $target
  $token = [guid]::NewGuid().ToString('N')
  $staging = Join-Path $parent ".codex-skin-theme-creator.installing.$token"
  $backup = Join-Path $parent ".codex-skin-theme-creator.backup.$token"
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  try {
    Copy-Item -LiteralPath $source -Destination $staging -Recurse
    if (Test-Path -LiteralPath $target) {
      Move-Item -LiteralPath $target -Destination $backup
    }
    try {
      Move-Item -LiteralPath $staging -Destination $target
      if (Test-Path -LiteralPath $backup) {
        Remove-Item -LiteralPath $backup -Recurse -Force
      }
    } catch {
      if ((Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $target)) {
        Move-Item -LiteralPath $backup -Destination $target
      }
      throw
    }
  } finally {
    if (Test-Path -LiteralPath $staging) {
      Remove-Item -LiteralPath $staging -Recurse -Force
    }
    if ((Test-Path -LiteralPath $backup) -and (Test-Path -LiteralPath $target)) {
      Remove-Item -LiteralPath $backup -Recurse -Force
    }
  }
  if (-not (Test-DreamSkinThemeSkillCurrent -EngineRoot $EngineRoot)) {
    throw '主题创建 Skill 安装后校验未通过。'
  }
  return $target
}
