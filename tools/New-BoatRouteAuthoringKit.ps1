param(
    [string]$Inkscape = "C:\Program Files\Inkscape\bin\inkscape.com",
    [string]$Ffmpeg = "C:\Program Files\ffmpeg\bin\ffmpeg.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$authoringRoot = Join-Path $projectRoot ".tools\route-authoring"
$template = Join-Path $authoringRoot "boat-route-template.svg"
$map = Join-Path $authoringRoot "battlemap01-crop-local.png"
$northGuide = Join-Path $authoringRoot "north-coast-centerline-guide.png"
$honrichGuide = Join-Path $authoringRoot "lake-honrich-centerline-guide.png"
$blankPaint = Join-Path $authoringRoot "paint-chalk-here.png"
$merged = Join-Path $authoringRoot "boat-route-template-preview.png"
$thumbnail = Join-Path $authoringRoot "boat-route-template-thumbnail.png"
$ora = Join-Path $authoringRoot "boat-route-chalk-template.ora"
$staging = Join-Path $authoringRoot "ora-staging"

foreach ($required in @($Inkscape, $Ffmpeg, $template, $map)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required route-authoring input was not found: $required"
    }
}

foreach ($export in @(
    @{ Id = "north-coast-routes"; Path = $northGuide },
    @{ Id = "lake-honrich-route"; Path = $honrichGuide }
)) {
    & $Inkscape $template `
        --export-area-page `
        --export-id=$($export.Id) `
        --export-id-only `
        --export-filename=$($export.Path)
    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path -LiteralPath $export.Path -PathType Leaf)) {
        throw "Inkscape failed to export guide layer: $($export.Id)"
    }
}

& $Inkscape $template `
    --export-area-page `
    --export-filename=$merged
if ($LASTEXITCODE -ne 0 -or
    -not (Test-Path -LiteralPath $merged -PathType Leaf)) {
    throw "Inkscape failed to export the merged route preview."
}

& $Ffmpeg -hide_banner -loglevel error -y `
    -f lavfi -i "color=c=black@0.0:s=4096x3016,format=rgba" `
    -frames:v 1 $blankPaint
if ($LASTEXITCODE -ne 0 -or
    -not (Test-Path -LiteralPath $blankPaint -PathType Leaf)) {
    throw "FFmpeg failed to create the transparent chalk layer."
}

& $Ffmpeg -hide_banner -loglevel error -y `
    -i $merged -vf "scale=512:-1" -frames:v 1 $thumbnail
if ($LASTEXITCODE -ne 0 -or
    -not (Test-Path -LiteralPath $thumbnail -PathType Leaf)) {
    throw "FFmpeg failed to create the OpenRaster thumbnail."
}

$resolvedAuthoring = [System.IO.Path]::GetFullPath($authoringRoot).TrimEnd('\') + '\'
$resolvedStaging = [System.IO.Path]::GetFullPath($staging)
if (-not $resolvedStaging.StartsWith(
    $resolvedAuthoring,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to prepare an OpenRaster staging directory outside .tools."
}
if (Test-Path -LiteralPath $staging) {
    Remove-Item -LiteralPath $staging -Recurse -Force
}
foreach ($directory in @(
    $staging,
    (Join-Path $staging "data"),
    (Join-Path $staging "Thumbnails")
)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

[System.IO.File]::WriteAllText(
    (Join-Path $staging "mimetype"),
    "image/openraster",
    [System.Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $blankPaint `
    -Destination (Join-Path $staging "data\paint-chalk-here.png") -Force
Copy-Item -LiteralPath $northGuide `
    -Destination (Join-Path $staging "data\north-coast-guide.png") -Force
Copy-Item -LiteralPath $honrichGuide `
    -Destination (Join-Path $staging "data\lake-honrich-guide.png") -Force
Copy-Item -LiteralPath $map `
    -Destination (Join-Path $staging "data\rustic-map-local-reference.png") -Force
Copy-Item -LiteralPath $merged `
    -Destination (Join-Path $staging "mergedimage.png") -Force
