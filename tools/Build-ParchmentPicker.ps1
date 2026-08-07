param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$PackageName = "DiegeticTravelParchmentPicker-offline-candidate",
    [switch]$PackageOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\parchment-picker"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$packageRoot = Join-Path $buildRoot $PackageName
$distRoot = Join-Path $projectRoot "dist"
$archive = Join-Path $distRoot "$PackageName.zip"
$nordenMarkerNames = @(
    "norden-town.dds",
    "norden-settlement.dds",
    "norden-farm.dds",
    "norden-wood-mill.dds",
    "norden-mine.dds",
    "norden-riften-capital.dds",
    "norden-windhelm-capital.dds",
    "norden-whiterun-capital.dds",
    "norden-solitude-capital.dds",
    "norden-markarth-capital.dds",
    "norden-winterhold-capital.dds",
    "norden-morthal-capital.dds",
    "norden-falkreath-capital.dds",
    "norden-dawnstar-capital.dds"
)

if (-not $PackageOnly) {
    & (Join-Path $PSScriptRoot "Build-VanillaParchmentMarkers.ps1")
    & (Join-Path $PSScriptRoot "Build-StylizedDocksMarker.ps1")
    & (Join-Path $PSScriptRoot "Build-StylizedShipMarker.ps1")
    & (Join-Path $PSScriptRoot "Build-VanillaHoldCapitalMarkers.ps1")
    & (Join-Path $PSScriptRoot "Build-CarriageParchmentMarkers.ps1")
    & (Join-Path $PSScriptRoot "Build-NordenCarriageMarkers.ps1")
    foreach ($obsoleteWizardMarker in @("winterhold-marker.dds", "wizard-hat-marker.dds")) {
        $obsoleteWizardMarkerPath = Join-Path $modRoot "textures\DiegeticTravel\$obsoleteWizardMarker"
        if (Test-Path -LiteralPath $obsoleteWizardMarkerPath -PathType Leaf) {
            Remove-Item -LiteralPath $obsoleteWizardMarkerPath -Force
        }
    }
    & (Join-Path $PSScriptRoot "Audit-NativeDependencies.ps1") `
        -LoreRimRoot $LoreRimRoot
    & cmake --build --preset parchment-ae
    if ($LASTEXITCODE -ne 0) {
        throw "Native parchment-picker build failed."
    }
    & (Join-Path $PSScriptRoot "Compile-ParchmentPickerPapyrus.ps1") `
        -LoreRimRoot $LoreRimRoot
    & (Join-Path $PSScriptRoot "Generate-WizardParchmentAdapter.ps1") `
        -LoreRimRoot $LoreRimRoot `
        -SkipCompile
    & (Join-Path $PSScriptRoot "Audit-WizardParchmentAdapter.ps1") `
        -LoreRimRoot $LoreRimRoot
    & (Join-Path $PSScriptRoot "Audit-ParchmentPicker.ps1") `
        -RequireNativeBuild
    & ctest --preset parchment-ae
    if ($LASTEXITCODE -ne 0) {
        throw "Offline parchment-picker tests failed."
    }
}

$requiredInputs = @(
    (Join-Path $modRoot "DiegeticTravelWizardParchment.esp"),
    (Join-Path $modRoot "README-ParchmentPicker.txt"),
    (Join-Path $modRoot "SEQ\DiegeticTravelWizardParchment.seq"),
    (Join-Path $modRoot "Scripts\DNT_ParchmentNative.pex"),
    (Join-Path $modRoot "Scripts\DNT_WizardParchmentFragment.pex"),
    (Join-Path $modRoot "Scripts\DNT_WizardParchmentPicker.pex"),
    (Join-Path $modRoot "Scripts\Source\DNT_ParchmentNative.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_WizardParchmentFragment.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_WizardParchmentPicker.psc"),
    (Join-Path $modRoot "SKSE\Plugins\DNTParchmentPicker.dll"),
    (Join-Path $modRoot "textures\DiegeticTravel\docks-marker.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\shipwreck-marker.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\whiterun-dragonsreach.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\riften-mistveil-keep.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\solitude-blue-palace.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\windhelm-palace-of-the-kings.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\markarth-understone-keep.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\dawnstar-white-hall.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\morthal-highmoon-hall.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\winterhold-college.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\falkreath-jarl-longhouse.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\town-marker.dds"),
    (Join-Path $projectRoot "THIRD_PARTY_NOTICES.txt")
)
$requiredInputs += $nordenMarkerNames | ForEach-Object {
    Join-Path $modRoot "textures\DiegeticTravel\$_"
}
foreach ($requiredInput in $requiredInputs) {
    if (-not (Test-Path -LiteralPath $requiredInput -PathType Leaf)) {
        throw "Required parchment-picker package input not found: $requiredInput"
    }
}

