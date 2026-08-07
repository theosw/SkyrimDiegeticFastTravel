param(
    [string]$PackageName = "DiegeticTravelCarriageParchment-offline-candidate"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\carriage-parchment"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$packageRoot = Join-Path $buildRoot $PackageName
$distRoot = Join-Path $projectRoot "dist"
$archive = Join-Path $distRoot "$PackageName.zip"

$required = @(
    (Join-Path $modRoot "DiegeticTravelCarriageParchment.esp"),
    (Join-Path $modRoot "README-CarriageParchment.txt"),
    (Join-Path $modRoot "SEQ\DiegeticTravelCarriageParchment.seq"),
    (Join-Path $modRoot "Scripts\DNT_CarriageParchmentPicker.pex"),
    (Join-Path $modRoot "Scripts\DNT_CarriageParchmentFragment.pex"),
    (Join-Path $modRoot "Scripts\Source\DNT_CarriageParchmentPicker.psc"),
    (Join-Path $modRoot "Scripts\Source\DNT_CarriageParchmentFragment.psc")
)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
        (Get-Item -LiteralPath $path).Length -le 0) {
        throw "Required carriage parchment package input is missing: $path"
    }
}
if ((Get-Item -LiteralPath (Join-Path $modRoot `
    "SEQ\DiegeticTravelCarriageParchment.seq")).Length -ne 4) {
    throw "Carriage parchment SEQ must contain one 4-byte FormID."
}

$resolvedPackage = [IO.Path]::GetFullPath($packageRoot)
$resolvedBuild = [IO.Path]::GetFullPath($buildRoot)
if (-not $resolvedPackage.StartsWith(
    $resolvedBuild,
    [StringComparison]::OrdinalIgnoreCase
)) { throw "Refusing to clean package outside build." }
if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
Copy-Item -Path (Join-Path $modRoot "*") `
    -Destination $packageRoot -Recurse -Force

$forbidden = @(".png", ".jpg", ".jpeg", ".dds", ".svg", ".wav", ".xwm", ".fuz")
$assets = Get-ChildItem -LiteralPath $packageRoot -Recurse -File |
    Where-Object { $forbidden -contains $_.Extension.ToLowerInvariant() }
if ($assets) {
    throw "Carriage package unexpectedly contains artwork/audio: $($assets.FullName -join ', ')"
}

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
Compress-Archive -Path (Join-Path $packageRoot "*") `
    -DestinationPath $archive -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Host "Packaged carriage parchment candidate: $archive"
Write-Host "Bundled artwork/audio assets: 0"
Write-Host "SHA-256: $hash"
