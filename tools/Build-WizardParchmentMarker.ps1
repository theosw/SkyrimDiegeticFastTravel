param(
    [string]$Inkscape = "C:\Program Files\Inkscape\bin\inkscape.com",
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}
$sourceSvg = Join-Path $projectRoot `
    "assets\third-party\dragonborn-wheeler-reskin\apparition-travel.svg"
$expectedSourceHash = "CC4197AA9772BBFE2EC37D612EEE3EEA51EB4D2937439995776B5C7A923ECE5C"
foreach ($required in @($Inkscape, $Texconv, $sourceSvg)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required wizard-marker build input was not found: $required"
    }
}
$sourceHash = (Get-FileHash -LiteralPath $sourceSvg -Algorithm SHA256).Hash
if ($sourceHash -ne $expectedSourceHash) {
    throw "Wizard-marker source hash changed unexpectedly: $sourceHash"
}

$buildRoot = Join-Path $projectRoot "build\wizard-parchment-marker"
$outputRoot = Join-Path $projectRoot `
    "modules\parchment-picker\mod\textures\DiegeticTravel"
foreach ($directory in @($buildRoot, $outputRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$sourcePng = Join-Path $buildRoot "wizard-travel-marker.png"
$convertedDds = Join-Path $buildRoot "wizard-travel-marker.dds"
$outputDds = Join-Path $outputRoot "wizard-travel-marker.dds"

& $Inkscape $sourceSvg `
    --export-type=png `
    --export-filename=$sourcePng `
    --export-width=512 `
    --export-height=512 `
    --export-background-opacity=0
if ($LASTEXITCODE -ne 0) {
    throw "Inkscape failed to render the credited wizard-travel marker."
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($sourcePng)
try {
    if ($image.Width -ne 512 -or $image.Height -ne 512) {
        throw "Wizard marker must render at 512x512; found $($image.Width)x$($image.Height)."
    }
    $pixelFormat = [int]$image.PixelFormat
    $alphaFlag = [int][System.Drawing.Imaging.PixelFormat]::Alpha
    $premultipliedAlphaFlag = [int][System.Drawing.Imaging.PixelFormat]::PAlpha
    if (($pixelFormat -band $alphaFlag) -eq 0 -and
        ($pixelFormat -band $premultipliedAlphaFlag) -eq 0) {
        throw "Wizard marker must retain an alpha channel. Pixel format: $($image.PixelFormat)"
    }
} finally {
    $image.Dispose()
}

& $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $sourcePng
if ($LASTEXITCODE -ne 0) {
    throw "Texconv failed to encode the wizard-travel marker."
}
if (-not (Test-Path -LiteralPath $convertedDds -PathType Leaf)) {
    throw "Texconv did not produce wizard-travel-marker.dds."
}
Copy-Item -LiteralPath $convertedDds -Destination $outputDds -Force
if ((Get-Item -LiteralPath $outputDds).Length -le 0) {
    throw "Encoded wizard-travel marker is empty: $outputDds"
}

$outputHash = (Get-FileHash -LiteralPath $outputDds -Algorithm SHA256).Hash
Write-Host "Built credited Dragonborn Wheeler Reskin wizard marker: $outputDds"
Write-Host "Original asset: KWD_DBWR_ApparitionTravel.svg by borokoshow"
Write-Host "Canvas: 512x512"
Write-Host "Format: BC7_UNORM with alpha"
Write-Host "SHA-256: $outputHash"
