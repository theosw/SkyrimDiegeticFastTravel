param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$PackageName = "DiegeticTravelWizardMapAdapter-alpha",
    [switch]$PackageOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\wizard-map-picker"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$packageRoot = Join-Path $buildRoot $PackageName
$distRoot = Join-Path $projectRoot "dist"
$archive = Join-Path $distRoot "$PackageName.zip"

if (-not $PackageOnly) {
    & (Join-Path $PSScriptRoot "Compile-WizardMapAdapterPapyrus.ps1") `
        -LoreRimRoot $LoreRimRoot
    & (Join-Path $PSScriptRoot "Generate-WizardMapAdapter.ps1") `
        -LoreRimRoot $LoreRimRoot `
        -SkipCompile
    & (Join-Path $PSScriptRoot "Audit-WizardMapAdapter.ps1") `
        -LoreRimRoot $LoreRimRoot
}

$requiredInputs = @(
    (Join-Path $modRoot "DiegeticTravelWizardMap.esp"),
    (Join-Path $modRoot "SEQ\DiegeticTravelWizardMap.seq"),
    (Join-Path $modRoot "Scripts\DNT_WizardMapPicker.pex"),
    (Join-Path $modRoot "Scripts\DNT_WizardMapFragment.pex"),
    (Join-Path $modRoot "Scripts\Source\DNT_WizardMapPicker.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_WizardMapFragment.psc"),
    (Join-Path $modRoot "README-WizardMapAdapter.txt")
)
foreach ($requiredInput in $requiredInputs) {
    if (-not (Test-Path -LiteralPath $requiredInput -PathType Leaf)) {
        throw "Required wizard map-adapter package input not found: $requiredInput"
    }
}
if ((Get-Item -LiteralPath (Join-Path $modRoot `
    "SEQ\DiegeticTravelWizardMap.seq")).Length -ne 4) {
    throw "Wizard map-adapter SEQ must contain exactly one 4-byte FormID."
}

if (Test-Path -LiteralPath $packageRoot) {
    $resolvedPackage = [System.IO.Path]::GetFullPath($packageRoot)
    $resolvedBuild = [System.IO.Path]::GetFullPath($buildRoot)
    if (-not $resolvedPackage.StartsWith(
        $resolvedBuild,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to clean package directory outside build: $resolvedPackage"
    }
    Remove-Item -LiteralPath $resolvedPackage -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
Copy-Item -Path (Join-Path $modRoot "*") `
    -Destination $packageRoot -Recurse -Force

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
if (Test-Path -LiteralPath $archive -PathType Leaf) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") `
    -DestinationPath $archive -CompressionLevel Optimal

$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Host "Packaged wizard map adapter: $archive"
Write-Host "SHA-256: $hash"
