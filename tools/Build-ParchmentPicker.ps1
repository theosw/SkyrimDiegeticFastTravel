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

if (-not $PackageOnly) {
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
    (Join-Path $modRoot "SKSE\Plugins\DNTParchmentPicker.dll")
)
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
    (Join-Path $packageRoot "SKSE\Plugins")
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

$forbiddenExtensions = @(".png", ".jpg", ".jpeg", ".dds", ".svg", ".wav", ".xwm", ".fuz")
$bundledAssets = Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object {
    $forbiddenExtensions -contains $_.Extension.ToLowerInvariant()
}
if ($bundledAssets) {
    throw "Package unexpectedly contains artwork/audio: $($bundledAssets.FullName -join ', ')"
}

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
if (Test-Path -LiteralPath $archive -PathType Leaf) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") `
    -DestinationPath $archive -CompressionLevel Optimal

$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Host "Packaged parchment-picker candidate: $archive"
Write-Host "Bundled artwork/audio assets: 0"
Write-Host "SHA-256: $hash"
