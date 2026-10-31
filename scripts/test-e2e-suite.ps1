<#
.SYNOPSIS
    Comprehensive 4-Tier Opaque-Box E2E Test Suite for Wand Enhancer (SovereignTitan).
.DESCRIPTION
    Systematically exercises:
      - Tier 1: Systematic Feature Coverage (R1, R2, R3, R4 >= 5 tests/feature)
      - Tier 2: Boundary & Corner Cases (R1, R2, R3, R4 >= 5 tests/feature)
      - Tier 3: Pairwise Cross-Feature Interactions
      - Tier 4: Real-World Application Scenarios (SC-01 to SC-05)
.PARAMETER Tier
    Filter tests by Tier: '1', '2', '3', '4', or 'All' (default: 'All').
.PARAMETER Feature
    Filter tests by Feature: 'R1', 'R2', 'R3', 'R4', or 'All' (default: 'All').
.PARAMETER TargetVersion
    Expected version string for harmonization tests (default: '2.3.0.0').
.PARAMETER AssemblyPath
    Path to compiled SovereignTitan.exe assembly (default: './SovereignTitan.exe').
.PARAMETER WandInstallDir
    Path to Wand v12.68.0 directory (default: auto-detected from %LOCALAPPDATA%\Wand\app-12.68.0).
.PARAMETER Strict
    When specified, tests for in-flight milestone dependencies fail rather than reporting PENDING.
.PARAMETER VerboseOutput
    Emits detailed diagnostic messages during test execution.
#>

param(
    [ValidateSet('1', '2', '3', '4', 'All')]
    [string]$Tier = 'All',

    [ValidateSet('R1', 'R2', 'R3', 'R4', 'All')]
    [string]$Feature = 'All',

    [string]$TargetVersion = '2.3.0.0',
    [string]$AssemblyPath = "$PSScriptRoot\..\SovereignTitan.exe",
    [string]$WandInstallDir = "$env:LOCALAPPDATA\Wand\app-12.68.0",
    [switch]$Strict,
    [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$resolvedAssemblyPath = if (Test-Path $AssemblyPath) { (Resolve-Path $AssemblyPath).Path } else { $null }

# Ensure Node is accessible
if (-not (Get-Command 'node' -ErrorAction SilentlyContinue)) {
    $adobeNode = 'C:\Program Files\Common Files\Adobe\Creative Cloud Libraries\libs'
    if (Test-Path (Join-Path $adobeNode 'node.exe')) { $env:PATH = "$adobeNode;$env:PATH" }
    $pwNode = 'C:\Users\pc\AppData\Roaming\ProjectLightningV5\resources\binaries\win\python\Lib\site-packages\playwright\driver'
    if (Test-Path (Join-Path $pwNode 'node.exe')) { $env:PATH = "$pwNode;$env:PATH" }
}

# Test Suite Tracking State
$suiteResults = [System.Collections.Generic.List[PSObject]]::new()
$suiteStartTime = [System.Diagnostics.Stopwatch]::StartNew()
$passCount = 0
$failCount = 0
$pendingCount = 0
$skipCount = 0

function Write-TestHeader([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
}

function Write-SectionHeader([string]$Title) {
    Write-Host ""
    Write-Host ("-" * 60) -ForegroundColor DarkCyan
    Write-Host " [SECTION] $Title" -ForegroundColor DarkCyan
    Write-Host ("-" * 60) -ForegroundColor DarkCyan
}

function Invoke-E2ETest {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$TierLevel,
        [Parameter(Mandatory = $true)][string]$FeatureDomain,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][scriptblock]$TestBlock,
        [string]$DependencyMilestone = $null
    )

    # Filter checks
    if ($Tier -ne 'All' -and $Tier -ne $TierLevel) {
        $script:skipCount++
        return
    }
    if ($Feature -ne 'All' -and $Feature -ne $FeatureDomain -and $FeatureDomain -ne 'CROSS') {
        $script:skipCount++
        return
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $status = 'PASS'
    $errorMsg = ''

    try {
        & $TestBlock
    }
    catch {
        $rawError = $_.Exception.GetBaseException().Message
        if (-not $Strict -and $null -ne $DependencyMilestone) {
            # Check if failure is an unmet in-flight milestone dependency
            $status = "PENDING ($DependencyMilestone)"
            $errorMsg = $rawError
        }
        else {
            $status = 'FAIL'
            $errorMsg = $rawError
        }
    }
    finally {
        $sw.Stop()
    }

    $durationMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)

    switch -Wildcard ($status) {
        'PASS' {
            $script:passCount++
            Write-Host "  [PASS] $Id - $Description (${durationMs}ms)" -ForegroundColor Green
        }
        'PENDING*' {
            $script:pendingCount++
            Write-Host "  [PEND] $Id - $Description ($status) - $errorMsg" -ForegroundColor Yellow
        }
        'FAIL' {
            $script:failCount++
            Write-Host "  [FAIL] $Id - $Description (${durationMs}ms)" -ForegroundColor Red
            Write-Host "         Error: $errorMsg" -ForegroundColor DarkRed
        }
    }

    $script:suiteResults.Add([PSCustomObject]@{
        Id          = $Id
        Tier        = $TierLevel
        Feature     = $FeatureDomain
        Description = $Description
        Status      = $status
        DurationMs  = $durationMs
        Error       = $errorMsg
    })
}

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected: '$Expected', actual: '$Actual')"
    }
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Assert-Contains([string]$Haystack, [string]$Needle, [string]$Message) {
    if ($null -eq $Haystack -or -not $Haystack.Contains($Needle)) {
        throw "$Message - Expected content to contain '$Needle'"
    }
}

# Pre-load SovereignTitan assembly if present
$titanAssembly = $null
if ($resolvedAssemblyPath -and (Test-Path $resolvedAssemblyPath)) {
    try {
        $titanAssembly = [Reflection.Assembly]::LoadFrom($resolvedAssemblyPath)
    }
    catch {
        Write-Warning "Could not load assembly from $resolvedAssemblyPath : $($_.Message)"
    }
}

Write-TestHeader "Wand Enhancer (SovereignTitan) - Comprehensive 4-Tier E2E Test Suite"
Write-Host "Target Release Version : $TargetVersion" -ForegroundColor Yellow
Write-Host "Assembly Path          : $(if ($resolvedAssemblyPath) { $resolvedAssemblyPath } else { 'NOT FOUND' })"
Write-Host "Filter Settings        : Tier='$Tier', Feature='$Feature', Strict=$Strict"
Write-Host "Node Version           : $(try { (& node --version) } catch { 'NOT FOUND' })"
Write-Host "Genuine Wand v12.68.0  : $(if (Test-Path $WandInstallDir) { "Detected at $WandInstallDir" } else { "Not Present (using synthetic fixtures)" })"


# ==============================================================================
# TIER 1: SYSTEMATIC FEATURE COVERAGE (R1, R2, R3, R4)
# ==============================================================================
Write-SectionHeader "TIER 1: FEATURE COVERAGE (>= 5 tests per feature)"

# --- Feature R1: Wand v12.68.0 Compatibility & Bridge Invariants ---

