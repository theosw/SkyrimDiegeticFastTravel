param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$DeploymentMod = "houseCARL - DiegeticTravelWizardGuides"
)

$ErrorActionPreference = "Stop"

if (Get-Process -Name "SkyrimSE" -ErrorAction SilentlyContinue) {
    throw "Refusing to deploy the wizard map adapter while SkyrimSE is running."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot "modules\wizard-map-picker\mod"
$modsRoot = [System.IO.Path]::GetFullPath((Join-Path $LoreRimRoot "mods"))
$targetRoot = [System.IO.Path]::GetFullPath((Join-Path $modsRoot $DeploymentMod))
if (-not $targetRoot.StartsWith(
    ($modsRoot + [System.IO.Path]::DirectorySeparatorChar),
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to deploy outside the LoreRim mods directory: $targetRoot"
}
if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
    throw "Owned wizard-guide deployment directory does not exist: $targetRoot"
}

$relativeFiles = @(
    "DiegeticTravelWizardMap.esp",
    "README-WizardMapAdapter.txt",
    "SEQ\DiegeticTravelWizardMap.seq",
    "Scripts\DNT_WizardMapFragment.pex",
    "Scripts\DNT_WizardMapPicker.pex",
    "Scripts\Source\DNT_WizardMapFragment.psc",
    "Scripts\Source\DNT_WizardMapPicker.psc"
)

foreach ($relativeFile in $relativeFiles) {
    $sourcePath = Join-Path $sourceRoot $relativeFile
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required wizard map-adapter payload is missing: $sourcePath"
    }
    $targetPath = Join-Path $targetRoot $relativeFile
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) `
        | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        throw "Deployed payload hash mismatch: $relativeFile"
    }
    Write-Host "MATCH $relativeFile $sourceHash"
}

Write-Host "Deployed wizard map adapter to owned module: $targetRoot"
Write-Host "MO2 still needs DiegeticTravelWizardMap.esp enabled after its two masters."
