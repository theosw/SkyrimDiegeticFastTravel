param(
    [switch]$RequireNativeBuild
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\parchment-picker"
$modRoot = Join-Path $moduleRoot "mod"
$nordenMarkerNames = @(
    "norden-town.dds",
    "norden-settlement.dds",
    "norden-farm.dds",
    "norden-wood-mill.dds",
    "norden-mine.dds",
    "norden-riften-capital.dds",
    "norden-windhelm-capital.dds",
    "norden-whiterun-capital.dds",
    "norden-solitude-capital.dds",
    "norden-markarth-capital.dds",
    "norden-winterhold-capital.dds",
    "norden-morthal-capital.dds",
    "norden-falkreath-capital.dds",
    "norden-dawnstar-capital.dds",
    "norden-shipwreck.dds",
    "norden-docks.dds",
    "thin-circle-selection-ring.dds",
    "thin-circle-oneway-selection-ring.dds",
    "parchment-thin-selection-ring.dds",
    "parchment-thin-oneway-selection-ring.dds",
    "norden-roundtrip-selection-ring.dds",
    "norden-oneway-selection-ring.dds"
)

$requiredSources = @(
    (Join-Path $moduleRoot "include\DNT\MenuFrameworkAPI.h"),
    (Join-Path $moduleRoot "include\DNT\ParchmentCore.h"),
    (Join-Path $moduleRoot "include\DNT\ParchmentMenu.h"),
    (Join-Path $moduleRoot "include\DNT\PricingConfig.h"),
    (Join-Path $moduleRoot "include\DNT\TravelCatalog.h"),
    (Join-Path $moduleRoot "include\DNT\TravelRuntime.h"),
    (Join-Path $moduleRoot "mod\SKSE\Plugins\DiegeticTravel.ini"),
    (Join-Path $moduleRoot "mod\SKSE\Plugins\DiegeticTravel\travel_catalog.tsv"),
    (Join-Path $moduleRoot "mod\Scripts\Source\DNT_ParchmentNative.psc"),
    (Join-Path $moduleRoot "mod\Scripts\Source\DNT_TravelCompatibility.psc"),
    (Join-Path $moduleRoot "mod\Scripts\Source\DNT_WizardParchmentFragment.psc"),
    (Join-Path $moduleRoot "mod\Scripts\Source\DNT_WizardParchmentPicker.psc"),
    (Join-Path $moduleRoot "src\MenuFrameworkAPI.cpp"),
    (Join-Path $moduleRoot "src\Papyrus.cpp"),
    (Join-Path $moduleRoot "src\ParchmentCore.cpp"),
    (Join-Path $moduleRoot "src\ParchmentMenu.cpp"),
    (Join-Path $moduleRoot "src\PricingConfig.cpp"),
    (Join-Path $moduleRoot "src\Plugin.cpp")
    (Join-Path $moduleRoot "src\TravelCatalog.cpp")
    (Join-Path $moduleRoot "src\TravelRuntime.cpp")
    (Join-Path $projectRoot "assets\route-overlays\boat-route-chalk-overlay.png")
    (Join-Path $projectRoot "assets\user-authored\stylized-docks-marker.png")
    (Join-Path $projectRoot "assets\user-authored\stylized-ship-marker.png")
    (Join-Path $projectRoot "assets\user-authored\winterhold-marker.png")
    (Join-Path $projectRoot "assets\user-authored\wizard-hat-marker.png")
    (Join-Path $projectRoot "assets\vanilla-interface\hold-capitals\whiterun-dragonsreach.png")
    (Join-Path $projectRoot "assets\vanilla-interface\hold-capitals\riften-mistveil-keep.png")
    (Join-Path $projectRoot "assets\vanilla-interface\hold-capitals\solitude-blue-palace.png")
    (Join-Path $projectRoot "assets\vanilla-interface\hold-capitals\windhelm-palace-of-the-kings.png")
    (Join-Path $projectRoot "assets\vanilla-interface\hold-capitals\markarth-understone-keep.png")
    (Join-Path $projectRoot "assets\vanilla-interface\hold-capitals\dawnstar-white-hall.png")
    (Join-Path $projectRoot "assets\vanilla-interface\hold-capitals\morthal-highmoon-hall.png")
    (Join-Path $projectRoot "assets\vanilla-interface\hold-capitals\winterhold-college.png")
    (Join-Path $projectRoot "assets\vanilla-interface\hold-capitals\falkreath-jarl-longhouse.svg")
    (Join-Path $projectRoot "assets\vanilla-interface\town-marker.svg")
    (Join-Path $projectRoot "assets\vanilla-interface\docks-marker.svg")
    (Join-Path $projectRoot "assets\vanilla-interface\shipwreck-marker.svg")
    (Join-Path $projectRoot "dependencies.lock.json")
    (Join-Path $projectRoot "tools\Build-BoatRouteChalkTexture.ps1")
    (Join-Path $projectRoot "tools\Build-StylizedDocksMarker.ps1")
    (Join-Path $projectRoot "tools\Build-StylizedShipMarker.ps1")
    (Join-Path $projectRoot "tools\Build-StylizedWizardMarkers.ps1")
    (Join-Path $projectRoot "tools\Build-VanillaHoldCapitalMarkers.ps1")
    (Join-Path $projectRoot "tools\Build-CarriageParchmentMarkers.ps1")
    (Join-Path $projectRoot "tools\Build-NordenCarriageMarkers.ps1")
    (Join-Path $projectRoot "tools\Build-NordenSelectionRing.ps1")
    (Join-Path $projectRoot "tools\Build-CalibratedSelectionRings.ps1")
    (Join-Path $projectRoot "tools\Remove-EdgeBackground.py")
    (Join-Path $projectRoot "tools\Fade-DarkMatte.py")
    (Join-Path $projectRoot "tools\Extract-TransparentComponent.py")
    (Join-Path $projectRoot "tools\Normalize-TransparentMarker.py")
    (Join-Path $projectRoot "assets\diegetic-travel\selection-rings\thin-circle-select.png")
    (Join-Path $projectRoot "assets\diegetic-travel\selection-rings\parchment-arrows-thin.png")
    (Join-Path $projectRoot "assets\norden-interface\selection-ring\SOURCE.md")
    (Join-Path $projectRoot "assets\norden-interface\selection-ring\norden-roundtrip-selection-ring.svg")
    (Join-Path $projectRoot "assets\norden-interface\selection-ring\selection-ring-cropped.svg")
    (Join-Path $projectRoot "tools\map-coordinate-calibrator\public\markers\norden-roundtrip-selection-ring-cropped.png")
    (Join-Path $projectRoot "tools\Build-VanillaParchmentMarkers.ps1")
    (Join-Path $projectRoot "tools\Audit-NativeDependencies.ps1")
    (Join-Path $projectRoot "THIRD_PARTY_NOTICES.txt")
)
$requiredSources += Get-ChildItem -LiteralPath (Join-Path $projectRoot `
    "assets\norden-interface\carriage-markers") -Filter "*.svg" -File |
    Select-Object -ExpandProperty FullName
if (($requiredSources | Where-Object { $_ -like "*\assets\norden-interface\carriage-markers\*.svg" }).Count -ne 14) {
    throw "Expected exactly fourteen authorized NORDIC UI marker SVG sources."
}
foreach ($source in $requiredSources) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Missing parchment-picker source: $source"
    }
}

$travelCatalogPath = Join-Path $moduleRoot "mod\SKSE\Plugins\DiegeticTravel\travel_catalog.tsv"
$travelCatalogLocations = @(Get-Content -LiteralPath $travelCatalogPath | Where-Object {
    $_.StartsWith("location`t")
})
if ($travelCatalogLocations.Count -ne 28) {
    throw "Native carriage catalogue must contain exactly 28 locations."
}
$embassyRow = "location`tthalmor_embassy`tThalmor Embassy`t0.317566`t0.169034`tCFTO.esp`t0x0B6E54`tone_way"
if ($travelCatalogLocations -notcontains $embassyRow) {
    throw "Native carriage catalogue is missing the authored CFTO Thalmor Embassy handoff."
}

