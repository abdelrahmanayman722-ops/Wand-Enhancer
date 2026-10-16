param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [switch]$EnableUpdateNotifications
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$webPanelDir = Join-Path $repoRoot 'web-panel'
$solutionPath = Join-Path $repoRoot 'Wand-Enhancer.sln'

function Resolve-CommandPath {
    param([string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command not found in PATH: $Name"
    }

    return $command.Source
}

function Resolve-MSBuildPath {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $installationPath = & $vswhere -latest -prerelease -products '*' -requires Microsoft.Component.MSBuild -property installationPath
        if (-not [string]::IsNullOrWhiteSpace($installationPath)) {
            $msbuildPath = Join-Path $installationPath 'MSBuild\Current\Bin\MSBuild.exe'
            if (Test-Path $msbuildPath) {
                return $msbuildPath
            }
        }
    }

    $frameworkMsbuild = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe'
    if (Test-Path $frameworkMsbuild) {
        return $frameworkMsbuild
    }

    $cmd = Get-Command 'MSBuild.exe' -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    throw 'MSBuild was not found.'
}

function Invoke-Step {
    param(
        [string]$Label,
        [scriptblock]$Action
    )

    Write-Host "==> $Label" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed: $Label"
    }
}

function Resolve-TargetFrameworkRoot {
    # Some local targeting packs are installed but not registered with MSBuild.
    $root = Join-Path ${env:ProgramFiles(x86)} 'Reference Assemblies\Microsoft\Framework'
    $frameworkList = Join-Path $root '.NETFramework\v4.8\RedistList\FrameworkList.xml'
    if (Test-Path $frameworkList) {
        return $root
    }

    return $null
}

if (-not (Get-Command 'node' -ErrorAction SilentlyContinue)) {
    $adobeNode = 'C:\Program Files\Common Files\Adobe\Creative Cloud Libraries\libs'
    if (Test-Path (Join-Path $adobeNode 'node.exe')) {
        $env:PATH = "$adobeNode;$env:PATH"
    }
    $pwNode = 'C:\Users\pc\AppData\Roaming\ProjectLightningV5\resources\binaries\win\python\Lib\site-packages\playwright\driver'
    if (Test-Path (Join-Path $pwNode 'node.exe')) {
        $env:PATH = "$pwNode;$env:PATH"
    }
}

$pnpmCmd = Get-Command 'pnpm' -ErrorAction SilentlyContinue
$msbuild = Resolve-MSBuildPath
$targetFrameworkRoot = Resolve-TargetFrameworkRoot

$buildArgs = @('/m', "/p:Configuration=$Configuration", '/p:Platform=Any CPU')
if ($targetFrameworkRoot) {
    $buildArgs += "/p:TargetFrameworkRootPath=$targetFrameworkRoot"
}
if ($EnableUpdateNotifications) {
    $buildArgs += '/p:EnableUpdateNotifications=true'
}

if ($pnpmCmd) {
    $pnpm = $pnpmCmd.Source
    Invoke-Step 'Install web-panel dependencies' {
        & $pnpm --dir $webPanelDir install --frozen-lockfile
    }

    Invoke-Step 'Lint web-panel' {
        & $pnpm --dir $webPanelDir run lint
    }

    Invoke-Step 'Build web-panel' {
        & $pnpm --dir $webPanelDir run build
    }

    Invoke-Step 'Test web-panel' {
        & $pnpm --dir $webPanelDir exec vitest run
    }
} elseif ((Get-Command 'node' -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $webPanelDir 'node_modules'))) {
    $biomeCmd = Join-Path $webPanelDir 'node_modules\.bin\biome.CMD'
    $viteCmd = Join-Path $webPanelDir 'node_modules\.bin\vite.CMD'
    $vitestCmd = Join-Path $webPanelDir 'node_modules\.bin\vitest.CMD'
    $bridgeBuildScript = Join-Path $webPanelDir 'bridge\build.mjs'
    $verifyDistScript = Join-Path $webPanelDir 'scripts\verify-dist.mjs'

    Invoke-Step 'Lint web-panel' {
        Push-Location $webPanelDir
        try {
            & $biomeCmd check .
        }
        finally {
            Pop-Location
        }
    }

    Invoke-Step 'Build web-panel' {
        Push-Location $webPanelDir
        try {
            & $viteCmd build
            & node $bridgeBuildScript
            & node $verifyDistScript
        }
        finally {
            Pop-Location
        }
    }

    Invoke-Step 'Test web-panel' {
        Push-Location $webPanelDir
        try {
            & $vitestCmd run
        }
        finally {
            Pop-Location
        }
    }
} else {
    Write-Host "Notice: pnpm is not installed in PATH; using existing web-panel dist assets." -ForegroundColor Yellow
}

if (-not (Test-Path (Join-Path $repoRoot 'packages\ILRepack.2.0.41'))) {
    Invoke-Step 'Restore NuGet packages' {
        & $msbuild $solutionPath /m /t:Restore /p:RestorePackagesConfig=true
    }
} else {
    Write-Host "NuGet packages already present in packages/ directory." -ForegroundColor Cyan
}

Invoke-Step 'Build solution' {
    & $msbuild $solutionPath @buildArgs /t:Build
}

$assemblyPath = Join-Path $repoRoot "WandEnhancer\bin\$Configuration\SovereignTitan.exe"
if (-not (Test-Path $assemblyPath)) {
    $assemblyPath = Join-Path $repoRoot "WandEnhancer\bin\$Configuration\WandEnhancer.exe"
}
Invoke-Step 'Test desktop patch state and interop' {
    & (Join-Path $repoRoot 'scripts\test-desktop.ps1') `
        -AssemblyPath $assemblyPath `
        -ExpectUpdateNotifications:$EnableUpdateNotifications
}

Invoke-Step 'Test structural patch locators' {
    & (Join-Path $repoRoot 'scripts\test-patch-locators.ps1') -AssemblyPath $assemblyPath
}

$targetRootExe = Join-Path $repoRoot 'SovereignTitan.exe'
Copy-Item -Path $assemblyPath -Destination $targetRootExe -Force
Write-Host "Synchronized standalone executable to root: $targetRootExe" -ForegroundColor Cyan

Write-Host ''
Write-Host "Build completed successfully ($Configuration)." -ForegroundColor Green
