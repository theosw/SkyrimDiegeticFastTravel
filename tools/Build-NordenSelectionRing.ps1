param(
    [string]$Inkscape = "C:\Program Files\Inkscape\bin\inkscape.com",
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe",
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}

$expectedVectorHash = "A207F90E2A73263FC9AA71EF8E05AE89A37ED609CF1CA634CAB494DC0E59B921"
$expectedAuthoredRoundTripHash = "20DE02A206983E9292E3718A09EDC9C56A4E0371E8F39562A9A5F25F44D7120D"
$vectorSourcePath = Join-Path $projectRoot "assets\norden-interface\selection-ring\norden-roundtrip-selection-ring.svg"
$authoredRoundTripPath = Join-Path $projectRoot "tools\map-coordinate-calibrator\public\markers\norden-roundtrip-selection-ring-cropped.png"
$buildRoot = Join-Path $projectRoot "build\norden-selection-ring"
$outputRoot = Join-Path $projectRoot "modules\parchment-picker\mod\textures\DiegeticTravel"
$extractor = Join-Path $PSScriptRoot "Extract-OneWaySelectionRing.py"

foreach ($required in @($Inkscape, $Texconv, $vectorSourcePath, $authoredRoundTripPath, $extractor)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Norden selection-ring input was not found: $required"
    }
}
if ((Get-FileHash -LiteralPath $vectorSourcePath -Algorithm SHA256).Hash -ne $expectedVectorHash) {
    throw "Norden selection-ring vector source hash changed unexpectedly: $vectorSourcePath"
}
if ((Get-FileHash -LiteralPath $authoredRoundTripPath -Algorithm SHA256).Hash -ne $expectedAuthoredRoundTripHash) {
    throw "Authored Norden selection-ring raster changed unexpectedly: $authoredRoundTripPath"
}
New-Item -ItemType Directory -Force -Path $buildRoot, $outputRoot | Out-Null

$oneWaySource = Join-Path $buildRoot "norden-oneway-selection-ring.svg"
& $Python $extractor --input $vectorSourcePath --output $oneWaySource
if ($LASTEXITCODE -ne 0) {
    throw "Failed to derive the one-way Norden selection ring."
}

foreach ($ring in @(
    # The authored raster already contains 37 degrees of clockwise rotation.
    # Apply the remaining 68 degrees so the shipped ring's final orientation is 105 degrees.
    @{ Name = "norden-roundtrip-selection-ring"; Source = $authoredRoundTripPath; Kind = "png"; RotateClockwise = 68.0 },
    # The extracted vector has no authored rotation, so its one-way variant receives the full angle.
    @{ Name = "norden-oneway-selection-ring"; Source = $oneWaySource; Kind = "svg"; RotateClockwise = 105.0 }
)) {
    $name = $ring.Name
    $renderedPng = Join-Path $buildRoot "$name-rendered.png"
    $normalizedPng = Join-Path $buildRoot "$name.png"
    if ($ring.Kind -eq "svg") {
        & $Inkscape $ring.Source `
            --export-type=png `
            --export-filename=$renderedPng `
            --export-width=512 `
            --export-background-opacity=0
        if ($LASTEXITCODE -ne 0) {
            throw "Inkscape failed to render the Norden selection ring: $name"
        }
    } else {
        Copy-Item -LiteralPath $ring.Source -Destination $renderedPng -Force
    }

    $normalizerArguments = @(
        (Join-Path $PSScriptRoot "Normalize-TransparentMarker.py"),
        "--input", $renderedPng,
        "--output", $normalizedPng,
        "--canvas", "512",
        "--max-width", "416",
        "--max-height", "416",
        "--rotate-clockwise-degrees", $ring.RotateClockwise,
        "--normalize-alpha-max"
    )
    & $Python @normalizerArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Alpha normalization failed for the Norden selection ring: $name"
    }

    & $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $normalizedPng
    if ($LASTEXITCODE -ne 0) {
        throw "Texconv failed to encode the Norden selection ring: $name"
    }
    $convertedDds = Join-Path $buildRoot "$name.dds"
    $outputDds = Join-Path $outputRoot "$name.dds"
    if (-not (Test-Path -LiteralPath $convertedDds -PathType Leaf)) {
        throw "Texconv did not produce the Norden selection-ring DDS: $name"
    }
    Copy-Item -LiteralPath $convertedDds -Destination $outputDds -Force
    Write-Host "Built Norden selection ring: $outputDds"
}
