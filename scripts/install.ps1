<#
.SYNOPSIS
  画图.skill 一键安装脚本 (Windows PowerShell)
.DESCRIPTION
  把网络画板 2D/3D 动态数学课件作图技能安装到 Claude Code / Cursor / Codex / Hermes。
  默认用 Junction 链接模式（改源即四端同步生效），也可 --Copy 复制独立副本。
.EXAMPLE
  .\install.ps1                     # 自动探测所有 Agent，链接模式安装
  .\install.ps1 -Agent cursor       # 只装 Cursor
  .\install.ps1 -Dest "D:\myskills" # 装到自定义 skills 目录
  .\install.ps1 -Copy               # 复制模式
  .\install.ps1 -Uninstall          # 卸载（不删源）
#>
param(
  [ValidateSet('all','claude','cursor','codex','hermes')]
  [string]$Agent = 'all',
  [string]$Dest = '',
  [string]$Source = '',
  [switch]$Copy,
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$SkillName = '画图.skill'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 定位源目录：-Source 显式指定 > 仓库内 > 脚本同级
if ($Source) {
  if (-not (Test-Path $Source)) { Write-Error "指定的源目录不存在: $Source"; exit 1 }
  $Src = (Resolve-Path $Source).Path
} else {
  $Candidates = @(
    (Join-Path (Split-Path -Parent $ScriptDir) $SkillName),
    (Join-Path $ScriptDir $SkillName)
  )
  $Src = $Candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $Src) { Write-Error "找不到 $SkillName 源目录（脚本应位于仓库内，或用 -Source 指定）"; exit 1 }
  $Src = (Resolve-Path $Src).Path
}

function Get-AgentDirs {
  $dirs = @()
  $map = @{
    claude = Join-Path $env:USERPROFILE '.claude\skills'
    cursor = Join-Path $env:USERPROFILE '.cursor\skills'
    codex  = if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME 'skills' } else { Join-Path $env:USERPROFILE '.codex\skills' }
    hermes = Join-Path $env:LOCALAPPDATA 'hermes\skills'
  }
  if ($Dest) { return @($Dest) }
  if ($Agent -ne 'all') {
    if (-not $map.ContainsKey($Agent)) { Write-Error "未知 agent: $Agent"; exit 1 }
    return @($map[$Agent])
  }
  foreach ($k in $map.Keys) { if (Test-Path $map[$k]) { $dirs += $map[$k] } }
  return $dirs
}

$Targets = Get-AgentDirs
if (-not $Targets -or $Targets.Count -eq 0) {
  Write-Error "未探测到任何 Agent skills 目录，请用 -Dest 指定"; exit 1
}

Write-Host "源目录: $Src" -ForegroundColor Cyan
Write-Host "模式  : $(if($Copy){'复制'}else{'链接(Junction)'})" -ForegroundColor Cyan
Write-Host ""

foreach ($t in $Targets) {
  $link = Join-Path $t $SkillName

  if ($Uninstall) {
    if (Test-Path $link) {
      # 只删链接本身，不删源目录内容
      $item = Get-Item $link -Force
      if ($item.LinkType -eq 'Junction' -or $item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        [System.IO.Directory]::Delete($link, $false)
      } else {
        Remove-Item $link -Recurse -Force
      }
      Write-Host "🗑  已卸载: $link" -ForegroundColor Yellow
    } else {
      Write-Host "⏭  无需卸载(不存在): $link" -ForegroundColor DarkGray
    }
    continue
  }

  if (-not (Test-Path $t)) {
    Write-Host "⚠  跳过(目录不存在): $t" -ForegroundColor DarkYellow
    continue
  }

  if (Test-Path $link) {
    $item = Get-Item $link -Force
    if ($item.LinkType -eq 'Junction' -or $item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
      [System.IO.Directory]::Delete($link, $false)
    } else {
      Remove-Item $link -Recurse -Force
    }
    Write-Host "↻  已删除旧版本: $link" -ForegroundColor DarkGray
  }

  if ($Copy) {
    Copy-Item $Src $link -Recurse -Force
    Write-Host "✅ 已复制安装: $link" -ForegroundColor Green
  } else {
    try {
      New-Item -ItemType Junction -Path $link -Target $Src | Out-Null
      Write-Host "✅ 已链接安装: $link -> $Src" -ForegroundColor Green
    } catch {
      Copy-Item $Src $link -Recurse -Force
      Write-Host "⚠  链接失败已改为复制: $link" -ForegroundColor Yellow
    }
  }
}

Write-Host ""
if ($Uninstall) {
  Write-Host "卸载完成（源目录未删除: $Src）" -ForegroundColor Cyan
} else {
  Write-Host "安装完成。触发词: 网络画板 / NetPad / 动态几何课件 / 函数图象 / 3D立体几何 / 课件编号" -ForegroundColor Cyan
  Write-Host "提示: 链接模式下更新源目录即四端同步生效；-Copy 模式需手动重装。" -ForegroundColor DarkGray
}
