param(
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}

$removeBackground = Join-Path $PSScriptRoot "Remove-EdgeBackground.py"
$fadeDarkMatte = Join-Path $PSScriptRoot "Fade-DarkMatte.py"
$extractComponent = Join-Path $PSScriptRoot "Extract-TransparentComponent.py"
$normalizer = Join-Path $PSScriptRoot "Normalize-TransparentMarker.py"
$buildRoot = Join-Path $projectRoot "build\calibrated-selection-rings"
$outputRoot = Join-Path $projectRoot "modules\parchment-picker\mod\textures\DiegeticTravel"
$rings = @(
    @{
        Name = "thin-circle-selection-ring"
        Source = Join-Path $projectRoot "assets\diegetic-travel\selection-rings\thin-circle-select.png"
        Hash = "6B7092C5118E8EF3EFFDF886037F8EFF70DFE7A674F3A2150E3002CBA5FC86B9"
        Threshold = 48
        FadeDarkMatte = $true
    },
    @{
        Name = "parchment-thin-selection-ring"
        Source = Join-Path $projectRoot "assets\diegetic-travel\selection-rings\parchment-arrows-thin.png"
        Hash = "C1F5503629CE82ABEE5FCE53391ADE8371855040328FFF74D29F94C99FEDA6FA"
        Threshold = 48
        FadeDarkMatte = $false
    }
)

foreach ($required in @($Texconv, $removeBackground, $fadeDarkMatte, $extractComponent, $normalizer) + ($rings | ForEach-Object { $_.Source })) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required calibrated selection-ring input was not found: $required"
    }
}
New-Item -ItemType Directory -Force -Path $buildRoot, $outputRoot | Out-Null

foreach ($ring in $rings) {
    if ((Get-FileHash -LiteralPath $ring.Source -Algorithm SHA256).Hash -ne $ring.Hash) {
        throw "Calibrated selection-ring source hash changed unexpectedly: $($ring.Source)"
    }
    $transparent = Join-Path $buildRoot "$($ring.Name)-transparent.png"
    $normalized = Join-Path $buildRoot "$($ring.Name).png"
    & python $removeBackground --input $ring.Source --output $transparent --threshold $ring.Threshold
    if ($LASTEXITCODE -ne 0) { throw "Background removal failed for $($ring.Name)." }
    if ($ring.FadeDarkMatte) {
        $cleaned = Join-Path $buildRoot "$($ring.Name)-cleaned.png"
        & python $fadeDarkMatte --input $transparent --output $cleaned --low 48 --high 84
        if ($LASTEXITCODE -ne 0) { throw "Dark-matte cleanup failed for $($ring.Name)." }
        $transparent = $cleaned
    }
    & python $normalizer --input $transparent --output $normalized --canvas 512 --max-width 448 --max-height 448 --normalize-alpha-max
    if ($LASTEXITCODE -ne 0) { throw "Normalization failed for $($ring.Name)." }
    & $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $normalized
    if ($LASTEXITCODE -ne 0) { throw "Texconv failed for $($ring.Name)." }
    $converted = Join-Path $buildRoot "$($ring.Name).dds"
    $output = Join-Path $outputRoot "$($ring.Name).dds"
    if (-not (Test-Path -LiteralPath $converted -PathType Leaf)) { throw "Missing converted DDS: $converted" }
    Copy-Item -LiteralPath $converted -Destination $output -Force
    Write-Host "Built calibrated selection ring: $output"
}

$roundTripTransparent = Join-Path $buildRoot "parchment-thin-selection-ring-transparent.png"
$oneWayTransparent = Join-Path $buildRoot "parchment-thin-oneway-selection-ring-transparent.png"
$oneWayNormalized = Join-Path $buildRoot "parchment-thin-oneway-selection-ring.png"
& python $extractComponent --input $roundTripTransparent --output $oneWayTransparent --side right
if ($LASTEXITCODE -ne 0) { throw "One-way parchment-ring extraction failed." }
& python $normalizer --input $oneWayTransparent --output $oneWayNormalized --bounds-from $roundTripTransparent --canvas 512 --max-width 448 --max-height 448 --normalize-alpha-max
if ($LASTEXITCODE -ne 0) { throw "One-way parchment-ring normalization failed." }
& $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $oneWayNormalized
if ($LASTEXITCODE -ne 0) { throw "Texconv failed for parchment-thin-oneway-selection-ring." }
$oneWayConverted = Join-Path $buildRoot "parchment-thin-oneway-selection-ring.dds"
$oneWayOutput = Join-Path $outputRoot "parchment-thin-oneway-selection-ring.dds"
if (-not (Test-Path -LiteralPath $oneWayConverted -PathType Leaf)) { throw "Missing converted DDS: $oneWayConverted" }
Copy-Item -LiteralPath $oneWayConverted -Destination $oneWayOutput -Force
Write-Host "Built calibrated one-way selection ring: $oneWayOutput"

$thinRoundTripTransparent = Join-Path $buildRoot "thin-circle-selection-ring-cleaned.png"
$thinOneWayTransparent = Join-Path $buildRoot "thin-circle-oneway-selection-ring-transparent.png"
$thinOneWayNormalized = Join-Path $buildRoot "thin-circle-oneway-selection-ring.png"
& python $extractComponent --input $thinRoundTripTransparent --output $thinOneWayTransparent --side right
if ($LASTEXITCODE -ne 0) { throw "One-way thin-circle extraction failed." }
& python $normalizer --input $thinOneWayTransparent --output $thinOneWayNormalized --bounds-from $thinRoundTripTransparent --canvas 512 --max-width 448 --max-height 448 --normalize-alpha-max
if ($LASTEXITCODE -ne 0) { throw "One-way thin-circle normalization failed." }
& $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $thinOneWayNormalized
if ($LASTEXITCODE -ne 0) { throw "Texconv failed for thin-circle-oneway-selection-ring." }
$thinOneWayConverted = Join-Path $buildRoot "thin-circle-oneway-selection-ring.dds"
$thinOneWayOutput = Join-Path $outputRoot "thin-circle-oneway-selection-ring.dds"
if (-not (Test-Path -LiteralPath $thinOneWayConverted -PathType Leaf)) { throw "Missing converted DDS: $thinOneWayConverted" }
Copy-Item -LiteralPath $thinOneWayConverted -Destination $thinOneWayOutput -Force
Write-Host "Built calibrated one-way selection ring: $thinOneWayOutput"