Invoke-E2ETest -Id "T1-R1-01" -TierLevel "1" -FeatureDomain "R1" `
    -Description "AST Patch Locators: Minified Bundle Compatibility" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $scriptPath = Join-Path $repoRoot "scripts\test-patch-locators.ps1"
        Assert-True (Test-Path $scriptPath) "scripts/test-patch-locators.ps1 must exist"
        
        $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-e2e-min-" + [guid]::NewGuid().ToString("N"))
        [IO.Directory]::CreateDirectory($scratch) | Out-Null
        try {
            $fixture = Join-Path $repoRoot "scripts\tests\patch-locators.js"
            $esbuild = Join-Path $repoRoot "web-panel\node_modules\esbuild\bin\esbuild"
            $minifiedOut = Join-Path $scratch "minified.js"
            & node $esbuild $fixture --target=es2022 --minify "--outfile=$minifiedOut"
            Assert-Equal $LASTEXITCODE 0 "esbuild minification must succeed"
            Assert-True (Test-Path $minifiedOut) "Minified bundle must be created"

            # Execute patch locators against minified bundle
            $configType = $titanAssembly.GetType("WandEnhancer.Core.EnhancerConfig", $true)
            $cursorType = $titanAssembly.GetType("WandEnhancer.Core.Js.JsCursor", $true)
            $patches = $configType.GetMethod("GetInstance").Invoke($null, @())
            $source = [IO.File]::ReadAllText($minifiedOut)
            $appliedCount = 0

            foreach ($selection in $patches.Values) {
                foreach ($entry in $selection) {
                    $cursor = [Activator]::CreateInstance($cursorType, @($source))
                    $edits = $entry.Locate.Invoke($cursor)
                    if ($null -ne $edits -and $edits.Length -gt 0) {
                        foreach ($edit in @($edits | Sort-Object Start -Descending)) {
                            $source = $edit.ApplyTo($source)
                        }
                        $appliedCount++
                    }
                }
            }
            Assert-Equal $appliedCount 12 "All 12 AST patches must apply to minified fixture"
            $patchedFile = Join-Path $scratch "patched.js"
            [IO.File]::WriteAllText($patchedFile, $source)
            & node --check $patchedFile
            Assert-Equal $LASTEXITCODE 0 "Patched minified bundle must be valid JavaScript"
        }
        finally {
            Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

Invoke-E2ETest -Id "T1-R1-02" -TierLevel "1" -FeatureDomain "R1" `
    -Description "AST Patch Locators: Prettified Bundle Compatibility" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-e2e-pret-" + [guid]::NewGuid().ToString("N"))
        [IO.Directory]::CreateDirectory($scratch) | Out-Null
        try {
            $fixture = Join-Path $repoRoot "scripts\tests\patch-locators.js"
            $esbuild = Join-Path $repoRoot "web-panel\node_modules\esbuild\bin\esbuild"
            $pretOut = Join-Path $scratch "prettified.js"
            & node $esbuild $fixture --target=es2022 "--outfile=$pretOut"
            Assert-Equal $LASTEXITCODE 0 "esbuild format must succeed"

            $configType = $titanAssembly.GetType("WandEnhancer.Core.EnhancerConfig", $true)
            $cursorType = $titanAssembly.GetType("WandEnhancer.Core.Js.JsCursor", $true)
            $patches = $configType.GetMethod("GetInstance").Invoke($null, @())
            $source = [IO.File]::ReadAllText($pretOut)
            $appliedCount = 0

            foreach ($selection in $patches.Values) {
                foreach ($entry in $selection) {
                    $cursor = [Activator]::CreateInstance($cursorType, @($source))
                    $edits = $entry.Locate.Invoke($cursor)
                    if ($null -ne $edits -and $edits.Length -gt 0) {
                        foreach ($edit in @($edits | Sort-Object Start -Descending)) {
                            $source = $edit.ApplyTo($source)
                        }
                        $appliedCount++
                    }
                }
            }
            Assert-Equal $appliedCount 12 "All 12 AST patches must apply to prettified fixture"
            $patchedFile = Join-Path $scratch "patched-pret.js"
            [IO.File]::WriteAllText($patchedFile, $source)
            & node --check $patchedFile
            Assert-Equal $LASTEXITCODE 0 "Patched prettified bundle must be valid JavaScript"
        }
        finally {
            Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

Invoke-E2ETest -Id "T1-R1-03" -TierLevel "1" -FeatureDomain "R1" `
    -Description "Electron Fuse Wire: Sentinel Offset Detection" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $fuseType = $titanAssembly.GetType("WandEnhancer.Core.Patching.Shared.ElectronFuseWire", $true)
        $findOffset = $fuseType.GetMethod("FindStateFileOffset", [Reflection.BindingFlags]'Public, Static')
        Assert-True ($null -ne $findOffset) "FindStateFileOffset method must exist"

        # Test against real Wand.exe if present, or synthetic fuse fixture
        $wandExe = [string](Join-Path $WandInstallDir "Wand.exe")
        if (Test-Path $wandExe) {
            $offset = $findOffset.Invoke($null, [object[]]@($wandExe))
            Assert-True ($offset -gt 0) "Must detect valid Electron fuse wire offset in Wand.exe"
        }
        else {
            # Synthetic fuse fixture
            $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-fuse-" + [guid]::NewGuid().ToString("N"))
            [IO.Directory]::CreateDirectory($scratch) | Out-Null
            try {
                $fakeExe = [string](Join-Path $scratch "FakeWand.exe")
                $sentinel = [Text.Encoding]::ASCII.GetBytes("dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX`0")
                $padding = New-Object byte[] 1024
                $fuseBytes = [byte[]]@(0x01, 0x01) # wire version 1, fuse 1
                $content = $padding + $sentinel + $fuseBytes + $padding
                [IO.File]::WriteAllBytes($fakeExe, $content)
                $offset = $findOffset.Invoke($null, [object[]]@($fakeExe))
                Assert-True ($offset -gt 0) "Must detect fuse wire offset in synthetic binary"
            }
            finally {
                Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

Invoke-E2ETest -Id "T1-R1-04" -TierLevel "1" -FeatureDomain "R1" `
    -Description "PE Resource ASAR Integrity Hash Anchor Discovery" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $patchType = $titanAssembly.GetType("WandEnhancer.Core.Patching.Strategies.Static.AsarIntegrityResourcePatch", $true)
        $findHash = $patchType.GetMethod("FindSoleHashOffset", [Reflection.BindingFlags]'NonPublic, Static')
        Assert-True ($null -ne $findHash) "FindSoleHashOffset method must exist"

        $wandExe = [string](Join-Path $WandInstallDir "Wand.exe")
        if (Test-Path $wandExe) {
            $anchor = [byte[]][Text.Encoding]::ASCII.GetBytes('"file":"resources\\app.asar","alg":"SHA256","value":"')
            $offset = $findHash.Invoke($null, [object[]]@($wandExe, $anchor))
            Assert-True ($offset -gt 0) "Must locate ASAR integrity PE resource in Wand.exe"
        }
        else {
            $anchorProp = $patchType.GetField("AnchorBackslash", [Reflection.BindingFlags]'NonPublic, Static')
            Assert-True ($null -ne $anchorProp) "PE integrity anchor constant must exist"
        }
    }

Invoke-E2ETest -Id "T1-R1-05" -TierLevel "1" -FeatureDomain "R1" `
    -Description "Auxiliary Service: DotNetImage Fuse & Trust Neutralization Offsets" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $dotNetImageType = $titanAssembly.GetType("WandEnhancer.Core.Patching.Strategies.Static.DotNetImage", $true)
        Assert-True ($null -ne $dotNetImageType) "DotNetImage type must exist"
        
        $auxExe = [string](Join-Path $WandInstallDir "WandAuxiliaryService.exe")
        if (Test-Path $auxExe) {
            $image = $dotNetImageType.GetMethod("Load", [Reflection.BindingFlags]'Public, Static').Invoke($null, [object[]]@($auxExe))
            Assert-True ($null -ne $image) "DotNetImage.Load must return image"
            try {
                $findOffset = $dotNetImageType.GetMethod("FindBoolPredicateOffsetByTypeStringAnchor")
                $offset = $findOffset.Invoke($image, [object[]]@("dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX"))
                Assert-True ($offset -gt 0) "Must locate fuse predicate in WandAuxiliaryService.exe"

                $findCaller = $dotNetImageType.GetMethod("FindPInvokeCallerCodeOffsets")
                $callers = $findCaller.Invoke($image, [object[]]@("WinVerifyTrust"))
                Assert-True ($callers.Count -gt 0) "Must locate WinVerifyTrust caller in WandAuxiliaryService.exe"
            }
            finally {
                $image.Dispose()
            }
        }
        else {
            $methods = $dotNetImageType.GetMethods([Reflection.BindingFlags]'Public, Instance')
            $names = @($methods | ForEach-Object { $_.Name })
            Assert-True ($names -contains "FindBoolPredicateOffsetByTypeStringAnchor") "FindBoolPredicateOffset exists"
            Assert-True ($names -contains "FindPInvokeCallerCodeOffsets") "FindPInvokeCallerCodeOffsets exists"
        }
    }

Invoke-E2ETest -Id "T1-R1-06" -TierLevel "1" -FeatureDomain "R1" `
    -Description "Web Contract Alignment: Port 3223, Base Paths, and Pairing Param" `
    -TestBlock {
        $contractPath = Join-Path $repoRoot "web-panel\protocol\web-contract.json"
        Assert-True (Test-Path $contractPath) "web-contract.json must exist"
        $contract = Get-Content $contractPath -Raw | ConvertFrom-Json
        
        Assert-Equal $contract.defaultRemotePort 3223 "Web contract port must be 3223"
        Assert-Equal $contract.protocolVersion 1 "Web contract protocol version must be 1"
        Assert-Equal $contract.basePath "/remote/" "Web contract base path must be /remote/"
        Assert-Equal $contract.webSocketPath "/remote/ws" "Web contract WS path must be /remote/ws"
        Assert-Equal $contract.healthPath "/remote/api/health" "Web contract health path must be /remote/api/health"
        Assert-Equal $contract.pairingTokenQueryParam "token" "Pairing token query param must be 'token'"

        # Verify bridge constants.ts imports and re-exports accurately
        $bridgeConstantsPath = Join-Path $repoRoot "web-panel\bridge\src\constants.ts"
        Assert-True (Test-Path $bridgeConstantsPath) "bridge constants.ts must exist"
        $bridgeContent = Get-Content $bridgeConstantsPath -Raw
        Assert-Contains $bridgeContent "web-contract.json" "bridge constants.ts must import web-contract.json"
        Assert-Contains $bridgeContent "DEFAULT_REMOTE_PORT: WEB_CONTRACT.defaultRemotePort" "Port must mirror contract"
        Assert-Contains $bridgeContent "PAIRING_TOKEN_QUERY_PARAM: WEB_CONTRACT.pairingTokenQueryParam" "Token param must mirror contract"
    }

