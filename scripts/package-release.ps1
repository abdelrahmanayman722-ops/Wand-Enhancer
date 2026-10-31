[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Version = '2.3.0.0',

    [Parameter(Position = 1)]
    [string]$OutputDir = 'release',

    [switch]$SkipBuild,

    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [switch]$EnableUpdateNotifications
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw 'Version cannot be empty.'
}

# Normalize version (e.g. "v2.3.0.0" -> "2.3.0.0")
$normalizedVersion = $Version.Trim().TrimStart('v', 'V')

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SovereignTitan Release Packaging Pipeline - v$normalizedVersion" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Step 1: Validate Release Metadata
$validateScript = Join-Path $PSScriptRoot 'validate-release-metadata.ps1'
if (-not (Test-Path $validateScript)) {
    throw "Metadata validator script not found: $validateScript"
}

Write-Host "`n==> [1/5] Validating release metadata..." -ForegroundColor Cyan
& $validateScript -ExpectedVersion $normalizedVersion

# Step 2: Build if not skipped
if (-not $SkipBuild) {
    Write-Host "`n==> [2/5] Executing full production build ($Configuration)..." -ForegroundColor Cyan
    $buildScript = Join-Path $repoRoot 'build.ps1'
    if (-not (Test-Path $buildScript)) {
        throw "Build script not found: $buildScript"
    }

    $buildParams = @{
        Configuration = $Configuration
    }
    if ($EnableUpdateNotifications) {
        $buildParams['EnableUpdateNotifications'] = $true
    }

    & $buildScript @buildParams
} else {
    Write-Host "`n==> [2/5] -SkipBuild specified: Skipping compilation step." -ForegroundColor Yellow
}

# Step 3: Locate Compiled Standalone Executable
Write-Host "`n==> [3/5] Locating compiled standalone executable..." -ForegroundColor Cyan
$candidatePaths = @(
    (Join-Path $repoRoot "WandEnhancer\bin\$Configuration\SovereignTitan.exe"),
    (Join-Path $repoRoot 'SovereignTitan.exe'),
    (Join-Path $repoRoot "WandEnhancer\bin\$Configuration\WandEnhancer.exe"),
    (Join-Path $repoRoot 'WandEnhancer.exe')
)

$sourceExe = $null
foreach ($path in $candidatePaths) {
    if (Test-Path $path) {
        $sourceExe = $path
        break
    }
}

if (-not $sourceExe) {
    throw "Compiled standalone executable not found in candidate paths: $($candidatePaths -join ', ')"
}

$fileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($sourceExe)
$fileVersion = $fileVersionInfo.FileVersion
Write-Host "Found executable: $sourceExe (FileVersion: $fileVersion)" -ForegroundColor Green

$baseVersion = ($normalizedVersion -replace '-.*$', '')
if ($fileVersion -ne $baseVersion) {
    throw "Executable FileVersion ($fileVersion) does not match expected version ($baseVersion)."
}

# Step 4: Ensure OutputDir and Stage SovereignTitan.exe
Write-Host "`n==> [4/5] Staging release artifacts..." -ForegroundColor Cyan
$resolvedOutputDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
} else {
    Join-Path $repoRoot $OutputDir
}

if (-not (Test-Path $resolvedOutputDir)) {
    [System.IO.Directory]::CreateDirectory($resolvedOutputDir) | Out-Null
    Write-Host "Created output directory: $resolvedOutputDir"
}

$destExePath = Join-Path $resolvedOutputDir 'SovereignTitan.exe'
Copy-Item -LiteralPath $sourceExe -Destination $destExePath -Force
Write-Host "Copied executable to: $destExePath"

# Create Release Zip Archive: SovereignTitan-v$normalizedVersion-win-x64.zip
$zipFileName = "SovereignTitan-v$normalizedVersion-win-x64.zip"
$destZipPath = Join-Path $resolvedOutputDir $zipFileName

