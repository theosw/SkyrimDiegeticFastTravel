param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [string]$PackageName = "DiegeticTravelBoatBaanMalur-offline-candidate",
    [switch]$PackageOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\boat-baan-malur"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$packageRoot = Join-Path $buildRoot $PackageName
$distRoot = Join-Path $projectRoot "dist"
$archive = Join-Path $distRoot "$PackageName.zip"

if (-not $PackageOnly) {
    & (Join-Path $PSScriptRoot "Compile-BoatBaanMalurPapyrus.ps1") `
        -LoreRimRoot $LoreRimRoot
    & (Join-Path $PSScriptRoot "Generate-BoatBaanMalur.ps1") `
        -LoreRimRoot $LoreRimRoot `
        -XEdit $XEdit `
        -SkipCompile
    & (Join-Path $PSScriptRoot "Audit-BoatBaanMalur.ps1") `
        -LoreRimRoot $LoreRimRoot `
        -XEdit $XEdit
}

$requiredInputs = @(
    (Join-Path $modRoot "DiegeticTravelBoatBaanMalur.esp"),
    (Join-Path $modRoot "README-BoatBaanMalur.txt"),
    (Join-Path $modRoot "SEQ\DiegeticTravelBoatBaanMalur.seq"),
    (Join-Path $modRoot "Scripts\DNT_BaanMalurBoatTravelService.pex"),
    (Join-Path $modRoot "Scripts\DNT_BaanMalurBoatParchmentPicker.pex"),
    (Join-Path $modRoot "Scripts\DNT_BaanMalurBoatParchmentFragment.pex"),
    (Join-Path $modRoot "Scripts\Source\DNT_BaanMalurBoatTravelService.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_BaanMalurBoatParchmentPicker.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_BaanMalurBoatParchmentFragment.psc")
)
foreach ($requiredInput in $requiredInputs) {
    if (-not (Test-Path -LiteralPath $requiredInput -PathType Leaf)) {
        throw "Required Baan Malur package input not found: $requiredInput"
    }
    if ((Get-Item -LiteralPath $requiredInput).Length -le 0) {
        throw "Baan Malur package input is empty: $requiredInput"
    }
}
if ((Get-Item -LiteralPath (Join-Path $modRoot `
    "SEQ\DiegeticTravelBoatBaanMalur.seq")).Length -ne 4) {
    throw "Baan Malur SEQ must contain exactly one 4-byte FormID."
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
    throw "Baan Malur package unexpectedly contains artwork/audio: $($bundledAssets.FullName -join ', ')"
}

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
if (Test-Path -LiteralPath $archive -PathType Leaf) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") `
    -DestinationPath $archive -CompressionLevel Optimal

$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Host "Packaged Baan Malur boat preview: $archive"
Write-Host "Bundled artwork/audio assets: 0"
Write-Host "SHA-256: $hash"
