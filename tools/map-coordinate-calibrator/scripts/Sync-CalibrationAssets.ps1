[CmdletBinding()]
param(
    [string]$LoreRimRoot = 'D:\Lorerim'
)

$ErrorActionPreference = 'Stop'

function Remove-TemporaryDirectory {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return
        }
        catch {
            if ($attempt -eq 5) {
                throw
            }
            Start-Sleep -Milliseconds 250
        }
    }
}

function Get-Sha256Hex {
    param([Parameter(Mandatory)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([System.BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-', '')
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Write-CalibrationPreset {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [object[]]$AuthoringStops = @()
    )

    $preset = Get-Content -LiteralPath $Source -Raw | ConvertFrom-Json
    if ($preset.PSObject.Properties.Name -contains 'destination_only_stops') {
        $preset.stops = @($preset.stops) + @($preset.destination_only_stops)
    }
    $preset | Add-Member -MemberType NoteProperty -Name authoring_stops -Value @($AuthoringStops) -Force
    $json = ($preset | ConvertTo-Json -Depth 20) + [Environment]::NewLine
    [System.IO.File]::WriteAllText($Destination, $json, (New-Object System.Text.UTF8Encoding($false)))
}

$siteRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoRoot = (Resolve-Path (Join-Path $siteRoot '..\..')).Path
$publicRoot = Join-Path $siteRoot 'public'
$presetRoot = Join-Path $publicRoot 'presets'
$markerRoot = Join-Path $publicRoot 'markers'
$mapSource = Join-Path $repoRoot '.tools\route-authoring\battlemap01-crop-local.png'
$wizardPresetSource = Join-Path $repoRoot 'modules\parchment-picker\config\wizard-map.json'
$iconOpticsSource = Join-Path $repoRoot 'modules\parchment-picker\config\icon-optics.json'
$wizardMapSource = Join-Path $LoreRimRoot 'mods\Skyrim Paper Map by Caro Tuts for FWMF\textures\terrain\tamriel\skyrim.dds'
$solstheimPresetSource = Join-Path $repoRoot 'modules\boat-solstheim\config\network.json'
$solstheimFerryMapSource = Join-Path $repoRoot 'Learning Sources\RUSTIC MAPS - 2K-42614-2-0-1606433716\Data\textures\dlc02\clutter\dlc2mapsolstheim02.dds'
$solstheimMerchantMapSource = Join-Path $LoreRimRoot 'mods\Solstheim and Baan Malur Paper Map for FWMF\textures\terrain\dlc2solstheimworld\solstheim.dds'
$textureRoot = Join-Path $repoRoot 'modules\parchment-picker\mod\textures\DiegeticTravel'
$texconv = Join-Path $repoRoot '.tools\TES5Edit-d12\Build\Edit Scripts\Texconvx64.exe'
$inkscape = 'C:\Program Files\Inkscape\bin\inkscape.com'
$nordenShipwreckSource = Join-Path $repoRoot 'assets\norden-interface\maritime-markers\norden-shipwreck.svg'
$nordenDocksSource = Join-Path $repoRoot 'assets\norden-interface\maritime-markers\norden-docks.svg'
$thinCircleSource = Join-Path $repoRoot 'assets\diegetic-travel\selection-rings\thin-circle-select.png'
$parchmentArrowsSource = Join-Path $repoRoot 'assets\diegetic-travel\selection-rings\parchment-arrows-thin.png'
$removeEdgeBackground = Join-Path $repoRoot 'tools\Remove-EdgeBackground.py'
$normalizeMarker = Join-Path $repoRoot 'tools\Normalize-TransparentMarker.py'

$required = @(
    $mapSource,
    $wizardPresetSource,
    $iconOpticsSource,
    $wizardMapSource,
    $solstheimPresetSource,
    $solstheimFerryMapSource,
    $solstheimMerchantMapSource,
    $textureRoot,
    $texconv,
    $inkscape,
    $nordenShipwreckSource,
    $nordenDocksSource,
    $thinCircleSource,
    $parchmentArrowsSource,
    $removeEdgeBackground,
    $normalizeMarker,
    (Join-Path $repoRoot 'modules\carriage-parchment\config\network.json'),
    (Join-Path $repoRoot 'modules\boat-north-coast\config\network.json'),
    (Join-Path $repoRoot 'modules\boat-honrich\config\network.json'),
    (Join-Path $repoRoot 'modules\boat-ilinalta\config\network.json')
)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required calibration source is missing: $path"
    }
}

$pinnedNordenMaritimeSources = @(
    @{ Path = $nordenShipwreckSource; Hash = '01A0150DBCB32F06D87CAC48665DC4F159B2CD6F34A2D13D21FE66E0BEAD755F' },
    @{ Path = $nordenDocksSource; Hash = '60F4A6FC3E73FA5F5C8E5D0AF318AE1C595A77E0D90BEB4D379A8E29FE591436' }
)
foreach ($source in $pinnedNordenMaritimeSources) {
    $actualHash = Get-Sha256Hex -Path $source.Path
    if ($actualHash -ne $source.Hash) {
        throw "Pinned Norden maritime marker changed unexpectedly: $($source.Path): $actualHash"
    }
}

$ffmpeg = Get-Command ffmpeg -ErrorAction Stop
New-Item -ItemType Directory -Force -Path $presetRoot, $markerRoot | Out-Null

Copy-Item -LiteralPath (Join-Path $repoRoot 'modules\carriage-parchment\config\network.json') -Destination (Join-Path $presetRoot 'carriage.json') -Force
Copy-Item -LiteralPath $wizardPresetSource -Destination (Join-Path $presetRoot 'wizard.json') -Force
Copy-Item -LiteralPath $iconOpticsSource -Destination (Join-Path $publicRoot 'icon-optics.json') -Force

$northCoastAuthoringStops = @(
    [ordered]@{
        id = 'icewater_jetty'; name = 'Icewater Jetty / Castle Volkihar'; runtime_enabled = $false
        availability = 'quest_locked'; position_status = 'calibrated'; map_position = @(0.122369, 0.097021)
        notes = 'Quest-special CFTO destination with discovery, persuasion, and extra-fare state.'
    },
    [ordered]@{
        id = 'windstad_manor'; name = 'Windstad Manor'; runtime_enabled = $false
        availability = 'quest_locked'; position_status = 'calibrated'; map_position = @(0.427903, 0.159475)
        notes = 'Private Hearthfire ferry gated by ownership, jetty, and ferryman construction.'
    }
)

$honrichAuthoringStops = @(
    [ordered]@{
        id = 'honeyside'; name = 'Honeyside'; runtime_enabled = $false
        availability = 'quest_locked'; position_status = 'calibrated'; map_position = @(0.893650, 0.805080)
        notes = 'Private Riften ferry gated by house ownership, porch, and ferryman state.'
    }
)

$ilinaltaAuthoringStops = @(
    [ordered]@{
        id = 'lakeview_manor'; name = 'Lakeview Manor'; runtime_enabled = $false
        availability = 'quest_locked'; position_status = 'calibrated'; map_position = @(0.423729, 0.709260)
        notes = 'Private Hearthfire ferry gated by ownership, jetty, and ferryman construction.'
    }
)

$solstheimAuthoringStops = @()

Write-CalibrationPreset -Source (Join-Path $repoRoot 'modules\boat-north-coast\config\network.json') -Destination (Join-Path $presetRoot 'north-coast.json') -AuthoringStops $northCoastAuthoringStops
Write-CalibrationPreset -Source (Join-Path $repoRoot 'modules\boat-honrich\config\network.json') -Destination (Join-Path $presetRoot 'honrich.json') -AuthoringStops $honrichAuthoringStops
Write-CalibrationPreset -Source (Join-Path $repoRoot 'modules\boat-ilinalta\config\network.json') -Destination (Join-Path $presetRoot 'ilinalta.json') -AuthoringStops $ilinaltaAuthoringStops
Write-CalibrationPreset -Source $solstheimPresetSource -Destination (Join-Path $presetRoot 'solstheim.json') -AuthoringStops $solstheimAuthoringStops

$solstheimMerchantPreset = [ordered]@{
    schema_version = 1
    provider = 'boat'
    lane = 'solstheim_merchant'
    fare_default = 30
    time_passage = 'delegated_to_journey_to_baan_malur'
    map = [ordered]@{
        texture = 'Data/textures/terrain/dlc2solstheimworld/solstheim.dds'
        uv_crop = @(0.0, 0.158447, 1.0, 0.810181)
        art_aspect_ratio = 1.534
        selection_ring_scale = 2.0
        marker_theme = 'norden_maritime'
        origin_marker = 'norden_shipwreck'
        destination_marker = 'norden_docks'
        selection_ring = 'thin_circle'
        presentation_note = 'installed Solstheim and Baan Malur chart used for Captain Remyris route authoring'
        asset_policy = 'reference-only; do not package the DDS'
    }
    ui_elements = @(
        [ordered]@{
            id = 'fare_label'
            name = 'Payment label'
            sample = 'Raven Rock to Baan Malur    30 gold'
            map_position = @(0.814330, 0.697376)
        }
    )
    stops = @(
        [ordered]@{
            id = 'raven_rock'
            name = 'Raven Rock'
            map_position = @(0.572274, 0.405605)
        },
        [ordered]@{
            id = 'baan_malur'
            name = 'Baan Malur'
            map_position = @(0.510018, 0.640516)
        },
        [ordered]@{
            id = 'cormaris'
            name = 'Cormaris'
            map_position = @(0.157237, 0.323277)
        }
    )
    authoring_stops = @(
        [ordered]@{
            id = 'pryai'; name = 'Pryai'; runtime_enabled = $false
            availability = 'broken_target'; position_status = 'staging'; map_position = @(0.68, 0.18)
            source_condition = 'SOMRBoatHirePryai via SOMRBoatTravelPryaiCheck'
            notes = 'The installed arrival target resolves out of bounds; do not expose at runtime.'
        },
        [ordered]@{
            id = 'llethrin_fel'; name = 'Llethrin Fel'; runtime_enabled = $false
            availability = 'unverified_separate_quest'; position_status = 'staging'; map_position = @(0.76, 0.18)
            source_condition = 'SOMRBoatHireLlethrinFel'
            notes = 'Uses a separate quest path whose complete travel and return contract is not proved.'
        },
        [ordered]@{
            id = 'sunmul'; name = 'Sunmul'; runtime_enabled = $false
            availability = 'outbound_only'; position_status = 'calibrated'; map_position = @(0.561367, 0.894535)
            source_condition = 'SOMRBoatHireSunmul via SOMRBoatTravelSunmulCheck'
            notes = 'Outbound stage works, but no return-side public provider has been proved.'
        },
        [ordered]@{
            id = 'seyda_neen'; name = 'Seyda Neen'; runtime_enabled = $false
            availability = 'target_unset'; position_status = 'staging'; map_position = @(0.68, 0.82)
            source_condition = 'SOMRBoatHireSeydaNeen'
            notes = 'The installed destination script has no TargetLocation property.'
        },
        [ordered]@{
            id = 'vivec'; name = 'Vivec'; runtime_enabled = $false
            availability = 'target_unset'; position_status = 'staging'; map_position = @(0.76, 0.82)
            source_condition = 'SOMRBoatHireVivec via SOMRBoatTravelVivecCheck'
            notes = 'The installed destination script has no TargetLocation property.'
        },
        [ordered]@{
            id = 'old_silgrad'; name = 'Old Silgrad'; runtime_enabled = $false
            availability = 'target_unset'; position_status = 'staging'; map_position = @(0.84, 0.82)
            source_condition = 'SOMRBoatHireOldSilgrad'
            notes = 'The installed destination script has no TargetLocation property.'
        }
    )
}
$solstheimMerchantJson = ($solstheimMerchantPreset | ConvertTo-Json -Depth 20) + [Environment]::NewLine
[System.IO.File]::WriteAllText(
    (Join-Path $presetRoot 'solstheim-merchant.json'),
    $solstheimMerchantJson,
    (New-Object System.Text.UTF8Encoding($false))
)

foreach ($legacyAsset in @(
    (Join-Path $presetRoot 'solstheim-paper.json'),
    (Join-Path $publicRoot 'solstheim-paper-map-reference.jpg')
)) {
    if (Test-Path -LiteralPath $legacyAsset -PathType Leaf) {
        Remove-Item -LiteralPath $legacyAsset -Force
    }
}

& $ffmpeg.Source -hide_banner -loglevel error -y -i $mapSource -vf 'scale=2048:1508' -q:v 3 (Join-Path $publicRoot 'map-reference.jpg')
if ($LASTEXITCODE -ne 0) {
    throw "ffmpeg failed to create the local map preview (exit $LASTEXITCODE)."
}

$temporaryRoot = Join-Path $siteRoot '.sync-temp'
Remove-TemporaryDirectory -Path $temporaryRoot
New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null
try {
    & $texconv -nologo -y -ft png -o $temporaryRoot $wizardMapSource | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Texconv failed to create the wizard-map source preview (exit $LASTEXITCODE)."
    }
    $wizardPng = Join-Path $temporaryRoot 'skyrim.PNG'
    if (-not (Test-Path -LiteralPath $wizardPng -PathType Leaf)) {
        throw "Texconv did not create the expected wizard-map preview: $wizardPng"
    }
    & $ffmpeg.Source -hide_banner -loglevel error -y -i $wizardPng `
        -vf 'crop=iw*0.84375:ih*0.596679:iw*0.088379:ih*0.187012,scale=2048:1448' `
        -q:v 3 (Join-Path $publicRoot 'wizard-map-reference.jpg')
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg failed to crop the local wizard-map preview (exit $LASTEXITCODE)."
    }

    & $texconv -nologo -y -ft png -o $temporaryRoot $solstheimFerryMapSource | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Texconv failed to create the Solstheim ferry-map preview (exit $LASTEXITCODE)."
    }
    $solstheimFerryPng = Join-Path $temporaryRoot 'dlc2mapsolstheim02.PNG'
    if (-not (Test-Path -LiteralPath $solstheimFerryPng -PathType Leaf)) {
        throw "Texconv did not create the expected Solstheim ferry-map preview: $solstheimFerryPng"
    }
    & $ffmpeg.Source -hide_banner -loglevel error -y -i $solstheimFerryPng `
        -vf 'crop=iw*0.5:ih:iw*0.5:0,scale=1600:1600' `
        -q:v 3 (Join-Path $publicRoot 'solstheim-ferry-map-reference.jpg')
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg failed to crop the Solstheim ferry-map preview (exit $LASTEXITCODE)."
    }

    & $texconv -nologo -y -ft png -w 4096 -h 4096 -o $temporaryRoot $solstheimMerchantMapSource | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Texconv failed to create the Solstheim merchant-map preview (exit $LASTEXITCODE)."
    }
    $solstheimMerchantPng = Join-Path $temporaryRoot 'solstheim.PNG'
    if (-not (Test-Path -LiteralPath $solstheimMerchantPng -PathType Leaf)) {
        throw "Texconv did not create the expected Solstheim merchant-map preview: $solstheimMerchantPng"
    }
    & $ffmpeg.Source -hide_banner -loglevel error -y -i $solstheimMerchantPng `
        -vf 'crop=iw:ih*0.651734:0:ih*0.158447,scale=2048:-1' `
        -q:v 3 (Join-Path $publicRoot 'solstheim-merchant-map-reference.jpg')
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg failed to create the Solstheim merchant-map preview (exit $LASTEXITCODE)."
    }
}
finally {
    Remove-TemporaryDirectory -Path $temporaryRoot
}

