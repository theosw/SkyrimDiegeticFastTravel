param(
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}
$sourcePng = Join-Path $projectRoot `
    "assets\user-authored\stylized-ship-marker.png"
$expectedSourceHash = "4AB0C1D9E9CACDBA246B3FCCE898325ACBAE1B0B812A1D4E855F642933809811"
foreach ($required in @($Texconv, $sourcePng)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required stylized ship-marker build input was not found: $required"
    }
}
$sourceHash = (Get-FileHash -LiteralPath $sourcePng -Algorithm SHA256).Hash
if ($sourceHash -ne $expectedSourceHash) {
    throw "Stylized ship-marker source hash changed unexpectedly: $sourceHash"
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($sourcePng)
try {
    if ($image.Width -ne 512 -or $image.Height -ne 512) {
        throw "Stylized ship marker must be 512x512; found $($image.Width)x$($image.Height)."
    }
    $pixelFormat = [int]$image.PixelFormat
    $alphaFlag = [int][System.Drawing.Imaging.PixelFormat]::Alpha
    $premultipliedAlphaFlag = [int][System.Drawing.Imaging.PixelFormat]::PAlpha
    if (($pixelFormat -band $alphaFlag) -eq 0 -and
        ($pixelFormat -band $premultipliedAlphaFlag) -eq 0) {
        throw "Stylized ship marker must retain an alpha channel. Pixel format: $($image.PixelFormat)"
    }
} finally {
    $image.Dispose()
}

$buildRoot = Join-Path $projectRoot "build\stylized-ship-marker"
$outputRoot = Join-Path $projectRoot `
    "modules\parchment-picker\mod\textures\DiegeticTravel"
foreach ($directory in @($buildRoot, $outputRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$convertedDds = Join-Path $buildRoot "stylized-ship-marker.dds"
$outputDds = Join-Path $outputRoot "shipwreck-marker.dds"
& $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $sourcePng
if ($LASTEXITCODE -ne 0) {
    throw "Texconv failed to encode the stylized ship marker."
}
if (-not (Test-Path -LiteralPath $convertedDds -PathType Leaf)) {
    throw "Texconv did not produce stylized-ship-marker.dds."
}
Copy-Item -LiteralPath $convertedDds -Destination $outputDds -Force
if ((Get-Item -LiteralPath $outputDds).Length -le 0) {
    throw "Encoded stylized ship marker is empty: $outputDds"
}

$outputHash = (Get-FileHash -LiteralPath $outputDds -Algorithm SHA256).Hash
Write-Host "Built AI-assisted, user-edited ship marker: $outputDds"
Write-Host "Canvas: 512x512"
Write-Host "Format: BC7_UNORM with alpha"
Write-Host "SHA-256: $outputHash"
