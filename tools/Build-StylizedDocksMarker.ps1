param(
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}
$sourcePng = Join-Path $projectRoot `
    "assets\user-authored\stylized-docks-marker.png"
$expectedSourceHash = "4CF9C724E4127748C23002470F45B348B60FEBF91DEEA52CC9AF94898E09FF93"
foreach ($required in @($Texconv, $sourcePng)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required stylized dock-marker build input was not found: $required"
    }
}
$sourceHash = (Get-FileHash -LiteralPath $sourcePng -Algorithm SHA256).Hash
if ($sourceHash -ne $expectedSourceHash) {
    throw "Stylized dock-marker source hash changed unexpectedly: $sourceHash"
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($sourcePng)
try {
    if ($image.Width -ne 512 -or $image.Height -ne 512) {
        throw "Stylized dock marker must be 512x512; found $($image.Width)x$($image.Height)."
    }
    $pixelFormat = [int]$image.PixelFormat
    $alphaFlag = [int][System.Drawing.Imaging.PixelFormat]::Alpha
    $premultipliedAlphaFlag = [int][System.Drawing.Imaging.PixelFormat]::PAlpha
    if (($pixelFormat -band $alphaFlag) -eq 0 -and
        ($pixelFormat -band $premultipliedAlphaFlag) -eq 0) {
        throw "Stylized dock marker must retain an alpha channel. Pixel format: $($image.PixelFormat)"
    }
} finally {
    $image.Dispose()
}

$buildRoot = Join-Path $projectRoot "build\stylized-docks-marker"
$outputRoot = Join-Path $projectRoot `
    "modules\parchment-picker\mod\textures\DiegeticTravel"
foreach ($directory in @($buildRoot, $outputRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$convertedDds = Join-Path $buildRoot "stylized-docks-marker.dds"
$outputDds = Join-Path $outputRoot "docks-marker.dds"
& $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $sourcePng
if ($LASTEXITCODE -ne 0) {
    throw "Texconv failed to encode the stylized dock marker."
}
$texconvOutput = Join-Path $buildRoot "stylized-docks-marker.dds"
if (-not (Test-Path -LiteralPath $texconvOutput -PathType Leaf)) {
    throw "Texconv did not produce stylized-docks-marker.dds."
}
Copy-Item -LiteralPath $texconvOutput -Destination $outputDds -Force
if ((Get-Item -LiteralPath $outputDds).Length -le 0) {
    throw "Encoded stylized dock marker is empty: $outputDds"
}

$outputHash = (Get-FileHash -LiteralPath $outputDds -Algorithm SHA256).Hash
Write-Host "Built AI-assisted, user-edited dock marker: $outputDds"
Write-Host "Canvas: 512x512"
Write-Host "Format: BC7_UNORM with alpha"
Write-Host "SHA-256: $outputHash"