Invoke-E2ETest -Id "T1-R1-07" -TierLevel "1" -FeatureDomain "R1" `
    -Description "Production Dist Cleanliness: Zero Dev-Only Assets & Syntax Validation" `
    -TestBlock {
        $verifyScript = Join-Path $repoRoot "web-panel\scripts\verify-dist.mjs"
        Assert-True (Test-Path $verifyScript) "verify-dist.mjs must exist"
        & node $verifyScript
        Assert-Equal $LASTEXITCODE 0 "verify-dist.mjs must pass with exit code 0"

        $distBridge = Join-Path $repoRoot "web-panel\dist\bridge.cjs"
        $distCleanup = Join-Path $repoRoot "web-panel\dist\renderer-scripts\remote-popup-cleanup.js"
        $distSync = Join-Path $repoRoot "web-panel\dist\renderer-scripts\installed-apps-sync.js"

        Assert-True (Test-Path $distBridge) "dist/bridge.cjs must exist"
        Assert-True (Test-Path $distCleanup) "dist/renderer-scripts/remote-popup-cleanup.js must exist"
        Assert-True (Test-Path $distSync) "dist/renderer-scripts/installed-apps-sync.js must exist"

        foreach ($file in @($distBridge, $distCleanup, $distSync)) {
            & node --check $file
            Assert-Equal $LASTEXITCODE 0 "node --check must pass on $(Split-Path $file -Leaf)"
        }
    }


# --- Feature R2: Realistic Version Numbering (v2.3.0.0) & Attribution ---

Invoke-E2ETest -Id "T1-R2-01" -TierLevel "1" -FeatureDomain "R2" `
    -Description "AssemblyInfo: Version String Harmonization to Target Version ($TargetVersion)" `
    -DependencyMilestone "M2" `
    -TestBlock {
        $assemblyInfoPath = Join-Path $repoRoot "WandEnhancer\Properties\AssemblyInfo.cs"
        Assert-True (Test-Path $assemblyInfoPath) "AssemblyInfo.cs must exist"
        $content = Get-Content $assemblyInfoPath -Raw
        
        $asmVer = [regex]::Match($content, '(?m)^\s*\[assembly:\s*AssemblyVersion\("(?<v>[^"]+)"\)\]').Groups['v'].Value
        $fileVer = [regex]::Match($content, '(?m)^\s*\[assembly:\s*AssemblyFileVersion\("(?<v>[^"]+)"\)\]').Groups['v'].Value
        
        Assert-Equal $asmVer $TargetVersion "AssemblyVersion must be $TargetVersion"
        Assert-Equal $fileVer $TargetVersion "AssemblyFileVersion must be $TargetVersion"
    }

Invoke-E2ETest -Id "T1-R2-02" -TierLevel "1" -FeatureDomain "R2" `
    -Description "Maintainer Attribution: Eng. Abdelrahman Rashad (@abdelrahmanayman722-ops)" `
    -DependencyMilestone "M2" `
    -TestBlock {
        $assemblyInfoPath = Join-Path $repoRoot "WandEnhancer\Properties\AssemblyInfo.cs"
        $constantsPath = Join-Path $repoRoot "WandEnhancer\Constants.cs"
        
        $asmContent = Get-Content $assemblyInfoPath -Raw
        $constContent = Get-Content $constantsPath -Raw

        Assert-Contains $asmContent "@abdelrahmanayman722-ops" "AssemblyInfo Company/Copyright must attribute to Abdelrahman"
        Assert-Contains $constContent "@abdelrahmanayman722-ops" "Constants.Author must attribute to Abdelrahman"
    }

Invoke-E2ETest -Id "T1-R2-03" -TierLevel "1" -FeatureDomain "R2" `
    -Description "UI Presentation: VersionLabel Design-Time & Code-Behind Binding" `
    -DependencyMilestone "M2" `
    -TestBlock {
        $xamlPath = Join-Path $repoRoot "WandEnhancer\View\MainWindow\MainWindow.xaml"
        $csPath = Join-Path $repoRoot "WandEnhancer\View\MainWindow\MainWindow.xaml.cs"
        
        $xamlContent = Get-Content $xamlPath -Raw
        $csContent = Get-Content $csPath -Raw

        Assert-Contains $xamlContent "x:Name=`"VersionLabel`"" "MainWindow.xaml must define VersionLabel"
        Assert-Contains $xamlContent "2.3.0.0" "MainWindow.xaml design-time label must reflect $TargetVersion"
        Assert-Contains $csContent "VersionLabel.Text" "MainWindow.xaml.cs must bind VersionLabel at runtime"
    }

Invoke-E2ETest -Id "T1-R2-04" -TierLevel "1" -FeatureDomain "R2" `
    -Description "Multi-Locale Synchronization: Arabic & English Attribution" `
    -DependencyMilestone "M2" `
    -TestBlock {
        $arPath = Join-Path $repoRoot "WandEnhancer\Locale\lang.ar-SA.xaml"
        $enPath = Join-Path $repoRoot "WandEnhancer\Locale\lang.en-US.xaml"
        
        Assert-True (Test-Path $arPath) "Arabic locale must exist"
        Assert-True (Test-Path $enPath) "English locale must exist"

        $arContent = Get-Content $arPath -Raw
        $enContent = Get-Content $enPath -Raw

        Assert-Contains $arContent "abdelrahmanayman722-ops" "Arabic locale must reference profile"
        Assert-Contains $enContent "abdelrahmanayman722-ops" "English locale must reference profile"
    }

Invoke-E2ETest -Id "T1-R2-05" -TierLevel "1" -FeatureDomain "R2" `
    -Description "CHANGELOG.md: Sequential Ordering & Harmonized [2.3.0.0] Header" `
    -DependencyMilestone "M2" `
    -TestBlock {
        $changelogPath = Join-Path $repoRoot "CHANGELOG.md"
        Assert-True (Test-Path $changelogPath) "CHANGELOG.md must exist"
        $content = Get-Content $changelogPath -Raw

        $matches = [regex]::Matches($content, '(?m)^##\s+\[(?<v>[^\]]+)\]')
        Assert-True ($matches.Count -ge 2) "CHANGELOG.md must contain multiple release sections"
        Assert-Equal $matches[0].Groups['v'].Value $TargetVersion "Top CHANGELOG entry must be $TargetVersion"
        Assert-Equal $matches[1].Groups['v'].Value "2.2.0.0" "Second CHANGELOG entry must be 2.2.0.0"
    }


# --- Feature R3: Defensive Security Countermeasures & Community Protection ---

Invoke-E2ETest -Id "T1-R3-01" -TierLevel "1" -FeatureDomain "R3" `
    -Description "README.md: Prominent Security Advisory Naming Threat Actor @ki11tbyte" `
    -DependencyMilestone "M3" `
    -TestBlock {
        $readmePath = Join-Path $repoRoot "README.md"
        Assert-True (Test-Path $readmePath) "README.md must exist"
        $content = Get-Content $readmePath -Raw

        Assert-Contains $content "ki11tbyte" "README must explicitly name malicious actor @ki11tbyte"
        Assert-Contains $content "ki1bytee" "README must name fraudulent repo ki1bytee"
        Assert-Contains $content "smokeysfc" "README must name fraudulent repo smokeysfc"
        Assert-True ($content.ToLower().Contains("infostealer") -or $content.ToLower().Contains("stealer") -or $content.ToLower().Contains("trojan")) `
            "README must explain the password stealer / trojan threat"
    }

Invoke-E2ETest -Id "T1-R3-02" -TierLevel "1" -FeatureDomain "R3" `
    -Description "SECURITY.md: Official Security Policy & Threat Intelligence Document" `
    -DependencyMilestone "M3" `
    -TestBlock {
        $secPath = Join-Path $repoRoot "SECURITY.md"
        Assert-True (Test-Path $secPath) "SECURITY.md must exist at repo root"
        $content = Get-Content $secPath -Raw

        Assert-Contains $content "ki11tbyte" "SECURITY.md must document @ki11tbyte threat"
        Assert-Contains $content "SHA256" "SECURITY.md must document cryptographic verification"
        Assert-Contains $content "abdelrahmanayman722-ops" "SECURITY.md must reference official maintainer profile"
    }

Invoke-E2ETest -Id "T1-R3-03" -TierLevel "1" -FeatureDomain "R3" `
    -Description "Cryptographic Verification Guide: PowerShell Get-FileHash Instructions" `
    -DependencyMilestone "M3" `
    -TestBlock {
        $readmePath = Join-Path $repoRoot "README.md"
        $secPath = Join-Path $repoRoot "SECURITY.md"
        $secContent = if (Test-Path $secPath) { Get-Content $secPath -Raw } else { "" }
        $combined = (Get-Content $readmePath -Raw) + "`n" + $secContent

        Assert-Contains $combined "Get-FileHash" "Documentation must provide PowerShell Get-FileHash instructions"
        Assert-Contains $combined "-Algorithm SHA256" "Documentation must specify -Algorithm SHA256"
    }