$resolvedPackage = [System.IO.Path]::GetFullPath($packageRoot)
$resolvedBuild = [System.IO.Path]::GetFullPath($buildRoot)
if (-not $resolvedPackage.StartsWith(
    $resolvedBuild,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean package directory outside build: $resolvedPackage"
}
if (Test-Path -LiteralPath $resolvedPackage) {
    Remove-Item -LiteralPath $resolvedPackage -Recurse -Force
}

foreach ($directory in @(
    $packageRoot,
    (Join-Path $packageRoot "SEQ"),
    (Join-Path $packageRoot "Scripts"),
    (Join-Path $packageRoot "Scripts\Source"),
    (Join-Path $packageRoot "SKSE\Plugins"),
    (Join-Path $packageRoot "textures\DiegeticTravel")
)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Copy-Item -LiteralPath (Join-Path $modRoot "DiegeticTravelWizardParchment.esp") `
    -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $modRoot "README-ParchmentPicker.txt") `
    -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $modRoot "SEQ\DiegeticTravelWizardParchment.seq") `
    -Destination (Join-Path $packageRoot "SEQ") -Force
Copy-Item -Path (Join-Path $modRoot "Scripts\*.pex") `
    -Destination (Join-Path $packageRoot "Scripts") -Force
Copy-Item -Path (Join-Path $modRoot "Scripts\Source\*.psc") `
    -Destination (Join-Path $packageRoot "Scripts\Source") -Force
Copy-Item -LiteralPath (Join-Path $modRoot "SKSE\Plugins\DNTParchmentPicker.dll") `
    -Destination (Join-Path $packageRoot "SKSE\Plugins") -Force
Copy-Item -LiteralPath (Join-Path $modRoot "textures\DiegeticTravel\docks-marker.dds") `
    -Destination (Join-Path $packageRoot "textures\DiegeticTravel") -Force
Copy-Item -LiteralPath (Join-Path $modRoot "textures\DiegeticTravel\shipwreck-marker.dds") `
    -Destination (Join-Path $packageRoot "textures\DiegeticTravel") -Force
$packageMarkerNames = @(
    "whiterun-dragonsreach.dds",
    "riften-mistveil-keep.dds",
    "solitude-blue-palace.dds",
    "windhelm-palace-of-the-kings.dds",
    "markarth-understone-keep.dds",
    "dawnstar-white-hall.dds",
    "morthal-highmoon-hall.dds",
    "winterhold-college.dds",
    "falkreath-jarl-longhouse.dds",
    "town-marker.dds"
) + $nordenMarkerNames
foreach ($marker in $packageMarkerNames) {
    Copy-Item -LiteralPath (Join-Path $modRoot "textures\DiegeticTravel\$marker") `
        -Destination (Join-Path $packageRoot "textures\DiegeticTravel") -Force
}
Copy-Item -LiteralPath (Join-Path $projectRoot "THIRD_PARTY_NOTICES.txt") `
    -Destination $packageRoot -Force

$forbiddenExtensions = @(".png", ".jpg", ".jpeg", ".dds", ".svg", ".wav", ".xwm", ".fuz")
$bundledAssets = Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object {
    $forbiddenExtensions -contains $_.Extension.ToLowerInvariant()
}
$expectedAssets = @(
    "textures\DiegeticTravel\docks-marker.dds",
    "textures\DiegeticTravel\shipwreck-marker.dds",
    "textures\DiegeticTravel\whiterun-dragonsreach.dds",
    "textures\DiegeticTravel\riften-mistveil-keep.dds",
    "textures\DiegeticTravel\solitude-blue-palace.dds",
    "textures\DiegeticTravel\windhelm-palace-of-the-kings.dds",
    "textures\DiegeticTravel\markarth-understone-keep.dds",
    "textures\DiegeticTravel\dawnstar-white-hall.dds",
    "textures\DiegeticTravel\morthal-highmoon-hall.dds",
    "textures\DiegeticTravel\winterhold-college.dds",
    "textures\DiegeticTravel\falkreath-jarl-longhouse.dds",
    "textures\DiegeticTravel\town-marker.dds"
)
$expectedAssets += $nordenMarkerNames | ForEach-Object {
    "textures\DiegeticTravel\$_"
}
$unexpectedAssets = @($bundledAssets | Where-Object {
    $expectedAssets -notcontains $_.FullName.Substring($packageRoot.Length + 1)
})
if ($unexpectedAssets.Count -gt 0 -or $bundledAssets.Count -ne $expectedAssets.Count) {
    throw "Package contains an unexpected artwork/audio set: $($bundledAssets.FullName -join ', ')"
}

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
if (Test-Path -LiteralPath $archive -PathType Leaf) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") `
    -DestinationPath $archive -CompressionLevel Optimal

$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Host "Packaged parchment-picker candidate: $archive"
Write-Host "Bundled artwork: 2 user-authored/edited marker assets, 10 Skyrim-derived map markers, and 14 authorized Norden map markers"
Write-Host "SHA-256: $hash"
