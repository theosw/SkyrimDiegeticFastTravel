param(
    [string]$Inkscape = "C:\Program Files\Inkscape\bin\inkscape.com",
    [string]$Texconv = ".tools\TES5Edit-d12\Build\Edit Scripts\Texconv.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Texconv)) {
    $Texconv = Join-Path $projectRoot $Texconv
}

# Exact discovered-map symbols exported from Norden UI's mapmarkerart.swf.
# The project owner has the Norden author's permission to use these assets.
$sources = @(
    @{ Name = "norden-town"; Hash = "BB04A1293BFC0E7CFACAC31F9D7BE2615D2540AF787777D9BA1FAA3D6C01636E" },
    @{ Name = "norden-settlement"; Hash = "F3EDAFAA562576704252D25ECC69B196D817C67C68CEEDF820F4BECF1BD21D6E" },
    @{ Name = "norden-farm"; Hash = "4E77FC535918D6BC4EB4B774F4F7AAF5F14CB1CF8CA4861529B96DEB73BABE53" },
    @{ Name = "norden-wood-mill"; Hash = "1C3BB35609E165A5EF2E6915AD282B6B5CEFEA116DA201A2BB01558A8C841432" },
    @{ Name = "norden-mine"; Hash = "04914427C0AE9DE384B0BC45342521E7070C0AC7581C0BBDF2EBDF49481FB84A" },
    @{ Name = "norden-riften-capital"; Hash = "E829FC00D350D818E5FFAD126AE984F6270D430A72DED6F29E63C948CB6D90E8" },
    @{ Name = "norden-windhelm-capital"; Hash = "AABD22F43C4DBBF9184E9346906234DF3A5A29CD8EF9206A971C04A6D58A5733" },
    @{ Name = "norden-whiterun-capital"; Hash = "972CB4947735D60379FD096955BB42DC1E17B016952FB97B10A7D80ACB86DBAA" },
    @{ Name = "norden-solitude-capital"; Hash = "17D1D511EAE0F54936B9EF5FE84F3CE02251503E4DDF6C8C1873C5A18B464B11" },
    @{ Name = "norden-markarth-capital"; Hash = "369C7214F8C6CAD3510E7BFF0E9C5BBC4CCBEF6838157BB2DD2078EC7843C716" },
    @{ Name = "norden-winterhold-capital"; Hash = "A31563F8F0E9D7B66B5307AEF05DCBA102C8CB3F0C1BE665397251E1884DF377" },
    @{ Name = "norden-morthal-capital"; Hash = "9B3F2AC6CC9A08373C239F54EE30077FC29485D566DD9EF47CC10004545D4889" },
    @{ Name = "norden-falkreath-capital"; Hash = "911EEA8276A80C82AAFE832D05B0D468A33FF4F7848BDBDD6AF2C9EEF4D07491" },
    @{ Name = "norden-dawnstar-capital"; Hash = "E6803FAFB2EF86588962F1834E897CCA11AD2C0FA0C2A1A8BBBD0D942DDBF6DD" }
)

$sourceRoot = Join-Path $projectRoot "assets\norden-interface\carriage-markers"
$buildRoot = Join-Path $projectRoot "build\norden-carriage-markers"
$outputRoot = Join-Path $projectRoot "modules\parchment-picker\mod\textures\DiegeticTravel"
foreach ($required in @($Inkscape, $Texconv)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Norden marker tool was not found: $required"
    }
}
foreach ($directory in @($buildRoot, $outputRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

foreach ($source in $sources) {
    $sourcePath = Join-Path $sourceRoot "$($source.Name).svg"
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required Norden marker source was not found: $sourcePath"
    }
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($sourceHash -ne $source.Hash) {
        throw "Norden marker source hash changed unexpectedly: $sourcePath`: $sourceHash"
    }

    $renderedPng = Join-Path $buildRoot "$($source.Name)-rendered.png"
    $normalizedPng = Join-Path $buildRoot "$($source.Name).png"
    & $Inkscape $sourcePath `
        --export-type=png `
        --export-filename=$renderedPng `
        --export-width=512 `
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
    Write-Host "Built Norden carriage marker: $outputDds"
}

Write-Host "Norden source SWF SHA-256: AF39A7C181E8BF6187E389CC6D5F333780F11057C562673BC40A78490998B1AA"
