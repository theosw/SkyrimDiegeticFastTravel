param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\boat-solstheim"
$buildRoot = Join-Path $projectRoot "build"
$auditRoot = Join-Path $buildRoot "boat-solstheim-audit"
$stagingData = Join-Path $auditRoot "data"
$pluginsList = Join-Path $auditRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "boat-solstheim-audit.status"
$errorPath = Join-Path $buildRoot "boat-solstheim-audit.error"
$reportPath = Join-Path $buildRoot "boat-solstheim-audit.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_AuditBoatSolstheim.pas"
$pluginPath = Join-Path $moduleRoot "mod\DiegeticTravelBoatSolstheim.esp"
$seqPath = Join-Path $moduleRoot "mod\SEQ\DiegeticTravelBoatSolstheim.seq"
$pickerSourcePath = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_SolstheimBoatParchmentPicker.psc"
$serviceSourcePath = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_SolstheimBoatTravelService.psc"
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
    throw "Refusing to clean Solstheim audit outside build."
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
        throw "Required Solstheim audit input not found: $required"
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
        throw "Solstheim dialogue handoff is missing token: $handoffToken"
    }
}
if ($nativeSource -notmatch [regex]::Escape(
    "Bool Function RequestDialogueClose() Global Native"
)) {
    throw "Parchment native contract is missing RequestDialogueClose."
}
if ($pickerSource -match [regex]::Escape("Input.TapKey")) {
    throw "Solstheim dialogue handoff must not synthesize keyboard input."
}

if ($network.lane -ne "solstheim" -or $network.stops.Count -ne 3) {
    throw "Solstheim network must define exactly three public stops."
}
if ($network.fare_global -ne "00AA12:CFTO.esp" -or
    $network.fare_default -ne 50) {
    throw "Solstheim network does not preserve CFTO's regional fare."
}
if ($network.map.texture -ne
    "Data/textures/dlc02/clutter/dlc2mapsolstheim02.dds") {
    throw "Solstheim network does not reference the physical Dragonborn map."
}
if ($network.map.art_aspect_ratio -ne 1.0 -or
    $network.map.uv_crop.Count -ne 4 -or
    $network.map.uv_crop[0] -ne 0.5 -or
    $network.map.uv_crop[1] -ne 0.0 -or
    $network.map.uv_crop[2] -ne 1.0 -or
    $network.map.uv_crop[3] -ne 1.0) {
    throw "Solstheim network map crop contract does not match."
}
$expectedIds = @("raven_rock", "tel_mithryn", "skaal_village")
foreach ($stopId in $expectedIds) {
    if (@($network.stops | Where-Object { $_.id -eq $stopId }).Count -ne 1) {
        throw "Solstheim network is missing stop $stopId."
    }
    if ($pickerSource -notmatch [regex]::Escape('"' + $stopId + '"')) {
        throw "Solstheim picker is missing stop $stopId."
    }
    if ($serviceSource -notmatch [regex]::Escape('"' + $stopId + '"')) {
        throw "Solstheim service is missing stop $stopId."
    }
}
foreach ($deferredId in @("northshore_landing", "bujolds_retreat")) {
    if (@($network.deferred_stops | Where-Object {
        $_.id -eq $deferredId
    }).Count -ne 1) {
        throw "Solstheim network must defer $deferredId."
    }
    if ($pickerSource -match [regex]::Escape('"' + $deferredId + '"')) {
        throw "Solstheim picker unexpectedly exposes $deferredId."
    }
    if ($serviceSource -match [regex]::Escape('"' + $deferredId + '"')) {
        throw "Solstheim service unexpectedly exposes $deferredId."
    }
}
foreach ($sourceToken in @(
    'MapAspectRatio = 1.0',
    'MapTexturePath = "Data/textures/dlc02/clutter/dlc2mapsolstheim02.dds"',
    'BeginRequest(ActiveRequest, "boat", SourceRef, MapTexturePath, MapAspectRatio, 0.5, 0.0, 1.0, 1.0)',
    '0.239171, 0.676223',
    '0.705729, 0.771395',
    '0.813066, 0.347056',
    'FerryCostForm = 0x00AA12',
    'lane=solstheim'
)) {
    if (($pickerSource + $serviceSource) -notmatch
        [regex]::Escape($sourceToken)) {
        throw "Solstheim source is missing contract: $sourceToken"
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
        throw "Required Solstheim audit input not found: $inputPath"
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
    "*CFTO.esp`r`n*DiegeticTravelBoatSolstheim.esp`r`n",
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
    throw "Solstheim audit failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Solstheim audit did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Solstheim audit did not create its report."
}

$report = Get-Content -LiteralPath $reportPath
$questIdLine = $report | Where-Object { $_ -match '^QUEST_FIXED_FORM_ID=' }
if (@($questIdLine).Count -ne 1) {
    throw "Solstheim audit report does not identify one quest FormID."
}
$expectedQuestId = [Convert]::ToUInt32(
    ($questIdLine -split '=', 2)[1],
    16
)
$seqBytes = [System.IO.File]::ReadAllBytes($seqPath)
if ($seqBytes.Length -ne 4) {
    throw "Solstheim SEQ is not exactly one FormID."
}
$actualQuestId = [BitConverter]::ToUInt32($seqBytes, 0)
if ($actualQuestId -ne $expectedQuestId) {
    throw ("Solstheim SEQ quest mismatch: expected {0:X8}, got {1:X8}" -f `
        $expectedQuestId, $actualQuestId)
}

$report
Write-Host "PASS source -> three public stops, clean map crop, two deferred stops"
Write-Host ("PASS SEQ -> start-game quest {0:X8}" -f $actualQuestId)
