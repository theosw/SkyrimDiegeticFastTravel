param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$PackageName = "DiegeticTravelWizardGuides-phase1",
    [switch]$PackageOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\wizard-guides"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$packageRoot = Join-Path $buildRoot $PackageName
$distRoot = Join-Path $projectRoot "dist"
$archive = Join-Path $distRoot "$PackageName.zip"

if (-not $PackageOnly) {
    & (Join-Path $PSScriptRoot "Compile-WizardGuidesPapyrus.ps1") `
        -LoreRimRoot $LoreRimRoot
}

$requiredInputs = @(
    (Join-Path $modRoot "DiegeticTravelWizardGuides.esp"),
    (Join-Path $modRoot "SEQ\DiegeticTravelWizardGuides.seq"),
    (Join-Path $modRoot "Scripts\DNT_WizardTravelService.pex"),
    (Join-Path $modRoot "Scripts\DNT_WizardTravelFragment.pex"),
    (Join-Path $modRoot "Scripts\Source\DNT_WizardTravelService.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_WizardTravelFragment.psc")
)
foreach ($requiredInput in $requiredInputs) {
    if (-not (Test-Path -LiteralPath $requiredInput -PathType Leaf)) {
        throw "Required wizard-guide package input not found: $requiredInput"
    }
}

if (Test-Path -LiteralPath $packageRoot) {
    $resolvedPackage = [System.IO.Path]::GetFullPath($packageRoot)
    $resolvedBuild = [System.IO.Path]::GetFullPath($buildRoot)
    if (-not $resolvedPackage.StartsWith($resolvedBuild, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean package directory outside build: $resolvedPackage"
    }
    Remove-Item -LiteralPath $resolvedPackage -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
Copy-Item -Path (Join-Path $modRoot "*") -Destination $packageRoot -Recurse -Force

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
if (Test-Path -LiteralPath $archive -PathType Leaf) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $archive -CompressionLevel Optimal

$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Host "Packaged College-centred wizard-guide network: $archive"
Write-Host "SHA-256: $hash"
