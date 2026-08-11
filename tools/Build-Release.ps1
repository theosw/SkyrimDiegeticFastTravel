param(
    [string]$Graph = "C:\Users\Theo\Documents\LoreRim Info\travel-network\graph.json",
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [string]$PackageName = "DiegeticTravel-beta",
    [switch]$PackageOnly
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$releaseRoot = Join-Path $buildRoot "release"
$packageRoot = Join-Path $buildRoot $PackageName
$distRoot = Join-Path $projectRoot "dist"
$archive = Join-Path $distRoot "$PackageName.zip"
$supportedModules = @(
    "wizard-guides",
    "parchment-picker",
    "carriage-parchment",
    "boat-honrich",
    "boat-ilinalta",
    "boat-north-coast",
    "boat-solstheim"
)

function Invoke-BuildStep([string]$Name, [scriptblock]$Action) {
    Write-Host "[release-build] $Name"
    $global:LASTEXITCODE = 0
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Release build step failed: $Name (exit $LASTEXITCODE)"
    }
}

if (-not $PackageOnly) {
    Invoke-BuildStep "dependency lock" {
        & (Join-Path $PSScriptRoot "Audit-NativeDependencies.ps1") `
            -LoreRimRoot $LoreRimRoot
    }
    Invoke-BuildStep "native parchment menu" {
        & cmake --build --preset parchment-ae
    }
    Invoke-BuildStep "native tests" {
        & ctest --preset parchment-ae
    }

    $oldPythonPath = $env:PYTHONPATH
    try {
        $env:PYTHONPATH = Join-Path $projectRoot "src"
        Invoke-BuildStep "runtime manifests" {
            & python -m diegetic_travel compile `
                --graph $Graph `
                --endpoints (Join-Path $projectRoot "config\cfto_endpoints.json") `
                --sensors (Join-Path $projectRoot "config\hazard_sensors.json") `
                --out $buildRoot
        }
    } finally {
        $env:PYTHONPATH = $oldPythonPath
    }

    $compilers = @(
        "Compile-Papyrus.ps1",
        "Compile-WizardGuidesPapyrus.ps1",
        "Compile-ParchmentPickerPapyrus.ps1",
        "Compile-CarriageParchmentPapyrus.ps1",
        "Compile-BoatHonrichPapyrus.ps1",
        "Compile-BoatIlinaltaPapyrus.ps1",
        "Compile-BoatNorthCoastPapyrus.ps1",
        "Compile-BoatSolstheimPapyrus.ps1"
    )
    foreach ($compiler in $compilers) {
        Invoke-BuildStep $compiler {
            & (Join-Path $PSScriptRoot $compiler) -LoreRimRoot $LoreRimRoot
        }
    }
    Invoke-BuildStep "consolidated ESP-FE" {
        & (Join-Path $PSScriptRoot "Generate-ReleasePlugin.ps1") `
            -LoreRimRoot $LoreRimRoot -XEdit $XEdit
    }
}

$required = @(
    (Join-Path $releaseRoot "DiegeticTravel.esp"),
    (Join-Path $releaseRoot "SEQ\DiegeticTravel.seq"),
    (Join-Path $releaseRoot "SKSE\Plugins\DiegeticTravel\dialogue_runtime.json"),
    (Join-Path $buildRoot "runtime.json"),
    (Join-Path $projectRoot "THIRD_PARTY_NOTICES.txt")
)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required consolidated release input not found: $path"
    }
}

