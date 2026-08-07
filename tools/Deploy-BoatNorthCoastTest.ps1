param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$DeploymentMod = "DiegeticTravel - North Coast Boat Test"
)

$ErrorActionPreference = "Stop"

if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
    throw "Close SkyrimSE before deploying the North-coast boat test mod."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot "modules\boat-north-coast\mod"
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "North-coast boat module was not found: $sourceRoot"
}

$modsRoot = [System.IO.Path]::GetFullPath((Join-Path $LoreRimRoot "mods"))
if (-not (Test-Path -LiteralPath $modsRoot -PathType Container)) {
    throw "LoreRim mods directory was not found: $modsRoot"
}
$targetRoot = [System.IO.Path]::GetFullPath((Join-Path $modsRoot $DeploymentMod))
$modsPrefix = $modsRoot.TrimEnd('\') + '\'
if (-not $targetRoot.StartsWith(
    $modsPrefix,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to deploy outside LoreRim's mods directory: $targetRoot"
}

$ownershipMarker = Join-Path $targetRoot "DNT_BOAT_NORTH_COAST_TEST_OWNED.txt"
if (Test-Path -LiteralPath $targetRoot) {
    if (-not (Test-Path -LiteralPath $ownershipMarker -PathType Leaf)) {
        throw "Refusing to overwrite a mod not created by this helper: $targetRoot"
    }
} else {
    New-Item -ItemType Directory -Path $targetRoot | Out-Null
    Set-Content -LiteralPath $ownershipMarker -Encoding UTF8 -Value @(
        "Owned local development mod for Diegetic Travel North-coast boat tests."
        "It is not part of the LoreRim baseline and may be disabled independently."
    )
}

$expectedRelativePaths = @(
    "DiegeticTravelBoatNorthCoast.esp",
    "README-BoatNorthCoast.txt",
    "SEQ\DiegeticTravelBoatNorthCoast.seq",
    "Scripts\DNT_NorthCoastBoatParchmentFragment.pex",
    "Scripts\DNT_NorthCoastBoatParchmentPicker.pex",
    "Scripts\DNT_NorthCoastBoatTravelService.pex",
    "Scripts\Source\DNT_NorthCoastBoatParchmentFragment.psc",
    "Scripts\Source\DNT_NorthCoastBoatParchmentPicker.psc",
    "Scripts\Source\DNT_NorthCoastBoatTravelService.psc"
)
foreach ($relativePath in $expectedRelativePaths) {
    $source = Join-Path $sourceRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required North-coast runtime file is missing: $source"
    }
    $destination = [System.IO.Path]::GetFullPath(
        (Join-Path $targetRoot $relativePath)
    )
    $targetPrefix = $targetRoot.TrimEnd('\') + '\'
    if (-not $destination.StartsWith(
        $targetPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Unsafe North-coast deployment path: $destination"
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) `
        -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    $destinationHash = (
        Get-FileHash -LiteralPath $destination -Algorithm SHA256
    ).Hash
    if ($sourceHash -ne $destinationHash) {
        throw "Deployment hash mismatch: $relativePath"
    }
}

$allowedFiles = @(
    $expectedRelativePaths + "DNT_BOAT_NORTH_COAST_TEST_OWNED.txt"
)
$unexpected = Get-ChildItem -LiteralPath $targetRoot -Recurse -File |
    Where-Object {
        $relative = $_.FullName.Substring($targetRoot.Length + 1)
        $allowedFiles -notcontains $relative
    }
if ($unexpected) {
    throw "Owned test mod contains unexpected files: $($unexpected.FullName -join ', ')"
}

Write-Host "Deployed isolated North-coast boat test mod: $targetRoot"
Write-Host "Verified runtime files: $($expectedRelativePaths.Count)"
Write-Host "Bundled artwork: none"
Write-Host "MO2 profile files were not changed; enable the mod and plugin in MO2."

