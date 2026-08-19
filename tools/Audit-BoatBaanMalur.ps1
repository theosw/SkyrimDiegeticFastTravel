param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\boat-baan-malur"
$buildRoot = Join-Path $projectRoot "build"
$auditRoot = Join-Path $buildRoot "boat-baan-malur-audit"
$stagingData = Join-Path $auditRoot "data"
$pluginsList = Join-Path $auditRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "boat-baan-malur-audit.status"
$errorPath = Join-Path $buildRoot "boat-baan-malur-audit.error"
$reportPath = Join-Path $buildRoot "boat-baan-malur-audit.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_AuditBoatBaanMalur.pas"
$pluginPath = Join-Path $moduleRoot "mod\DiegeticTravelBoatBaanMalur.esp"
$seqPath = Join-Path $moduleRoot "mod\SEQ\DiegeticTravelBoatBaanMalur.seq"
$pickerSourcePath = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_BaanMalurBoatParchmentPicker.psc"
$serviceSourcePath = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_BaanMalurBoatTravelService.psc"
$networkPath = Join-Path $moduleRoot "config\network.json"
$nativeSourcePath = Join-Path $projectRoot `
    "modules\parchment-picker\mod\Scripts\Source\DNT_ParchmentNative.psc"
$sourcePlugin = Join-Path $LoreRimRoot `
    "mods\Journey to Baan Malur and Morrowind\Journey to Baan Malur.esp"
$mapTexture = Join-Path $LoreRimRoot `
    "mods\Solstheim and Baan Malur Paper Map for FWMF\textures\terrain\dlc2solstheimworld\solstheim.dds"

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
    throw "Refusing to clean Baan Malur audit outside build."
}

foreach ($required in @(
    $xeditPath,
    $scriptPath,
    $pluginPath,
    $seqPath,
    $pickerSourcePath,
    $serviceSourcePath,
    $networkPath,
    $nativeSourcePath,
    $sourcePlugin,
    $mapTexture
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Baan Malur audit input not found: $required"
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
        throw "Baan Malur dialogue handoff is missing token: $handoffToken"
    }
}
if ($nativeSource -notmatch [regex]::Escape(
    "Bool Function RequestDialogueClose() Global Native"
)) {
    throw "Parchment native contract is missing RequestDialogueClose."
}
if ($pickerSource -match [regex]::Escape("Input.TapKey")) {
    throw "Baan Malur dialogue handoff must not synthesize keyboard input."
}

if ($network.lane -ne "baan_malur_public" -or $network.stops.Count -ne 3) {
    throw "Baan Malur network must define exactly three public stops."
}
if ($network.fare_default -ne 30) {
    throw "Baan Malur network must preserve the source's 30-septim fare."
}
$paymentLabel = @($network.ui_elements | Where-Object { $_.id -eq 'fare_label' })
if ($paymentLabel.Count -ne 1 -or
    [Math]::Abs([double]$paymentLabel[0].map_position[0] - 0.814330) -gt 0.000001 -or
    [Math]::Abs([double]$paymentLabel[0].map_position[1] - 0.697376) -gt 0.000001) {
    throw "Baan Malur payment-label coordinate contract does not match."
}
if ($network.travel_delegate.quest -ne
    "0033708F:Journey to Baan Malur.esp") {
    throw "Baan Malur source quest contract does not match."
}
$expectedStages = @{
    baan_malur = 1
    cormaris = 2
    raven_rock = 3
    sunmul = 5
}
foreach ($entry in $expectedStages.GetEnumerator()) {
    if ($network.travel_delegate.stages.($entry.Key) -ne $entry.Value) {
        throw "Baan Malur stage contract mismatch for $($entry.Key)."
    }
    if ($serviceSource -notmatch [regex]::Escape(
        'DestinationId == "' + $entry.Key + '"'
    )) {
        throw "Baan Malur service is missing destination $($entry.Key)."
    }
}
foreach ($sourceToken in @(
    'FerryQuest.SetStage(DestinationStage)',
    'BaanMalurStage = 1',
    'CormarisStage = 2',
    'RavenRockStage = 3',
    'SunmulStage = 5',
    'lane=baan_malur',
    'MapTexturePath = "Data/textures/terrain/dlc2solstheimworld/solstheim.dds"',
    'MapAspectRatio = 1.534',
    '0.0, 0.158447, 1.0, 0.810181',
    '0.572274, 0.405605',
    '0.510018, 0.640516',
    '0.157237, 0.323277',
    'SetPaymentLabelPosition(ActiveRequest, 0.814330, 0.697376)'
)) {
    if (($pickerSource + $serviceSource) -notmatch
        [regex]::Escape($sourceToken)) {
        throw "Baan Malur source is missing contract: $sourceToken"
    }
}
$sunmul = @($network.one_way_stops | Where-Object { $_.id -eq "sunmul" })
if ($sunmul.Count -ne 1 -or
    @($sunmul[0].available_from).Count -ne 3 -or
    $sunmul[0].available_from[0] -ne "raven_rock" -or
    $sunmul[0].available_from[1] -ne "baan_malur" -or
    $sunmul[0].available_from[2] -ne "cormaris" -or
    $sunmul[0].stage -ne 5 -or
    $sunmul[0].fare_default -ne 30 -or
    $sunmul[0].return_service_verified -ne $false -or
    $sunmul[0].selection_ring -ne "Data/textures/DiegeticTravel/norden-oneway-selection-ring.dds" -or
    [Math]::Abs([double]$sunmul[0].map_position[0] - 0.561367) -gt 0.000001 -or
    [Math]::Abs([double]$sunmul[0].map_position[1] - 0.894535) -gt 0.000001) {
    throw "Baan Malur Sunmul one-way contract does not match the verified stage-5 route."
}
foreach ($oneWayToken in @(
    'AddedAll = AddSunmul(Fare) && AddedAll',
    'Return "sunmul"',
    'SetDestinationSelectionRingTexture(ActiveRequest, "sunmul", "Data/textures/DiegeticTravel/norden-oneway-selection-ring.dds")',
    'Bool Function SetDestinationSelectionRingTexture('
)) {
    if (($pickerSource + $nativeSource) -notmatch [regex]::Escape($oneWayToken)) {
        throw "Baan Malur Sunmul one-way runtime is missing contract: $oneWayToken"
    }
}
if (([regex]::Matches(
    $pickerSource,
    [regex]::Escape('AddedAll = AddSunmul(Fare) && AddedAll')
)).Count -ne 3) {
    throw "Baan Malur Sunmul must be offered by all three public captains."
}
if (([regex]::Matches(
    $pickerSource,
    [regex]::Escape('Return "sunmul"')
)).Count -ne 3) {
    throw "Baan Malur Sunmul selection mapping must cover all three public captains."
}
foreach ($deferredId in @(
    "pryai",
    "llethrin_fel",
    "seyda_neen",
    "vivec",
    "old_silgrad"
)) {
    if ($pickerSource -match [regex]::Escape('"' + $deferredId + '"') -or
        $serviceSource -match [regex]::Escape('"' + $deferredId + '"')) {
        throw "Baan Malur runtime unexpectedly exposes $deferredId."
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
$masterNames = @(
    "Skyrim.esm",
    "Update.esm",
    "Dawnguard.esm",
    "HearthFires.esm",
    "Dragonborn.esm",
    "ccBGSSSE001-Fish.esm",
    "ccBGSSSE037-Curios.esl",
    "Skyrim - Interface.bsa"
)
foreach ($masterName in $masterNames) {
    $sourcePath = Join-Path $stockData $masterName
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
        $masterName -in @("ccBGSSSE001-Fish.esm", "ccBGSSSE037-Curios.esl")) {
        $sourcePath = Join-Path $LoreRimRoot `
            ("mods\Official Master Files - Cleaned Plugins\" + $masterName)
    }
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required Baan Malur master not found: $sourcePath"
    }
    Copy-Item -LiteralPath $sourcePath `
        -Destination (Join-Path $stagingData $masterName) -Force
}
Copy-Item -LiteralPath $sourcePlugin `
    -Destination (Join-Path $stagingData "Journey to Baan Malur.esp") -Force
