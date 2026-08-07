param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$DeploymentMod = "DiegeticTravel - Lake Honrich Boat Test"
)

$ErrorActionPreference = "Stop"

if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
    throw "Close SkyrimSE before deploying the Lake Honrich boat test mod."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot "modules\boat-honrich\mod"
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Lake Honrich boat module was not found: $sourceRoot"
}

$expectedRelativePaths = @(
    "DiegeticTravelBoatHonrich.esp",
    "README-BoatHonrich.txt",
    "SEQ\DiegeticTravelBoatHonrich.seq",
    "Scripts\DNT_BoatParchmentFragment.pex",
    "Scripts\DNT_BoatParchmentPicker.pex",
    "Scripts\DNT_BoatTravelService.pex",
    "Scripts\Source\DNT_BoatParchmentFragment.psc",
    "Scripts\Source\DNT_BoatParchmentPicker.psc",
    "Scripts\Source\DNT_BoatTravelService.psc"
)

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

$ownershipMarker = Join-Path $targetRoot "DNT_BOAT_HONRICH_TEST_OWNED.txt"
if (Test-Path -LiteralPath $targetRoot) {
    if (-not (Test-Path -LiteralPath $ownershipMarker -PathType Leaf)) {
        $existingFiles = @(Get-ChildItem -LiteralPath $targetRoot -Recurse -File |
            ForEach-Object { $_.FullName.Substring($targetRoot.Length + 1) })
        $unexpected = @($existingFiles | Where-Object {
            $expectedRelativePaths -notcontains $_
        })
        $missing = @($expectedRelativePaths | Where-Object {
            $existingFiles -notcontains $_
        })
        if ($unexpected.Count -gt 0 -or $missing.Count -gt 0) {
            throw "Refusing to adopt a Lake Honrich folder whose file list does not exactly match the known test module."
        }
    }
} else {
    New-Item -ItemType Directory -Path $targetRoot | Out-Null
}
Set-Content -LiteralPath $ownershipMarker -Encoding UTF8 -Value @(
    "Owned local development mod for Diegetic Travel Lake Honrich boat tests."
    "It is not part of the LoreRim baseline and may be disabled independently."
)

foreach ($relativePath in $expectedRelativePaths) {
    $source = Join-Path $sourceRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required Lake Honrich runtime file is missing: $source"
    }
    $destination = [System.IO.Path]::GetFullPath((Join-Path $targetRoot $relativePath))
    $targetPrefix = $targetRoot.TrimEnd('\') + '\'
    if (-not $destination.StartsWith(
        $targetPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Unsafe Lake Honrich deployment path: $destination"
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force |
        Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash) {
        throw "Deployment hash mismatch: $relativePath"
    }
}

$allowedFiles = @($expectedRelativePaths + "DNT_BOAT_HONRICH_TEST_OWNED.txt")
$unexpected = @(Get-ChildItem -LiteralPath $targetRoot -Recurse -File |
    Where-Object {
        $relative = $_.FullName.Substring($targetRoot.Length + 1)
        $allowedFiles -notcontains $relative
    })
if ($unexpected.Count -gt 0) {
    throw "Owned test mod contains unexpected files: $($unexpected.FullName -join ', ')"
}

Write-Host "Deployed isolated Lake Honrich boat test mod: $targetRoot"
Write-Host "Verified runtime files: $($expectedRelativePaths.Count)"
Write-Host "Bundled artwork: none"
Write-Host "MO2 profile files were not changed; enable the mod and plugin in MO2."
