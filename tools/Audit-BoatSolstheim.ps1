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
if (@($network.deferred_stops).Count -ne 0) {
    throw "Solstheim public Route 4 scope should have no remaining deferred stops."
}
$destinationOnlyContracts = @(
    @{
        Id = "northshore_landing"; Marker = "03840C:CFTO.esp"
        MarkerToken = "NorthshoreMarkerForm = 0x03840C"
        Position = @(0.126267, 0.162120)
    },
    @{
        Id = "bujolds_retreat"; Marker = "03840D:CFTO.esp"
        MarkerToken = "BujoldMarkerForm = 0x03840D"
        Position = @(0.842557, 0.472330)
    }
)
if (@($network.destination_only_stops).Count -ne 2) {
    throw "Solstheim network must define exactly two destination-only stops."
}
$paymentLabel = @($network.ui_elements | Where-Object { $_.id -eq 'fare_label' })
if ($paymentLabel.Count -ne 1 -or
    [Math]::Abs([double]$paymentLabel[0].map_position[0] - 0.501441) -gt 0.000001 -or
    [Math]::Abs([double]$paymentLabel[0].map_position[1] - 0.919340) -gt 0.000001) {
    throw "Solstheim payment-label position must match the live calibration."
}
foreach ($contract in $destinationOnlyContracts) {
    $stop = @($network.destination_only_stops | Where-Object {
        $_.id -eq $contract.Id
    })
    if ($stop.Count -ne 1 -or
        $stop[0].provider_enabled -ne $false -or
        $stop[0].arrival_marker -ne $contract.Marker -or
        $stop[0].fare_global -ne "00AA12:CFTO.esp" -or
        $stop[0].PSObject.Properties.Name -contains "service_npc" -or
        @($stop[0].available_from).Count -ne 3 -or
        @($stop[0].available_from | Where-Object { $_ -notin $expectedIds }).Count -ne 0 -or
        [Math]::Abs([double]$stop[0].map_position[0] - $contract.Position[0]) -gt 0.000001 -or
        [Math]::Abs([double]$stop[0].map_position[1] - $contract.Position[1]) -gt 0.000001 -or
        $pickerSource -notmatch [regex]::Escape('"' + $contract.Id + '"') -or
        $pickerSource -notmatch [regex]::Escape(("{0:F6}, {1:F6}" -f $contract.Position[0], $contract.Position[1])) -or
        $serviceSource -notmatch [regex]::Escape($contract.MarkerToken)) {
        throw "Solstheim destination-only contract does not match: $($contract.Id)."
    }
}
foreach ($sourceToken in @(
    'MapAspectRatio = 1.0',
    'MapTexturePath = "Data/textures/dlc02/clutter/dlc2mapsolstheim02.dds"',
    'BeginRequest(ActiveRequest, "boat", SourceRef, MapTexturePath, MapAspectRatio, 0.5, 0.0, 1.0, 1.0)',
    '0.239171, 0.676223',
    '0.705729, 0.771395',
    '0.813066, 0.347056',
    'SetPaymentLabelPosition(ActiveRequest, 0.501441, 0.919340)',
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
Write-Host "PASS source -> three public providers plus two destination-only stops"
Write-Host "PASS scope -> Northshore and Bujold cannot become return providers"
Write-Host ("PASS SEQ -> start-game quest {0:X8}" -f $actualQuestId)
