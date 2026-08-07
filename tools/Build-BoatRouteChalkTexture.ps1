param(
    [string]$SourcePng = "",
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SourcePng)) {
    $SourcePng = Join-Path $projectRoot `
        "assets\route-overlays\boat-route-chalk-overlay.png"
} elseif (-not [System.IO.Path]::IsPathRooted($SourcePng)) {
    $SourcePng = Join-Path $projectRoot $SourcePng
}
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}

foreach ($required in @($SourcePng, $Texconv)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required chalk-texture input was not found: $required"
    }
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($SourcePng)
try {
    if ($image.Width -ne 4096 -or $image.Height -ne 3016) {
        throw "Chalk overlay must remain exactly 4096x3016; found $($image.Width)x$($image.Height)."
    }
    $pixelFormat = [int]$image.PixelFormat
    $alphaFlag = [int][System.Drawing.Imaging.PixelFormat]::Alpha
    $premultipliedAlphaFlag = [int][System.Drawing.Imaging.PixelFormat]::PAlpha
    if (($pixelFormat -band $alphaFlag) -eq 0 -and
        ($pixelFormat -band $premultipliedAlphaFlag) -eq 0) {
        throw "Chalk overlay must retain an alpha channel. Pixel format: $($image.PixelFormat)"
    }
} finally {
    $image.Dispose()
}

$buildRoot = Join-Path $projectRoot "build\boat-route-chalk-texture"
$outputRoot = Join-Path $projectRoot `
    "modules\parchment-picker\mod\textures\DiegeticTravel"
$output = Join-Path $outputRoot "boat-route-chalk-overlay.dds"
foreach ($directory in @($buildRoot, $outputRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

& $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $SourcePng
if ($LASTEXITCODE -ne 0) {
    throw "Texconv failed to encode the chalk overlay."
}
$converted = Get-ChildItem -LiteralPath $buildRoot -Filter `
    "boat-route-chalk-overlay.dds" -File | Select-Object -First 1
if (-not $converted) {
    throw "Texconv did not produce boat-route-chalk-overlay.dds."
}
$copyRequired = $true
if (Test-Path -LiteralPath $output -PathType Leaf) {
    $copyRequired =
        (Get-FileHash -LiteralPath $converted.FullName -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
}
if ($copyRequired) {
    Copy-Item -LiteralPath $converted.FullName -Destination $output -Force
} else {
    Write-Host "Route overlay is already byte-identical; keeping the existing DDS."
}
if (-not (Test-Path -LiteralPath $output -PathType Leaf) -or
    (Get-Item -LiteralPath $output).Length -le 0) {
    throw "Encoded chalk overlay is missing or empty: $output"
}

$hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
Write-Host "Built user-authored boat route overlay: $output"
Write-Host "Canvas: 4096x3016"
Write-Host "Format: BC7_UNORM with alpha"
Write-Host "SHA-256: $hash"