Copy-Item -LiteralPath $thumbnail `
    -Destination (Join-Path $staging "Thumbnails\thumbnail.png") -Force

$stackXml = @'
<?xml version="1.0" encoding="UTF-8"?>
<image version="0.0.1" w="4096" h="3016" name="Diegetic Travel boat route chalk">
  <stack name="root">
    <layer name="PAINT CHALK HERE" src="data/paint-chalk-here.png" visibility="visible" />
    <layer name="NORTH COAST CENTERLINE GUIDE" src="data/north-coast-guide.png" visibility="visible" opacity="0.70" edit-locked="true" />
    <layer name="LAKE HONRICH CENTERLINE GUIDE" src="data/lake-honrich-guide.png" visibility="visible" opacity="0.70" edit-locked="true" />
    <layer name="RUSTIC MAP LOCAL REFERENCE - DO NOT SHIP" src="data/rustic-map-local-reference.png" visibility="visible" edit-locked="true" />
  </stack>
</image>
'@
[System.IO.File]::WriteAllText(
    (Join-Path $staging "stack.xml"),
    $stackXml,
    [System.Text.UTF8Encoding]::new($false))

if (Test-Path -LiteralPath $ora -PathType Leaf) {
    Remove-Item -LiteralPath $ora -Force
}
Add-Type -AssemblyName System.IO.Compression
$archiveStream = [System.IO.File]::Open(
    $ora,
    [System.IO.FileMode]::CreateNew,
    [System.IO.FileAccess]::ReadWrite,
    [System.IO.FileShare]::None)
try {
    $archive = [System.IO.Compression.ZipArchive]::new(
        $archiveStream,
        [System.IO.Compression.ZipArchiveMode]::Create,
        $true)
    try {
        function Add-OraEntry(
            [string]$Source,
            [string]$EntryName,
            [System.IO.Compression.CompressionLevel]$Compression
        ) {
            $entry = $archive.CreateEntry($EntryName, $Compression)
            $entryStream = $entry.Open()
            $sourceStream = [System.IO.File]::OpenRead($Source)
            try {
                $sourceStream.CopyTo($entryStream)
            } finally {
                $sourceStream.Dispose()
                $entryStream.Dispose()
            }
        }

        Add-OraEntry (Join-Path $staging "mimetype") "mimetype" `
            ([System.IO.Compression.CompressionLevel]::NoCompression)
        Add-OraEntry (Join-Path $staging "stack.xml") "stack.xml" `
            ([System.IO.Compression.CompressionLevel]::Optimal)
        Add-OraEntry (Join-Path $staging "mergedimage.png") "mergedimage.png" `
            ([System.IO.Compression.CompressionLevel]::Optimal)
        Add-OraEntry (Join-Path $staging "Thumbnails\thumbnail.png") `
            "Thumbnails/thumbnail.png" `
            ([System.IO.Compression.CompressionLevel]::Optimal)
        Add-OraEntry (Join-Path $staging "data\paint-chalk-here.png") `
            "data/paint-chalk-here.png" `
            ([System.IO.Compression.CompressionLevel]::Optimal)
        Add-OraEntry (Join-Path $staging "data\north-coast-guide.png") `
            "data/north-coast-guide.png" `
            ([System.IO.Compression.CompressionLevel]::Optimal)
        Add-OraEntry (Join-Path $staging "data\lake-honrich-guide.png") `
            "data/lake-honrich-guide.png" `
            ([System.IO.Compression.CompressionLevel]::Optimal)
        Add-OraEntry (Join-Path $staging "data\rustic-map-local-reference.png") `
            "data/rustic-map-local-reference.png" `
            ([System.IO.Compression.CompressionLevel]::Optimal)
    } finally {
        $archive.Dispose()
    }
} finally {
    $archiveStream.Dispose()
}

Write-Host "Built Krita/OpenRaster chalk template: $ora"
Write-Host "Canvas: 4096x3016"
Write-Host "Paint layer: transparent"
Write-Host "RUSTIC MAPS reference remains inside ignored .tools only"
