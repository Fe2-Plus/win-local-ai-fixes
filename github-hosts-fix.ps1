# github-hosts-fix.ps1
# GitHub 打不开时：逐个测候选 IP，挑一个能连的写进 hosts。改前自动备份。
# 用法（管理员 PowerShell）：
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#   .\github-hosts-fix.ps1
param(
    [string[]]$Candidates = @(
        '140.82.113.3', '140.82.114.3', '20.27.177.113', '4.237.22.38',
        '20.200.245.247', '20.205.243.166', '140.82.112.3', '140.82.116.3'
    ),
    [string]$BackupDir = "$env:USERPROFILE\hosts-backups",
    [string]$TakeOwnership = 'github.com'
)

$ErrorActionPreference = 'Continue'
$hosts = Join-Path $env:WINDIR 'System32\drivers\etc\hosts'

# 1. 挑一个能连的 IP
$picked = $null
foreach ($ip in $Candidates) {
    $ok = (Test-NetConnection -ComputerName $ip -Port 443 -WarningAction SilentlyContinue).TcpTestSucceeded
    Write-Host ("test {0,-16} {1}" -f $ip, $ok)
    if ($ok) { $picked = $ip; break }
}

if (-not $picked) {
    Write-Host 'no reachable IP found - github may be blocked at the route level right now'
    exit 1
}

# 2. 备份 hosts
if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$bak = Join-Path $BackupDir "hosts-$stamp.txt"
Copy-Item $hosts $bak -Force
Write-Host "backup -> $bak"

# 3. 重写这一行（保留其余内容）
$lines = Get-Content $hosts
$kept = $lines | Where-Object {
    -not ($_ -match ("^\s*[0-9\.]+\s+" + [regex]::Escape($TakeOwnership) + "\s*$")) -and
    -not ($_ -match '^\s*#\s*pinned-by-script')
}
$out = @($kept) + @("# pinned-by-script $picked $TakeOwnership", "$picked $TakeOwnership")

try {
    [System.IO.File]::WriteAllLines($hosts, $out, (New-Object System.Text.UTF8Encoding($false)))
} catch {
    Write-Host "WRITE FAILED (run as Administrator): $($_.Exception.Message)"
    exit 1
}

ipconfig /flushdns | Out-Null
Write-Host "pinned $TakeOwnership -> $picked"
Write-Host "rollback: copy $bak back over the hosts file"