Copy-Item -LiteralPath $pluginPath `
    -Destination (Join-Path $stagingData "DiegeticTravelBoatBaanMalur.esp") `
    -Force

[System.IO.File]::WriteAllText(
    $pluginsList,
    "*Journey to Baan Malur.esp`r`n*DiegeticTravelBoatBaanMalur.esp`r`n",
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
$deadline = [DateTime]::UtcNow.AddMinutes(4)
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
    throw "Baan Malur audit failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Baan Malur audit did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Baan Malur audit did not create its report."
}

$report = Get-Content -LiteralPath $reportPath
if ($report -notcontains `
    "PASS native_dialogue_gate=provider_scoped_default_off_restorable") {
    throw "Baan Malur audit did not prove the provider-scoped native-dialogue gate."
}
$questIdLine = $report | Where-Object { $_ -match '^QUEST_FIXED_FORM_ID=' }
if (@($questIdLine).Count -ne 1) {
    throw "Baan Malur audit report does not identify one quest FormID."
}
$expectedQuestId = [Convert]::ToUInt32(
    ($questIdLine -split '=', 2)[1],
    16
)
$seqBytes = [System.IO.File]::ReadAllBytes($seqPath)
if ($seqBytes.Length -ne 4) {
    throw "Baan Malur SEQ is not exactly one FormID."
}
$actualQuestId = [BitConverter]::ToUInt32($seqBytes, 0)
if ($actualQuestId -ne $expectedQuestId) {
    throw ("Baan Malur SEQ quest mismatch: expected {0:X8}, got {1:X8}" -f `
        $expectedQuestId, $actualQuestId)
}

$report
Write-Host "PASS source -> three public stops plus all-origins Sunmul stage-5 one-way route"
Write-Host "PASS marker -> Sunmul uses the destination-specific bottom-arrow selection ring"
Write-Host "PASS deferred -> five unverified Baan Malur destinations remain unavailable"
Write-Host "PASS external chart -> present and not packaged"
Write-Host ("PASS SEQ -> start-game quest {0:X8}" -f $actualQuestId)
