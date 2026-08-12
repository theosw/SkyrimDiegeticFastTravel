param()

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$pickerPath = Join-Path $projectRoot `
    "modules\carriage-parchment\mod\Scripts\Source\DNT_CarriageParchmentPicker.psc"
$originPath = Join-Path $projectRoot "mod\Scripts\Source\DNT_OriginService.psc"
$coordinatorPath = Join-Path $projectRoot "mod\Scripts\Source\DNT_TravelCoordinator.psc"
$networkPath = Join-Path $projectRoot "modules\carriage-parchment\config\network.json"
$providerPath = Join-Path $projectRoot "config\carriage_provider.json"
$generatorPath = Join-Path $projectRoot "tools\xedit\DNT_GeneratePlugin.pas"
$nativePath = Join-Path $projectRoot "modules\parchment-picker\src\Papyrus.cpp"

foreach ($path in @(
    $pickerPath, $originPath, $coordinatorPath, $networkPath,
    $providerPath, $generatorPath, $nativePath
)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required carriage source input not found: $path"
    }
}

function Assert-Contains([string]$Text, [string[]]$Tokens, [string]$Subject) {
    foreach ($token in $Tokens) {
        if ($Text -notmatch [regex]::Escape($token)) {
            throw "$Subject is missing contract: $token"
        }
    }
}

function Assert-Excludes([string]$Text, [string[]]$Tokens, [string]$Subject) {
    foreach ($token in $Tokens) {
        if ($Text -match [regex]::Escape($token)) {
            throw "$Subject retains obsolete contract: $token"
        }
    }
}

$picker = Get-Content -LiteralPath $pickerPath -Raw
$origin = Get-Content -LiteralPath $originPath -Raw
$coordinator = Get-Content -LiteralPath $coordinatorPath -Raw
$generator = Get-Content -LiteralPath $generatorPath -Raw
$native = Get-Content -LiteralPath $nativePath -Raw
$network = Get-Content -LiteralPath $networkPath -Raw | ConvertFrom-Json
$provider = Get-Content -LiteralPath $providerPath -Raw | ConvertFrom-Json

if ($network.stops.Count -ne 27 -or $network.slice -ne "cfto_native_destinations") {
    throw "Carriage network must define all 27 native CFTO destinations."
}
$expectedOneWay = @(
    "darkwater_crossing", "mixwater_mill", "halfmoon_mill", "karthwasten",
    "soljunds_sinkhole", "shors_stone", "heartwood_mill", "stonehills"
)
if (@($network.return_service_model.one_way_destinations).Count -ne 8) {
    throw "Carriage return-service model must define exactly eight one-way stops."
}
foreach ($id in $expectedOneWay) {
    if (@($network.return_service_model.one_way_destinations) -notcontains $id) {
        throw "Carriage return-service model is missing one-way stop: $id"
    }
}
if (@($provider.origins.PSObject.Properties).Count -ne 9) {
    throw "Carriage provider manifest must define exactly nine origins."
}

Assert-Contains $picker @(
    "BuildCarriageRequest", "ConsumeCarriageSelectionId", "Coordinator.Purchase",
    "RequestDialogueClose", "CARRIAGE_PARCHMENT_OPEN"
) "Carriage picker"
Assert-Excludes $picker @(
    "SelectionIds", "GetPublishedFare", "GetPublishedHours", "AddStop",
    "SetRouteOrigin", "AddRouteSegment"
) "Carriage picker"

Assert-Contains $origin @(
    "GetCarriageDestinationMarker", "GetCarriageFare", "GetCarriageHours",
    "DNT_TravelCompatibility.Travel", "PurchaseDestination"
) "Origin service"
Assert-Excludes $origin @(
    "JValue", "JMap", "JArray", "DNT_RouteService", "DialoguePath",
    "Game.FastTravel"
) "Origin service"

foreach ($token in @(
    "Dawnstar", "Falkreath", "Markarth", "Morthal", "Riften", "Solitude",
    "Whiterun", "Windhelm", "Winterhold"
)) {
    Assert-Contains $coordinator @(
        "$($token)Driver", "$($token)Service"
    ) "Travel coordinator"
}
Assert-Contains $coordinator @("GetOriginService", "Purchase") "Travel coordinator"
Assert-Excludes $coordinator @(
    "JValue", "JMap", "JArray", "DialoguePath", "Preload"
) "Travel coordinator"

Assert-Contains $native @(
    "const auto originLocation = std::ranges::find_if(locations",
    "SetSourceLabel(requestId, originLocation->name)",
    "reason=origin_missing"
) "Native carriage request builder"
Assert-Excludes $native @("GetCarriageSourceLabel") "Native carriage request builder"

Assert-Contains $generator @(
    "Manifest.O['origins']", "Token + 'Driver'", "Token + 'Service'"
) "Plugin generator"
Assert-Excludes $generator @(
    "CreateGlobals", "PatchDialogue", "dialogue_runtime", "DNT_RouteService"
) "Plugin generator"

$productSources = @(
    Get-ChildItem -LiteralPath (Join-Path $projectRoot "mod\Scripts\Source") `
        -Filter "DNT_*.psc" -File
    Get-ChildItem -LiteralPath `
        (Join-Path $projectRoot "modules\carriage-parchment\mod\Scripts\Source") `
        -Filter "DNT_*.psc" -File
)
foreach ($source in $productSources) {
    $text = Get-Content -LiteralPath $source.FullName -Raw
    Assert-Excludes $text @("JValue", "JMap", "JArray") $source.Name
}

Write-Host "PASS carriage source -> native 27-stop request, nine scalar origin services"
Write-Host "PASS catalogue source labels -> nine city and seven WCI inn origins"
Write-Host "PASS obsolete runtime -> no graph, JContainers, cached quote, or route geometry path"
