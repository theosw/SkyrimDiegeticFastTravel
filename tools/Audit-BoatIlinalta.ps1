param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\boat-ilinalta"
$buildRoot = Join-Path $projectRoot "build"
$auditRoot = Join-Path $buildRoot "boat-ilinalta-audit"
$stagingData = Join-Path $auditRoot "data"
$pluginsList = Join-Path $auditRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "boat-ilinalta-audit.status"
$errorPath = Join-Path $buildRoot "boat-ilinalta-audit.error"
$reportPath = Join-Path $buildRoot "boat-ilinalta-audit.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_AuditBoatIlinalta.pas"
$pluginPath = Join-Path $moduleRoot "mod\DiegeticTravelBoatIlinalta.esp"
$seqPath = Join-Path $moduleRoot "mod\SEQ\DiegeticTravelBoatIlinalta.seq"
$pickerSourcePath = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_IlinaltaBoatParchmentPicker.psc"
$serviceSourcePath = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_IlinaltaBoatTravelService.psc"
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
    throw "Refusing to clean Lake Ilinalta audit outside build."
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
        throw "Required Lake Ilinalta audit input not found: $required"
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
        throw "Lake Ilinalta dialogue handoff is missing token: $handoffToken"
    }
}
if ($nativeSource -notmatch [regex]::Escape(
    "Bool Function RequestDialogueClose() Global Native"
)) {
    throw "Parchment native contract is missing RequestDialogueClose."
}
if ($pickerSource -match [regex]::Escape("Input.TapKey")) {
    throw "Lake Ilinalta dialogue handoff must not synthesize keyboard input."
}
if ($nativeSource -notmatch [regex]::Escape(
    "Bool Function AddRouteLandmark("
)) {
    throw "Parchment native contract is missing inactive-landmark support."
}
if (($pickerSource | Select-String -Pattern "DNT_ParchmentNative.AddRouteLandmark" -AllMatches).Matches.Count -ne 10 -or
    $pickerSource -notmatch [regex]::Escape("Bool Function AddInactiveMainlandLandmarks()")) {
    throw "Lake Ilinalta picker must expose the seven North-coast and three Lake Honrich inactive anchors."
}

if ($network.lane -ne "lake_ilinalta" -or $network.stops.Count -ne 3) {
    throw "Lake Ilinalta network must define exactly three public stops."
}
$expectedIds = @("brittleshin_pass", "half_moon_mill", "guardian_stones")
foreach ($stopId in $expectedIds) {
    if (@($network.stops | Where-Object { $_.id -eq $stopId }).Count -ne 1) {
        throw "Lake Ilinalta network is missing stop $stopId."
    }
    if ($pickerSource -notmatch [regex]::Escape('"' + $stopId + '"')) {
        throw "Lake Ilinalta picker is missing stop $stopId."
    }
    if ($serviceSource -notmatch [regex]::Escape('"' + $stopId + '"')) {
        throw "Lake Ilinalta service is missing stop $stopId."
    }
}
$brittleshin = @($network.stops | Where-Object { $_.id -eq "brittleshin_pass" })[0]
$halfMoonMill = @($network.stops | Where-Object { $_.id -eq "half_moon_mill" })[0]
if ([math]::Abs([double]$brittleshin.map_position[0] - 0.448478) -gt 0.000001 -or
    [math]::Abs([double]$brittleshin.map_position[1] - 0.683198) -gt 0.000001 -or
    $pickerSource -notmatch [regex]::Escape("0.448478, 0.683198")) {
    throw "Lake Ilinalta Brittleshin anchor must use the live-corrected southern shoreline position."
}
if ([math]::Abs([double]$halfMoonMill.map_position[0] - 0.396241) -gt 0.000001 -or
    [math]::Abs([double]$halfMoonMill.map_position[1] - 0.692916) -gt 0.000001 -or
    $pickerSource -notmatch [regex]::Escape("0.396241, 0.692916")) {
    throw "Lake Ilinalta Half-Moon Mill anchor must use the live-corrected shoreline position."
}
foreach ($deferredId in @("lakeview_manor", "ilinatas_deep")) {
    if (@($network.deferred_stops | Where-Object {
        $_.id -eq $deferredId
    }).Count -ne 1) {
        throw "Lake Ilinalta network must defer $deferredId."
    }
    if ($pickerSource -match [regex]::Escape('"' + $deferredId + '"')) {
        throw "Lake Ilinalta picker unexpectedly exposes $deferredId."
    }
}
foreach ($companionToken in @(
    "BrittleshinHorseMarkerForm = 0x195C32",
    "GuardianFollowerMarkerForm = 0x195C33",
    "GuardianHorseMarkerForm = 0x195C34",
    'DestinationId == "brittleshin_pass"',
    'DestinationId == "guardian_stones"'
)) {
    if ($serviceSource -notmatch [regex]::Escape($companionToken)) {
        throw "Lake Ilinalta service is missing companion contract: $companionToken"
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
        throw "Required Lake Ilinalta audit input not found: $inputPath"
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
    "*CFTO.esp`r`n*DiegeticTravelBoatIlinalta.esp`r`n",
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
    throw "Lake Ilinalta audit failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Lake Ilinalta audit did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Lake Ilinalta audit did not create its report."
}

$report = Get-Content -LiteralPath $reportPath
$questIdLine = $report | Where-Object { $_ -match '^QUEST_FIXED_FORM_ID=' }
if (@($questIdLine).Count -ne 1) {
    throw "Lake Ilinalta audit report does not identify one quest FormID."
}
$expectedQuestId = [Convert]::ToUInt32(
    ($questIdLine -split '=', 2)[1],
    16
)
$seqBytes = [System.IO.File]::ReadAllBytes($seqPath)
if ($seqBytes.Length -ne 4) {
    throw "Lake Ilinalta SEQ is not exactly one FormID."
}
$actualQuestId = [BitConverter]::ToUInt32($seqBytes, 0)
if ($actualQuestId -ne $expectedQuestId) {
    throw ("Lake Ilinalta SEQ quest mismatch: expected {0:X8}, got {1:X8}" -f `
        $expectedQuestId, $actualQuestId)
}

$report
Write-Host "PASS source -> three public stops and exact companion handoffs"
Write-Host ("PASS SEQ -> start-game quest {0:X8}" -f $actualQuestId)
