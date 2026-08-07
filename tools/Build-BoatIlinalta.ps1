param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [string]$PackageName = "DiegeticTravelBoatIlinalta-offline-candidate",
    [switch]$PackageOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\boat-ilinalta"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$packageRoot = Join-Path $buildRoot $PackageName
$distRoot = Join-Path $projectRoot "dist"
$archive = Join-Path $distRoot "$PackageName.zip"

if (-not $PackageOnly) {
    & (Join-Path $PSScriptRoot "Compile-BoatIlinaltaPapyrus.ps1") `
        -LoreRimRoot $LoreRimRoot
    & (Join-Path $PSScriptRoot "Generate-BoatIlinalta.ps1") `
        -LoreRimRoot $LoreRimRoot `
        -XEdit $XEdit `
        -SkipCompile
    & (Join-Path $PSScriptRoot "Audit-BoatIlinalta.ps1") `
        -LoreRimRoot $LoreRimRoot `
        -XEdit $XEdit
    & (Join-Path $PSScriptRoot "Audit-BoatIlinaltaVoiceAssets.ps1") `
        -LoreRimRoot $LoreRimRoot `
        -XEdit $XEdit
}

$requiredInputs = @(
    (Join-Path $modRoot "DiegeticTravelBoatIlinalta.esp"),
    (Join-Path $modRoot "README-BoatIlinalta.txt"),
    (Join-Path $modRoot "SEQ\DiegeticTravelBoatIlinalta.seq"),
    (Join-Path $modRoot "Scripts\DNT_IlinaltaBoatTravelService.pex"),
    (Join-Path $modRoot "Scripts\DNT_IlinaltaBoatParchmentPicker.pex"),
    (Join-Path $modRoot "Scripts\DNT_IlinaltaBoatParchmentFragment.pex"),
    (Join-Path $modRoot "Scripts\Source\DNT_IlinaltaBoatTravelService.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_IlinaltaBoatParchmentPicker.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_IlinaltaBoatParchmentFragment.psc")
)
foreach ($requiredInput in $requiredInputs) {
    if (-not (Test-Path -LiteralPath $requiredInput -PathType Leaf)) {
        throw "Required Lake Ilinalta package input not found: $requiredInput"
    }
    if ((Get-Item -LiteralPath $requiredInput).Length -le 0) {
        throw "Lake Ilinalta package input is empty: $requiredInput"
    }
}
if ((Get-Item -LiteralPath (Join-Path $modRoot `
    "SEQ\DiegeticTravelBoatIlinalta.seq")).Length -ne 4) {
    throw "Lake Ilinalta SEQ must contain exactly one 4-byte FormID."
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

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
Copy-Item -Path (Join-Path $modRoot "*") `
    -Destination $packageRoot -Recurse -Force

$forbiddenExtensions = @(
    ".png", ".jpg", ".jpeg", ".dds", ".svg", ".wav", ".xwm", ".fuz"
)
$bundledAssets = Get-ChildItem -LiteralPath $packageRoot -Recurse -File |
    Where-Object { $forbiddenExtensions -contains $_.Extension.ToLowerInvariant() }
if ($bundledAssets) {
    throw "Boat package unexpectedly contains artwork/audio: $($bundledAssets.FullName -join ', ')"
}

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
if (Test-Path -LiteralPath $archive -PathType Leaf) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") `
    -DestinationPath $archive -CompressionLevel Optimal

$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Host "Packaged Lake Ilinalta boat candidate: $archive"
Write-Host "Bundled artwork/audio assets: 0"
Write-Host "SHA-256: $hash"
