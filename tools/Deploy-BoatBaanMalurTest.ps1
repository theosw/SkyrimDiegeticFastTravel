param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$DeploymentMod = "DiegeticTravel - Baan Malur Boat Test"
)

$ErrorActionPreference = "Stop"

if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
    throw "Close SkyrimSE before deploying the Baan Malur boat test mod."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot "modules\boat-baan-malur\mod"
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Baan Malur boat module was not found: $sourceRoot"
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

$ownershipMarker = Join-Path $targetRoot "DNT_BOAT_BAAN_MALUR_TEST_OWNED.txt"
if (Test-Path -LiteralPath $targetRoot) {
    if (-not (Test-Path -LiteralPath $ownershipMarker -PathType Leaf)) {
        throw "Refusing to overwrite a mod not created by this helper: $targetRoot"
    }
} else {
    New-Item -ItemType Directory -Path $targetRoot | Out-Null
    Set-Content -LiteralPath $ownershipMarker -Encoding UTF8 -Value @(
        "Owned local development mod for Diegetic Travel Baan Malur tests."
        "It is not part of the LoreRim baseline and may be disabled independently."
    )
}

$expectedRelativePaths = @(
    "DiegeticTravelBoatBaanMalur.esp",
    "README-BoatBaanMalur.txt",
    "SEQ\DiegeticTravelBoatBaanMalur.seq",
    "Scripts\DNT_BaanMalurBoatParchmentFragment.pex",
    "Scripts\DNT_BaanMalurBoatParchmentPicker.pex",
    "Scripts\DNT_BaanMalurBoatTravelService.pex",
    "Scripts\Source\DNT_BaanMalurBoatParchmentFragment.psc",
    "Scripts\Source\DNT_BaanMalurBoatParchmentPicker.psc",
    "Scripts\Source\DNT_BaanMalurBoatTravelService.psc"
)
foreach ($relativePath in $expectedRelativePaths) {
    $source = Join-Path $sourceRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required Baan Malur runtime file is missing: $source"
    }
    $destination = [System.IO.Path]::GetFullPath(
        (Join-Path $targetRoot $relativePath)
    )
    $targetPrefix = $targetRoot.TrimEnd('\') + '\'
    if (-not $destination.StartsWith(
        $targetPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Unsafe Baan Malur deployment path: $destination"
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
    $expectedRelativePaths + "DNT_BOAT_BAAN_MALUR_TEST_OWNED.txt"
)
$unexpected = Get-ChildItem -LiteralPath $targetRoot -Recurse -File |
    Where-Object {
        $relative = $_.FullName.Substring($targetRoot.Length + 1)
        $allowedFiles -notcontains $relative
    }
if ($unexpected) {
    throw "Owned test mod contains unexpected files: $($unexpected.FullName -join ', ')"
}

$bundledAssets = Get-ChildItem -LiteralPath $targetRoot -Recurse -File |
    Where-Object {
        $_.Extension.ToLowerInvariant() -in @(
            ".dds", ".png", ".jpg", ".jpeg", ".fuz", ".wav", ".xwm"
        )
    }
if ($bundledAssets) {
    throw "Baan Malur test mod unexpectedly bundles artwork/audio."
}

Write-Host "Deployed isolated Baan Malur boat test mod: $targetRoot"
Write-Host "Verified runtime files: $($expectedRelativePaths.Count)"
Write-Host "Bundled artwork/audio: none"
Write-Host "MO2 profile files were not changed; enable the mod and plugin in MO2."
