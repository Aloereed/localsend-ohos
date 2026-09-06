param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$projectPath = [System.IO.Path]::GetFullPath($ProjectRoot)
$metadataPath = Join-Path $projectPath '.flutter-plugins-dependencies'
$stageRoot = Join-Path $projectPath '.dart_tool\ohos-plugins'

if (-not (Test-Path -LiteralPath $metadataPath)) {
    throw "Flutter plugin metadata not found: $metadataPath. Run flutter pub get first."
}

function Normalize-GeneratedPath([string]$Value) {
    $normalized = $Value
    while ($normalized.Contains('\\')) {
        $normalized = $normalized.Replace('\\', '\')
    }
    return $normalized
}

function Test-IsUnderPath([string]$Candidate, [string]$Parent) {
    $candidatePath = [System.IO.Path]::GetFullPath($Candidate).TrimEnd('\') + '\'
    $parentPath = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
    return $candidatePath.StartsWith(
        $parentPath,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$ohosPlugins = @($metadata.plugins.ohos)

# photo_manager 2.x is required by the local assets picker. Flutter 3.41
# removed DecoderCallback; apply the compatibility fix after each pub get.
$packageConfigPath = Join-Path $projectPath '.dart_tool\package_config.json'
$packageConfig = Get-Content -LiteralPath $packageConfigPath -Raw | ConvertFrom-Json
$photoManager = $packageConfig.packages | Where-Object { $_.name -eq 'photo_manager' }
if ($photoManager) {
    $packageUri = [Uri]::new([Uri]::new($packageConfigPath), [string]$photoManager.rootUri)
    $providerPath = Join-Path $packageUri.LocalPath 'lib\src\internal\image_provider.dart'
    if (Test-Path -LiteralPath $providerPath) {
        $provider = Get-Content -LiteralPath $providerPath -Raw -Encoding utf8
        if ($provider -match '\bDecoderCallback\b') {
            $provider = $provider.Replace('ImageStreamCompleter load(', 'ImageStreamCompleter loadImage(')
            $provider = $provider.Replace('DecoderCallback decode', 'ImageDecoderCallback decode')
            $provider = $provider.Replace('return decode(data);', 'return decode(await ui.ImmutableBuffer.fromUint8List(data));')
            [System.IO.File]::WriteAllText($providerPath, $provider, [System.Text.UTF8Encoding]::new($false))
            Write-Host 'Updated photo_manager image decoding for Flutter 3.41.' -ForegroundColor DarkCyan
        }
    }
}

if ($ohosPlugins.Count -eq 0) {
    Write-Host 'No OHOS plugins found in Flutter metadata.' -ForegroundColor Yellow
    return
}

New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

foreach ($plugin in $ohosPlugins) {
    $sourceRoot = Normalize-GeneratedPath ([string]$plugin.path)
    if (-not [System.IO.Path]::IsPathRooted($sourceRoot)) {
        $sourceRoot = Join-Path $projectPath $sourceRoot
    }
    $sourceRoot = [System.IO.Path]::GetFullPath($sourceRoot)

    $sourceOhos = Join-Path $sourceRoot 'ohos'
    if (-not (Test-Path -LiteralPath $sourceOhos)) {
        throw "OHOS source for plugin '$($plugin.name)' not found: $sourceOhos"
    }

    $sourceDrive = [System.IO.Path]::GetPathRoot($sourceRoot)
    $projectDrive = [System.IO.Path]::GetPathRoot($projectPath)
    $isPubCachePath = $sourceRoot -match '[\\/]\.?pub-cache[\\/]'
    $isDifferentDrive = -not $sourceDrive.Equals(
        $projectDrive,
        [System.StringComparison]::OrdinalIgnoreCase
    )
    $alreadyStaged = Test-IsUnderPath $sourceRoot $stageRoot

    if (($isPubCachePath -or $isDifferentDrive) -and -not $alreadyStaged) {
        $destinationRoot = Join-Path $stageRoot ([string]$plugin.name)
        $destinationOhos = Join-Path $destinationRoot 'ohos'

        if (([System.IO.Path]::GetFullPath($destinationRoot).TrimEnd('\') -eq $stageRoot.TrimEnd('\')) -or -not (Test-IsUnderPath $destinationRoot $stageRoot)) {
            throw "Refusing to stage plugin outside $stageRoot"
        }

        if (Test-Path -LiteralPath $destinationRoot) {
            Remove-Item -LiteralPath $destinationRoot -Recurse -Force
        }
        New-Item -ItemType Directory -Path $destinationOhos -Force | Out-Null
        Get-ChildItem -LiteralPath $sourceOhos -Force |
            Where-Object { $_.Name -notin @('oh_modules', 'build', '.hvigor') } |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $destinationOhos -Recurse -Force
            }
        $plugin.path = $destinationRoot.TrimEnd('\') + '\'
        Write-Host "Staged OHOS plugin: $($plugin.name)" -ForegroundColor DarkCyan
    } else {
        $plugin.path = $sourceRoot.TrimEnd('\') + '\'
    }
}

$metadata | ConvertTo-Json -Depth 100 -Compress |
    Set-Content -LiteralPath $metadataPath -Encoding utf8

# pub get also writes module paths into build-profile.json5. Keep those paths
# consistent with metadata so Hvigor builds HARs where Flutter looks for them.
$profilePath = Join-Path $projectPath 'ohos\build-profile.json5'
if (Test-Path -LiteralPath $profilePath) {
    $profile = Get-Content -LiteralPath $profilePath -Raw -Encoding utf8
    foreach ($plugin in $ohosPlugins) {
        $ohosUri = [Uri]::new((Join-Path $projectPath 'ohos') + '\')
        $pluginUri = [Uri]::new((Join-Path ([string]$plugin.path) 'ohos'))
        $modulePath = [Uri]::UnescapeDataString($ohosUri.MakeRelativeUri($pluginUri).ToString())
        $pattern = '("name"\s*:\s*"' + [regex]::Escape([string]$plugin.name) + '"\s*,\s*"srcPath"\s*:\s*")[^"]*(")'
        if ([regex]::IsMatch($profile, $pattern)) {
            $profile = [regex]::Replace($profile, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{
                param($match)
                $match.Groups[1].Value + $modulePath + $match.Groups[2].Value
            })
        } else {
            # A fresh signing profile contains only entry. Pre-register plugins
            # before Flutter adds them using their original Pub cache paths.
            $module = [ordered]@{
                name = [string]$plugin.name
                srcPath = $modulePath
                targets = @(@{ name = 'default'; applyToProducts = @('default') })
            } | ConvertTo-Json -Depth 10 -Compress
            if ($profile -notmatch '"modules"\s*:\s*\[') {
                throw "No modules array found in $profilePath"
            }
            $profile = [regex]::Replace($profile, '"modules"\s*:\s*\[', [System.Text.RegularExpressions.MatchEvaluator]{
                param($match)
                $match.Value + $module + ','
            })
        }
    }
    [System.IO.File]::WriteAllText($profilePath, $profile, [System.Text.UTF8Encoding]::new($false))
}

Write-Host "Prepared $($ohosPlugins.Count) OHOS plugin paths." -ForegroundColor Green
