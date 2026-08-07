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

function Write-CalibrationPreset {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [object[]]$AuthoringStops = @()
    )

    $preset = Get-Content -LiteralPath $Source -Raw | ConvertFrom-Json
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
$wizardMapSource = Join-Path $LoreRimRoot 'mods\Skyrim Paper Map by Caro Tuts for FWMF\textures\terrain\tamriel\skyrim.dds'
$solstheimPresetSource = Join-Path $repoRoot 'modules\boat-solstheim\config\network.json'
$solstheimFerryMapSource = Join-Path $repoRoot 'Learning Sources\RUSTIC MAPS - 2K-42614-2-0-1606433716\Data\textures\dlc02\clutter\dlc2mapsolstheim02.dds'
$solstheimMerchantMapSource = Join-Path $LoreRimRoot 'mods\Solstheim and Baan Malur Paper Map for FWMF\textures\terrain\dlc2solstheimworld\solstheim.dds'
$textureRoot = Join-Path $repoRoot 'modules\parchment-picker\mod\textures\DiegeticTravel'
$texconv = Join-Path $repoRoot '.tools\TES5Edit-d12\Build\Edit Scripts\Texconvx64.exe'

$required = @(
    $mapSource,
    $wizardPresetSource,
    $wizardMapSource,
    $solstheimPresetSource,
    $solstheimFerryMapSource,
    $solstheimMerchantMapSource,
    $textureRoot,
    $texconv,
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

$ffmpeg = Get-Command ffmpeg -ErrorAction Stop
New-Item -ItemType Directory -Force -Path $presetRoot, $markerRoot | Out-Null

Copy-Item -LiteralPath (Join-Path $repoRoot 'modules\carriage-parchment\config\network.json') -Destination (Join-Path $presetRoot 'carriage.json') -Force
Copy-Item -LiteralPath $wizardPresetSource -Destination (Join-Path $presetRoot 'wizard.json') -Force

$northCoastAuthoringStops = @(
    [ordered]@{
        id = 'frostflow_lighthouse'; name = 'Frostflow Lighthouse'; runtime_enabled = $false
        availability = 'one_way'; position_status = 'calibrated'; map_position = @(0.629774, 0.159475)
        notes = 'Executable CFTO Route 1 destination with no public return provider.'
    },
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
        availability = 'quest_locked'; position_status = 'provisional'; map_position = @(0.923, 0.818)
        notes = 'Private Riften ferry gated by house ownership, porch, and ferryman state.'
    }
)

$ilinaltaAuthoringStops = @(
    [ordered]@{
        id = 'lakeview_manor'; name = 'Lakeview Manor'; runtime_enabled = $false
        availability = 'quest_locked'; position_status = 'calibrated'; map_position = @(0.423729, 0.709260)
        notes = 'Private Hearthfire ferry gated by ownership, jetty, and ferryman construction.'
    },
    [ordered]@{
        id = 'ilinatas_deep'; name = "Ilinalta's Deep"; runtime_enabled = $false
        availability = 'one_way'; position_status = 'calibrated'; map_position = @(0.412943, 0.664269)
        notes = 'Executable CFTO Route 3 destination with no public return provider.'
    }
)

$solstheimAuthoringStops = @(
    [ordered]@{
        id = 'northshore_landing'; name = 'Northshore Landing'; runtime_enabled = $false
        availability = 'one_way'; position_status = 'calibrated'; map_position = @(0.126267, 0.162120)
        notes = 'Executable CFTO Route 4 destination with no public return provider.'
    },
    [ordered]@{
        id = 'bujolds_retreat'; name = "Bujold's Retreat"; runtime_enabled = $false
        availability = 'one_way'; position_status = 'calibrated'; map_position = @(0.842557, 0.472330)
        notes = 'Executable CFTO Route 4 destination with no public return provider.'
    }
)

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
            availability = 'outbound_only'; position_status = 'staging'; map_position = @(0.84, 0.18)
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

$markerCount = (Get-ChildItem -LiteralPath $markerRoot -Filter '*.png').Count
Write-Host "Calibration assets synced: 7 presets, $markerCount marker previews, 4 local map crops."
