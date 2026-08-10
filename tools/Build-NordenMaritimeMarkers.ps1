param(
    [string]$Inkscape = "C:\Program Files\Inkscape\bin\inkscape.com",
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) { $Texconv = Join-Path $projectRoot $Texconv }
$normalizer = Join-Path $PSScriptRoot "Normalize-TransparentMarker.py"
$buildRoot = Join-Path $projectRoot "build\norden-maritime-markers"
$outputRoot = Join-Path $projectRoot "modules\parchment-picker\mod\textures\DiegeticTravel"
$markers = @(
    @{ Name = "norden-shipwreck"; Source = Join-Path $projectRoot "assets\norden-interface\maritime-markers\norden-shipwreck.svg"; Hash = "01A0150DBCB32F06D87CAC48665DC4F159B2CD6F34A2D13D21FE66E0BEAD755F" },
    @{ Name = "norden-docks"; Source = Join-Path $projectRoot "assets\norden-interface\maritime-markers\norden-docks.svg"; Hash = "60F4A6FC3E73FA5F5C8E5D0AF318AE1C595A77E0D90BEB4D379A8E29FE591436" }
)

foreach ($required in @($Inkscape, $Texconv, $normalizer) + ($markers | ForEach-Object { $_.Source })) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required Norden maritime input was not found: $required" }
}
New-Item -ItemType Directory -Force -Path $buildRoot, $outputRoot | Out-Null

foreach ($marker in $markers) {
    if ((Get-FileHash -LiteralPath $marker.Source -Algorithm SHA256).Hash -ne $marker.Hash) {
        throw "Norden maritime source hash changed unexpectedly: $($marker.Source)"
    }
    $rendered = Join-Path $buildRoot "$($marker.Name)-rendered.png"
    $normalized = Join-Path $buildRoot "$($marker.Name).png"
    & $Inkscape $marker.Source --export-type=png --export-filename=$rendered --export-width=512 --export-background-opacity=0
    if ($LASTEXITCODE -ne 0) { throw "Inkscape failed for $($marker.Name)." }
    & python $normalizer --input $rendered --output $normalized --canvas 512 --max-width 416 --max-height 416 --normalize-alpha-max
    if ($LASTEXITCODE -ne 0) { throw "Normalization failed for $($marker.Name)." }
    & $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $normalized
    if ($LASTEXITCODE -ne 0) { throw "Texconv failed for $($marker.Name)." }
    $converted = Join-Path $buildRoot "$($marker.Name).dds"
    $output = Join-Path $outputRoot "$($marker.Name).dds"
    if (-not (Test-Path -LiteralPath $converted -PathType Leaf)) { throw "Missing converted DDS: $converted" }
    Copy-Item -LiteralPath $converted -Destination $output -Force
    Write-Host "Built Norden maritime marker: $output"
}
