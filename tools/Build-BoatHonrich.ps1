param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [string]$PackageName = "DiegeticTravelBoatHonrich-offline-candidate",
    [switch]$PackageOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\boat-honrich"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$packageRoot = Join-Path $buildRoot $PackageName
$distRoot = Join-Path $projectRoot "dist"
$archive = Join-Path $distRoot "$PackageName.zip"

if (-not $PackageOnly) {
    & (Join-Path $PSScriptRoot "Compile-BoatHonrichPapyrus.ps1") `
        -LoreRimRoot $LoreRimRoot
    & (Join-Path $PSScriptRoot "Generate-BoatHonrich.ps1") `
        -LoreRimRoot $LoreRimRoot `
        -XEdit $XEdit `
        -SkipCompile
    & (Join-Path $PSScriptRoot "Audit-BoatHonrich.ps1") `
        -LoreRimRoot $LoreRimRoot `
        -XEdit $XEdit
    & (Join-Path $PSScriptRoot "Audit-BoatHonrichVoiceAssets.ps1") `
        -LoreRimRoot $LoreRimRoot `
        -XEdit $XEdit
}

$requiredInputs = @(
    (Join-Path $modRoot "DiegeticTravelBoatHonrich.esp"),
    (Join-Path $modRoot "README-BoatHonrich.txt"),
    (Join-Path $modRoot "SEQ\DiegeticTravelBoatHonrich.seq"),
    (Join-Path $modRoot "Scripts\DNT_BoatTravelService.pex"),
    (Join-Path $modRoot "Scripts\DNT_BoatParchmentPicker.pex"),
    (Join-Path $modRoot "Scripts\DNT_BoatParchmentFragment.pex"),
    (Join-Path $modRoot "Scripts\Source\DNT_BoatTravelService.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_BoatParchmentPicker.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_BoatParchmentFragment.psc")
)
foreach ($requiredInput in $requiredInputs) {
    if (-not (Test-Path -LiteralPath $requiredInput -PathType Leaf)) {
        throw "Required Lake Honrich package input not found: $requiredInput"
    }
    if ((Get-Item -LiteralPath $requiredInput).Length -le 0) {
        throw "Lake Honrich package input is empty: $requiredInput"
    }
}
if ((Get-Item -LiteralPath (Join-Path $modRoot `
    "SEQ\DiegeticTravelBoatHonrich.seq")).Length -ne 4) {
    throw "Lake Honrich SEQ must contain exactly one 4-byte FormID."
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
Write-Host "Packaged Lake Honrich boat candidate: $archive"
Write-Host "Bundled artwork/audio assets: 0"
Write-Host "SHA-256: $hash"
