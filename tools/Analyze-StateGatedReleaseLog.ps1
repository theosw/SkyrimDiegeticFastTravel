param(
    [string]$PapyrusLogPath = (Join-Path $env:USERPROFILE 'Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log'),
    [string]$NativeLogPath = (Join-Path $env:USERPROFILE 'Documents\My Games\Skyrim Special Edition\SKSE\DNTParchmentPicker.log'),
    [string]$OutputPath = 'build\state-gated-release-gameplay.report.txt'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [IO.Path]::IsPathRooted($OutputPath)) { $OutputPath = Join-Path $projectRoot $OutputPath }
$papyrus = if (Test-Path -LiteralPath $PapyrusLogPath) { @(Get-Content -LiteralPath $PapyrusLogPath) } else { @() }
$native = if (Test-Path -LiteralPath $NativeLogPath) { @(Get-Content -LiteralPath $NativeLogPath) } else { @() }
$dnt = @($papyrus | Where-Object { $_ -match '\[DNT\]' })
$nativeDnt = @($native | Where-Object { $_ -match 'PARCHMENT_' })
$issues = @($dnt + $nativeDnt | Where-Object { $_ -match '(?i)(error|warning|critical|exception|stack dump)' })
$modes = @($dnt | Where-Object { $_ -match '(BOAT_|WIZARD_)?TRAVEL_MODE' })
$normal = @($modes | Where-Object { $_ -match 'apparition=False' })
$apparition = @($modes | Where-Object { $_ -match 'apparition=True' })
$completions = @($dnt | Where-Object { $_ -match '(BOAT_TRAVEL_COMPLETE|WIZARD_TRAVEL_COMPLETE|PURCHASE_COMMITTED)' })
$privateDenied = @($dnt | Where-Object { $_ -match 'reason=private_service_locked' })
$carriageSkipped = @($dnt | Where-Object { $_ -match 'CARRIAGE_PARCHMENT_ROUTE_SKIPPED.*reason=unavailable' })

$status = if ($issues.Count -gt 0) { 'FAIL' } elseif ($completions.Count -eq 0) { 'INCOMPLETE' } else { 'PASS_WITH_MANUAL_GATE_CHECKS' }
$report = @(
    "STATE_GATED_RELEASE_GAMEPLAY=$status",
    "DNT_LINES=$($dnt.Count)",
    "NATIVE_PARCHMENT_LINES=$($nativeDnt.Count)",
    "COMPLETIONS=$($completions.Count)",
    "PRIVATE_DENIALS=$($privateDenied.Count)",
    "CARRIAGE_UNAVAILABLE_SKIPS=$($carriageSkipped.Count)",
    "NORMAL_TIME_EVIDENCE=$($normal.Count)",
    "APPARITION_TIME_EVIDENCE=$($apparition.Count)",
    "ISSUES=$($issues.Count)",
    'MANUAL_ASSERTIONS_REQUIRED=destination_visibility,gold_delta,game_hour_delta,arrival,save_reload'
)
$report += $modes | ForEach-Object { "MODE|$_" }
$report += $completions | ForEach-Object { "COMPLETE|$_" }
$report += $carriageSkipped | ForEach-Object { "SKIP|$_" }
$report += $issues | ForEach-Object { "ISSUE|$_" }
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
Set-Content -LiteralPath $OutputPath -Value $report -Encoding UTF8
$report
