param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\boat-honrich"
$buildRoot = Join-Path $projectRoot "build"
$auditRoot = Join-Path $buildRoot "boat-honrich-audit"
$stagingData = Join-Path $auditRoot "data"
$pluginsList = Join-Path $auditRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "boat-honrich-audit.status"
$errorPath = Join-Path $buildRoot "boat-honrich-audit.error"
$reportPath = Join-Path $buildRoot "boat-honrich-audit.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_AuditBoatHonrich.pas"
$pluginPath = Join-Path $moduleRoot "mod\DiegeticTravelBoatHonrich.esp"
$seqPath = Join-Path $moduleRoot `
    "mod\SEQ\DiegeticTravelBoatHonrich.seq"
$pickerSourcePath = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_BoatParchmentPicker.psc"
$serviceSourcePath = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_BoatTravelService.psc"
$nativeSourcePath = Join-Path $projectRoot `
    "modules\parchment-picker\mod\Scripts\Source\DNT_ParchmentNative.psc"
$networkPath = Join-Path $moduleRoot "config\network.json"

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
    throw "Refusing to clean Lake Honrich audit outside build."
}

foreach ($required in @(
    $xeditPath,
    $scriptPath,
    $pluginPath,
    $seqPath,
    $pickerSourcePath,
    $serviceSourcePath,
    $nativeSourcePath,
    $networkPath
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Lake Honrich audit input not found: $required"
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
        throw "Lake Honrich dialogue handoff is missing token: $handoffToken"
    }
}
if ($nativeSource -notmatch [regex]::Escape(
    "Bool Function RequestDialogueClose() Global Native"
)) {
    throw "Parchment native Papyrus contract is missing RequestDialogueClose."
}
if ($pickerSource -match [regex]::Escape("Input.TapKey")) {
    throw "Lake Honrich dialogue handoff must not synthesize keyboard input."
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
    "AddedAll = AddLaneNetwork() && AddedAll"
)) {
    if ($pickerSource -match [regex]::Escape($deferredRuntimeToken)) {
        throw "Lake Honrich beta must not activate deferred route artwork: $deferredRuntimeToken"
    }
}
if ($network.map.PSObject.Properties.Name -contains "overlay_texture") {
    throw "Lake Honrich beta config must not activate deferred route artwork."
}
if (($pickerSource | Select-String -Pattern "DNT_ParchmentNative.AddRouteSegment" -AllMatches).Matches.Count -ne 33 -or
    $pickerSource -notmatch [regex]::Escape("Bool Function AddLaneNetwork()")) {
    throw "Lake Honrich deferred authoring geometry must retain the audited 33-segment water ring."
}
if (($pickerSource | Select-String -Pattern "DNT_ParchmentNative.AddRouteLandmark" -AllMatches).Matches.Count -ne 10 -or
    $pickerSource -notmatch [regex]::Escape("Bool Function AddInactiveMainlandLandmarks()")) {
    throw "Lake Honrich picker must expose the seven North-coast and three Lake Ilinalta inactive anchors."
}

if ($network.lane -ne "lake_honrich" -or $network.stops.Count -ne 3) {
    throw "Lake Honrich network must define exactly three public stops."
}
$honeyside = @($network.private_stops | Where-Object { $_.id -eq "honeyside" })
if ($honeyside.Count -ne 1 -or
    $honeyside[0].service_npc -ne "014C8C:CFTO.esp" -or
    $honeyside[0].service_ref -ne "014C8D:CFTO.esp" -or
    $honeyside[0].arrival_marker -ne "014C8E:CFTO.esp" -or
    $honeyside[0].fare_global -ne "0BBF93:CFTO.esp" -or
    $honeyside[0].fare_default -ne 30 -or
    $honeyside[0].availability -ne "service_ref_enabled" -or
    [Math]::Abs([double]$honeyside[0].map_position[0] - 0.89365) -gt 0.000001 -or
    [Math]::Abs([double]$honeyside[0].map_position[1] - 0.80508) -gt 0.000001) {
    throw "Lake Honrich Honeyside private-service contract does not match CFTO."
}
foreach ($privateToken in @(
    'HoneysideFerrymanForm = 0x014C8C',
    'HoneysideFerrymanRefForm = 0x014C8D',
    'HoneysideMarkerForm = 0x014C8E',
    'FerryCostLocalForm = 0x0BBF93',
    '"honeyside"',
    '0.893650, 0.805080'
)) {
    if (($pickerSource + $serviceSource) -notmatch [regex]::Escape($privateToken)) {
        throw "Lake Honrich Honeyside runtime is missing contract: $privateToken"
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
        throw "Required Lake Honrich audit input not found: $inputPath"
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
    "*CFTO.esp`r`n*DiegeticTravelBoatHonrich.esp`r`n",
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
    throw "Lake Honrich audit failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Lake Honrich audit did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Lake Honrich audit did not create its report."
}

$report = Get-Content -LiteralPath $reportPath
$questIdLine = $report | Where-Object { $_ -match '^QUEST_FIXED_FORM_ID=' }
if (@($questIdLine).Count -ne 1) {
    throw "Lake Honrich audit report does not identify one quest FormID."
}
$expectedQuestId = [Convert]::ToUInt32(
    ($questIdLine -split '=', 2)[1],
    16
)
$seqBytes = [System.IO.File]::ReadAllBytes($seqPath)
if ($seqBytes.Length -ne 4) {
    throw "Lake Honrich SEQ is not exactly one FormID."
}
$actualQuestId = [BitConverter]::ToUInt32($seqBytes, 0)
if ($actualQuestId -ne $expectedQuestId) {
    throw ("Lake Honrich SEQ quest mismatch: expected {0:X8}, got {1:X8}" -f `
        $expectedQuestId, $actualQuestId)
}

$report
Write-Host "PASS source -> three public providers plus gated Honeyside private service"
Write-Host ("PASS SEQ -> start-game quest {0:X8}" -f $actualQuestId)
