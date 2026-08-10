param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\boat-north-coast"
$buildRoot = Join-Path $projectRoot "build"
$auditRoot = Join-Path $buildRoot "boat-north-coast-audit"
$stagingData = Join-Path $auditRoot "data"
$pluginsList = Join-Path $auditRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "boat-north-coast-audit.status"
$errorPath = Join-Path $buildRoot "boat-north-coast-audit.error"
$reportPath = Join-Path $buildRoot "boat-north-coast-audit.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_AuditBoatNorthCoast.pas"
$pluginPath = Join-Path $moduleRoot "mod\DiegeticTravelBoatNorthCoast.esp"
$seqPath = Join-Path $moduleRoot "mod\SEQ\DiegeticTravelBoatNorthCoast.seq"
$pickerSourcePath = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_NorthCoastBoatParchmentPicker.psc"
$serviceSourcePath = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_NorthCoastBoatTravelService.psc"
$networkPath = Join-Path $moduleRoot "config\network.json"
$nativeSourcePath = Join-Path $projectRoot `
    "modules\parchment-picker\mod\Scripts\Source\DNT_ParchmentNative.psc"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$xeditPath = Resolve-ProjectPath $XEdit
$resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot)
$resolvedAuditRoot = [System.IO.Path]::GetFullPath($auditRoot)
if (-not $resolvedAuditRoot.StartsWith(
    $resolvedBuildRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean North-coast audit outside build."
}

foreach ($required in @(
    $xeditPath,
    $scriptPath,
    $pluginPath,
    $seqPath,
    $pickerSourcePath,
    $serviceSourcePath,
    $networkPath,
    $nativeSourcePath
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required North-coast audit input not found: $required"
    }
}

$pickerSource = Get-Content -LiteralPath $pickerSourcePath -Raw
$serviceSource = Get-Content -LiteralPath $serviceSourcePath -Raw
$nativeSource = Get-Content -LiteralPath $nativeSourcePath -Raw
$network = Get-Content -LiteralPath $networkPath -Raw | ConvertFrom-Json

foreach ($handoffToken in @(
    "DNT_ParchmentNative.RequestDialogueClose",
    "BOAT_DIALOGUE_HANDOFF_CLOSE_REQUEST",
    "BOAT_DIALOGUE_HANDOFF_ALREADY_CLOSED",
    "BOAT_DIALOGUE_HANDOFF_COMPLETE",
    "BOAT_DIALOGUE_HANDOFF_TIMEOUT",
    'UI.IsMenuOpen("Dialogue Menu")',
    "dialogue_close_request_failed",
    "dialogue_timeout"
)) {
    if ($pickerSource -notmatch [regex]::Escape($handoffToken)) {
        throw "North-coast dialogue handoff is missing token: $handoffToken"
    }
}
if ($nativeSource -notmatch [regex]::Escape(
    "Bool Function RequestDialogueClose() Global Native"
)) {
    throw "Parchment native contract is missing RequestDialogueClose."
}
if ($pickerSource -match [regex]::Escape("Input.TapKey")) {
    throw "North-coast dialogue handoff must not synthesize keyboard input."
}
if ($nativeSource -notmatch [regex]::Escape(
    "Bool Function AddRouteSegment("
)) {
    throw "Parchment native contract is missing route-segment support."
}
if ($nativeSource -notmatch [regex]::Escape(
    "Bool Function AddRouteLandmark("
)) {
    throw "Parchment native contract is missing inactive-landmark support."
}
if ($nativeSource -notmatch [regex]::Escape("Bool Function SetOverlayTexture(")) {
    throw "Parchment native contract is missing optional overlay support."
}
foreach ($deferredRuntimeToken in @(
    "DNT_ParchmentNative.SetOverlayTexture",
    "AddedAll = AddNorthCoastNetwork() && AddedAll"
)) {
    if ($pickerSource -match [regex]::Escape($deferredRuntimeToken)) {
        throw "North-coast beta must not activate deferred route artwork: $deferredRuntimeToken"
    }
}
if (($pickerSource | Select-String -Pattern "DNT_ParchmentNative.AddRouteSegment" -AllMatches).Matches.Count -ne 68 -or
    $pickerSource -notmatch [regex]::Escape("Bool Function AddNorthCoastNetwork()")) {
    throw "North-coast deferred authoring geometry must retain the audited 68-segment coastal network."
}
if (($pickerSource | Select-String -Pattern "DNT_ParchmentNative.AddRouteLandmark" -AllMatches).Matches.Count -ne 6 -or
    $pickerSource -notmatch [regex]::Escape("Bool Function AddInactiveMainlandLandmarks()")) {
    throw "North-coast picker must expose the three Lake Honrich and three Lake Ilinalta inactive anchors."
}

if ($network.lane -ne "north_coast" -or $network.stops.Count -ne 7) {
    throw "North-coast network must define exactly seven public stops."
}
if ($network.fare_global -ne "00AA12:CFTO.esp" -or
    $network.fare_default -ne 50) {
    throw "North-coast network does not preserve CFTO's regional fare."
}
$paymentLabel = @($network.ui_elements | Where-Object { $_.id -eq 'fare_label' })
if ($paymentLabel.Count -ne 1 -or
    [Math]::Abs([double]$paymentLabel[0].map_position[0] - 0.647846) -gt 0.000001 -or
    [Math]::Abs([double]$paymentLabel[0].map_position[1] - 0.899624) -gt 0.000001) {
    throw "North-coast payment-label coordinate contract does not match."
}
if ($network.map.texture -ne
    "Data/textures/dungeons/imperial/battlemap01.dds") {
    throw "North-coast network does not reference the Skyrim parchment map."
}
if ($network.map.PSObject.Properties.Name -contains "overlay_texture") {
    throw "North-coast beta config must not activate deferred route artwork."
}
if ($network.map.art_aspect_ratio -ne 1.35809 -or
    $network.map.uv_crop.Count -ne 4 -or
    $network.map.uv_crop[0] -ne 0.0 -or
    $network.map.uv_crop[1] -ne 0.0 -or
    $network.map.uv_crop[2] -ne 1.0 -or
    $network.map.uv_crop[3] -ne 0.736328) {
    throw "North-coast network map crop contract does not match."
}
$expectedIds = @(
    "dawnstar",
    "solitude",
    "windhelm",
    "morthal",
    "solitude_lighthouse",
    "winterhold",
    "dragon_bridge"
)
foreach ($stopId in $expectedIds) {
    if (@($network.stops | Where-Object { $_.id -eq $stopId }).Count -ne 1) {
        throw "North-coast network is missing stop $stopId."
    }
    if ($pickerSource -notmatch [regex]::Escape('"' + $stopId + '"')) {
        throw "North-coast picker is missing stop $stopId."
    }
    if ($serviceSource -notmatch [regex]::Escape('"' + $stopId + '"')) {
        throw "North-coast service is missing stop $stopId."
    }
}
$frostflow = @($network.destination_only_stops | Where-Object {
    $_.id -eq "frostflow_lighthouse"
})
if ($frostflow.Count -ne 1 -or
    $frostflow[0].provider_enabled -ne $false -or
    $frostflow[0].arrival_marker -ne "038411:CFTO.esp" -or
    $frostflow[0].fare_global -ne "00AA12:CFTO.esp" -or
    $frostflow[0].PSObject.Properties.Name -contains "service_npc" -or
    [Math]::Abs([double]$frostflow[0].map_position[0] - 0.629774) -gt 0.000001 -or
    [Math]::Abs([double]$frostflow[0].map_position[1] - 0.159475) -gt 0.000001) {
    throw "North-coast Frostflow destination-only contract does not match."
}
$allProviderIds = $expectedIds + @("windstad_manor", "icewater_jetty")
if (@($frostflow[0].available_from).Count -ne 9 -or
    @($frostflow[0].available_from | Where-Object { $_ -notin $allProviderIds }).Count -ne 0 -or
    $pickerSource -notmatch [regex]::Escape('"frostflow_lighthouse"') -or
    $pickerSource -notmatch [regex]::Escape("0.629774, 0.159475") -or
    $pickerSource -notmatch [regex]::Escape("SelectionIds = new String[10]") -or
    $serviceSource -notmatch [regex]::Escape("FrostflowMarkerForm = 0x038411")) {
    throw "North-coast runtime does not expose Frostflow from every available provider."
}
$windstad = @($network.private_stops | Where-Object { $_.id -eq "windstad_manor" })
if ($windstad.Count -ne 1 -or
    $windstad[0].service_npc -ne "014C89:CFTO.esp" -or
    $windstad[0].service_ref -ne "014C8A:CFTO.esp" -or
    $windstad[0].arrival_marker -ne "014C86:CFTO.esp" -or
    $windstad[0].follower_marker -ne "195C3D:CFTO.esp" -or
    $windstad[0].horse_marker -ne "195C3C:CFTO.esp" -or
    $windstad[0].fare_global -ne "00AA12:CFTO.esp" -or
    $windstad[0].fare_default -ne 50 -or
    $windstad[0].availability -ne "service_ref_enabled") {
    throw "North-coast Windstad Manor private-service contract does not match CFTO."
}
$icewater = @($network.private_stops | Where-Object { $_.id -eq "icewater_jetty" })
if ($icewater.Count -ne 1 -or
    $icewater[0].service_npc -ne "1F0E6A:CFTO.esp" -or
    $icewater[0].service_ref -ne "1F0E6B:CFTO.esp" -or
    $icewater[0].arrival_marker -ne "03840F:CFTO.esp" -or
    $icewater[0].follower_marker -ne "195C42:CFTO.esp" -or
    $icewater[0].horse_marker -ne "195C41:CFTO.esp" -or
    $icewater[0].outbound_fare_global -ne "038425:CFTO.esp" -or
    $icewater[0].outbound_fare_default -ne 100 -or
    $icewater[0].return_fare_default -ne 0 -or
    $icewater[0].availability_global -ne "038426:CFTO.esp" -or
    $icewater[0].availability_minimum -ne 1) {
    throw "North-coast Icewater/Volkihar private-service contract does not match CFTO."
}
foreach ($privateToken in @(
    'WindstadFerrymanForm = 0x014C89',
    'WindstadFerrymanRefForm = 0x014C8A',
    'WindstadMarkerForm = 0x014C86',
    'WindstadFollowerMarkerForm = 0x195C3D',
    'WindstadHorseMarkerForm = 0x195C3C',
    'VolkiharFerrymanForm = 0x1F0E6A',
    'FerryVolkiharStateForm = 0x038426',
    'FerryCostExtraForm = 0x038425',
    'IcewaterFollowerMarkerForm = 0x195C42',
    'IcewaterHorseMarkerForm = 0x195C41',
    '"windstad_manor"',
    '"icewater_jetty"'
)) {
    if (($pickerSource + $serviceSource) -notmatch [regex]::Escape($privateToken)) {
        throw "North-coast private ferry runtime is missing contract: $privateToken"
    }
}
foreach ($sourceToken in @(
    'MapAspectRatio = 1.358090',
    'MapTexturePath = "Data/textures/dungeons/imperial/battlemap01.dds"',
    'BeginRequest(ActiveRequest, "boat", SourceRef, MapTexturePath, MapAspectRatio, 0.0, 0.0, 1.0, 0.736328)',
    'SetPaymentLabelPosition(ActiveRequest, 0.647846, 0.899624)',
    '0.562613, 0.139944',
    '0.343646, 0.176873',
    '0.825231, 0.399423',
    '0.404470, 0.256564',
    '0.380140, 0.082606',
    '0.730059, 0.137028',
    '0.243465, 0.226437',
    'DawnstarFerrymanForm = 0x00AA07',
    'SolitudeFerrymanForm = 0x00AA08',
    'WindhelmFerrymanForm = 0x00AA09',
    'MorthalFerrymanForm = 0x00AA0B',
    'LighthouseFerrymanForm = 0x014C5A',
    'WinterholdFerrymanForm = 0x158FFC',
    'DragonBridgeFerrymanForm = 0x2D4C09',
    'FerryCostForm = 0x00AA12',
    'lane=north_coast'
)) {
    if (($pickerSource + $serviceSource) -notmatch
        [regex]::Escape($sourceToken)) {
        throw "North-coast source is missing contract: $sourceToken"
    }
}

if (Test-Path -LiteralPath $auditRoot) {
    Remove-Item -LiteralPath $auditRoot -Recurse -Force
}
foreach ($resultFile in @($statusPath, $errorPath, $reportPath)) {
    if (Test-Path -LiteralPath $resultFile -PathType Leaf) {
        Remove-Item -LiteralPath $resultFile -Force
    }
}

New-Item -ItemType Directory -Force -Path $stagingData | Out-Null
$stockData = Join-Path $LoreRimRoot "Stock Game\Data"
foreach ($inputName in @(
    "Skyrim.esm",
    "Update.esm",
    "Dawnguard.esm",
    "HearthFires.esm",
    "Dragonborn.esm",
    "Skyrim - Interface.bsa"
)) {
    $inputPath = Join-Path $stockData $inputName
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
        throw "Required North-coast audit input not found: $inputPath"
    }
    Copy-Item -LiteralPath $inputPath `
        -Destination (Join-Path $stagingData $inputName) -Force
}
$cftoPlugin = Join-Path $LoreRimRoot `
    "mods\Carriage and Ferry Travel Overhaul - Fixes and Winterhold\CFTO.esp"
if (-not (Test-Path -LiteralPath $cftoPlugin -PathType Leaf)) {
    throw "Required CFTO plugin not found: $cftoPlugin"
}
Copy-Item -LiteralPath $cftoPlugin `
    -Destination (Join-Path $stagingData "CFTO.esp") -Force
