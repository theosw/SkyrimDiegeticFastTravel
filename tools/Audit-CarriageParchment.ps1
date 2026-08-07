param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$moduleRoot = Join-Path $projectRoot "modules\carriage-parchment"
$auditRoot = Join-Path $buildRoot "carriage-parchment-audit"
$stagingData = Join-Path $auditRoot "data"
$pluginsList = Join-Path $auditRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "carriage-parchment-audit.status"
$errorPath = Join-Path $buildRoot "carriage-parchment-audit.error"
$reportPath = Join-Path $buildRoot "carriage-parchment-audit.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_AuditCarriageParchment.pas"
$adapterPlugin = Join-Path $moduleRoot "mod\DiegeticTravelCarriageParchment.esp"
$corePlugin = Join-Path $buildRoot "DiegeticTravel.esp"
$seqPath = Join-Path $moduleRoot "mod\SEQ\DiegeticTravelCarriageParchment.seq"
$pickerSource = Join-Path $moduleRoot `
    "mod\Scripts\Source\DNT_CarriageParchmentPicker.psc"
$originSource = Join-Path $projectRoot "mod\Scripts\Source\DNT_OriginService.psc"
$routeSource = Join-Path $projectRoot "mod\Scripts\Source\DNT_RouteService.psc"
$coordinatorSource = Join-Path $projectRoot "mod\Scripts\Source\DNT_TravelCoordinator.psc"
$configPath = Join-Path $moduleRoot "config\network.json"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$xeditPath = Resolve-ProjectPath $XEdit
foreach ($required in @(
    $xeditPath, $scriptPath, $adapterPlugin, $corePlugin, $seqPath,
    $pickerSource, $originSource, $routeSource, $coordinatorSource, $configPath
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required carriage parchment audit input not found: $required"
    }
}

$picker = Get-Content -LiteralPath $pickerSource -Raw
$origin = Get-Content -LiteralPath $originSource -Raw
$route = Get-Content -LiteralPath $routeSource -Raw
$coordinator = Get-Content -LiteralPath $coordinatorSource -Raw
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ($config.stops.Count -ne 27 -or $config.slice -ne "cfto_native_destinations") {
    throw "Carriage parchment config must define all 27 native CFTO destinations."
}
$expectedCapitalPositions = @(
    @{ id = "dawnstar"; x = 0.571558; y = 0.157923; token = "0.571558, 0.157923" },
    @{ id = "falkreath"; x = 0.417708; y = 0.780867; token = "0.417708, 0.780867" },
    @{ id = "riften"; x = 0.917183; y = 0.809050; token = "0.917183, 0.809050" },
    @{ id = "windhelm"; x = 0.808415; y = 0.375613; token = "0.808415, 0.375613" }
)
foreach ($expected in $expectedCapitalPositions) {
    $stop = @($config.stops | Where-Object { $_.id -eq $expected.id })[0]
    if ($null -eq $stop -or
        [math]::Abs([double]$stop.map_position[0] - $expected.x) -gt 0.000001 -or
        [math]::Abs([double]$stop.map_position[1] - $expected.y) -gt 0.000001 -or
        $picker -notmatch [regex]::Escape($expected.token)) {
        throw "Capital $($expected.id) must use its live-calibrated parchment position."
    }
}
foreach ($stop in $config.stops) {
    if ($picker -notmatch [regex]::Escape('"' + $stop.id + '"')) {
        throw "Carriage picker is missing destination $($stop.id)."
    }
}
foreach ($token in @(
    "EnsureQuotesForSpeaker",
    "GetPublishedFare",
    "GetPublishedHours",
    "SetMarkerTextures",
    "SetDestinationMarkerTexture",
    "norden-town.dds",
    "norden-settlement.dds",
    "norden-farm.dds",
    "norden-wood-mill.dds",
    "norden-mine.dds",
    "Coordinator.Purchase",
    "RequestDialogueClose",
    "CARRIAGE_DIALOGUE_HANDOFF_COMPLETE"
)) {
    if ($picker -notmatch [regex]::Escape($token)) {
        throw "Carriage picker is missing contract: $token"
    }
}
foreach ($forbidden in @(
    "RefreshDestinationQuote",
    "SetRouteOrigin",
    "AddRouteSegment"
)) {
    if ($picker -match [regex]::Escape($forbidden)) {
        throw "Beta carriage picker must not use per-stop refresh or route geometry: $forbidden"
    }
}
foreach ($token in @(
    "FindEntryIndex",
    "RefreshDestinationQuote",
    "GetPublishedFare",
    "GetPublishedHours",
    "GetCarriageDestinationMarker",
    "ExecuteDirectCarriageTravel",
    "Game.FastTravel",
    "CARRIAGE_TRAVEL_COMPLETE"
)) {
    if ($origin -notmatch [regex]::Escape($token)) {
        throw "Carriage core is missing quote API: $token"
    }
}
foreach ($forbidden in @("LinkCarriageSeat", "CARRIAGE_LINK_BLOCKED", "RegisterForSingleUpdate")) {
    if ($origin -match [regex]::Escape($forbidden)) {
        throw "Direct carriage beta must not retain boarding-link execution: $forbidden"
    }
}
if ($config.execution -notmatch "Immediate Game.FastTravel") {
    throw "Carriage network manifest does not declare direct marker travel."
}
foreach ($token in @("BeginQuoteBatch", "EndQuoteBatch", "GetHazardPhaseForQuote")) {
    if ($route -notmatch [regex]::Escape($token)) {
        throw "Carriage route service is missing batch quote cache: $token"
    }
}
foreach ($token in @(
    "Beta policy: unknown and active hazards affect price",
    "fare += hazardCost * multiplier"
)) {
    if ($route -notmatch [regex]::Escape($token)) {
        throw "Carriage route service is missing beta endpoint-preservation policy: $token"
    }
}
foreach ($forbidden in @(
    "_batchHazardIds = None",
    "_batchHazardPhases = None",
    "blocked = True",
    "!blocked"
)) {
    if ($route -match [regex]::Escape($forbidden)) {
        throw "Carriage route service retains a rejected beta filter/runtime error: $forbidden"
    }
}
foreach ($token in @("EnsureQuotesForSpeaker", "MENU_QUOTES_COALESCED")) {
    if ($coordinator -notmatch [regex]::Escape($token)) {
        throw "Carriage coordinator is missing quote coalescing contract: $token"
    }
}

$resolvedAudit = [System.IO.Path]::GetFullPath($auditRoot)
$resolvedBuild = [System.IO.Path]::GetFullPath($buildRoot)
if (-not $resolvedAudit.StartsWith(
    $resolvedBuild,
    [System.StringComparison]::OrdinalIgnoreCase
)) { throw "Refusing to clean carriage audit outside build." }
if (Test-Path -LiteralPath $auditRoot) {
    Remove-Item -LiteralPath $auditRoot -Recurse -Force
}
foreach ($result in @($statusPath, $errorPath, $reportPath)) {
    if (Test-Path -LiteralPath $result) {
        Remove-Item -LiteralPath $result -Force
    }
}
New-Item -ItemType Directory -Force -Path $stagingData | Out-Null
$stockData = Join-Path $LoreRimRoot "Stock Game\Data"
foreach ($name in @(
    "Skyrim.esm", "Update.esm", "Dawnguard.esm", "HearthFires.esm",
    "Dragonborn.esm", "Skyrim - Interface.bsa"
)) {
    Copy-Item -LiteralPath (Join-Path $stockData $name) `
        -Destination (Join-Path $stagingData $name) -Force
}
$cfto = Join-Path $LoreRimRoot `
    "mods\Carriage and Ferry Travel Overhaul - Fixes and Winterhold\CFTO.esp"
Copy-Item -LiteralPath $cfto -Destination (Join-Path $stagingData "CFTO.esp") -Force
Copy-Item -LiteralPath $corePlugin `
    -Destination (Join-Path $stagingData "DiegeticTravel.esp") -Force