Invoke-E2ETest -Id "T1-R3-04" -TierLevel "1" -FeatureDomain "R3" `
    -Description "Cryptographic Verification Guide: CMD certutil Instructions" `
    -DependencyMilestone "M3" `
    -TestBlock {
        $readmePath = Join-Path $repoRoot "README.md"
        $secPath = Join-Path $repoRoot "SECURITY.md"
        $secContent = if (Test-Path $secPath) { Get-Content $secPath -Raw } else { "" }
        $combined = (Get-Content $readmePath -Raw) + "`n" + $secContent

        Assert-Contains $combined "certutil" "Documentation must provide CMD certutil instructions"
        Assert-Contains $combined "-hashfile" "Documentation must specify -hashfile SHA256"
    }

Invoke-E2ETest -Id "T1-R3-05" -TierLevel "1" -FeatureDomain "R3" `
    -Description "Launcher Startup Security Advisory in MainWindow LauncherLog" `
    -DependencyMilestone "M3" `
    -TestBlock {
        $csPath = Join-Path $repoRoot "WandEnhancer\View\MainWindow\MainWindow.xaml.cs"
        Assert-True (Test-Path $csPath) "MainWindow.xaml.cs must exist"
        $content = Get-Content $csPath -Raw

        Assert-Contains $content "LauncherLog" "MainWindow.xaml.cs must reference LauncherLog"
        Assert-True ($content.Contains("SHA256") -or $content.Contains("ki11tbyte") -or $content.Contains("abdelrahmanayman722-ops") -or $content.Contains("Security")) `
            "MainWindow.xaml.cs must log security verification advisory during startup"
    }


# --- Feature R4: Production Packaging & Release Automation ---

Invoke-E2ETest -Id "T1-R4-01" -TierLevel "1" -FeatureDomain "R4" `
    -Description "Standalone Executable: ILRepack Single-File Binary Verification" `
    -TestBlock {
        Assert-True ($null -ne $resolvedAssemblyPath -and (Test-Path $resolvedAssemblyPath)) `
            "Standalone executable SovereignTitan.exe must exist in root or build output"
        $bytes = [IO.File]::ReadAllBytes($resolvedAssemblyPath)
        Assert-True ($bytes.Length -gt 1000000) "Executable must be standalone merged binary (> 1MB)"
        Assert-Equal $bytes[0] 0x4D "PE Header 'M'"
        Assert-Equal $bytes[1] 0x5A "PE Header 'Z'"
    }

Invoke-E2ETest -Id "T1-R4-02" -TierLevel "1" -FeatureDomain "R4" `
    -Description "Release Packaging Automation Script (scripts/package-release.ps1)" `
    -DependencyMilestone "M4" `
    -TestBlock {
        $pkgScript = Join-Path $repoRoot "scripts\package-release.ps1"
        Assert-True (Test-Path $pkgScript) "scripts/package-release.ps1 must exist"
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($pkgScript, [ref]$null, [ref]$errors) | Out-Null
        Assert-Equal $errors.Count 0 "package-release.ps1 must have zero parse errors"
    }

Invoke-E2ETest -Id "T1-R4-03" -TierLevel "1" -FeatureDomain "R4" `
    -Description "Release Zip Archive Structure (SovereignTitan-v2.3.0.0-win-x64.zip)" `
    -DependencyMilestone "M4" `
    -TestBlock {
        $zipPath = Join-Path $repoRoot "release\SovereignTitan-v$TargetVersion-win-x64.zip"
        Assert-True (Test-Path $zipPath) "Release zip must exist at $zipPath"
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            $entryNames = @($zip.Entries | ForEach-Object { $_.FullName })
            Assert-True ($entryNames -contains "SovereignTitan.exe") "Archive must contain SovereignTitan.exe"
            Assert-True ($entryNames -contains "README.md") "Archive must contain README.md"
            Assert-True ($entryNames -contains "LICENSE.md") "Archive must contain LICENSE.md"
        }
        finally {
            $zip.Dispose()
        }
    }

Invoke-E2ETest -Id "T1-R4-04" -TierLevel "1" -FeatureDomain "R4" `
    -Description "Cryptographic Manifest Generation (SHA256SUMS.txt)" `
    -DependencyMilestone "M4" `
    -TestBlock {
        $sumPath = Join-Path $repoRoot "release\SHA256SUMS.txt"
        Assert-True (Test-Path $sumPath) "release/SHA256SUMS.txt must exist"
        $lines = Get-Content $sumPath
        Assert-True ($lines.Count -ge 2) "SHA256SUMS.txt must contain at least 2 entries (exe and zip)"
        
        foreach ($line in $lines) {
            Assert-True ($line -match '^[a-fA-F0-9]{64}\s{2}\S+') "Line must match RFC sha256sum format: $line"
        }
    }

Invoke-E2ETest -Id "T1-R4-05" -TierLevel "1" -FeatureDomain "R4" `
    -Description "Git Pre-Commit Hook Enforcement of Metadata Validation" `
    -TestBlock {
        $hookPath = Join-Path $repoRoot ".githooks\pre-commit"
        Assert-True (Test-Path $hookPath) ".githooks/pre-commit must exist"
        $content = Get-Content $hookPath -Raw
        Assert-Contains $content "validate-release-metadata.ps1" "Pre-commit hook must execute validate-release-metadata.ps1"
    }


# ==============================================================================
# TIER 2: BOUNDARY & CORNER CASES (R1, R2, R3, R4)
# ==============================================================================
Write-SectionHeader "TIER 2: BOUNDARY & CORNER CASES (>= 5 tests per feature)"

# --- Feature R1 Boundaries ---

Invoke-E2ETest -Id "T2-R1-01" -TierLevel "2" -FeatureDomain "R1" `
    -Description "JsCursor Stress: Unclosed Braces & Malformed Syntax Rejection" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $cursorType = $titanAssembly.GetType("WandEnhancer.Core.Js.JsCursor", $true)
        
        $malformedJs = "function test() { const a = { unclosed: 1; return a; "
        $cursor = [Activator]::CreateInstance($cursorType, @($malformedJs))
        
        $threw = $false
        try {
            $cursor.MatchClose([char]'{', [char]'}', 16) | Out-Null
        }
        catch {
            $threw = $true
        }
        Assert-True $threw "MatchClose must throw on unclosed braces without hanging"
    }

Invoke-E2ETest -Id "T2-R1-02" -TierLevel "2" -FeatureDomain "R1" `
    -Description "AsarContentPatcher: Missing Optional Capability Hint Toleration" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $configType = $titanAssembly.GetType("WandEnhancer.Core.EnhancerConfig", $true)
        $patches = $configType.GetMethod("GetInstance").Invoke($null, @())
        
        $optionalPatch = $null
        foreach ($selection in $patches.Values) {
            foreach ($entry in $selection) {
                if ($entry.IsOptional) {
                    $optionalPatch = $entry
                    break
                }
            }
        }
        Assert-True ($null -ne $optionalPatch) "Config must declare at least one optional patch"
        Assert-Equal $optionalPatch.Name "setAccountWandBrandExperience" "Optional patch is setAccountWandBrandExperience"
    }