Copy-Item -LiteralPath $pluginPath `
    -Destination (Join-Path $stagingData (Split-Path -Leaf $pluginPath)) `
    -Force

[System.IO.File]::WriteAllText(
    $pluginsList,
    "*CFTO.esp`r`n*DiegeticTravelBoatNorthCoast.esp`r`n",
    [System.Text.UTF8Encoding]::new($false)
)

$arguments = @(
    "-sse",
    "-D:$stagingData",
    "-P:$pluginsList",
    "-IKnowWhatImDoing",
    "-nobuildrefs",
    "-autoload",
    "-autoexit",
    "-script:$scriptPath"
)
$process = Start-Process -FilePath $xeditPath -ArgumentList $arguments `
    -WindowStyle Hidden -PassThru
$deadline = [DateTime]::UtcNow.AddMinutes(3)
$terminalStatus = $null
while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
        $terminalStatus = (Get-Content -LiteralPath $statusPath -Raw).Trim()
        if ($terminalStatus -in @("success", "failed")) {
            break
        }
    }
    Start-Sleep -Milliseconds 200
    $process.Refresh()
}
if ($terminalStatus -in @("success", "failed") -and -not $process.HasExited) {
    $null = $process.WaitForExit(15000)
    $process.Refresh()
}
if (-not $process.HasExited) {
    Stop-Process -Id $process.Id -Force
}
if ($terminalStatus -eq "failed") {
    $detail = if (Test-Path -LiteralPath $errorPath -PathType Leaf) {
        (Get-Content -LiteralPath $errorPath -Raw).Trim()
    } else {
        "no error detail was written"
    }
    throw "North-coast audit failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "North-coast audit did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "North-coast audit did not create its report."
}

$report = Get-Content -LiteralPath $reportPath
$questIdLine = $report | Where-Object { $_ -match '^QUEST_FIXED_FORM_ID=' }
if (@($questIdLine).Count -ne 1) {
    throw "North-coast audit report does not identify one quest FormID."
}
$expectedQuestId = [Convert]::ToUInt32(
    ($questIdLine -split '=', 2)[1],
    16
)
$seqBytes = [System.IO.File]::ReadAllBytes($seqPath)
if ($seqBytes.Length -ne 4) {
    throw "North-coast SEQ is not exactly one FormID."
}
$actualQuestId = [BitConverter]::ToUInt32($seqBytes, 0)
if ($actualQuestId -ne $expectedQuestId) {
    throw ("North-coast SEQ quest mismatch: expected {0:X8}, got {1:X8}" -f `
        $expectedQuestId, $actualQuestId)
}

$report
Write-Host "PASS source -> seven public providers plus gated Windstad and Icewater private services"
Write-Host "PASS scope -> Frostflow destination-only from all nine providers"
Write-Host "PASS fares -> regional CFTO fare, 100-gold Volkihar outbound, free Volkihar return"
Write-Host ("PASS SEQ -> start-game quest {0:X8}" -f $actualQuestId)
