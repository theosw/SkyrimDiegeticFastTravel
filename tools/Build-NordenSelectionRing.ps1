param(
    [string]$Inkscape = "C:\Program Files\Inkscape\bin\inkscape.com",
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}

$expectedHash = "A207F90E2A73263FC9AA71EF8E05AE89A37ED609CF1CA634CAB494DC0E59B921"
$sourcePath = Join-Path $projectRoot "assets\norden-interface\selection-ring\norden-roundtrip-selection-ring.svg"
$buildRoot = Join-Path $projectRoot "build\norden-selection-ring"
$outputRoot = Join-Path $projectRoot "modules\parchment-picker\mod\textures\DiegeticTravel"
$extractor = Join-Path $PSScriptRoot "Extract-OneWaySelectionRing.py"

foreach ($required in @($Inkscape, $Texconv, $sourcePath, $extractor)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Norden selection-ring input was not found: $required"
    }
}
if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne $expectedHash) {
    throw "Norden selection-ring source hash changed unexpectedly: $sourcePath"
}
New-Item -ItemType Directory -Force -Path $buildRoot, $outputRoot | Out-Null

$oneWaySource = Join-Path $buildRoot "norden-oneway-selection-ring.svg"
& python $extractor --input $sourcePath --output $oneWaySource
if ($LASTEXITCODE -ne 0) {
    throw "Failed to derive the one-way Norden selection ring."
}

foreach ($ring in @(
    @{ Name = "norden-roundtrip-selection-ring"; Source = $sourcePath; BoundsFrom = $null },
    @{ Name = "norden-oneway-selection-ring"; Source = $oneWaySource; BoundsFrom = (Join-Path $buildRoot "norden-roundtrip-selection-ring-rendered.png") }
)) {
    $name = $ring.Name
    $renderedPng = Join-Path $buildRoot "$name-rendered.png"
    $normalizedPng = Join-Path $buildRoot "$name.png"
    & $Inkscape $ring.Source `
        --export-type=png `
        --export-filename=$renderedPng `
        --export-width=512 `
        --export-background-opacity=0
    if ($LASTEXITCODE -ne 0) {
        throw "Inkscape failed to render the Norden selection ring: $name"
    }

    $normalizerArguments = @(
        (Join-Path $PSScriptRoot "Normalize-TransparentMarker.py"),
        "--input", $renderedPng,
        "--output", $normalizedPng,
        "--canvas", "512",
        "--max-width", "416",
        "--max-height", "416",
        "--normalize-alpha-max"
    )
    if ($ring.BoundsFrom) {
        $normalizerArguments += @("--bounds-from", $ring.BoundsFrom)
    }
    & python @normalizerArguments
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
