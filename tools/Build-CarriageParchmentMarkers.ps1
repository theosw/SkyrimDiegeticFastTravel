param(
    [string]$Inkscape = "C:\Program Files\Inkscape\bin\inkscape.com",
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}

$sources = @(
    @{
        Name = "falkreath-jarl-longhouse"
        Path = "assets\vanilla-interface\hold-capitals\falkreath-jarl-longhouse.svg"
        Hash = "DE24E7685F32AB723445FC7500CCF197059C8BB61C1B775CF74474E809EF8EB6"
    },
    @{
        Name = "town-marker"
        Path = "assets\vanilla-interface\town-marker.svg"
        Hash = "D0FBFB934D362A65E32C84575A75D5C33C191C355C72EF5862D7B2B6C77804FA"
    }
)

foreach ($source in $sources) {
    $source.Path = Join-Path $projectRoot $source.Path
}
foreach ($required in @($Inkscape, $Texconv) + @($sources.Path)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required carriage marker input was not found: $required"
    }
}

$buildRoot = Join-Path $projectRoot "build\carriage-parchment-markers"
$outputRoot = Join-Path $projectRoot `
    "modules\parchment-picker\mod\textures\DiegeticTravel"
foreach ($directory in @($buildRoot, $outputRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

foreach ($source in $sources) {
    $sourceHash = (Get-FileHash -LiteralPath $source.Path -Algorithm SHA256).Hash
    if ($sourceHash -ne $source.Hash) {
        throw "Carriage marker source hash changed unexpectedly: $($source.Path): $sourceHash"
    }

    $renderedPng = Join-Path $buildRoot "$($source.Name)-rendered.png"
    $normalizedPng = Join-Path $buildRoot "$($source.Name).png"
    & $Inkscape $source.Path `
        --export-type=png `
        --export-filename=$renderedPng `
        --export-width=512 `
        --export-height=512 `
        --export-background-opacity=0
    if ($LASTEXITCODE -ne 0) {
        throw "Inkscape failed to render $($source.Name)."
    }

    & python (Join-Path $PSScriptRoot "Normalize-TransparentMarker.py") `
        --input $renderedPng `
        --output $normalizedPng `
        --canvas 512 `
        --max-width 416 `
        --max-height 416 `
        --normalize-alpha-max
    if ($LASTEXITCODE -ne 0) {
        throw "Alpha normalization failed for $($source.Name)."
    }

    & $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $normalizedPng
    if ($LASTEXITCODE -ne 0) {
        throw "Texconv failed to encode $($source.Name)."
    }
    $convertedDds = Join-Path $buildRoot "$($source.Name).dds"
    $outputDds = Join-Path $outputRoot "$($source.Name).dds"
    if (-not (Test-Path -LiteralPath $convertedDds -PathType Leaf)) {
        throw "Texconv did not produce $($source.Name).dds."
    }
    Copy-Item -LiteralPath $convertedDds -Destination $outputDds -Force
    Write-Host "Built Skyrim-derived carriage marker: $outputDds"
}
