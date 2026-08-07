param(
    [string]$Inkscape = "C:\Program Files\Inkscape\bin\inkscape.com",
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}
$markerSpecs = @(
    @{ Name = "shipwreck-marker"; Label = "Shipwreck" }
)
$requiredInputs = @($Inkscape, $Texconv)
foreach ($spec in $markerSpecs) {
    $requiredInputs += Join-Path $projectRoot `
        "assets\vanilla-interface\$($spec.Name).svg"
}
foreach ($required in $requiredInputs) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required vanilla-marker build input was not found: $required"
    }
}

$buildRoot = Join-Path $projectRoot "build\vanilla-parchment-markers"
$outputRoot = Join-Path $projectRoot `
    "modules\parchment-picker\mod\textures\DiegeticTravel"
foreach ($directory in @($buildRoot, $outputRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Add-Type -AssemblyName System.Drawing
foreach ($spec in $markerSpecs) {
    $sourceSvg = Join-Path $projectRoot `
        "assets\vanilla-interface\$($spec.Name).svg"
    $sourcePng = Join-Path $buildRoot "$($spec.Name).png"
    $output = Join-Path $outputRoot "$($spec.Name).dds"

    & $Inkscape $sourceSvg `
        --export-type=png `
        --export-filename=$sourcePng `
        --export-width=512 `
        --export-height=512 `
        --export-background-opacity=0
    if ($LASTEXITCODE -ne 0) {
        throw "Inkscape failed to render the vanilla $($spec.Label) marker."
    }

    $image = [System.Drawing.Image]::FromFile($sourcePng)
    try {
        if ($image.Width -ne 512 -or $image.Height -ne 512) {
            throw "$($spec.Label) marker must render at 512x512; found $($image.Width)x$($image.Height)."
        }
        $pixelFormat = [int]$image.PixelFormat
        $alphaFlag = [int][System.Drawing.Imaging.PixelFormat]::Alpha
        $premultipliedAlphaFlag = [int][System.Drawing.Imaging.PixelFormat]::PAlpha
        if (($pixelFormat -band $alphaFlag) -eq 0 -and
            ($pixelFormat -band $premultipliedAlphaFlag) -eq 0) {
            throw "$($spec.Label) marker must retain an alpha channel. Pixel format: $($image.PixelFormat)"
        }
    } finally {
        $image.Dispose()
    }

    & $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $sourcePng
    if ($LASTEXITCODE -ne 0) {
        throw "Texconv failed to encode the vanilla $($spec.Label) marker."
    }
    $converted = Get-ChildItem -LiteralPath $buildRoot -Filter `
        "$($spec.Name).dds" -File | Select-Object -First 1
    if (-not $converted) {
        throw "Texconv did not produce $($spec.Name).dds."
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
        Write-Host "$($spec.Label) marker is already byte-identical; keeping the existing DDS."
    }
    if (-not (Test-Path -LiteralPath $output -PathType Leaf) -or
        (Get-Item -LiteralPath $output).Length -le 0) {
        throw "Encoded $($spec.Label) marker is missing or empty: $output"
    }

    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
    Write-Host "Built Skyrim-derived $($spec.Label) marker: $output"
    Write-Host "Canvas: 512x512"
    Write-Host "Format: BC7_UNORM with alpha"
    Write-Host "SHA-256: $hash"
}
