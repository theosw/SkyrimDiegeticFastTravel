param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$DeploymentMod = "DiegeticTravel - Parchment Picker Test",
    [string]$ArtworkMod = "RUSTIC MAPS",
    [string]$WizardArtworkMod = "Skyrim Paper Map by Caro Tuts for FWMF"
)

$ErrorActionPreference = "Stop"

if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
    throw "Close SkyrimSE before deploying the parchment-picker test mod."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$archive = Join-Path $projectRoot "dist\DiegeticTravelParchmentPicker-offline-candidate.zip"

if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    throw "Build the parchment-picker candidate first: $archive"
}

$modsRoot = [System.IO.Path]::GetFullPath((Join-Path $LoreRimRoot "mods"))
if (-not (Test-Path -LiteralPath $modsRoot -PathType Container)) {
    throw "LoreRim mods directory was not found: $modsRoot"
}

$artDependency = Join-Path (Join-Path $modsRoot $ArtworkMod) `
    "textures\dungeons\imperial\battlemap01.dds"
if (-not (Test-Path -LiteralPath $artDependency -PathType Leaf)) {
    throw "Required loose battle-map texture was not found: $artDependency"
}
$wizardArtDependency = Join-Path (Join-Path $modsRoot $WizardArtworkMod) `
    "textures\terrain\tamriel\skyrim.dds"
if (-not (Test-Path -LiteralPath $wizardArtDependency -PathType Leaf)) {
    throw "Required loose wizard-map texture was not found: $wizardArtDependency"
}

