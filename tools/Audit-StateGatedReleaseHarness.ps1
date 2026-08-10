param(
    [string]$HarnessRoot = "test-harness\state-gated-release\mod",
    [string]$InventoryReport = "build\cfto-private-ferries-inventory.report.txt",
    [string]$CarriageReport = "build\carriage-parchment-inventory.report.txt",
    [string]$OutputPath = "build\state-gated-release-harness.audit.txt"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
function Resolve-ProjectPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$root = Resolve-ProjectPath $HarnessRoot
$privateReport = Resolve-ProjectPath $InventoryReport
$carriageReportPath = Resolve-ProjectPath $CarriageReport
$output = Resolve-ProjectPath $OutputPath
foreach ($path in @($root, $privateReport, $carriageReportPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required harness input missing: $path" }
}

$expectedFiles = @(
    "README-StateGatedReleaseHarness.txt",
    "dnt_gates_lock_all.txt", "dnt_gates_unlock_all.txt",
    "dnt_gate_honeyside_lock.txt", "dnt_gate_honeyside_unlock.txt",
    "dnt_gate_lakeview_lock.txt", "dnt_gate_lakeview_unlock.txt",
    "dnt_gate_windstad_lock.txt", "dnt_gate_windstad_unlock.txt",
    "dnt_gate_heljarchen_lock.txt", "dnt_gate_heljarchen_unlock.txt",
    "dnt_gate_volkihar_lock.txt", "dnt_gate_volkihar_unlock.txt",
    "dnt_goto_honeyside_ferry.txt", "dnt_goto_lakeview_ferry.txt",
    "dnt_goto_windstad_ferry.txt", "dnt_goto_icewater_ferry.txt",
    "dnt_apparition_add.txt", "dnt_apparition_remove.txt"
)
$actualFiles = @(Get-ChildItem -LiteralPath $root -File | Select-Object -ExpandProperty Name)
$missing = @($expectedFiles | Where-Object { $actualFiles -notcontains $_ })
$unexpected = @($actualFiles | Where-Object { $expectedFiles -notcontains $_ })
if ($missing) { throw "Harness files missing: $($missing -join ', ')" }
if ($unexpected) { throw "Unexpected harness files: $($unexpected -join ', ')" }

$forbiddenExtensions = @('.esp','.esm','.esl','.pex','.dll','.dds','.bsa')
$badPayload = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
    $forbiddenExtensions -contains $_.Extension.ToLowerInvariant()
})
if ($badPayload) { throw "Runtime payload is forbidden in the test-only harness: $($badPayload.FullName -join ', ')" }

$batchFiles = @(Get-ChildItem -LiteralPath $root -Filter 'dnt_*.txt' -File)
$forbiddenCommand = '(?i)\b(prid|save|savegame|setstage|completequest|resetquest|player\.setstage|delete|markfordelete|kill|recycleactor)\b'
foreach ($file in $batchFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    if ($text -match $forbiddenCommand) { throw "Unsafe command in $($file.Name): $($Matches[0])" }
    if ($text -match '(?i)\b[0-9A-F]{8}\b') { throw "Fixed load-order FormID in $($file.Name)" }
}

$privateText = Get-Content -LiteralPath $privateReport -Raw
foreach ($token in @(
    'KmodHouse1FerrymanMarker', 'KmodHouse2FerrymanMarker',
    'RiftenPlayerHouseDecoratePorch', 'KmodFerryVolkihar',
    'KmodFerryHoneysideMarker', 'KmodFerryLakeviewMarker',
    'KmodFerryWindstadMarker', 'KmodFerryIcewaterMarker'
)) {
    if ($privateText -notmatch [regex]::Escape($token)) { throw "Unproven CFTO EditorID in harness: $token" }
}
$carriageText = Get-Content -LiteralPath $carriageReportPath -Raw
foreach ($token in @('BYOHHouse1MapMarker','BYOHHouse2MapMarker','BYOHHouse3MapMarker')) {
    if ($carriageText -notmatch [regex]::Escape($token)) { throw "Unproven Hearthfire EditorID in harness: $token" }
}

$lines = @(
    'STATE_GATED_RELEASE_HARNESS_AUDIT=PASS',
    "FILE_COUNT=$($actualFiles.Count)",
    "BATCH_COUNT=$($batchFiles.Count)",
    'FIXED_FORMIDS=0',
    'SELECTED_REFERENCE_COMMANDS=0',
    'PLUGIN_PAYLOAD=0',
    'RUNTIME_DEPENDENCY=0'
)
$lines += $batchFiles | Sort-Object Name | ForEach-Object {
    "SHA256|$($_.Name)|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
}
New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
Set-Content -LiteralPath $output -Value $lines -Encoding UTF8
$lines
