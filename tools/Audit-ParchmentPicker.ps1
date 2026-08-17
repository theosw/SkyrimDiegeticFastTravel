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

$nativeScript = Get-Content -Raw (Join-Path $modRoot "Scripts\Source\DNT_ParchmentNative.psc")
$travelCompatibilityScript = Get-Content -Raw (Join-Path $modRoot "Scripts\Source\DNT_TravelCompatibility.psc")
$providerScript = Get-Content -Raw (Join-Path $modRoot "Scripts\Source\DNT_WizardParchmentPicker.psc")
foreach ($requiredToken in @("GetWizardFare", "ResolveFerryFare", "RequestDialogueClose", "BeginRequest", "SetSourceLabel", "SetPaymentLabelPosition", "SetMarkerTextures", "SetOriginMarkerTexture", "SetSelectionRingTexture", "SetRouteOrigin", "AddRouteLandmark", "AddDestination", "SetDestinationMarkerTexture", "SetDestinationMarkerScale", "SetDestinationSelectionRingStyle", "SetDestinationSelectionRingTexture", "Show", "Cancel", "PlayPresentation", "DNT_ParchmentResult")) {
    if ($nativeScript -notmatch [regex]::Escape($requiredToken) -and
        $providerScript -notmatch [regex]::Escape($requiredToken)) {
        throw "Parchment Papyrus contract is missing token: $requiredToken"
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
    if ($providerScript -notmatch ('"' + [regex]::Escape($destination) + '"')) {
        throw "Wizard parchment provider is missing destination: $destination"
    }
}
foreach ($artToken in @("textures/terrain/tamriel/skyrim.dds", "norden-winterhold-capital.dds", "norden-whiterun-capital.dds", "norden-riften-capital.dds", "norden-solitude-capital.dds", "norden-windhelm-capital.dds", "norden-markarth-capital.dds", "norden-dawnstar-capital.dds", "norden-morthal-capital.dds", "norden-roundtrip-selection-ring.dds", "SetMarkerTextures", "SetOriginMarkerTexture", "SetSelectionRingTexture", "SetDestinationMarkerTexture", "TextureUvMinX", "TextureUvMaxY", "1.414075", "0.088379", "0.187012", "0.932129", "0.783691", "0.750802", "0.167836")) {
    if ($providerScript -notmatch [regex]::Escape($artToken)) {
        throw "Wizard parchment provider is missing artwork contract token: $artToken"
    }
}
foreach ($voiceToken in @(
    "MirabelleBase",
    "Voice/Skyrim.esm/FemaleUniqueMirabelleErvine/mg01__000d67d1_1.fuz",
    "Very good. Then we're done here.",
    "MirabellePresentationDurationSeconds = 2.147846",
    "DNT_ParchmentNative.PlayPresentation",
    "WIZARD_PARCHMENT_PRESENTATION_QUEUED",
    "timing=info_on_begin",
    "mapSuppressed=false",
    "presentationSeconds=",
    "fallback=map",
    "Bool VoiceStarted = False",
    "presentationVoice="
)) {
    if ($providerScript -notmatch [regex]::Escape($voiceToken)) {
        throw "Wizard parchment provider is missing Mirabelle presentation token: $voiceToken"
    }
}

$papyrusSource = Get-Content -Raw (Join-Path $moduleRoot "src\Papyrus.cpp")
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
foreach ($voiceToken in @(
    "ExpectedRuntime{ 1, 6, 1170, 0 }",
    "ModernCompileAndRunId = 441582",
    "ExpectedCompileAndRunOffset = 0x33D6A0",
    "ValidatePresentation",
    "PresentationWindowSeconds",
    "CompileAndRunWithRuntimeRelocation",
    "AddPresentationSubtitle",
    "SubtitleManager::GetSingleton",
    "BSSpinLockGuard",
    "subtitleManager->subtitles.push_back",
    "subtitle.forceDisplay = true",
    "REL::ID(a_relocationId)",
    "PARCHMENT_PRESENTATION_QUEUED",
    "PARCHMENT_PRESENTATION_DISPATCH",
    "PARCHMENT_PRESENTATION_REJECT",
    "subtitleAdded=",
    "PauseCurrentDialogue",
    'std::format("SpeakSound \"{}\"", presentation.voicePath)'
)) {
    if ($papyrusSource -notmatch [regex]::Escape($voiceToken)) {
        throw "Native presentation support is missing token: $voiceToken"
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
$presentationSource = $menuSource + "`n" + $frameworkSource
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
    "ImDrawList_AddCircle",
    "ImDrawList_AddImage",
    "ImDrawList_AddCircleFilled",
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
}

Write-Host "Parchment-picker audit passed."
Write-Host "Bundled artwork: 2 user-authored/edited marker assets, 10 Skyrim-derived map markers, 14 open-permission NORDIC UI map markers, and 2 authorized Norden UI selection rings"
Write-Host "Wizard destinations: 7"
