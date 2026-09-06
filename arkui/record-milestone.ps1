param(
    [Parameter(Mandatory)][int]$VersionCode,
    [Parameter(Mandatory)][string]$Commit
)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $resolvedCommit = git rev-parse --verify "$Commit^{commit}"
    if ($LASTEXITCODE -ne 0) { throw 'Milestone commit does not exist' }
    $committedProfile = (git show "${resolvedCommit}:arkui/AloeSend/AppScope/app.json5") -join "`n"
    if ($LASTEXITCODE -ne 0 -or $committedProfile -notmatch ('"versionCode"\s*:\s*' + $VersionCode + '\b')) {
        throw 'Commit does not contain the requested milestone version'
    }
    $manifests = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'artifacts') -Filter "AloeSend-$VersionCode-*-unsigned.hap.json")
    if ($manifests.Count -ne 1) { throw 'Expected exactly one archived package for this version' }
    $manifestPath = $manifests[0].FullName
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $hapPath = $manifestPath.Substring(0, $manifestPath.Length - 5)
    if ((Get-FileHash -LiteralPath $hapPath -Algorithm SHA256).Hash -ne $manifest.sha256) { throw 'Archived package hash mismatch' }
    if (-not ($manifest.PSObject.Properties.Name -contains 'baseCommit')) {
        $manifest | Add-Member -NotePropertyName baseCommit -NotePropertyValue $manifest.sourceCommit
    }
    $manifest.sourceCommit = $resolvedCommit
    $manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Host "Recorded $VersionCode -> $resolvedCommit"
} finally { Pop-Location }
