param(
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}

$sources = @(
    @{
        Name = "winterhold-marker"
        Path = Join-Path $projectRoot "assets\user-authored\winterhold-marker.png"
        Hash = "8A6730B5CE7429ED69EE85C55A7510D46B136DA3C5A2746729BD5B84AE1FCA82"
    },
    @{
        Name = "wizard-hat-marker"
        Path = Join-Path $projectRoot "assets\user-authored\wizard-hat-marker.png"
        Hash = "E82028A1CFECA69A804672E8B290682CDE92814B8AD4E0E027B8EBB74C3CA890"
    }
)

if (-not (Test-Path -LiteralPath $Texconv -PathType Leaf)) {
    throw "Required Texconv executable was not found: $Texconv"
}

Add-Type -AssemblyName System.Drawing
foreach ($source in $sources) {
    if (-not (Test-Path -LiteralPath $source.Path -PathType Leaf)) {
        throw "Required stylized wizard-marker source was not found: $($source.Path)"
    }
    $sourceHash = (Get-FileHash -LiteralPath $source.Path -Algorithm SHA256).Hash
    if ($sourceHash -ne $source.Hash) {
        throw "Stylized wizard-marker source hash changed unexpectedly: $($source.Path): $sourceHash"
    }

    $image = [System.Drawing.Image]::FromFile($source.Path)
    try {
        if ($image.Width -ne 512 -or $image.Height -ne 512) {
            throw "Stylized wizard marker must be 512x512; found $($image.Width)x$($image.Height): $($source.Path)"
        }
        $pixelFormat = [int]$image.PixelFormat
        $alphaFlag = [int][System.Drawing.Imaging.PixelFormat]::Alpha
        $premultipliedAlphaFlag = [int][System.Drawing.Imaging.PixelFormat]::PAlpha
        if (($pixelFormat -band $alphaFlag) -eq 0 -and
            ($pixelFormat -band $premultipliedAlphaFlag) -eq 0) {
            throw "Stylized wizard marker must retain an alpha channel: $($source.Path)"
        }
    } finally {
        $image.Dispose()
    }
}

$buildRoot = Join-Path $projectRoot "build\stylized-wizard-markers"
$outputRoot = Join-Path $projectRoot "modules\parchment-picker\mod\textures\DiegeticTravel"
foreach ($directory in @($buildRoot, $outputRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

foreach ($source in $sources) {
    & $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $source.Path
    if ($LASTEXITCODE -ne 0) {
        throw "Texconv failed to encode $($source.Name)."
    }
    $convertedDds = Join-Path $buildRoot "$($source.Name).dds"
    $outputDds = Join-Path $outputRoot "$($source.Name).dds"
    if (-not (Test-Path -LiteralPath $convertedDds -PathType Leaf)) {
        throw "Texconv did not produce $($source.Name).dds."
    }
    Copy-Item -LiteralPath $convertedDds -Destination $outputDds -Force
    if ((Get-Item -LiteralPath $outputDds).Length -le 0) {
        throw "Encoded stylized wizard marker is empty: $outputDds"
    }
    $outputHash = (Get-FileHash -LiteralPath $outputDds -Algorithm SHA256).Hash
    Write-Host "Built AI-assisted, user-directed wizard marker: $outputDds"
    Write-Host "Canvas: 512x512"
    Write-Host "Format: BC7_UNORM with alpha"
    Write-Host "SHA-256: $outputHash"
}