$tempStaging = Join-Path ([System.IO.Path]::GetTempPath()) ("sovereigntitan-pkg-" + [System.Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempStaging) | Out-Null

try {
    # 1. SovereignTitan.exe
    Copy-Item -LiteralPath $destExePath -Destination (Join-Path $tempStaging 'SovereignTitan.exe') -Force

    # 2. Required documentation
    $docFiles = @('README.md', 'SECURITY.md', 'CHANGELOG.md')
    foreach ($doc in $docFiles) {
        $docPath = Join-Path $repoRoot $doc
        if (Test-Path $docPath) {
            Copy-Item -LiteralPath $docPath -Destination (Join-Path $tempStaging $doc) -Force
            Write-Host "  Included: $doc"
        } else {
            throw "Mandatory documentation file missing from repo root: $doc"
        }
    }

    # 3. LICENSE (if present)
    $licenseCandidates = @('LICENSE', 'LICENSE.md', 'LICENSE.txt')
    $licenseFound = $false
    foreach ($lic in $licenseCandidates) {
        $licPath = Join-Path $repoRoot $lic
        if (Test-Path $licPath) {
            Copy-Item -LiteralPath $licPath -Destination (Join-Path $tempStaging $lic) -Force
            Write-Host "  Included: $lic"
            $licenseFound = $true
            break
        }
    }
    if (-not $licenseFound) {
        Write-Host "  Notice: No LICENSE file found at repository root." -ForegroundColor Yellow
    }

    if (Test-Path $destZipPath) {
        Remove-Item -LiteralPath $destZipPath -Force
    }

    # Compress staging folder to zip
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempStaging, $destZipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    Write-Host "Created release archive: $destZipPath"
}
finally {
    if (Test-Path $tempStaging) {
        Remove-Item -LiteralPath $tempStaging -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Verify Zip Contents
$zipArchive = [System.IO.Compression.ZipFile]::OpenRead($destZipPath)
try {
    $archivedFiles = @($zipArchive.Entries | ForEach-Object { $_.FullName })
    Write-Host "Archive contents ($($archivedFiles.Count) files):"
    foreach ($f in $archivedFiles) {
        Write-Host "    $f"
    }
    if ('SovereignTitan.exe' -notin $archivedFiles) {
        throw "Archive verification failed: SovereignTitan.exe missing from $destZipPath"
    }
}
finally {
    $zipArchive.Dispose()
}

# Step 5: Compute SHA256 Hashes and Generate SHA256SUMS.txt
Write-Host "`n==> [5/5] Computing SHA256 checksums..." -ForegroundColor Cyan
function Get-Sha256Checksum([string]$FilePath) {
    return (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
}

$exeHash = Get-Sha256Checksum $destExePath
$zipHash = Get-Sha256Checksum $destZipPath

$sumsFileName = 'SHA256SUMS.txt'
$sumsFilePath = Join-Path $resolvedOutputDir $sumsFileName
$sumsContent = "$exeHash  SovereignTitan.exe`n$zipHash  $zipFileName`n"

[System.IO.File]::WriteAllText($sumsFilePath, $sumsContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Generated checksum file: $sumsFilePath"

# Output Summary
$exeLength = (Get-Item -LiteralPath $destExePath).Length
$zipLength = (Get-Item -LiteralPath $destZipPath).Length

Write-Host "`n================ Release Packaging Summary ================" -ForegroundColor Green
Write-Host "Version:    $normalizedVersion" -ForegroundColor Green
Write-Host "Output Dir: $resolvedOutputDir" -ForegroundColor Green
Write-Host ""
Write-Host "Staged Artifacts:" -ForegroundColor Green
Write-Host "  1. SovereignTitan.exe"
Write-Host "     Size:   $exeLength bytes ($([math]::Round($exeLength / 1MB, 2)) MB)"
Write-Host "     SHA256: $exeHash"
Write-Host "  2. $zipFileName"
Write-Host "     Size:   $zipLength bytes ($([math]::Round($zipLength / 1MB, 2)) MB)"
Write-Host "     SHA256: $zipHash"
Write-Host "  3. $sumsFileName"
Write-Host "     Content:"
Get-Content -Path $sumsFilePath | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
Write-Host "===========================================================" -ForegroundColor Green