$carriageNetworkPath = Join-Path $projectRoot "modules\carriage-parchment\config\network.json"
$carriageNetwork = Get-Content -LiteralPath $carriageNetworkPath -Raw | ConvertFrom-Json
$carriageProviderPath = Join-Path $projectRoot "config\carriage_provider.json"
$carriageProvider = Get-Content -LiteralPath $carriageProviderPath -Raw | ConvertFrom-Json
$expectedPrivateOrigins = [ordered]@{
    lakeview_manor = "CFTO.esp|0x0CB329"
    winstad_manor = "CFTO.esp|0x0CB32A"
    heljarchen_hall = "CFTO.esp|0x0CB32B"
}
$privateOriginProperties = @($carriageProvider.conditional_private_origins.PSObject.Properties)
if ($privateOriginProperties.Count -ne $expectedPrivateOrigins.Count) {
    throw "Carriage provider must define exactly three conditional private origins."
}
foreach ($entry in $expectedPrivateOrigins.GetEnumerator()) {
    $configured = $carriageProvider.conditional_private_origins.($entry.Key)
    if ($null -eq $configured -or $configured.driver_base -ne $entry.Value) {
        throw "Private carriage origin mapping differs for $($entry.Key)."
    }
}
$carriageStops = @($carriageNetwork.stops)
if ($carriageStops.Count -ne $travelCatalogLocations.Count) {
    throw "Carriage authoring/runtime stop counts differ: JSON=$($carriageStops.Count) TSV=$($travelCatalogLocations.Count)"
}
$oneWayIds = @($carriageNetwork.return_service_model.one_way_destinations)
$questLockedIds = @($carriageNetwork.return_service_model.conditional_private_origins)
for ($index = 0; $index -lt $carriageStops.Count; $index += 1) {
    $stop = $carriageStops[$index]
    $fields = $travelCatalogLocations[$index] -split "`t"
    $expectedAvailability = if ($questLockedIds -contains $stop.id) {
        "quest_locked"
    } elseif ($oneWayIds -contains $stop.id) {
        "one_way"
    } else {
        "open"
    }
    if ($fields.Count -ne 8 -or
        $fields[1] -ne $stop.id -or
        $fields[2] -ne $stop.name -or
        [Math]::Abs(([double]$fields[3]) - ([double]$stop.map_position[0])) -gt 0.0000005 -or
        [Math]::Abs(([double]$fields[4]) - ([double]$stop.map_position[1])) -gt 0.0000005 -or
        $fields[7] -ne $expectedAvailability) {
        throw "Carriage JSON/TSV parity failed at ordered stop $index ($($stop.id))."
    }
}

