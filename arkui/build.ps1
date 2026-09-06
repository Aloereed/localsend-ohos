param(
    [string]$Milestone = 'development',
    [int]$VersionCode = 0,
    [string]$DevEcoRoot = 'E:\Huawei\DevEco_Studio'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Join-Path $PSScriptRoot 'AloeSend'
$env:DEVECO_SDK_HOME = Join-Path $DevEcoRoot 'sdk'
$env:HOS_SDK_HOME = $env:DEVECO_SDK_HOME
$env:NODE_HOME = Join-Path $DevEcoRoot 'tools\node'
$env:Path = "$env:NODE_HOME;$(Join-Path $DevEcoRoot 'tools\ohpm\bin');$(Join-Path $DevEcoRoot 'tools\hvigor\bin');$env:Path"
if ($Milestone -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid milestone name' }
$appPath = Join-Path $projectRoot 'AppScope\app.json5'
$appText = Get-Content -LiteralPath $appPath -Raw
if ($VersionCode -eq 0) {
    if ($appText -notmatch '"versionCode"\s*:\s*(\d+)') { throw 'Cannot read current versionCode' }
    $VersionCode = [int]$Matches[1]
}
if ($VersionCode -lt 2000001) { throw 'Native milestone versionCode must be at least 2000001' }
$appText = $appText -replace '"versionCode"\s*:\s*\d+', ('"versionCode": ' + $VersionCode)
[IO.File]::WriteAllText($appPath, $appText, [Text.UTF8Encoding]::new($false))
Push-Location $projectRoot
try {
    & ohpm install --all
    if ($LASTEXITCODE -ne 0) { throw "ohpm failed: $LASTEXITCODE" }
    $started = Get-Date
    & hvigorw assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "Hvigor failed: $LASTEXITCODE" }
    $hap = Get-Item -LiteralPath (Join-Path $projectRoot 'entry\build\default\outputs\default\entry-default-unsigned.hap')
    if ($hap.LastWriteTime -lt $started) { throw 'HAP was not refreshed by this build' }
    $archiveDir = Join-Path $PSScriptRoot 'artifacts'
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    $archivePath = Join-Path $archiveDir ("AloeSend-$VersionCode-$Milestone-unsigned.hap")
    Copy-Item -LiteralPath $hap.FullName -Destination $archivePath -Force
    $hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    [ordered]@{milestone=$Milestone; versionCode=$VersionCode; builtAt=(Get-Date).ToString('o'); sha256=$hash; bytes=$hap.Length; baseCommit=(git rev-parse HEAD); sourceCommit=$null; unsigned=$true} |
        ConvertTo-Json | Set-Content -LiteralPath "$archivePath.json" -Encoding utf8
    Write-Host "Unsigned HAP: $archivePath"
    Write-Host "SHA256: $hash"
} finally {
    Pop-Location
}
