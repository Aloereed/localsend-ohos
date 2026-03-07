param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("debug", "release")]
    [string]$Config,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$DeviceId
)

$appRoot = $PSScriptRoot
Set-Location $appRoot

function Update-VersionIfChanged {
    $isGitRepo = (Test-Path ".git") -or (Test-Path "..\.git")
    if (-not $isGitRepo) {
        Write-Host "Not in a git repository, skipping version check." -ForegroundColor Yellow
        return
    }

    $gitStatus = git status --porcelain
    if ([string]::IsNullOrWhiteSpace($gitStatus)) {
        Write-Host "No code changes detected, keeping current version." -ForegroundColor Green
        return
    }

    Write-Host "Code changes detected, updating version..." -ForegroundColor Cyan

    $pubspecPath = "pubspec.yaml"
    if (-not (Test-Path $pubspecPath)) {
        Write-Warning "pubspec.yaml not found, skipping version update."
        return
    }

    $content = Get-Content $pubspecPath -Raw

    if ($content -match 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3]
        $build = [int]$matches[4]

        $oldVersion = "$major.$minor.$patch+$build"
        $build++
        $newVersion = "$major.$minor.$patch+$build"

        Write-Host "Version updated: $oldVersion -> $newVersion" -ForegroundColor Green

        $newContent = $content -replace "version:\s*\d+\.\d+\.\d+\+\d+", "version: $newVersion"
        Set-Content -Path $pubspecPath -Value $newContent -NoNewline

        Write-Host "pubspec.yaml updated." -ForegroundColor Green
    }
    else {
        Write-Warning "Failed to parse version from pubspec.yaml."
    }
}

Update-VersionIfChanged

$buildProfilePath = "ohos\build-profile.json5"
$configSuffix = (Get-Culture).TextInfo.ToTitleCase($Config.ToLower())
$buildProfileSource = "ohos\build-profile.$configSuffix.json5"

if (-not (Test-Path $buildProfileSource)) {
    Write-Error "Build profile not found: $buildProfileSource"
    exit 1
}

if (Test-Path $buildProfilePath) {
    Write-Host "Backing up current build profile..."
    Copy-Item $buildProfilePath "$buildProfilePath.backup" -Force
}

Write-Host "Using config: $Config"
Write-Host "Copying $buildProfileSource to $buildProfilePath"
Copy-Item $buildProfileSource $buildProfilePath -Force

$runCommand = "flutter run --release -d $DeviceId"
Write-Host "Running command: $runCommand"
Write-Host "Selected build profile config: $Config"
Write-Host "Target device: $DeviceId"
Write-Host "----------------------------------------"

try {
    dart run build_runner build --delete-conflicting-outputs
    Invoke-Expression $runCommand
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "----------------------------------------"
        Write-Host "Run completed." -ForegroundColor Green
    }
    else {
        Write-Host "----------------------------------------"
        Write-Host "Run failed with exit code: $exitCode" -ForegroundColor Red
        exit $exitCode
    }
}
catch {
    Write-Host "----------------------------------------"
    Write-Host "Run process error: $_" -ForegroundColor Red
    exit 1
}
