param([switch]$WriteCatalog)
$ErrorActionPreference = 'Stop'
$artifacts = Join-Path $PSScriptRoot 'artifacts'
$manifests = @(Get-ChildItem -LiteralPath $artifacts -Filter '*-unsigned.hap.json' |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json } |
    Sort-Object versionCode -Descending)
if (!$manifests.Count) { throw 'No archived unsigned packages found' }
$seen = @{}
$rows = @()
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    foreach ($manifest in $manifests) {
        if ($seen.ContainsKey([string]$manifest.versionCode)) { throw 'Duplicate milestone version' }
        $seen[[string]$manifest.versionCode] = $true
        if ($manifest.unsigned -ne $true -or $manifest.milestone -notmatch '^M[0-9]+-[a-z0-9-]+$') { throw 'Invalid milestone manifest' }
        $name = "AloeSend-$($manifest.versionCode)-$($manifest.milestone)-unsigned.hap"
        $package = Get-Item -LiteralPath (Join-Path $artifacts $name)
        if ($package.Length -ne $manifest.bytes) { throw "Package size mismatch: $name" }
        if ((Get-FileHash -LiteralPath $package.FullName -Algorithm SHA256).Hash -ne $manifest.sha256) { throw "Package hash mismatch: $name" }
        if ($manifest.sourceCommit -notmatch '^[0-9a-f]{40}$') { throw "Missing milestone commit: $name" }
        $profile = (git show "$($manifest.sourceCommit):arkui/AloeSend/AppScope/app.json5") -join "`n"
        if ($LASTEXITCODE -ne 0 -or $profile -notmatch ('"versionCode"\s*:\s*' + $manifest.versionCode + '\b')) { throw "Commit version mismatch: $name" }
        $short = $manifest.sourceCommit.Substring(0, 8)
        $rows += "| $($manifest.versionCode) | [$($manifest.milestone)](artifacts/$name) | $short | $($manifest.sha256) |"
    }
    if ($WriteCatalog) {
        $lines = @('# 未签名包清单', '', '由 verify-artifacts.ps1 -WriteCatalog 生成，逐包核对 SHA-256、大小及提交中的版本号。按新到旧排列；包与 JSON 元数据保存在本地 artifacts 目录，不纳入 Git。', '',
            '| 版本号 | 包（新到旧） | 源码提交 | SHA-256 |', '| --- | --- | --- | --- |') + $rows
        Set-Content -LiteralPath (Join-Path $PSScriptRoot 'PACKAGES.md') -Value $lines -Encoding utf8
    }
    Write-Host "Verified $($manifests.Count) unsigned packages. Latest: $($manifests[0].versionCode)"
} finally { Pop-Location }
