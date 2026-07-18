[CmdletBinding()]
param(
  [int]$Port = 9335
)

$ErrorActionPreference = 'Stop'
$PortExplicit = $PSBoundParameters.ContainsKey('Port')
$Injector = Join-Path $PSScriptRoot 'injector.mjs'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

$operationLock = Enter-DreamSkinOperationLock
try {
  Assert-DreamSkinPort -Port $Port
  $StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
  $StatePath = Join-Path $StateRoot 'state.json'
  $ThemeDir = Join-Path $StateRoot 'theme'
  $state = Read-DreamSkinState -Path $StatePath
  if (-not $PortExplicit -and $null -ne $state -and $state.port) {
    $Port = [int]$state.port
    Assert-DreamSkinPort -Port $Port
  }

  $currentCodex = $null
  try { $currentCodex = Get-DreamSkinCodexInstall } catch {}
  $savedCodex = Get-DreamSkinCodexInstallFromState -State $state
  $codex = if ($null -ne $savedCodex) { $savedCodex } else { $currentCodex }
  $identity = if ($null -ne $codex) {
    Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
  } else {
    $null
  }

  if ($null -ne $state -and $state.injectorPid) {
    $stopped = Stop-DreamSkinRecordedInjector -State $state
    if (-not $stopped) {
      $staleStatePath = Archive-DreamSkinStateFile -Path $StatePath
      Write-Warning "Archived stale Dream Skin state at $staleStatePath"
    }
  }

  if ($null -ne $identity) {
    $node = Get-DreamSkinNodeRuntime
    & $node.Path $Injector --remove --port $Port --browser-id $identity.BrowserId `
      --theme-dir $ThemeDir --timeout-ms 10000 *> $null
    if ($LASTEXITCODE -ne 0) {
      throw 'Codex 已连接，但实时移除皮肤失败。'
    }
  }

  $pausedState = [pscustomobject]@{
    schemaVersion = 2
    platform = 'windows'
    session = 'paused'
    selectedThemeId = 'codex-default'
    port = $Port
    themeDir = $ThemeDir
    codexExe = if ($null -ne $codex) { $codex.Executable } else { $null }
    codexPackageRoot = if ($null -ne $codex) { $codex.PackageRoot } else { $null }
    codexPackageFullName = if ($null -ne $codex) { $codex.PackageFullName } else { $null }
    codexPackageFamilyName = if ($null -ne $codex) { $codex.PackageFamilyName } else { $null }
    codexVersion = if ($null -ne $codex) { $codex.Version } else { $null }
    pausedAt = (Get-Date).ToUniversalTime().ToString('o')
  }
  Write-DreamSkinState -Path $StatePath -State $pausedState
  Write-Host '已恢复 Codex 原版外观；Codex 保持运行。'
  exit 0
} finally {
  Exit-DreamSkinOperationLock -Mutex $operationLock
}
