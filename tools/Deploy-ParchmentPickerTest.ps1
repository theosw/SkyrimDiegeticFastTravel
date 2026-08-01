param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$DeploymentMod = "DiegeticTravel - Parchment Picker Test",
    [string]$ArtworkMod = "RUSTIC MAPS"
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

$obsoleteLocalArt = Join-Path $targetRoot "Interface\DiegeticTravel\CollegeTravelMap.png"
if (Test-Path -LiteralPath $obsoleteLocalArt -PathType Leaf) {
    Remove-Item -LiteralPath $obsoleteLocalArt -Force
}

$dependencyHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $artDependency).Hash
Write-Host "Deployed isolated parchment-picker test mod: $targetRoot"
Write-Host "Artwork dependency: $artDependency"
Write-Host "Artwork SHA-256: $dependencyHash"
Write-Host "Bundled artwork: none"
Write-Host "MO2 profile files were not changed; enable the mod and plugin manually."
