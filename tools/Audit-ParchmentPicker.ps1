param(
    [switch]$RequireNativeBuild
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\parchment-picker"
$modRoot = Join-Path $moduleRoot "mod"

$requiredSources = @(
    (Join-Path $moduleRoot "include\DNT\MenuFrameworkAPI.h"),
    (Join-Path $moduleRoot "include\DNT\ParchmentCore.h"),
    (Join-Path $moduleRoot "include\DNT\ParchmentMenu.h"),
    (Join-Path $moduleRoot "mod\Scripts\Source\DNT_ParchmentNative.psc"),
    (Join-Path $moduleRoot "mod\Scripts\Source\DNT_WizardParchmentFragment.psc"),
    (Join-Path $moduleRoot "mod\Scripts\Source\DNT_WizardParchmentPicker.psc"),
    (Join-Path $moduleRoot "src\MenuFrameworkAPI.cpp"),
    (Join-Path $moduleRoot "src\Papyrus.cpp"),
    (Join-Path $moduleRoot "src\ParchmentCore.cpp"),
    (Join-Path $moduleRoot "src\ParchmentMenu.cpp"),
    (Join-Path $moduleRoot "src\Plugin.cpp")
    (Join-Path $projectRoot "dependencies.lock.json")
    (Join-Path $projectRoot "tools\Audit-NativeDependencies.ps1")
    (Join-Path $projectRoot "THIRD_PARTY_NOTICES.txt")
)
foreach ($source in $requiredSources) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Missing parchment-picker source: $source"
    }
}

$forbiddenAssetExtensions = @(".png", ".jpg", ".jpeg", ".dds", ".svg", ".wav", ".xwm", ".fuz")
$shippedAssets = Get-ChildItem -LiteralPath $modRoot -Recurse -File | Where-Object {
    $forbiddenAssetExtensions -contains $_.Extension.ToLowerInvariant()
}
if ($shippedAssets) {
    throw "Parchment module must not ship third-party artwork/audio: $($shippedAssets.FullName -join ', ')"
}

$nativeScript = Get-Content -Raw (Join-Path $modRoot "Scripts\Source\DNT_ParchmentNative.psc")
$providerScript = Get-Content -Raw (Join-Path $modRoot "Scripts\Source\DNT_WizardParchmentPicker.psc")
foreach ($requiredToken in @("BeginRequest", "SetRouteOrigin", "AddDestination", "Show", "Cancel", "PlayPresentation", "PlayVoiceProbe", "DNT_ParchmentResult")) {
    if ($nativeScript -notmatch [regex]::Escape($requiredToken) -and
        $providerScript -notmatch [regex]::Escape($requiredToken)) {
        throw "Parchment Papyrus contract is missing token: $requiredToken"
    }
}
foreach ($destination in @("whiterun", "riften", "solitude", "windhelm", "markarth", "dawnstar", "morthal")) {
    if ($providerScript -notmatch ('"' + [regex]::Escape($destination) + '"')) {
        throw "Wizard parchment provider is missing destination: $destination"
    }
}
foreach ($artToken in @("battlemap01.dds", "TextureUvMinX", "TextureUvMaxY", "1.358090", "0.736328", "0.752", "0.167")) {
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
foreach ($voiceToken in @(
    "ExpectedRuntime{ 1, 6, 1170, 0 }",
    "ModernCompileAndRunId = 441582",
    "ExpectedCompileAndRunOffset = 0x33D6A0",
    "MirabelleReferenceId = 0x0001C1B9",
    "MirabelleProbeSubtitle",
    "MirabelleProbeDurationSeconds = 2.147846F",
    "ValidatePresentation",
    "PresentationWindowSeconds",
    "CompileAndRunWithRuntimeRelocation",
    "AddPresentationSubtitle",
    "SubtitleManager::GetSingleton",
    "BSSpinLockGuard",
    "subtitleManager->subtitles.push_back",
    "subtitle.forceDisplay = true",
    "REL::ID(a_relocationId)",
    "PARCHMENT_VOICE_PROBE_QUEUED",
    "PARCHMENT_PRESENTATION_QUEUED",
    "PARCHMENT_PRESENTATION_DISPATCH",
    "PARCHMENT_PRESENTATION_REJECT",
    "subtitleAdded=",
    "PauseCurrentDialogue",
    'std::format("SpeakSound \"{}\"", presentation.voicePath)'
)) {
    if ($papyrusSource -notmatch [regex]::Escape($voiceToken)) {
        throw "Runtime-gated Mirabelle voice probe is missing token: $voiceToken"
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
    '"{} - {} gold"',
    "igInvisibleButton",
    "igGetMousePos",
    "igSetMouseCursor",
    "igGetForegroundDrawList_Nil",
    "ImDrawList_AddCircle",
    "ImDrawList_AddPolyline",
    "ImDrawList_AddConcavePolyFilled",
    "DrawRouteConnection",
    "DrawRouteOrigin",
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
if ($menuSource -match [regex]::Escape([char]0x2014)) {
    throw "Parchment menu source must not use an em dash in the Scaleform-facing footer."
}

if ($RequireNativeBuild) {
    $dll = Join-Path $modRoot "SKSE\Plugins\DNTParchmentPicker.dll"
    $esp = Join-Path $modRoot "DiegeticTravelWizardParchment.esp"
    $seq = Join-Path $modRoot "SEQ\DiegeticTravelWizardParchment.seq"
    $nativePex = Join-Path $modRoot "Scripts\DNT_ParchmentNative.pex"
    $fragmentPex = Join-Path $modRoot "Scripts\DNT_WizardParchmentFragment.pex"
    $providerPex = Join-Path $modRoot "Scripts\DNT_WizardParchmentPicker.pex"
    foreach ($artifact in @($dll, $esp, $seq, $nativePex, $fragmentPex, $providerPex)) {
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
Write-Host "Bundled artwork/audio assets: 0"
Write-Host "Wizard destinations: 7"