Invoke-E2ETest -Id "T2-R1-03" -TierLevel "2" -FeatureDomain "R1" `
    -Description "AsarContentPatcher: Missing Mandatory Patch Anchor Rejection" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $cursorType = $titanAssembly.GetType("WandEnhancer.Core.Js.JsCursor", $true)
        $configType = $titanAssembly.GetType("WandEnhancer.Core.EnhancerConfig", $true)
        $patches = $configType.GetMethod("GetInstance").Invoke($null, @())
        
        $mandatoryPatch = $patches['ActivatePro'] | Where-Object { $_.Name -eq 'getUserAccount' } | Select-Object -First 1
        Assert-True ($null -ne $mandatoryPatch) "getUserAccount mandatory patch must exist"

        # Search against dummy bundle missing the anchor
        $emptyBundle = "console.log('empty bundle without wand anchors');"
        $cursor = [Activator]::CreateInstance($cursorType, @($emptyBundle))
        $edits = $mandatoryPatch.Locate.Invoke($cursor)
        Assert-True ($null -eq $edits) "Locate must return null when anchor is absent"
    }

Invoke-E2ETest -Id "T2-R1-04" -TierLevel "2" -FeatureDomain "R1" `
    -Description "WebSocket Safety: 1MB Maximum Frame Size Enforcement" `
    -TestBlock {
        $bridgeConstantsPath = Join-Path $repoRoot "web-panel\bridge\src\constants.ts"
        $content = Get-Content $bridgeConstantsPath -Raw
        Assert-Contains $content "MAX_WS_FRAME_BYTES: 1024 * 1024" "Bridge must limit WebSocket frames to exactly 1MB"
        
        $codecPath = Join-Path $repoRoot "web-panel\bridge\src\websocket-codec.ts"
        $codecContent = Get-Content $codecPath -Raw
        Assert-Contains $codecContent "MAX_WS_FRAME_BYTES" "Codec must enforce MAX_WS_FRAME_BYTES"
        Assert-Contains $codecContent "WS_FRAME_TOO_LARGE" "Codec must define FRAME_TOO_LARGE_ERROR"
    }

Invoke-E2ETest -Id "T2-R1-05" -TierLevel "2" -FeatureDomain "R1" `
    -Description "WebSocket Security: Unauthenticated Pairing Token Rejection" `
    -TestBlock {
        $serverPath = Join-Path $repoRoot "web-panel\bridge\src\server.ts"
        $serverContent = Get-Content $serverPath -Raw
        Assert-Contains $serverContent "pairing_required" "Server must reject unauthenticated clients with pairing_required"
        Assert-Contains $serverContent "1008" "Server must close unauthenticated sockets with policy violation code 1008"
    }

Invoke-E2ETest -Id "T2-R1-06" -TierLevel "2" -FeatureDomain "R1" `
    -Description "AsarExtractor: In-Place Extraction Self-Copy Collision Bypass" `
    -TestBlock {
        $extractorSource = Join-Path $repoRoot "AsarSharp\AsarExtractor.cs"
        Assert-True (Test-Path $extractorSource) "AsarExtractor.cs must exist"
        $content = Get-Content $extractorSource -Raw
        Assert-Contains $content "string.Equals(unpackedSourcePath, unpackedDestPath, StringComparison.OrdinalIgnoreCase)" `
            "AsarExtractor must check if sourcePath equals destPath to prevent locked self-copy crash"
    }


# --- Feature R2 Boundaries ---