$resolvedPackage = [IO.Path]::GetFullPath($packageRoot)
$resolvedBuild = [IO.Path]::GetFullPath($buildRoot)
if (-not $resolvedPackage.StartsWith($resolvedBuild, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean package directory outside build: $resolvedPackage"
}
if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}
foreach ($directory in @(
    $packageRoot,
    (Join-Path $packageRoot "SEQ"),
    (Join-Path $packageRoot "Scripts"),
    (Join-Path $packageRoot "Scripts\Source"),
    (Join-Path $packageRoot "SKSE\Plugins"),
    (Join-Path $packageRoot "SKSE\Plugins\DiegeticTravel"),
    (Join-Path $packageRoot "textures\DiegeticTravel")
)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Copy-Item -LiteralPath (Join-Path $projectRoot "mod\README.txt") `
    -Destination (Join-Path $packageRoot "README.txt") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "THIRD_PARTY_NOTICES.txt") `
    -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $releaseRoot "DiegeticTravel.esp") `
    -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $releaseRoot "SEQ\DiegeticTravel.seq") `
    -Destination (Join-Path $packageRoot "SEQ") -Force
Copy-Item -LiteralPath (Join-Path $buildRoot "runtime.json") `
    -Destination (Join-Path $packageRoot "SKSE\Plugins\DiegeticTravel") -Force
Copy-Item -LiteralPath (Join-Path $releaseRoot `
        "SKSE\Plugins\DiegeticTravel\dialogue_runtime.json") `
    -Destination (Join-Path $packageRoot "SKSE\Plugins\DiegeticTravel") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "mod\SKSE\Plugins\DiegeticTravel\README.txt") `
    -Destination (Join-Path $packageRoot "SKSE\Plugins\DiegeticTravel") -Force

Copy-Item -Path (Join-Path $buildRoot "Scripts\*.pex") `
    -Destination (Join-Path $packageRoot "Scripts") -Force
Copy-Item -Path (Join-Path $projectRoot "mod\Scripts\Source\*.psc") `
    -Destination (Join-Path $packageRoot "Scripts\Source") -Force
foreach ($module in $supportedModules) {
    $moduleMod = Join-Path $projectRoot "modules\$module\mod"
    $compiled = Join-Path $moduleMod "Scripts"
    $source = Join-Path $compiled "Source"
    if (Test-Path -LiteralPath $compiled) {
        Copy-Item -Path (Join-Path $compiled "*.pex") `
            -Destination (Join-Path $packageRoot "Scripts") -Force
    }
    if (Test-Path -LiteralPath $source) {
        Copy-Item -Path (Join-Path $source "*.psc") `
            -Destination (Join-Path $packageRoot "Scripts\Source") -Force
    }
}

$parchmentMod = Join-Path $projectRoot "modules\parchment-picker\mod"
Copy-Item -LiteralPath (Join-Path $parchmentMod "SKSE\Plugins\DNTParchmentPicker.dll") `
    -Destination (Join-Path $packageRoot "SKSE\Plugins") -Force
Copy-Item -LiteralPath (Join-Path $parchmentMod "SKSE\Plugins\DiegeticTravel\travel_catalog.tsv") `
    -Destination (Join-Path $packageRoot "SKSE\Plugins\DiegeticTravel") -Force
Copy-Item -Path (Join-Path $parchmentMod "textures\DiegeticTravel\*.dds") `
    -Destination (Join-Path $packageRoot "textures\DiegeticTravel") -Force

$manifestLines = Get-ChildItem -LiteralPath $packageRoot -Recurse -File |
    Sort-Object FullName |
    ForEach-Object {
        $relative = $_.FullName.Substring($packageRoot.Length + 1)
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        "$hash  $relative"
    }
[IO.File]::WriteAllLines(
    (Join-Path $packageRoot "PACKAGE-MANIFEST.txt"),
    $manifestLines,
    [Text.UTF8Encoding]::new($false)
)

Invoke-BuildStep "consolidated package audit" {
    & (Join-Path $PSScriptRoot "Audit-ReleasePackage.ps1") `
        -LoreRimRoot $LoreRimRoot -XEdit $XEdit -PackageRoot $packageRoot
}

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
if (Test-Path -LiteralPath $archive -PathType Leaf) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") `
    -DestinationPath $archive -CompressionLevel Optimal
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Host "Consolidated release package: $archive"
Write-Host "SHA-256: $archiveHash"
