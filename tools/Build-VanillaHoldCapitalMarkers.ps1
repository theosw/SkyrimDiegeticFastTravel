param(
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}

$sources = @(
    @{ Name = "whiterun-dragonsreach"; Hash = "9C33EAC8EDD12111949A31DC929F1A3972486A88832A19A3940A844AD60E085C" },
    @{ Name = "riften-mistveil-keep"; Hash = "00021E783C6FECB3AAA66DD4FA151C0701D5C2604965073D2D76D5CE9B133896" },
    @{ Name = "solitude-blue-palace"; Hash = "DAD00C87247472E14CC455CA1EC4B0798D567581D07059DCF0CCCFEA49582B69" },
    @{ Name = "windhelm-palace-of-the-kings"; Hash = "CDC86DABB8BE165FF20E800522EC37D034367A5C88AC69A55026C9A2F2C4A833" },
    @{ Name = "markarth-understone-keep"; Hash = "A9CCAE93B2FD345A768735F86235776B72D8E5B0E7E2189119A7F5884B47759B" },
    @{ Name = "dawnstar-white-hall"; Hash = "B12E312EF37A7642D2FA2430AC7324D18EE04EA373D7169699B7B85F81949234" },
    @{ Name = "morthal-highmoon-hall"; Hash = "6809EDA0794B761150EB361B259F0881453033EA578D9BA66DAEFBECF04770D6" }
    @{ Name = "winterhold-college"; Hash = "3B8D778710BBBAC6160EDE8491923C1542C0649556920D82AF501CC0BCFEBBE7" }
)

if (-not (Test-Path -LiteralPath $Texconv -PathType Leaf)) {
    throw "Required Texconv executable was not found: $Texconv"
}

$sourceRoot = Join-Path $projectRoot "assets\vanilla-interface\hold-capitals"
$buildRoot = Join-Path $projectRoot "build\vanilla-hold-capital-markers"
$outputRoot = Join-Path $projectRoot "modules\parchment-picker\mod\textures\DiegeticTravel"
foreach ($directory in @($buildRoot, $outputRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Add-Type -AssemblyName System.Drawing
foreach ($source in $sources) {
    $sourcePath = Join-Path $sourceRoot "$($source.Name).png"
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required vanilla hold-capital marker was not found: $sourcePath"
    }
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($sourceHash -ne $source.Hash) {
        throw "Vanilla hold-capital marker hash changed unexpectedly: $sourcePath`: $sourceHash"
    }

    $image = [System.Drawing.Image]::FromFile($sourcePath)
    try {
        if ($image.Width -ne 512 -or $image.Height -ne 512) {
            throw "Vanilla hold-capital marker must be 512x512; found $($image.Width)x$($image.Height): $sourcePath"
        }
        $pixelFormat = [int]$image.PixelFormat
        $alphaFlag = [int][System.Drawing.Imaging.PixelFormat]::Alpha
        $premultipliedAlphaFlag = [int][System.Drawing.Imaging.PixelFormat]::PAlpha
        if (($pixelFormat -band $alphaFlag) -eq 0 -and
            ($pixelFormat -band $premultipliedAlphaFlag) -eq 0) {
            throw "Vanilla hold-capital marker must retain an alpha channel: $sourcePath"
        }
    } finally {
        $image.Dispose()
    }

    $opaqueSourcePath = Join-Path $buildRoot "$($source.Name)-opaque.png"
    & python (Join-Path $PSScriptRoot "Normalize-TransparentMarker.py") `
        --input $sourcePath `
        --output $opaqueSourcePath `
        --canvas 512 `
        --max-width 416 `
        --max-height 416 `
        --normalize-alpha-max
    if ($LASTEXITCODE -ne 0) {
        throw "Alpha normalization failed for $($source.Name)."
    }

    & $Texconv -nologo -y -m 1 -f BC7_UNORM -o $buildRoot $opaqueSourcePath
    if ($LASTEXITCODE -ne 0) {
        throw "Texconv failed to encode $($source.Name)."
    }
    $convertedDds = Join-Path $buildRoot "$($source.Name)-opaque.dds"
    $outputDds = Join-Path $outputRoot "$($source.Name).dds"
    if (-not (Test-Path -LiteralPath $convertedDds -PathType Leaf)) {
        throw "Texconv did not produce $($source.Name).dds."
    }
    Copy-Item -LiteralPath $convertedDds -Destination $outputDds -Force
    if ((Get-Item -LiteralPath $outputDds).Length -le 0) {
        throw "Encoded vanilla hold-capital marker is empty: $outputDds"
    }
    Write-Host "Built vanilla hold-capital fallback: $outputDds"
}
