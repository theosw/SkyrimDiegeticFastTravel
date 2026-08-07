param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\wizard-map-picker"
$buildRoot = Join-Path $projectRoot "build"
$auditRoot = Join-Path $buildRoot "wizard-map-adapter-audit"
$stagingData = Join-Path $auditRoot "data"
$pluginsList = Join-Path $auditRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "wizard-map-adapter-audit.status"
$errorPath = Join-Path $buildRoot "wizard-map-adapter-audit.error"
$reportPath = Join-Path $buildRoot "wizard-map-adapter-audit.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_AuditWizardMapAdapter.pas"
$seqPath = Join-Path $moduleRoot "mod\SEQ\DiegeticTravelWizardMap.seq"

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
    throw "Refusing to clean wizard map-adapter audit outside build."
}

foreach ($required in @($xeditPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required wizard map-adapter audit input not found: $required"
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
        throw "Required wizard map-adapter audit input not found: $inputPath"
    }
    Copy-Item -LiteralPath $inputPath `
        -Destination (Join-Path $stagingData $inputName) -Force
}

$plugins = @(
    (Join-Path $projectRoot `
        "modules\wizard-guides\mod\DiegeticTravelWizardGuides.esp"),
    (Join-Path $LoreRimRoot `
        "mods\Better Carriage Destinations\Better Carriage Destinations.esp"),
    (Join-Path $moduleRoot "mod\DiegeticTravelWizardMap.esp")
)
foreach ($plugin in $plugins) {
    if (-not (Test-Path -LiteralPath $plugin -PathType Leaf)) {
        throw "Required wizard map-adapter audit plugin not found: $plugin"
    }
    Copy-Item -LiteralPath $plugin `
        -Destination (Join-Path $stagingData (Split-Path -Leaf $plugin)) `
        -Force
}

[System.IO.File]::WriteAllText(
    $pluginsList,
    (
        "*DiegeticTravelWizardGuides.esp`r`n" +
        "*Better Carriage Destinations.esp`r`n" +
        "*DiegeticTravelWizardMap.esp`r`n"
    ),
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
$process = Start-Process `
    -FilePath $xeditPath `
    -ArgumentList $arguments `
    -WindowStyle Hidden `
    -PassThru

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

if (
    $terminalStatus -in @("success", "failed") -and
    -not $process.HasExited
) {
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
    throw "Wizard map-adapter audit failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Wizard map-adapter audit did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Wizard map-adapter audit did not create its report."
}

$report = Get-Content -LiteralPath $reportPath
$questIdLine = @($report | Where-Object {
    $_ -match '^QUEST_FIXED_FORM_ID='
})
if ($questIdLine.Count -ne 1) {
    throw "Wizard map-adapter audit does not identify one quest FormID."
}
if (-not (Test-Path -LiteralPath $seqPath -PathType Leaf)) {
    throw "Wizard map-adapter SEQ is missing: $seqPath"
}
$seqBytes = [System.IO.File]::ReadAllBytes($seqPath)
if ($seqBytes.Length -ne 4) {
    throw "Wizard map-adapter SEQ is not exactly one FormID."
}
$expectedQuestId = [Convert]::ToUInt32(
    ($questIdLine[0] -split '=', 2)[1],
    16
)
$actualQuestId = [BitConverter]::ToUInt32($seqBytes, 0)
if ($actualQuestId -ne $expectedQuestId) {
    throw ("Wizard map-adapter SEQ mismatch: expected {0:X8}, got {1:X8}" -f `
        $expectedQuestId, $actualQuestId)
}
$report
Write-Host ("PASS SEQ -> start-game quest {0:X8}" -f $actualQuestId)