Copy-Item -LiteralPath $adapterPlugin `
    -Destination (Join-Path $stagingData "DiegeticTravelCarriageParchment.esp") -Force
[System.IO.File]::WriteAllText(
    $pluginsList,
    "*CFTO.esp`r`n*DiegeticTravel.esp`r`n*DiegeticTravelCarriageParchment.esp`r`n",
    [System.Text.UTF8Encoding]::new($false)
)

$arguments = @(
    "-sse", "-D:$stagingData", "-P:$pluginsList", "-IKnowWhatImDoing",
    "-nobuildrefs", "-autoload", "-autoexit", "-script:$scriptPath"
)
$process = Start-Process -FilePath $xeditPath -ArgumentList $arguments `
    -WindowStyle Hidden -PassThru
$deadline = [DateTime]::UtcNow.AddMinutes(3)
$terminalStatus = $null
while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $statusPath) {
        $terminalStatus = (Get-Content -LiteralPath $statusPath -Raw).Trim()
        if ($terminalStatus -in @("success", "failed")) { break }
    }
    Start-Sleep -Milliseconds 200
    $process.Refresh()
}
if ($terminalStatus -in @("success", "failed") -and -not $process.HasExited) {
    $null = $process.WaitForExit(15000); $process.Refresh()
}
if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
if ($terminalStatus -eq "failed") {
    $detail = if (Test-Path -LiteralPath $errorPath) {
        (Get-Content -LiteralPath $errorPath -Raw).Trim()
    } else { "no error detail was written" }
    throw "Carriage parchment audit failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Carriage parchment audit did not report success."
}
$report = Get-Content -LiteralPath $reportPath
$questLine = @($report | Where-Object { $_ -match '^QUEST_FIXED_FORM_ID=' })
if ($questLine.Count -ne 1) { throw "Audit did not report one quest FormID." }
$expected = [Convert]::ToUInt32(($questLine[0] -split '=',2)[1],16)
$bytes = [System.IO.File]::ReadAllBytes($seqPath)
if ($bytes.Length -ne 4 -or [BitConverter]::ToUInt32($bytes,0) -ne $expected) {
    throw "Carriage parchment SEQ does not match its quest."
}
$report
Write-Host "PASS source -> cached 27-stop CFTO sheet, exact Norden markers, atomic direct travel to CFTO arrivals"
Write-Host ("PASS SEQ -> start-game quest {0:X8}" -f $expected)
