#requires -Version 7.0
param(
    [string]$DevEcoRoot = 'E:\Huawei\DevEco_Studio',
    [string]$FlutterProfile = (Join-Path $PSScriptRoot '..\app\ohos\build-profile.Release.json5')
)
$ErrorActionPreference = 'Stop'
$projectRoot = Join-Path $PSScriptRoot 'AloeSend'
$env:DEVECO_SDK_HOME = Join-Path $DevEcoRoot 'sdk'
$env:HOS_SDK_HOME = $env:DEVECO_SDK_HOME
$env:NODE_HOME = Join-Path $DevEcoRoot 'tools\node'
$env:Path = "$env:NODE_HOME;$(Join-Path $DevEcoRoot 'tools\ohpm\bin');$(Join-Path $DevEcoRoot 'tools\hvigor\bin');$env:Path"
$profile = Get-Content -LiteralPath (Join-Path $projectRoot 'AppScope\app.json5') -Raw | ConvertFrom-Json
$versionCode = $profile.app.versionCode
$versionName = $profile.app.versionName
if ($versionName -notmatch '^\d+(\.\d+)*$') { throw 'Release version must contain only numeric components' }
$nativeProfilePath = Join-Path $projectRoot 'build-profile.json5'
$originalProfile = [IO.File]::ReadAllBytes($nativeProfilePath)
$nativeProfile = [Text.Encoding]::UTF8.GetString($originalProfile) | ConvertFrom-Json
$FlutterProfile = (Resolve-Path -LiteralPath $FlutterProfile).Path
$flutterRelease = Get-Content -LiteralPath $FlutterProfile -Raw | ConvertFrom-Json
$releaseProduct = @($flutterRelease.app.products | Where-Object name -eq 'default')[0]
$signing = @($flutterRelease.app.signingConfigs | Where-Object name -eq $releaseProduct.signingConfig)[0]
if (-not $signing.material) { throw 'Flutter release signing material is missing' }
$material = $signing.material
foreach ($field in @('storeFile', 'profile', 'certpath')) {
    if (-not [IO.Path]::IsPathRooted($material.$field)) {
        $material.$field = [IO.Path]::GetFullPath((Join-Path (Split-Path $FlutterProfile -Parent) $material.$field))
    }
}
Add-Type -AssemblyName System.Security.Cryptography.Pkcs
$cms = [Security.Cryptography.Pkcs.SignedCms]::new()
$cms.Decode([IO.File]::ReadAllBytes($material.profile))
$provision = [Text.Encoding]::UTF8.GetString($cms.ContentInfo.Content) | ConvertFrom-Json
if ($provision.type -ne 'release' -or $provision.'bundle-info'.'bundle-name' -ne $profile.app.bundleName) {
    throw 'Flutter profile is not a release profile for this application'
}
$pem = $provision.'bundle-info'.'distribution-certificate'
$certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($pem)
$releaseDir = Join-Path $PSScriptRoot 'artifacts\release'
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $material.certpath)) {
    # A renamed certificate chain can be recovered by matching its leaf to the
    # signed profile, rather than guessing from the filename or using a lone leaf.
    $matches = @(Get-ChildItem -LiteralPath (Split-Path $material.certpath -Parent) -Filter '*.cer' -File | Where-Object {
        $chain = [Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
        try { $chain.ImportFromPemFile($_.FullName) } catch { return $false }
        return @($chain | Where-Object Thumbprint -eq $certificate.Thumbprint).Count -eq 1
    })
    if ($matches.Count -ne 1) { throw 'Cannot uniquely locate the certificate chain matching the Flutter release profile' }
    $material.certpath = $matches[0].FullName
}
$configuredChain = [Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
$configuredChain.ImportFromPemFile($material.certpath)
if (@($configuredChain | Where-Object Thumbprint -eq $certificate.Thumbprint).Count -ne 1) { throw 'Signing certificate chain does not match the Flutter release profile' }
if (-not (Test-Path -LiteralPath $material.storeFile)) { throw 'Flutter release keystore is missing' }
$nativeProfile.app.signingConfigs = @($signing)
$nativeProduct = @($nativeProfile.app.products | Where-Object name -eq 'default')[0]
$nativeProduct | Add-Member -NotePropertyName signingConfig -NotePropertyValue $releaseProduct.signingConfig -Force
$nativeProduct.runtimeOS = $releaseProduct.runtimeOS
$nativeProduct.compatibleSdkVersion = $releaseProduct.compatibleSdkVersion
Push-Location $projectRoot
$sourceCommit = git rev-parse HEAD
$sourceDirty = [bool](git status --porcelain)
try {
    & ohpm install --all
    if ($LASTEXITCODE -ne 0) { throw "ohpm failed: $LASTEXITCODE" }
    [IO.File]::WriteAllText($nativeProfilePath, ($nativeProfile | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
    $started = Get-Date
    & hvigorw assembleApp --mode project -p product=default -p buildMode=release --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "Release build failed: $LASTEXITCODE" }
    $outputDir = Join-Path $projectRoot 'build\outputs\default'
    $packages = @(Get-ChildItem -LiteralPath $outputDir -Filter '*.app' -File | Where-Object { $_.LastWriteTime -ge $started -and $_.Name -notlike '*unsigned*' })
    if ($packages.Count -ne 1) { throw "Expected one newly generated signed APP in $outputDir" }
    # Check the final nested module manifests, not only the editable source.
    $disallowed = @('ohos.permission.INTERNET', 'ohos.permission.READ_PASTEBOARD', 'ohos.permission.FILE_ACCESS_PERSIST')
    $actualPermissions = @()
    $appArchive = [IO.Compression.ZipFile]::OpenRead($packages[0].FullName)
    try {
        $modules = @($appArchive.Entries | Where-Object FullName -like '*.hap')
        if (-not $modules.Count) { throw 'Release APP contains no modules' }
        foreach ($module in $modules) {
            $memory = [IO.MemoryStream]::new()
            $stream = $module.Open()
            try { $stream.CopyTo($memory) } finally { $stream.Dispose() }
            $memory.Position = 0
            $hapArchive = [IO.Compression.ZipArchive]::new($memory, [IO.Compression.ZipArchiveMode]::Read)
            try {
                $reader = [IO.StreamReader]::new($hapArchive.GetEntry('module.json').Open())
                try { $packedModule = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
                if ($packedModule.app.debug -ne $false) { throw 'A release module is still debuggable' }
                if ($packedModule.app.bundleName -ne $profile.app.bundleName -or $packedModule.app.versionCode -ne $versionCode) { throw 'Packaged application identity/version mismatch' }
                $requested = @($packedModule.module.requestPermissions | ForEach-Object name)
                if (@($requested | Where-Object { $_ -in $disallowed }).Count) { throw 'Store APP still declares a permission excluded from this release' }
                $actualPermissions += $requested
            } finally { $hapArchive.Dispose(); $memory.Dispose() }
        }
    } finally { $appArchive.Dispose() }
    $verifyDir = Join-Path $releaseDir 'verification'
    New-Item -ItemType Directory -Path $verifyDir -Force | Out-Null
    $java = Join-Path $DevEcoRoot 'jbr\bin\java.exe'
    $signTool = Join-Path $DevEcoRoot 'sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar'
    & $java -jar $signTool verify-app -inFile $packages[0].FullName -outCertChain (Join-Path $verifyDir 'app-chain.cer') -outProfile (Join-Path $verifyDir 'app-profile.p7b') *> (Join-Path $PSScriptRoot 'verify-release-app.log')
    if ($LASTEXITCODE -ne 0) { throw 'Release APP signature verification failed' }
    $verifiedChain = [Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
    $verifiedChain.ImportFromPemFile((Join-Path $verifyDir 'app-chain.cer'))
    if (@($verifiedChain | Where-Object Thumbprint -eq $certificate.Thumbprint).Count -ne 1) { throw 'APP signer differs from the Flutter release identity' }
    $signedHap = Join-Path $projectRoot 'entry\build\default\outputs\default\entry-default-signed.hap'
    & $java -jar $signTool verify-app -inFile $signedHap -outCertChain (Join-Path $verifyDir 'hap-chain.cer') -outProfile (Join-Path $verifyDir 'hap-profile.p7b') *> (Join-Path $PSScriptRoot 'verify-release-hap.log')
    if ($LASTEXITCODE -ne 0) { throw 'Release module signature verification failed' }
    $stamp = $started.ToString('yyyyMMdd-HHmmss')
    $archive = Join-Path $releaseDir "AloeSend-$versionCode-release-$stamp-signed.app"
    Copy-Item -LiteralPath $packages[0].FullName -Destination $archive
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    [ordered]@{
        versionCode = $versionCode; versionName = $versionName; buildMode = 'release'; unsigned = $false
        flutterProfileSha256 = (Get-FileHash -LiteralPath $FlutterProfile -Algorithm SHA256).Hash
        certificateThumbprint = $certificate.Thumbprint
        appSignatureVerified = $true; moduleSignatureVerified = $true
        requestedPermissions = @($actualPermissions | Sort-Object -Unique)
        sourceCommit = $sourceCommit; sourceDirty = $sourceDirty
        builtAt = (Get-Date).ToString('o'); bytes = $packages[0].Length; sha256 = $hash
    } | ConvertTo-Json | Set-Content -LiteralPath "$archive.json" -Encoding utf8
    Write-Host "Release APP: $archive"
    Write-Host "SHA256: $hash"
} finally {
    [IO.File]::WriteAllBytes($nativeProfilePath, $originalProfile)
    Pop-Location
}