& $texconv -nologo -y -ft png -o $markerRoot (Join-Path $textureRoot '*.dds') | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Texconv failed to create marker previews (exit $LASTEXITCODE)."
}

Get-ChildItem -LiteralPath $markerRoot -Filter '*.PNG' | ForEach-Object {
    $temporary = $_.FullName + '.case-normalization'
    Move-Item -LiteralPath $_.FullName -Destination $temporary -Force
    Move-Item -LiteralPath $temporary -Destination ([System.IO.Path]::ChangeExtension($_.FullName, '.png')) -Force
}

$markerTemporaryRoot = Join-Path $siteRoot '.sync-marker-temp'
Remove-TemporaryDirectory -Path $markerTemporaryRoot
New-Item -ItemType Directory -Force -Path $markerTemporaryRoot | Out-Null
try {
    foreach ($maritimeMarker in @(
        @{ Source = $nordenShipwreckSource; Name = 'norden-shipwreck' },
        @{ Source = $nordenDocksSource; Name = 'norden-docks' }
    )) {
        $rendered = Join-Path $markerTemporaryRoot "$($maritimeMarker.Name)-rendered.png"
        $normalized = Join-Path $markerRoot "$($maritimeMarker.Name).png"
        & $inkscape $maritimeMarker.Source `
            --export-type=png `
            --export-filename=$rendered `
            --export-width=512 `
            --export-background-opacity=0
        if ($LASTEXITCODE -ne 0) {
            throw "Inkscape failed to render $($maritimeMarker.Name)."
        }
        & python $normalizeMarker `
            --input $rendered `
            --output $normalized `
            --canvas 512 `
            --max-width 416 `
            --max-height 416 `
            --normalize-alpha-max
        if ($LASTEXITCODE -ne 0) {
            throw "Alpha normalization failed for $($maritimeMarker.Name)."
        }
    }

    foreach ($selectionRing in @(
        @{ Source = $thinCircleSource; Name = 'thin-circle-selection-ring' },
        @{ Source = $parchmentArrowsSource; Name = 'parchment-thin-selection-ring' }
    )) {
        $transparent = Join-Path $markerTemporaryRoot "$($selectionRing.Name)-transparent.png"
        $normalized = Join-Path $markerRoot "$($selectionRing.Name).png"
        & python $removeEdgeBackground `
            --input $selectionRing.Source `
            --output $transparent `
            --threshold 20
        if ($LASTEXITCODE -ne 0) {
            throw "Background removal failed for $($selectionRing.Name)."
        }
        & python $normalizeMarker `
            --input $transparent `
            --output $normalized `
            --canvas 512 `
            --max-width 448 `
            --max-height 448 `
            --normalize-alpha-max
        if ($LASTEXITCODE -ne 0) {
            throw "Alpha normalization failed for $($selectionRing.Name)."
        }
    }
}
finally {
    Remove-TemporaryDirectory -Path $markerTemporaryRoot
}

$markerCount = (Get-ChildItem -LiteralPath $markerRoot -Filter '*.png').Count
Write-Host "Calibration assets synced: 7 presets, $markerCount marker previews, 4 local map crops."
