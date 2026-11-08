# dsh-config-backup.ps1
# 更新插件前，把 DSH 的配置、本机插件源码、会话记录打成一个 zip。
# 用法：
#   .\dsh-config-backup.ps1 -ProfileDir "$env:USERPROFILE\.dsh\profiles\desktop"
param(
    [string]$ProfileDir = "$env:USERPROFILE\.dsh\profiles\desktop",
    [string]$OutDir = "$env:USERPROFILE\Desktop",
    [string]$DshHome = "$env:USERPROFILE\.dsh"
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path $ProfileDir)) { throw "profile not found: $ProfileDir" }
if (-not (Test-Path $OutDir))    { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$stamp = Get-Date -Format 'yyyyMMdd_HHmm'
$zip = Join-Path $OutDir "dsh-backup-$stamp.zip"

$entries = New-Object System.Collections.ArrayList

function Add-Tree([string]$src, [string]$prefix, [string[]]$skip) {
    if (-not (Test-Path $src)) { return }
    $rootLen = (Resolve-Path $src).Path.Length
    Get-ChildItem $src -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $full = $_.FullName
        foreach ($s in $skip) { if ($full -match [regex]::Escape($s)) { return } }
        $rel = $full.Substring($rootLen).TrimStart('\')
        [void]$entries.Add([pscustomobject]@{ File = $full; Name = ($prefix + '/' + ($rel -replace '\\','/')) })
    }
}

# 1) profile 配置（跳过 node_modules）
Add-Tree $ProfileDir 'profile' @('\node_modules\', '\.pnpm\')
# 2) 本机插件源码（跳过依赖）
Add-Tree (Join-Path $DshHome 'plugins') 'plugins' @('\node_modules\', '\.pnpm\', '\.git\')
# 3) 会话记录
Add-Tree (Join-Path $DshHome 'sessions') 'sessions' @()
# 4) 顶层配置
foreach ($f in 'AGENTS.md','see-window.json','watch-window.json','asr.json') {
    $p = Join-Path $DshHome $f
    if (Test-Path $p) { [void]$entries.Add([pscustomobject]@{ File = $p; Name = "home/$f" }) }
}

if ($entries.Count -eq 0) { throw 'nothing to back up' }

$z = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
try {
    foreach ($e in $entries) {
        $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $z, $e.File, $e.Name, [System.IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $z.Dispose() }

$info = Get-Item $zip
Write-Host ("backup -> {0}" -f $info.FullName)
Write-Host ("files: {0}  size: {1:N1} MB" -f $entries.Count, ($info.Length / 1MB))