$boatProviderContracts = @(
    @{
        Name = "Lake Honrich"
        Network = "modules\boat-honrich\config\network.json"
        Picker = "modules\boat-honrich\mod\Scripts\Source\DNT_BoatParchmentPicker.psc"
    },
    @{
        Name = "Lake Ilinalta"
        Network = "modules\boat-ilinalta\config\network.json"
        Picker = "modules\boat-ilinalta\mod\Scripts\Source\DNT_IlinaltaBoatParchmentPicker.psc"
    },
    @{
        Name = "North coast"
        Network = "modules\boat-north-coast\config\network.json"
        Picker = "modules\boat-north-coast\mod\Scripts\Source\DNT_NorthCoastBoatParchmentPicker.psc"
    },
    @{
        Name = "Solstheim"
        Network = "modules\boat-solstheim\config\network.json"
        Picker = "modules\boat-solstheim\mod\Scripts\Source\DNT_SolstheimBoatParchmentPicker.psc"
    }
)
$boatPaymentPositions = @{}
foreach ($contract in $boatProviderContracts) {
    $networkPath = Join-Path $projectRoot $contract.Network
    $pickerPath = Join-Path $projectRoot $contract.Picker
    $network = Get-Content -LiteralPath $networkPath -Raw | ConvertFrom-Json
    $fareLabels = @($network.ui_elements | Where-Object { $_.id -eq "fare_label" })
    if ($fareLabels.Count -ne 1 -or @($fareLabels[0].map_position).Count -ne 2) {
        throw "$($contract.Name) authoring data must define exactly one two-coordinate fare_label."
    }

    $picker = Get-Content -LiteralPath $pickerPath -Raw
    $positionMatches = [regex]::Matches(
        $picker,
        'SetPaymentLabelPosition\(\s*ActiveRequest,\s*([0-9.]+),\s*([0-9.]+)\s*\)')
    if ($positionMatches.Count -ne 1) {
        throw "$($contract.Name) runtime must set exactly one explicit payment-label position."
    }

    $runtimeX = [double]::Parse($positionMatches[0].Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
    $runtimeY = [double]::Parse($positionMatches[0].Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
    $authoringX = [double]$fareLabels[0].map_position[0]
    $authoringY = [double]$fareLabels[0].map_position[1]
    if ([Math]::Abs($runtimeX - $authoringX) -gt 0.0000005 -or
        [Math]::Abs($runtimeY - $authoringY) -gt 0.0000005) {
        throw "$($contract.Name) runtime/authoring payment-label positions differ."
    }
    $boatPaymentPositions[$contract.Name] = @($authoringX, $authoringY)
}

$honrichPaymentPosition = $boatPaymentPositions["Lake Honrich"]
$northCoastPaymentPosition = $boatPaymentPositions["North coast"]
if ([Math]::Abs($honrichPaymentPosition[0] - $northCoastPaymentPosition[0]) -gt 0.0000005 -or
    [Math]::Abs($honrichPaymentPosition[1] - $northCoastPaymentPosition[1]) -gt 0.0000005) {
    throw "Lake Honrich payment-label position must match the north-coast route."
}

$forbiddenAssetExtensions = @(".png", ".jpg", ".jpeg", ".dds", ".svg", ".wav", ".xwm", ".fuz")
$shippedAssets = Get-ChildItem -LiteralPath $modRoot -Recurse -File | Where-Object {
    $forbiddenAssetExtensions -contains $_.Extension.ToLowerInvariant()
}
$expectedAssets = @(
    (Join-Path $modRoot "textures\DiegeticTravel\docks-marker.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\shipwreck-marker.dds"),
    (Join-Path $modRoot "textures\DiegeticTravel\whiterun-dragonsreach.dds")
    (Join-Path $modRoot "textures\DiegeticTravel\riften-mistveil-keep.dds")
    (Join-Path $modRoot "textures\DiegeticTravel\solitude-blue-palace.dds")
    (Join-Path $modRoot "textures\DiegeticTravel\windhelm-palace-of-the-kings.dds")
    (Join-Path $modRoot "textures\DiegeticTravel\markarth-understone-keep.dds")
    (Join-Path $modRoot "textures\DiegeticTravel\dawnstar-white-hall.dds")
    (Join-Path $modRoot "textures\DiegeticTravel\morthal-highmoon-hall.dds")
    (Join-Path $modRoot "textures\DiegeticTravel\winterhold-college.dds")
    (Join-Path $modRoot "textures\DiegeticTravel\falkreath-jarl-longhouse.dds")
    (Join-Path $modRoot "textures\DiegeticTravel\town-marker.dds")
)
$expectedAssets += $nordenMarkerNames | ForEach-Object {
    Join-Path $modRoot "textures\DiegeticTravel\$_"
}
$unexpectedAssets = @($shippedAssets | Where-Object { $expectedAssets -notcontains $_.FullName })
if ($unexpectedAssets.Count -gt 0 -or $shippedAssets.Count -ne $expectedAssets.Count) {
    throw "Parchment module contains an unexpected artwork/audio set: $($shippedAssets.FullName -join ', ')"
}

$selectionRingHashes = [ordered]@{
    "norden-roundtrip-selection-ring.dds" = "A8CED99555B7A324F629276E9664F043D0E044690E930A1636B905C059D1E9A3"
    "norden-oneway-selection-ring.dds" = "C0FA0372829E39878FD561A91D889E1649FD6B2074B527EBB24FB262479E4A5A"
}
foreach ($selectionRing in $selectionRingHashes.GetEnumerator()) {
    $selectionRingPath = Join-Path $modRoot "textures\DiegeticTravel\$($selectionRing.Key)"
    $actualHash = (Get-FileHash -LiteralPath $selectionRingPath -Algorithm SHA256).Hash
    if ($actualHash -ne $selectionRing.Value) {
        throw "Calibrated selection-ring hash mismatch: $($selectionRing.Key) expected=$($selectionRing.Value) actual=$actualHash"
    }
}

$nativeScript = Get-Content -Raw (Join-Path $modRoot "Scripts\Source\DNT_ParchmentNative.psc")
$originServiceScript = Get-Content -Raw (Join-Path $projectRoot "mod\Scripts\Source\DNT_OriginService.psc")
$travelCompatibilityScript = Get-Content -Raw (Join-Path $modRoot "Scripts\Source\DNT_TravelCompatibility.psc")
$providerScript = Get-Content -Raw (Join-Path $modRoot "Scripts\Source\DNT_WizardParchmentPicker.psc")
$papyrusSource = Get-Content -Raw (Join-Path $moduleRoot "src\Papyrus.cpp")
$settingsHeader = Get-Content -Raw (Join-Path $moduleRoot "include\DNT\PricingConfig.h")
$settingsSource = Get-Content -Raw (Join-Path $moduleRoot "src\PricingConfig.cpp")
$runtimeSource = Get-Content -Raw (Join-Path $moduleRoot "src\TravelRuntime.cpp")
$pricingIni = Get-Content -Raw (Join-Path $modRoot "SKSE\Plugins\DiegeticTravel.ini")
$coordinatorScript = Get-Content -Raw (Join-Path $projectRoot "mod\Scripts\Source\DNT_TravelCoordinator.psc")
$carriagePickerScript = Get-Content -Raw (Join-Path $projectRoot "modules\carriage-parchment\mod\Scripts\Source\DNT_CarriageParchmentPicker.psc")
$privateOriginHex = [ordered]@{
    lakeview_manor = "0x0CB329"
    winstad_manor = "0x0CB32A"
    heljarchen_hall = "0x0CB32B"
}
foreach ($entry in $privateOriginHex.GetEnumerator()) {
    $mappingPattern = 'Game\.GetFormFromFile\(' + [regex]::Escape($entry.Value) +
        ',\s*"CFTO\.esp"\)[\s\S]{0,100}?Return\s+"' + [regex]::Escape($entry.Key) + '"'
    if ($coordinatorScript -notmatch $mappingPattern) {
        throw "Coordinator is missing the audited private carriage mapping for $($entry.Key)."
    }
}
if ($coordinatorScript -notmatch 'Function\s+GetPrivateCarriageOrigin\s*\(Actor\s+speaker\)' -or
    $coordinatorScript -notmatch [regex]::Escape('!speaker || !IsFreeRideForSpeaker(speaker)')) {
    throw "Private carriage lookup must require an exact free-faction speaker."
}
$privateLookupIndex = $carriagePickerScript.IndexOf("Coordinator.GetPrivateCarriageOrigin(Speaker)", [StringComparison]::Ordinal)
$wciLookupIndex = $carriagePickerScript.IndexOf("Coordinator.GetWciInnOrigin(Speaker)", [StringComparison]::Ordinal)
if ($privateLookupIndex -lt 0 -or $wciLookupIndex -lt 0 -or $privateLookupIndex -gt $wciLookupIndex -or
    $carriagePickerScript -notmatch [regex]::Escape('CARRIAGE_PRIVATE_ORIGIN_ACCEPTED') -or
    $carriagePickerScript -notmatch 'FreeRide\s*=\s*True') {
    throw "Carriage picker must accept private free drivers before the WCI fallback."
}
foreach ($requiredToken in @("BuildWizardRequest", "ResolveCarriageDestinationMarker", "GetWizardFare", "ResolveFerryFare", "RequestDialogueClose", "BeginRequest", "SetSourceLabel", "SetPaymentLabelPosition", "SetMarkerTextures", "SetOriginMarkerTexture", "SetSelectionRingTexture", "SetRouteOrigin", "AddRouteLandmark", "AddDestination", "SetDestinationMarkerScale", "SetDestinationSelectionRingStyle", "SetDestinationSelectionRingTexture", "Show", "Cancel", "DNT_ParchmentResult")) {
    if ($nativeScript -notmatch [regex]::Escape($requiredToken) -and
        $providerScript -notmatch [regex]::Escape($requiredToken)) {
        throw "Parchment Papyrus contract is missing token: $requiredToken"
    }
}

$wizardMap = Get-Content -LiteralPath (Join-Path $moduleRoot "config\wizard-map.json") -Raw | ConvertFrom-Json
$wizardNetwork = Get-Content -LiteralPath (Join-Path $projectRoot "modules\wizard-guides\config\network.json") -Raw | ConvertFrom-Json
$expectedFallbackTexture = "Data/textures/dungeons/imperial/battlemap01.dds"
$expectedFallbackCrop = @(0.0, 0.0, 1.0, 0.736328)
$expectedFallbackX = @(1.06506646, 0.03186359, -0.04444646)
$expectedFallbackY = @(0.0227157, 1.03031003, -0.05573539)
foreach ($formalMap in @($wizardMap.map, $carriageNetwork.map)) {
    $fallback = $formalMap.fallback
    if ($null -eq $fallback -or
        $fallback.texture -ne $expectedFallbackTexture -or
        [Math]::Abs([double]$fallback.art_aspect_ratio - 1.35809) -gt 0.0000005 -or
        @($fallback.uv_crop).Count -ne 4 -or
        @($fallback.coordinate_transform.x).Count -ne 3 -or
        @($fallback.coordinate_transform.y).Count -ne 3) {
        throw "Formal map is missing the calibrated vanilla battle-map fallback profile."
    }
    for ($index = 0; $index -lt 4; $index += 1) {
        if ([Math]::Abs([double]$fallback.uv_crop[$index] - $expectedFallbackCrop[$index]) -gt 0.0000005) {
            throw "Formal fallback UV crop differs at index $index."
        }
    }
    for ($index = 0; $index -lt 3; $index += 1) {
        if ([Math]::Abs([double]$fallback.coordinate_transform.x[$index] - $expectedFallbackX[$index]) -gt 0.0000005 -or
            [Math]::Abs([double]$fallback.coordinate_transform.y[$index] - $expectedFallbackY[$index]) -gt 0.0000005) {
            throw "Formal fallback coordinate transform differs at index $index."
        }
    }
}
$expectedWizardStops = @($wizardMap.stops | Select-Object -Skip 1)
$wizardNetworkStops = @($wizardNetwork.destinations | Select-Object -Skip 1)
$wizardLinks = @($wizardNetwork.destinations[0].links)
$nativeWizardMatches = [regex]::Matches(
    $papyrusSource,
    'WizardDestination\{\s*"([^"]+)",\s*"([^"]+)",\s*([0-9.]+)F,\s*([0-9.]+)F,')
$papyrusWizardMatches = [regex]::Matches(
    $providerScript,
    'SelectionIndex\s*==\s*([0-9]+)\s*\r?\n\s*Return\s+"([^"]+)"')
if ($expectedWizardStops.Count -ne 7 -or
    $wizardNetworkStops.Count -ne 7 -or
    $wizardLinks.Count -ne 7 -or
    $nativeWizardMatches.Count -ne 7 -or
    $papyrusWizardMatches.Count -ne 7) {
    throw "Wizard ordered parity requires exactly seven destinations in every source."
}
for ($index = 0; $index -lt 7; $index += 1) {
    $expected = $expectedWizardStops[$index]
    $networkStop = $wizardNetworkStops[$index]
    $nativeMatch = $nativeWizardMatches[$index]
    $papyrusMatch = $papyrusWizardMatches[$index]
    $nativeX = [double]::Parse($nativeMatch.Groups[3].Value, [Globalization.CultureInfo]::InvariantCulture)
    $nativeY = [double]::Parse($nativeMatch.Groups[4].Value, [Globalization.CultureInfo]::InvariantCulture)
    if ($wizardLinks[$index] -ne $expected.id -or
        $networkStop.id -ne $expected.id -or
        $networkStop.name -ne $expected.name -or
        $nativeMatch.Groups[1].Value -ne $expected.id -or
        $nativeMatch.Groups[2].Value -ne $expected.name -or
        [Math]::Abs($nativeX - ([double]$expected.map_position[0])) -gt 0.0000005 -or
        [Math]::Abs($nativeY - ([double]$expected.map_position[1])) -gt 0.0000005 -or
        [int]$papyrusMatch.Groups[1].Value -ne $index -or
        $papyrusMatch.Groups[2].Value -ne $expected.id) {
        throw "Wizard JSON/C++/Papyrus ordered parity failed at destination $index ($($expected.id))."
    }
}

$retiredNativeSurface = @(
    "PlayPresentation",
    "QueuePresentation",
    "ValidatePresentation",
    "PresentationWindowSeconds",
    "CompileAndRunWithRuntimeRelocation",
    "AddPresentationSubtitle",
    "SetDestinationMarkerTexture"
)
$nativeSurface = @(
    $nativeScript,
    $papyrusSource,
    (Get-Content -Raw (Join-Path $moduleRoot "include\DNT\ParchmentCore.h")),
    (Get-Content -Raw (Join-Path $moduleRoot "include\DNT\ParchmentMenu.h")),
    (Get-Content -Raw (Join-Path $moduleRoot "src\ParchmentCore.cpp")),
    (Get-Content -Raw (Join-Path $moduleRoot "src\ParchmentMenu.cpp"))
) -join "`n"
foreach ($retiredToken in $retiredNativeSurface) {
    if ($nativeSurface -match [regex]::Escape($retiredToken)) {
        throw "Retired native API remains in the maintained runtime: $retiredToken"
    }
}
if ($coordinatorScript -match 'Bool\s+Function\s+Purchase\s*\(' -or
    $originServiceScript -match 'Bool\s+Function\s+(CommitDestination|PurchaseDestination)\s*\(') {
    throw "Retired carriage purchase wrappers remain in the Papyrus runtime."
}
if ($nativeScript -notmatch [regex]::Escape("ObjectReference Function ResolveCarriageDestinationMarker(String DestinationId) Global Native")) {
    throw "Native Papyrus contract must return the catalogue marker as an ObjectReference."
}
if ($nativeScript -notmatch [regex]::Escape("Int Function BuildWizardRequest(String RequestId, ObjectReference SourceRef, Int Fare) Global Native")) {
    throw "Native Papyrus contract is missing the single-call wizard request builder."
}
if ($originServiceScript -notmatch [regex]::Escape("DNT_ParchmentNative.ResolveCarriageDestinationMarker(destinationId)")) {
    throw "Carriage purchase must resolve its destination marker through the native catalogue."
}
foreach ($retiredMarkerRegistryToken in @(
    "Function GetCarriageDestinationMarker",
    "DNT_ParchmentNative.GetCarriageHours",
    'Game.GetFormFromFile(0x0A7B39, "CFTO.esp")',
    'Game.GetFormFromFile(0x0B6E43, "CFTO.esp")'
)) {
    if ($originServiceScript -match [regex]::Escape($retiredMarkerRegistryToken)) {
        throw "Carriage purchase still contains retired duplicated marker logic: $retiredMarkerRegistryToken"
    }
}
foreach ($compatibilityToken in @(
    'Game.GetFormFromFile(0x000808, "WizardingTraversal.esl") as MagicEffect',
    'PlayerRef.HasMagicEffect(ApparitionHolder)',
    'Game.GetGameSettingFloat("fFastTravelSpeedMult")',
    'TravelSpeed >= 99999.0',
    'APPARITION_CHECK',
    'PlayerRef.MoveTo(DestinationMarker)',
    'Game.FastTravel(DestinationMarker)',
    'TRAVEL_COMPAT mode=apparition',
    'TRAVEL_COMPAT mode=fast_travel'
)) {
    if ($travelCompatibilityScript -notmatch [regex]::Escape($compatibilityToken)) {
        throw "Optional Apparition compatibility is missing contract: $compatibilityToken"
    }
}
if ($travelCompatibilityScript -match 'SetGameSettingFloat' -or
    $travelCompatibilityScript -match 'WizardingTraversal\.esl' -and
    $travelCompatibilityScript -match 'Property') {
    throw "Apparition compatibility may read the speed override but must not mutate globals or require a hard plugin property."
}
foreach ($destination in @("whiterun", "riften", "solitude", "windhelm", "markarth", "dawnstar", "morthal")) {
    if ($papyrusSource -notmatch ('"' + [regex]::Escape($destination) + '"')) {
        throw "Native wizard request builder is missing destination: $destination"
    }
}
foreach ($artToken in @("textures/terrain/tamriel/skyrim.dds", "textures/dungeons/imperial/battlemap01.dds", "norden-winterhold-capital.dds", "norden-whiterun-capital.dds", "norden-riften-capital.dds", "norden-solitude-capital.dds", "norden-windhelm-capital.dds", "norden-markarth-capital.dds", "norden-dawnstar-capital.dds", "norden-morthal-capital.dds", "norden-roundtrip-selection-ring.dds", "FormalMapFallbackArtwork", "SetFallbackArtwork", "SetMarkerTextures", "SetOriginMarkerTexture", "SetSelectionRingTexture", "AddStyledDestination", "1.414075", "1.35809", "0.736328", "1.06506646", "0.03186359", "-0.04444646", "0.02271570", "1.03031003", "-0.05573539", "0.088379", "0.187012", "0.932129", "0.783691", "0.750802", "0.167836")) {
    if ($papyrusSource -notmatch [regex]::Escape($artToken)) {
        throw "Native wizard request builder is missing artwork contract token: $artToken"
    }
}
$preferenceSource = $settingsHeader + "`n" + $settingsSource + "`n" +
    $runtimeSource + "`n" + $pricingIni + "`n" + $papyrusSource
foreach ($preferenceToken in @(
    "bool preferFormalMapArtwork{ true }",
    'qualifiedKey == "display.preferformalmapartwork"',
    "loadedSettings.preferFormalMapArtwork",
    "PreferFormalMapArtwork=true",
    "!pricing.preferFormalMapArtwork",
    "!settings.preferFormalMapArtwork"
)) {
    if ($preferenceSource -notmatch [regex]::Escape($preferenceToken)) {
        throw "Native formal-map preference is missing contract: $preferenceToken"
    }
}
foreach ($wizardBuilderToken in @(
    "DNT_ParchmentNative.BuildWizardRequest",
    'Int DestinationCount = DNT_ParchmentNative.BuildWizardRequest(ActiveRequest, SourceRef, Fare)',
    'DestinationCount != 7',
    'destinations=" + DestinationCount'
)) {
    if ($providerScript -notmatch [regex]::Escape($wizardBuilderToken)) {
        throw "Wizard parchment provider is missing native builder contract: $wizardBuilderToken"
    }
}
foreach ($retiredWizardToken in @(
    "MirabelleBase",
    "MirabellePresentation",
    "DNT_ParchmentNative.PlayPresentation",
    "DNT_ParchmentNative.BeginRequest",
    "DNT_ParchmentNative.AddDestination",
    "DNT_ParchmentNative.SetDestinationMarkerTexture",
    "DNT_ParchmentNative.SetDestinationMarkerScale",
    "DNT_ParchmentNative.SetDestinationSelectionRingStyle",
    "presentationVoice="
)) {
    if ($providerScript -match [regex]::Escape($retiredWizardToken)) {
        throw "Wizard parchment provider still contains retired slow/presentation path: $retiredWizardToken"
    }
}

foreach ($nativeMarkerToken in @(
    "RE::TESObjectREFR* ResolveCarriageDestinationMarker",
    "DNT::TravelRuntime::GetLocation(destinationId)",
    "CARRIAGE_NATIVE_MARKER_READY",
    'RegisterFunction("ResolveCarriageDestinationMarker"'
)) {
    if ($papyrusSource -notmatch [regex]::Escape($nativeMarkerToken)) {
        throw "Native catalogue marker resolver is missing contract: $nativeMarkerToken"
    }
}
foreach ($nativeWizardToken in @(
    "std::int32_t BuildWizardRequest",
    "WizardDestinations",
    "WIZARD_NATIVE_REQUEST_READY",
    "WIZARD_NATIVE_REQUEST_REJECT",
    'RegisterFunction("BuildWizardRequest"'
)) {
    if ($papyrusSource -notmatch [regex]::Escape($nativeWizardToken)) {
        throw "Native wizard request builder is missing contract: $nativeWizardToken"
    }
}
if ($papyrusSource -match [regex]::Escape('RegisterFunction("GetCarriageHours"') -or
    $papyrusSource -match 'float\s+GetCarriageHours\s*\(') {
    throw "The discarded Papyrus carriage-hours lookup must not remain registered."
}
if ($papyrusSource -notmatch [regex]::Escape("Data/textures/DiegeticTravel/norden-oneway-selection-ring.dds")) {
    throw "Native carriage one-way destinations must use the calibrated Norden one-way selection ring."
}
if ($papyrusSource -match [regex]::Escape("Data/textures/DiegeticTravel/thin-circle-oneway-selection-ring.dds")) {
    throw "Native carriage one-way destinations still reference the retired thin-circle one-way ring."
}
foreach ($handoffToken in @(
    "RequestDialogueClose",
    "RE::UI::GetSingleton",
    "RE::UIMessageQueue::GetSingleton",
    "RE::DialogueMenu::MENU_NAME",
    "RE::UI_MESSAGE_TYPE::kHide",
    "PARCHMENT_DIALOGUE_CLOSE_REQUESTED",
    "PARCHMENT_DIALOGUE_CLOSE_SKIPPED",
    "PARCHMENT_DIALOGUE_CLOSE_REJECT"
)) {
    if ($papyrusSource -notmatch [regex]::Escape($handoffToken)) {
        throw "Native dialogue handoff is missing token: $handoffToken"
    }
}
if ($providerScript -match "ConsoleUtil" -or
    $papyrusSource -match [regex]::Escape("script->CompileAndRun(" ) -or
    $papyrusSource -match [regex]::Escape("RELOCATION_ID(21416, 21890)")) {
    throw "Rejected stock CommonLib/ConsoleUtil voice path is still present."
}

$menuSource = Get-Content -Raw (Join-Path $moduleRoot "src\ParchmentMenu.cpp")
$frameworkSource = @(
    (Get-Content -Raw (Join-Path $moduleRoot "include\DNT\MenuFrameworkAPI.h")),
    (Get-Content -Raw (Join-Path $moduleRoot "src\MenuFrameworkAPI.cpp"))
) -join "`n"
foreach ($unusedFrameworkExport in @(
    '"igButton"',
    '"igSetItemDefaultFocus"',
    '"ImDrawList_AddTriangle"',
    '"ImDrawList_AddCircle"',
    '"ImDrawList_AddCircleFilled"'
)) {
    if ($frameworkSource -match [regex]::Escape($unusedFrameworkExport)) {
        throw "Unused Menu Framework export is still a runtime requirement: $unusedFrameworkExport"
    }
}
$presentationSource = $menuSource + "`n" + $frameworkSource
foreach ($fallbackRuntimeToken in @(
    "RE::BSResourceNiBinaryStream",
    "temp_directory_path",
    "MENU_TEXTURE_ARCHIVE_READY",
    "MaxArchivedTextureBytes",
    "PARCHMENT_ART_FALLBACK",
    "fallbackArtwork",
    "preferFallbackArtwork",
    'reason={}',
    '"preference"',
    '"preferred-missing"',
    "coordinateTransform",
    "TransformPoint"
)) {
    if ($presentationSource -notmatch [regex]::Escape($fallbackRuntimeToken)) {
        throw "Native archived/formal artwork fallback is missing contract: $fallbackRuntimeToken"
    }
}
if ($presentationSource -match [regex]::Escape("Map artwork dependency is missing; selection remains available for testing.")) {
    throw "Runtime still treats a blank dependency map as an acceptable testing fallback."
}
foreach ($presentationToken in @(
    "focusedDescription = std::format(",
    '"{} to {}    {} gold"',
    "igInvisibleButton",
    "igGetMousePos",
    "igSetMouseCursor",
    "igPushStyleColor_U32",
    "igPopStyleColor",
    "igSetWindowFontScale",
    "igCalcTextSize",
    "igGetForegroundDrawList_Nil",
    "ImDrawList_AddImage",
    "ImDrawList_AddTriangleFilled",
    "ImDrawList_AddPolyline",
    "ImDrawList_AddConcavePolyFilled",
    "DrawRouteOrigin",
    "DrawRouteLandmark",
    "DrawFerryDestinationMarker",
    "ComputeDestinationHitSizes",
    "routeLandmarks",
    "MakeColor(238, 229, 207, 245)",
    "const auto baseExtent = std::clamp(a_radius, 17.0F, 34.0F)",
    "a_scaleOnlyHighlight",
    "EqualsAsciiInsensitive",
    "isCollegeProvider",
    "isCarriageProvider",
    'destinationTexturePath.find("-capital.dds")',
    "1.25F : 0.84F",
    "markerArtScale",
    "shipwreck-marker.dds",
    "docks-marker.dds",
    "defaultSelectedMarkerTexturePath",
    "defaultIdleMarkerTexturePath",
    "loadedSelectedMarkerTexturePath",
    "loadedIdleMarkerTexturePath",
    "loadedOriginMarkerTexturePath",
    "loadedSelectionRingTexturePath",
    "PARCHMENT_SELECTION_RING_READY",
    "PARCHMENT_SELECTION_RING_SET",
    "ringExtent = extent * a_selectionRingScale * a_destinationRingScale",
    "iconExtent * a_selectionRingOffsetX",
    "iconExtent * a_selectionRingOffsetY",
    "PARCHMENT_SELECTION_RING_SCALE_SET",
    "PARCHMENT_DESTINATION_RING_STYLE_SET",
    "a_event->device == RE::INPUT_DEVICE::kMouse",
    "selectedMarkerTexture = destinationTexture->second",
    "PARCHMENT_ORIGIN_MARKER_SET",
    "PARCHMENT_MARKERS_SET",
    "MakeColor(170, 174, 178, 168)",
    "navigationFocusEngaged.store(false",
    "navigationFocusEngaged.load",
    "MakeColor(18, 18, 18, 150)",
    "##DNT-destination-{}",
    "PARCHMENT_HUD_HIDDEN",
    "PARCHMENT_HUD_RESTORED",
    "PARCHMENT_HUD_LAYER_HIDDEN",
    "PARCHMENT_HUD_LAYER_RESTORED",
    '"_root._alpha"',
    '"TrueHUD"',
    '"lvlWidget"',
    '"STBActiveEffects"',
    "GetVisible()",
    "SetVisible(false)"
)) {
    if ($presentationSource -notmatch [regex]::Escape($presentationToken)) {
        throw "Parchment presentation lifecycle is missing token: $presentationToken"
    }
}
if ($menuSource -match [regex]::Escape("DrawDestinationHighlight")) {
    throw "Target-style X marker must not remain in the parchment presentation."
}
if ($menuSource -match [regex]::Escape("originRing")) {
    throw "The route origin must use the boat marker without a separate circle."
}
if ($menuSource -notmatch "loadedOriginMarkerTexture\s*\?\s*loadedOriginMarkerTexture\s*:\s*loadedSelectedMarkerTexture") {
    throw "The route origin must use its provider texture with selected-marker fallback."
}
if ($menuSource -match [regex]::Escape("MakeColor(255, 137, 82, 238)")) {
    throw "The sharp bright-red route core must not remain in the parchment presentation."
}
if ($menuSource -notmatch 'a_highlighted\s*&&\s*a_scaleOnlyHighlight\s*\?\s*1\.18F') {
    throw "Scale-only selection must still enlarge its icon."
}
if ($menuSource -match 'if \(a_highlighted && !a_scaleOnlyHighlight\)') {
    throw "Destination selection must not draw the retired red provider halo."
}
if ($menuSource -match 'snapshot\.request\.providerId\s*(==|!=)\s*"(boat|college|carriage)"') {
    throw "Provider presentation policy must use case-insensitive IDs from the runtime boundary."
}
if ($menuSource -match [regex]::Escape('Close map##DNT-cancel') -or
    $menuSource -match [regex]::Escape('cancel_button')) {
    throw "Parchment presentation must rely on Escape/gamepad-B instead of a visible close button."
}
if ($menuSource -match [regex]::Escape([char]0x2014)) {
    throw "Parchment menu source must not use an em dash in the Scaleform-facing footer."
}

if ($RequireNativeBuild) {
    $dll = Join-Path $modRoot "SKSE\Plugins\DNTParchmentPicker.dll"
    $esp = Join-Path $modRoot "DiegeticTravelWizardParchment.esp"
    $seq = Join-Path $modRoot "SEQ\DiegeticTravelWizardParchment.seq"
    $nativePex = Join-Path $modRoot "Scripts\DNT_ParchmentNative.pex"
    $travelCompatibilityPex = Join-Path $modRoot "Scripts\DNT_TravelCompatibility.pex"
    $fragmentPex = Join-Path $modRoot "Scripts\DNT_WizardParchmentFragment.pex"
    $providerPex = Join-Path $modRoot "Scripts\DNT_WizardParchmentPicker.pex"
    $docksMarker = Join-Path $modRoot "textures\DiegeticTravel\docks-marker.dds"
    $shipwreckMarker = Join-Path $modRoot "textures\DiegeticTravel\shipwreck-marker.dds"
    $nordenMarkers = $nordenMarkerNames | ForEach-Object {
        Join-Path $modRoot "textures\DiegeticTravel\$_"
    }
    foreach ($artifact in @($dll, $esp, $seq, $nativePex, $travelCompatibilityPex, $fragmentPex, $providerPex, $docksMarker, $shipwreckMarker) + $nordenMarkers) {
        if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
            throw "Required parchment-picker build artifact not found: $artifact"
        }
        if ((Get-Item -LiteralPath $artifact).Length -le 0) {
            throw "Parchment-picker build artifact is empty: $artifact"
        }
    }
    if ((Get-Item -LiteralPath $seq).Length -ne 4) {
        throw "Wizard parchment SEQ must contain exactly one 4-byte FormID."
    }
    foreach ($nativeContractArtifact in @($dll, $nativePex)) {
        $nativeContractBytes = [IO.File]::ReadAllBytes($nativeContractArtifact)
        $nativeContractText = [Text.Encoding]::ASCII.GetString($nativeContractBytes)
        if (-not $nativeContractText.Contains("ResolveCarriageDestinationMarker")) {
            throw "Native marker resolver is missing from built artifact: $nativeContractArtifact"
        }
    }
}

Write-Host "Parchment-picker audit passed."
Write-Host "Carriage parity: 28 ordered JSON/TSV destinations"
Write-Host "Maintained DDS authoring inventory: $($expectedAssets.Count) assets; release packaging uses its separate 22-texture allowlist"
Write-Host "Wizard parity: 7 ordered JSON/C++/Papyrus destinations"