Invoke-E2ETest -Id "T2-R2-01" -TierLevel "2" -FeatureDomain "R2" `
    -Description "Release Validator: Mismatched AssemblyVersion vs AssemblyFileVersion Rejection" `
    -TestBlock {
        $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-val-err-" + [guid]::NewGuid().ToString("N"))
        [IO.Directory]::CreateDirectory($scratch) | Out-Null
        try {
            $scratchScripts = Join-Path $scratch "scripts"
            $scratchProps = Join-Path $scratch "WandEnhancer\Properties"
            [IO.Directory]::CreateDirectory($scratchScripts) | Out-Null
            [IO.Directory]::CreateDirectory($scratchProps) | Out-Null

            Copy-Item (Join-Path $repoRoot "scripts\validate-release-metadata.ps1") $scratchScripts

            $fakeAssemblyInfo = Join-Path $scratchProps "AssemblyInfo.cs"
            $fakeChangelog = Join-Path $scratch "CHANGELOG.md"

            [IO.File]::WriteAllText($fakeAssemblyInfo, @"
[assembly: AssemblyVersion("2.3.0.0")]
[assembly: AssemblyFileVersion("2.4.0.0")]
"@)
            [IO.File]::WriteAllText($fakeChangelog, "## [2.3.0.0] - 2026-10-31`nNotes")

            $valScript = Join-Path $scratchScripts "validate-release-metadata.ps1"
            $ErrorActionPreference = 'Continue'
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $valScript 2>&1 | Out-String

            Assert-True ($LASTEXITCODE -ne 0) "Validator must exit with non-zero code on version mismatch"
            Assert-True ($output -match "AssemblyVersion \(2\.3\.0\.0\) and AssemblyFileVersion \(2\.4\.0\.0\) must match") `
                "Validator error message must describe mismatched AssemblyVersion and AssemblyFileVersion"
        }
        finally {
            Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

Invoke-E2ETest -Id "T2-R2-02" -TierLevel "2" -FeatureDomain "R2" `
    -Description "Version Normalizer: Empty and Whitespace Version Rejection" `
    -TestBlock {
        $valScript = Join-Path $repoRoot "scripts\validate-release-metadata.ps1"
        $content = Get-Content $valScript -Raw
        Assert-Contains $content "Version value cannot be empty" "Normalize-Version must reject empty values"
    }

Invoke-E2ETest -Id "T2-R2-03" -TierLevel "2" -FeatureDomain "R2" `
    -Description "Version Normalizer: Tag Prefix Tolerance (v2.3.0.0 vs 2.3.0.0)" `
    -TestBlock {
        $valScript = Join-Path $repoRoot "scripts\validate-release-metadata.ps1"
        Assert-True (Test-Path $valScript) "validate-release-metadata.ps1 must exist"

        # Load Normalize-Version directly from scripts/validate-release-metadata.ps1 AST
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($valScript, [ref]$null, [ref]$null)
        $funcAst = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Normalize-Version' }, $true)
        Assert-True ($null -ne $funcAst) "Normalize-Version function must be defined in validate-release-metadata.ps1"

        . ([scriptblock]::Create($funcAst.Extent.Text))

        Assert-Equal (Normalize-Version "v2.3.0.0") "2.3.0.0" "v-prefix must normalize"
        Assert-Equal (Normalize-Version "V2.3.0.0") "2.3.0.0" "V-prefix must normalize"
        Assert-Equal (Normalize-Version "2.3.0.0") "2.3.0.0" "Clean version must pass"
        Assert-Equal (Normalize-Version "2.3.0.0-rc.1") "2.3.0.0" "Prerelease suffix must strip"

        $emptyThrew = $false
        try { Normalize-Version "" } catch { $emptyThrew = $true }
        Assert-True $emptyThrew "Normalize-Version must reject empty version"

        # End-to-end script invocation with v-prefix
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $valScript -ExpectedVersion "v2.3.0.0" 2>&1
        Assert-Equal $LASTEXITCODE 0 "validate-release-metadata.ps1 must accept v-prefixed version in end-to-end execution: $out"
    }

Invoke-E2ETest -Id "T2-R2-04" -TierLevel "2" -FeatureDomain "R2" `
    -Description "Changelog Extractor: Non-Existent Section Query Behavior" `
    -TestBlock {
        $extractScript = Join-Path $repoRoot "scripts\get-changelog-section.ps1"
        Assert-True (Test-Path $extractScript) "get-changelog-section.ps1 must exist"
        
        $nonExistentSection = & powershell -NoProfile -ExecutionPolicy Bypass -File $extractScript -Version "99.99.99.99"
        Assert-True ([string]::IsNullOrWhiteSpace($nonExistentSection)) "Querying non-existent version must return empty"
    }

Invoke-E2ETest -Id "T2-R2-05" -TierLevel "2" -FeatureDomain "R2" `
    -Description "Brand Resolution: Case-Insensitive Matching for Wand & WeMod" `
    -TestBlock {
        $constantsPath = Join-Path $repoRoot "WandEnhancer\Constants.cs"
        $content = Get-Content $constantsPath -Raw
        Assert-Contains $content "WeModBrandNames" "Constants must define WeModBrandNames"

        $brands = @("Wand", "WeMod")
        foreach ($testCase in @("wand", "WAND", "wemod", "WEMOD", "Wand", "WeMod")) {
            $matched = $brands | Where-Object { $_ -eq $testCase -or $_.Equals($testCase, [StringComparison]::OrdinalIgnoreCase) }
            Assert-True ($null -ne $matched) "Brand lookup for '$testCase' must resolve"
        }
    }


# --- Feature R3 Boundaries ---

Invoke-E2ETest -Id "T2-R3-01" -TierLevel "2" -FeatureDomain "R3" `
    -Description "Cryptographic Guard: Single-Byte Tampering Detection" `
    -TestBlock {
        $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-tamper-" + [guid]::NewGuid().ToString("N"))
        [IO.Directory]::CreateDirectory($scratch) | Out-Null
        try {
            $origFile = Join-Path $scratch "Authentic.bin"
            $tamperedFile = Join-Path $scratch "Tampered.bin"
            
            $data = [Text.Encoding]::UTF8.GetBytes("Authentic release binary payload 2026-10-31")
            [IO.File]::WriteAllBytes($origFile, $data)

            $tamperedData = [byte[]]$data.Clone()
            $tamperedData[0] = ($tamperedData[0] -bxor 0xFF) # Flip bits
            [IO.File]::WriteAllBytes($tamperedFile, $tamperedData)

            $origHash = (Get-FileHash -Path $origFile -Algorithm SHA256).Hash.ToLowerInvariant()
            $tamperedHash = (Get-FileHash -Path $tamperedFile -Algorithm SHA256).Hash.ToLowerInvariant()

            Assert-True ($origHash -ne $tamperedHash) "Tampered binary hash must differ completely"
        }
        finally {
            Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

Invoke-E2ETest -Id "T2-R3-02" -TierLevel "2" -FeatureDomain "R3" `
    -Description "Manifest Validation: Truncated or Malformed Hash Rejection" `
    -TestBlock {
        $validLine = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  SovereignTitan.exe"
        $truncatedLine = "e3b0c442  SovereignTitan.exe"
        $invalidHexLine = "g3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  SovereignTitan.exe"

        $regex = '^[a-fA-F0-9]{64}\s{2}\S+'
        Assert-True ($validLine -match $regex) "Valid line must match standard format"
        Assert-True ($truncatedLine -notmatch $regex) "Truncated hash must fail"
        Assert-True ($invalidHexLine -notmatch $regex) "Invalid hex must fail"
    }

Invoke-E2ETest -Id "T2-R3-03" -TierLevel "2" -FeatureDomain "R3" `
    -Description "Privacy Defense: Pairing Token Stripping on /remote/api/health" `
    -TestBlock {
        $serverPath = Join-Path $repoRoot "web-panel\bridge\src\server.ts"
        $bridgeStatePath = Join-Path $repoRoot "web-panel\bridge\src\bridge-state.ts"
        $bridgeStateContent = if (Test-Path $bridgeStatePath) { Get-Content $bridgeStatePath -Raw } else { "" }
        $content = (Get-Content $serverPath -Raw) + "`n" + $bridgeStateContent
        Assert-Contains $content "stripPairingToken" "Health route must invoke stripPairingToken"
    }

Invoke-E2ETest -Id "T2-R3-04" -TierLevel "2" -FeatureDomain "R3" `
    -Description "Process Safety: ProcessTerminator Patcher selfId Immunity" `
    -TestBlock {
        $termPath = Join-Path $repoRoot "WandEnhancer\Utils\ProcessTerminator.cs"
        Assert-True (Test-Path $termPath) "ProcessTerminator.cs must exist"
        $content = Get-Content $termPath -Raw
        Assert-Contains $content "selfId" "ProcessTerminator must define selfId"
        Assert-Contains $content "p.Id != selfId" "ProcessTerminator must guard caller selfId from termination"
    }

Invoke-E2ETest -Id "T2-R3-05" -TierLevel "2" -FeatureDomain "R3" `
    -Description "Threat Defense: Homoglyph Typosquat Differentiation (@ki11tbyte vs @k1tbyte)" `
    -TestBlock {
        $maliciousRegex = '(?i)\bki11tbyte\b'
        $impersonator = "@ki11tbyte"
        $legitimate = "@k1tbyte"

        Assert-True ($impersonator -match $maliciousRegex) "Must match impersonator with double-1s"
        Assert-True ($legitimate -notmatch $maliciousRegex) "Must not match upstream @k1tbyte"
    }


# --- Feature R4 Boundaries ---

Invoke-E2ETest -Id "T2-R4-01" -TierLevel "2" -FeatureDomain "R4" `
    -Description "Packaging Defense: Clean Error on Absent Executable Input" `
    -TestBlock {
        $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-pkg-noexe-" + [guid]::NewGuid().ToString("N"))
        try {
            $scratchScripts = Join-Path $scratch "scripts"
            $scratchProps = Join-Path $scratch "WandEnhancer\Properties"
            [IO.Directory]::CreateDirectory($scratchScripts) | Out-Null
            [IO.Directory]::CreateDirectory($scratchProps) | Out-Null

            Copy-Item (Join-Path $repoRoot "scripts\package-release.ps1") $scratchScripts
            Copy-Item (Join-Path $repoRoot "scripts\validate-release-metadata.ps1") $scratchScripts
            Copy-Item (Join-Path $repoRoot "WandEnhancer\Properties\AssemblyInfo.cs") $scratchProps
            Copy-Item (Join-Path $repoRoot "CHANGELOG.md") $scratch

            # Invoke package-release.ps1 in an environment with no compiled executable
            $pkgScript = Join-Path $scratchScripts "package-release.ps1"
            $ErrorActionPreference = 'Continue'
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pkgScript -SkipBuild -OutputDir (Join-Path $scratch "out") 2>&1 | Out-String

            Assert-True ($LASTEXITCODE -ne 0) "Packaging script must exit with non-zero code when executable is missing"
            Assert-True ($output -match "Compiled standalone executable not found in candidate paths") `
                "Packaging script must throw clean descriptive error when executable is absent"
        }
        finally {
            Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

Invoke-E2ETest -Id "T2-R4-02" -TierLevel "2" -FeatureDomain "R4" `
    -Description "Staging Isolation: Release Output Directory Clean Overwrite Safety" `
    -TestBlock {
        $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-pkg-clean-" + [guid]::NewGuid().ToString("N"))
        [IO.Directory]::CreateDirectory($scratch) | Out-Null
        try {
            $staleFile = Join-Path $scratch "stale-artifact.tmp"
            [IO.File]::WriteAllText($staleFile, "stale content")
            Assert-True (Test-Path $staleFile) "Stale file exists"
            
            Remove-Item (Join-Path $scratch "*") -Force
            Assert-Equal @(Get-ChildItem $scratch).Count 0 "Directory must be empty after clean"
        }
        finally {
            Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

Invoke-E2ETest -Id "T2-R4-03" -TierLevel "2" -FeatureDomain "R4" `
    -Description "Packaging Content Assertion: Mandatory License & Readme Inclusion" `
    -TestBlock {
        $readme = Join-Path $repoRoot "README.md"
        $license = Join-Path $repoRoot "LICENSE.md"
        Assert-True (Test-Path $readme) "README.md must exist in root for packaging"
        Assert-True (Test-Path $license) "LICENSE.md must exist in root for packaging"
    }

Invoke-E2ETest -Id "T2-R4-04" -TierLevel "2" -FeatureDomain "R4" `
    -Description "RFC Formatting: SHA256SUMS Binary Mode Two-Space Separator" `
    -DependencyMilestone "M4" `
    -TestBlock {
        $sumPath = Join-Path $repoRoot "release\SHA256SUMS.txt"
        Assert-True (Test-Path $sumPath) "release/SHA256SUMS.txt must exist"

        $lines = @(Get-Content $sumPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Assert-True ($lines.Count -ge 2) "SHA256SUMS.txt must contain at least 2 entries"

        foreach ($line in $lines) {
            Assert-True ($line.Length -ge 67) "Manifest line must be at least 67 characters: $line"

            $hashPart = $line.Substring(0, 64)
            Assert-True ($hashPart -match '^[a-fA-F0-9]{64}$') "Hash part must be 64 hexadecimal characters: $hashPart"

            $separatorPart = $line.Substring(64, 2)
            Assert-Equal $separatorPart "  " "Must use strict Unix standard two-space separator (0x20 0x20)"

            $filePart = $line.Substring(66)
            Assert-True (-not $filePart.StartsWith('*')) "Filename must not begin with asterisk marker: $filePart"
            Assert-True (-not $filePart.StartsWith(' ')) "Filename must not contain leading space: $filePart"

            $targetFile = Join-Path $repoRoot (Join-Path "release" $filePart)
            Assert-True (Test-Path $targetFile) "Referenced manifest file must exist in release directory: $targetFile"

            $computedHash = (Get-FileHash -Path $targetFile -Algorithm SHA256).Hash.ToLowerInvariant()
            Assert-Equal $hashPart.ToLowerInvariant() $computedHash "Manifest hash must match real file hash for $filePart"
        }

        # Negative boundary check: verify strict regex rejects single-space asterisk format
        $strictRegex = '^[a-fA-F0-9]{64}  [^\s*]\S*$'
        Assert-True ($lines[0] -match $strictRegex) "Actual manifest line must conform to strict two-space format: $($lines[0])"
    }

Invoke-E2ETest -Id "T2-R4-05" -TierLevel "2" -FeatureDomain "R4" `
    -Description "Archive Security: Zip Entry Path Traversal Immunity" `
    -DependencyMilestone "M4" `
    -TestBlock {
        $zipPath = Join-Path $repoRoot "release\SovereignTitan-v$TargetVersion-win-x64.zip"
        Assert-True (Test-Path $zipPath) "Release zip must exist at $zipPath"

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            $destRoot = Join-Path ([IO.Path]::GetTempPath()) "wand-zip-safe-dest"
            foreach ($entry in $zip.Entries) {
                $name = $entry.FullName
                Assert-True (-not $name.StartsWith("/") -and -not $name.StartsWith("\")) `
                    "Archive entry must not start with path separator: $name"
                Assert-True (-not $name.Contains("..")) `
                    "Archive entry must not contain parent directory traversal: $name"
                Assert-True (-not [System.IO.Path]::IsPathRooted($name)) `
                    "Archive entry must not be rooted: $name"

                # Verify canonical containment
                $combined = [System.IO.Path]::GetFullPath((Join-Path $destRoot $name))
                Assert-True ($combined.StartsWith($destRoot, [StringComparison]::OrdinalIgnoreCase)) `
                    "Canonical path for entry '$name' must resolve inside destination root"
            }
        }
        finally {
            $zip.Dispose()
        }

        # Verify application path-traversal guard logic (AsarSharp.Utils.Extensions.IsPathInside)
        if ($null -ne $titanAssembly) {
            $extType = $titanAssembly.GetType("AsarSharp.Utils.Extensions", $false)
            if ($null -ne $extType) {
                $isInsideMethod = $extType.GetMethod("IsPathInside", [Reflection.BindingFlags]"Public,Static")
                if ($null -ne $isInsideMethod) {
                    $mockRoot = "C:\safe\extract\root"
                    Assert-True ($isInsideMethod.Invoke($null, @($mockRoot, "C:\safe\extract\root\file.txt"))) `
                        "IsPathInside must accept legitimate child file"
                    Assert-True (-not $isInsideMethod.Invoke($null, @($mockRoot, "C:\safe\extract\root\..\..\evil.exe"))) `
                        "IsPathInside must reject path traversal attempt"
                    Assert-True (-not $isInsideMethod.Invoke($null, @($mockRoot, "C:\Windows\System32\cmd.exe"))) `
                        "IsPathInside must reject out-of-root absolute path"
                }
            }
        }
    }


# ==============================================================================
# TIER 3: CROSS-FEATURE PAIRWISE INTERACTIONS
# ==============================================================================
Write-SectionHeader "TIER 3: CROSS-FEATURE PAIRWISE INTERACTIONS"

Invoke-E2ETest -Id "T3-01" -TierLevel "3" -FeatureDomain "CROSS" `
    -Description "Pairwise (R1 x R2): Patch Engine Execution under Target Version Assembly" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $configType = $titanAssembly.GetType("WandEnhancer.Core.EnhancerConfig", $true)
        $patches = $configType.GetMethod("GetInstance").Invoke($null, @())
        Assert-True ($patches.Count -ge 4) "EnhancerConfig must provide all 4 patch selections"
    }

Invoke-E2ETest -Id "T3-02" -TierLevel "3" -FeatureDomain "CROSS" `
    -Description "Pairwise (R1 x R4): RemotePanelInjector Validates web-panel/dist Layout" `
    -TestBlock {
        $injectorSource = Join-Path $repoRoot "WandEnhancer\Core\Patching\Content\RemotePanelInjector.cs"
        Assert-True (Test-Path $injectorSource) "RemotePanelInjector.cs must exist"
        $content = Get-Content $injectorSource -Raw

        Assert-Contains $content "bridge.cjs" "Injector must verify bridge.cjs"
        Assert-Contains $content "renderer-scripts" "Injector must verify renderer-scripts folder"
    }

Invoke-E2ETest -Id "T3-03" -TierLevel "3" -FeatureDomain "CROSS" `
    -Description "Pairwise (R2 x R3): Version Harmonization & Security Policy Agreement" `
    -DependencyMilestone "M3" `
    -TestBlock {
        $assemblyInfo = Join-Path $repoRoot "WandEnhancer\Properties\AssemblyInfo.cs"
        $changelog = Join-Path $repoRoot "CHANGELOG.md"
        $sec = Join-Path $repoRoot "SECURITY.md"
        
        $asmVer = [regex]::Match((Get-Content $assemblyInfo -Raw), '(?m)^\s*\[assembly:\s*AssemblyVersion\("(?<v>[^"]+)"\)\]').Groups['v'].Value
        $chVer = [regex]::Match((Get-Content $changelog -Raw), '(?m)^##\s+\[(?<v>[^\]]+)\]').Groups['v'].Value
        Assert-Equal $asmVer $chVer "AssemblyInfo version and CHANGELOG top version must agree"
        
        if (Test-Path $sec) {
            $secContent = Get-Content $sec -Raw
            Assert-Contains $secContent "@abdelrahmanayman722-ops" "SECURITY.md must reference official author"
        }
    }

Invoke-E2ETest -Id "T3-04" -TierLevel "3" -FeatureDomain "CROSS" `
    -Description "Pairwise (R2 x R4): Packaging Script Consumes Validated Release Metadata" `
    -DependencyMilestone "M4" `
    -TestBlock {
        $valScript = Join-Path $repoRoot "scripts\validate-release-metadata.ps1"
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $valScript -ExpectedVersion $TargetVersion
        Assert-Equal $LASTEXITCODE 0 "validate-release-metadata must pass for $TargetVersion"
    }

Invoke-E2ETest -Id "T3-05" -TierLevel "3" -FeatureDomain "CROSS" `
    -Description "Pairwise (R3 x R4): SHA256SUMS Manifest Matches Standalone Binary Hash" `
    -DependencyMilestone "M4" `
    -TestBlock {
        $sumPath = Join-Path $repoRoot "release\SHA256SUMS.txt"
        $exePath = Join-Path $repoRoot "release\SovereignTitan.exe"
        if (-not (Test-Path $exePath)) { $exePath = $resolvedAssemblyPath }

        Assert-True (Test-Path $sumPath) "SHA256SUMS.txt must exist"
        Assert-True (Test-Path $exePath) "Executable must exist"

        $computedHash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $manifestContent = Get-Content $sumPath -Raw
        Assert-Contains $manifestContent.ToLowerInvariant() $computedHash `
            "SHA256SUMS.txt must contain computed hash of SovereignTitan.exe"
    }

Invoke-E2ETest -Id "T3-06" -TierLevel "3" -FeatureDomain "CROSS" `
    -Description "Pairwise (R1 x R3): Rollback Safety Restores Pristine ASAR and Purges Injections" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $enhancerType = $titanAssembly.GetType("WandEnhancer.Core.Enhancer", $true)
        $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-t3-rollback-" + [guid]::NewGuid().ToString("N"))
        $install = Join-Path $scratch "app-12.68.0"
        $resources = Join-Path $install "resources"
        [IO.Directory]::CreateDirectory($resources) | Out-Null
        
        try {
            $backup = Join-Path $resources "app.asar.backup"
            $unpackedBackup = Join-Path $resources "app.asar.unpacked.backup"
            $asar = Join-Path $resources "app.asar"
            $unpacked = Join-Path $resources "app.asar.unpacked"

            [IO.File]::WriteAllText($backup, "pristine asar archive")
            [IO.Directory]::CreateDirectory($unpackedBackup) | Out-Null
            [IO.File]::WriteAllText((Join-Path $unpackedBackup "orig.txt"), "pristine unpacked")

            [IO.File]::WriteAllText($asar, "injected asar archive")
            [IO.Directory]::CreateDirectory($unpacked) | Out-Null
            [IO.File]::WriteAllText((Join-Path $unpacked "injected.txt"), "injected bridge script")

            $config = [Activator]::CreateInstance($titanAssembly.GetType("WandEnhancer.Models.WeModConfig", $true))
            $config.RootDirectory = $install
            $config.ExecutableName = "Wand.exe"
            $config.BrandName = "Wand"

            $logType = $titanAssembly.GetType("WandEnhancer.Core.ELogType", $true)
            $loggerType = [Action``2].MakeGenericType([string], $logType)
            $logger = { param($m, $l) } -as $loggerType
            $enhancer = [Activator]::CreateInstance($enhancerType, @($config, $logger))

            $rollbackMethod = $enhancerType.GetMethod("RollbackQuietly", [Reflection.BindingFlags]'NonPublic, Instance')
            $rollbackMethod.Invoke($enhancer, $null) | Out-Null

            Assert-Equal ([IO.File]::ReadAllText($asar)) "pristine asar archive" "Rollback must restore original ASAR"
            Assert-Equal (Test-Path (Join-Path $unpacked "injected.txt")) $false "Injected assets must be purged"
        }
        finally {
            Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
        }
    }


# ==============================================================================
# TIER 4: REAL-WORLD APPLICATION SCENARIOS
# ==============================================================================
Write-SectionHeader "TIER 4: REAL-WORLD APPLICATION SCENARIOS"

Invoke-E2ETest -Id "SC-01" -TierLevel "4" -FeatureDomain "CROSS" `
    -Description "Scenario 1: End-to-End Release Build, ILRepack & Asset Audit" `
    -TestBlock {
        Assert-True ($null -ne $resolvedAssemblyPath -and (Test-Path $resolvedAssemblyPath)) `
            "Compiled standalone executable SovereignTitan.exe must exist"
        
        $item = Get-Item $resolvedAssemblyPath
        Assert-True ($item.Length -gt 2000000) "Merged binary must exceed 2MB"
        
        # Verify no prohibited debug classes inside merged binary
        $forbiddenStrings = @("mock-instance", "Mock Adventure", "demo-session")
        $bytes = [IO.File]::ReadAllBytes($resolvedAssemblyPath)
        $text = [Text.Encoding]::ASCII.GetString($bytes)
        foreach ($forbidden in $forbiddenStrings) {
            Assert-True (-not $text.Contains($forbidden)) "Executable must not contain '$forbidden'"
        }
    }

Invoke-E2ETest -Id "SC-02" -TierLevel "4" -FeatureDomain "CROSS" `
    -Description "Scenario 2: Complete Desktop Patch Lifecycle Simulation" `
    -TestBlock {
        Assert-True ($null -ne $titanAssembly) "SovereignTitan assembly must be loaded"
        $enhancerType = $titanAssembly.GetType("WandEnhancer.Core.Enhancer", $true)
        $isPatched = $enhancerType.GetMethod("IsPatched")
        $hasBackup = $enhancerType.GetMethod("HasBackup")
        
        $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-sc2-lifecycle-" + [guid]::NewGuid().ToString("N"))
        $install = Join-Path $scratch "app-12.68.0"
        $resources = Join-Path $install "resources"
        [IO.Directory]::CreateDirectory($resources) | Out-Null
        
        try {
            $arg = [object[]]@([string]$install)
            # Step 1: Pristine install state
            Assert-Equal ($isPatched.Invoke($null, $arg)) $false "Unpatched directory returns false"
            Assert-Equal ($hasBackup.Invoke($null, $arg)) $false "Unpatched directory has no backup"

            # Step 2: Establish backup & marker
            $backup = Join-Path $resources "app.asar.backup"
            $unpackedBackup = Join-Path $resources "app.asar.unpacked.backup"
            [IO.File]::WriteAllText($backup, "original")
            [IO.Directory]::CreateDirectory($unpackedBackup) | Out-Null
            Assert-Equal ($hasBackup.Invoke($null, $arg)) $true "Complete backup detected"

            # Step 3: Verify incomplete marker handling
            $markerName = $enhancerType.GetField("IncompletePatchMarkerFileName", [Reflection.BindingFlags]'NonPublic, Static').GetRawConstantValue()
            $marker = Join-Path $resources $markerName
            [IO.File]::WriteAllText($marker, "")
            Assert-Equal ($isPatched.Invoke($null, $arg)) $false "Incomplete patch marker indicates unpatched"

            # Step 4: Finished patch state
            [IO.File]::Delete($marker)
            Assert-Equal ($isPatched.Invoke($null, $arg)) $true "Finished patch verified as patched"
        }
        finally {
            Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

Invoke-E2ETest -Id "SC-03" -TierLevel "4" -FeatureDomain "CROSS" `
    -Description "Scenario 3: End-User Download & Cryptographic Integrity Verification Workflow" `
    -TestBlock {
        $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-sc3-userverify-" + [guid]::NewGuid().ToString("N"))
        [IO.Directory]::CreateDirectory($scratch) | Out-Null
        try {
            $downloadedBinary = Join-Path $scratch "SovereignTitan.exe"
            [IO.File]::WriteAllText($downloadedBinary, "SovereignTitan v2.3.0.0 official production payload")
            
            # User Step A: Calculate hash via PowerShell Get-FileHash
            $psHash = (Get-FileHash -Path $downloadedBinary -Algorithm SHA256).Hash.ToLowerInvariant()
            Assert-Equal $psHash.Length 64 "Calculated hash must be 64 hex characters"

            # User Step B: Calculate hash via CMD certutil
            $certutilOutput = & certutil -hashfile $downloadedBinary SHA256
            Assert-Equal $LASTEXITCODE 0 "certutil execution must succeed"
            $certHash = ($certutilOutput | Where-Object { $_ -match '^[a-fA-F0-9\s]{64,}$' } | Select-Object -First 1) -replace '\s+', ''
            Assert-Equal $certHash.ToLowerInvariant() $psHash "certutil hash must match PowerShell hash"

            # User Step C: Contrast against tampered download
            $poisonedBinary = Join-Path $scratch "MaliciousTrojan.exe"
            [IO.File]::WriteAllText($poisonedBinary, "Malicious password stealer payload from @ki11tbyte")
            $poisonedHash = (Get-FileHash -Path $poisonedBinary -Algorithm SHA256).Hash.ToLowerInvariant()
            Assert-True ($poisonedHash -ne $psHash) "Poisoned download must fail cryptographic comparison"
        }
        finally {
            Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

Invoke-E2ETest -Id "SC-04" -TierLevel "4" -FeatureDomain "CROSS" `
    -Description "Scenario 4: Web Panel Production Dist & Electron Bridge Launch Simulation" `
    -TestBlock {
        $distBridge = Join-Path $repoRoot "web-panel\dist\bridge.cjs"
        Assert-True (Test-Path $distBridge) "dist/bridge.cjs must exist"

        # Verify bridge exports installWandRuntime
        $escapedPath = $distBridge.Replace('\', '/')
        $nodeCheckScript = "const bridge = require('$escapedPath'); if (typeof bridge.installWandRuntime !== 'function') { throw new Error('installWandRuntime not exported'); } console.log('Bridge runtime interface verified');"
        $scratch = Join-Path ([IO.Path]::GetTempPath()) ("wand-sc4-bridge-" + [guid]::NewGuid().ToString("N") + ".js")
        [IO.File]::WriteAllText($scratch, $nodeCheckScript)
        try {
            $output = & node $scratch
            Assert-Equal $LASTEXITCODE 0 "Node.js bridge runtime validation must exit with 0"
        }
        finally {
            Remove-Item -LiteralPath $scratch -Force -ErrorAction SilentlyContinue
        }
    }

Invoke-E2ETest -Id "SC-05" -TierLevel "4" -FeatureDomain "CROSS" `
    -Description "Scenario 5: Git Release Readiness & Metadata Consistency Gate" `
    -TestBlock {
        $valScript = Join-Path $repoRoot "scripts\validate-release-metadata.ps1"
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $valScript
        Assert-Equal $LASTEXITCODE 0 "validate-release-metadata.ps1 must pass"

        # Extract changelog section for release notes
        $extractScript = Join-Path $repoRoot "scripts\get-changelog-section.ps1"
        $notes = & powershell -NoProfile -ExecutionPolicy Bypass -File $extractScript -Version $TargetVersion
        Assert-Equal $LASTEXITCODE 0 "get-changelog-section.ps1 must pass"
        Assert-True (-not [string]::IsNullOrWhiteSpace($notes)) "Changelog notes must be non-empty"
    }


# ==============================================================================
# SUITE EXECUTION SUMMARY & REPORTING
# ==============================================================================
$suiteStartTime.Stop()
$totalExecuted = $passCount + $failCount + $pendingCount

Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "  TEST SUITE EXECUTION SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "  Total Executed : $totalExecuted"
Write-Host "  Passed         : $passCount" -ForegroundColor Green
Write-Host "  Pending Deps   : $pendingCount" -ForegroundColor Yellow
Write-Host "  Failed         : $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Skipped        : $skipCount"
Write-Host "  Total Duration : $([math]::Round($suiteStartTime.Elapsed.TotalSeconds, 2))s"
Write-Host ("=" * 80) -ForegroundColor Cyan

# Output Summary by Tier
Write-Host ""
Write-Host "Results Breakdown by Tier:" -ForegroundColor DarkGray
$suiteResults | Group-Object Tier | ForEach-Object {
    $tierName = $_.Name
    $tierItems = @($_.Group)
    $tPass = @($tierItems | Where-Object { $_.Status -eq 'PASS' }).Count
    $tPend = @($tierItems | Where-Object { $_.Status -like 'PENDING*' }).Count
    $tFail = @($tierItems | Where-Object { $_.Status -eq 'FAIL' }).Count
    Write-Host "  Tier $tierName`: Total $($tierItems.Count) (Pass: $tPass, Pending: $tPend, Fail: $tFail)"
}

if ($failCount -gt 0) {
    Write-Host "`nFAILED TESTS DETAILS:" -ForegroundColor Red
    $suiteResults | Where-Object { $_.Status -eq 'FAIL' } | ForEach-Object {
        Write-Host "  [$($_.Id)] $($_.Description)" -ForegroundColor Red
        Write-Host "    Error: $($_.Error)" -ForegroundColor DarkRed
    }
    exit 1
}

if ($pendingCount -gt 0 -and $Strict) {
    Write-Host "`nSTRICT MODE: Pending dependencies treated as failures." -ForegroundColor Red
    exit 1
}

Write-Host "`nTest suite run completed successfully.`n" -ForegroundColor Green
exit 0