$targetRoot = [System.IO.Path]::GetFullPath((Join-Path $modsRoot $DeploymentMod))
$modsPrefix = $modsRoot.TrimEnd('\') + '\'
if (-not $targetRoot.StartsWith($modsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to deploy outside LoreRim's mods directory: $targetRoot"
}

$ownershipMarker = Join-Path $targetRoot "DNT_PARCHMENT_TEST_OWNED.txt"
if (Test-Path -LiteralPath $targetRoot) {
    if (-not (Test-Path -LiteralPath $ownershipMarker -PathType Leaf)) {
        throw "Refusing to overwrite a mod not created by this helper: $targetRoot"
    }
} else {
    New-Item -ItemType Directory -Path $targetRoot | Out-Null
    Set-Content -LiteralPath $ownershipMarker -Encoding UTF8 -Value @(
        "Owned local development mod for Diegetic Travel parchment-picker tests."
        "It is not part of the LoreRim baseline and may be disabled independently."
    )
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
try {
    foreach ($entry in $zip.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) {
            continue
        }
        $destination = [System.IO.Path]::GetFullPath((Join-Path $targetRoot $entry.FullName))
        $targetPrefix = $targetRoot.TrimEnd('\') + '\'
        if (-not $destination.StartsWith($targetPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Unsafe path in parchment-picker archive: $($entry.FullName)"
        }
        $destinationDirectory = Split-Path -Parent $destination
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
    }
} finally {
    $zip.Dispose()
}

# Deployments are archive-based. Refuse to launch a test if the candidate ZIP
# was not rebuilt after the workspace DLL/PEX outputs changed.
$workspaceModRoot = Join-Path $projectRoot "modules\parchment-picker\mod"
$freshnessPairs = @(
    @{
        Source = Join-Path $workspaceModRoot "SKSE\Plugins\DNTParchmentPicker.dll"
        Target = Join-Path $targetRoot "SKSE\Plugins\DNTParchmentPicker.dll"
    },
    @{
        Source = Join-Path $workspaceModRoot "Scripts\DNT_ParchmentNative.pex"
        Target = Join-Path $targetRoot "Scripts\DNT_ParchmentNative.pex"
    },
    @{
        Source = Join-Path $workspaceModRoot "Scripts\DNT_TravelCompatibility.pex"
        Target = Join-Path $targetRoot "Scripts\DNT_TravelCompatibility.pex"
    },
    @{
        Source = Join-Path $workspaceModRoot "Scripts\DNT_WizardParchmentFragment.pex"
        Target = Join-Path $targetRoot "Scripts\DNT_WizardParchmentFragment.pex"
    },
    @{
        Source = Join-Path $workspaceModRoot "Scripts\DNT_WizardParchmentPicker.pex"
        Target = Join-Path $targetRoot "Scripts\DNT_WizardParchmentPicker.pex"
    }
)
foreach ($pair in $freshnessPairs) {
    $sourceHash = (Get-FileHash -LiteralPath $pair.Source -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $pair.Target -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        throw "Stale parchment candidate archive: rebuild before deploy. Workspace '$($pair.Source)' does not match archive '$($pair.Target)'."
    }
}

$obsoleteRuntimeFiles = @(
    (Join-Path $targetRoot "Interface\DiegeticTravel\CollegeTravelMap.png"),
    (Join-Path $targetRoot "textures\DiegeticTravel\boat-route-chalk-overlay.dds"),
    (Join-Path $targetRoot "textures\DiegeticTravel\wizard-travel-marker.dds"),
    (Join-Path $targetRoot "textures\DiegeticTravel\winterhold-marker.dds"),
    (Join-Path $targetRoot "textures\DiegeticTravel\wizard-hat-marker.dds")
)
foreach ($obsoleteRuntimeFile in $obsoleteRuntimeFiles) {
    if (Test-Path -LiteralPath $obsoleteRuntimeFile -PathType Leaf) {
        Remove-Item -LiteralPath $obsoleteRuntimeFile -Force
        Write-Host "Removed obsolete parchment-picker runtime file: $obsoleteRuntimeFile"
    }
}

$requiredRuntime = @(
    (Join-Path $targetRoot "SKSE\Plugins\DNTParchmentPicker.dll"),
    (Join-Path $targetRoot "Scripts\DNT_ParchmentNative.pex"),
    (Join-Path $targetRoot "Scripts\DNT_TravelCompatibility.pex"),
    (Join-Path $targetRoot "Scripts\DNT_WizardParchmentPicker.pex"),
    (Join-Path $targetRoot "textures\DiegeticTravel\docks-marker.dds"),
    (Join-Path $targetRoot "textures\DiegeticTravel\shipwreck-marker.dds"),
    (Join-Path $targetRoot "textures\DiegeticTravel\whiterun-dragonsreach.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\riften-mistveil-keep.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\solitude-blue-palace.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\windhelm-palace-of-the-kings.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\markarth-understone-keep.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\dawnstar-white-hall.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\morthal-highmoon-hall.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\winterhold-college.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\falkreath-jarl-longhouse.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\town-marker.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-town.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-settlement.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-farm.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-wood-mill.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-mine.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-riften-capital.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-windhelm-capital.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-whiterun-capital.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-solitude-capital.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-markarth-capital.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-winterhold-capital.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-morthal-capital.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-falkreath-capital.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-dawnstar-capital.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-shipwreck.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-docks.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\thin-circle-selection-ring.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\thin-circle-oneway-selection-ring.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\parchment-thin-selection-ring.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-roundtrip-selection-ring.dds")
    (Join-Path $targetRoot "textures\DiegeticTravel\norden-oneway-selection-ring.dds")
)
foreach ($runtimeFile in $requiredRuntime) {
    if (-not (Test-Path -LiteralPath $runtimeFile -PathType Leaf) -or
        (Get-Item -LiteralPath $runtimeFile).Length -le 0) {
        throw "Deployed parchment-picker runtime file is missing or empty: $runtimeFile"
    }
}

$dependencyHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $artDependency).Hash
$wizardDependencyHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $wizardArtDependency
).Hash
Write-Host "Deployed isolated parchment-picker test mod: $targetRoot"
Write-Host "Boat artwork dependency: $artDependency"
Write-Host "Boat artwork SHA-256: $dependencyHash"
Write-Host "Wizard/carriage artwork dependency: $wizardArtDependency"
Write-Host "Wizard/carriage artwork SHA-256: $wizardDependencyHash"
Write-Host "Route artwork: deferred; no chalk overlay is shipped for beta."
Write-Host "Bundled AI-assisted, user-edited idle marker: textures\DiegeticTravel\docks-marker.dds"
Write-Host "Bundled AI-assisted, user-edited selected marker: textures\DiegeticTravel\shipwreck-marker.dds"
Write-Host "Bundled Skyrim-derived fallback markers: 9 hold-capital and 1 town DDS texture"
Write-Host "Bundled authorized Norden formal-map assets: 9 capitals; town, settlement, farm, wood mill, and mine; plus round-trip and one-way selection rings"
Write-Host "MO2 profile files were not changed; enable the mod and plugin manually."
