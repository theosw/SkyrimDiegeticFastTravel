param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$inspectRoot = Join-Path $buildRoot "baan-malur-ferry-inspect"
$stagingData = Join-Path $inspectRoot "data"
$pluginsList = Join-Path $inspectRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "baan-malur-ferry-inspect.status"
$errorPath = Join-Path $buildRoot "baan-malur-ferry-inspect.error"
$reportPath = Join-Path $buildRoot "baan-malur-ferry-inspect.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_InspectBaanMalurFerry.pas"
$sourcePlugin = Join-Path $LoreRimRoot `
    "mods\Journey to Baan Malur and Morrowind\Journey to Baan Malur.esp"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$xeditPath = Resolve-ProjectPath $XEdit
foreach ($required in @($xeditPath, $scriptPath, $sourcePlugin)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Baan Malur inspection input not found: $required"
    }
}

$resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot)
$resolvedInspectRoot = [System.IO.Path]::GetFullPath($inspectRoot)
if (-not $resolvedInspectRoot.StartsWith(
    $resolvedBuildRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean Baan Malur inspection outside build."
}

if (Test-Path -LiteralPath $inspectRoot) {
    Remove-Item -LiteralPath $inspectRoot -Recurse -Force
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

[System.IO.File]::WriteAllText(
    $pluginsList,
    "*Journey to Baan Malur.esp`r`n",
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
$deadline = [DateTime]::UtcNow.AddMinutes(5)
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
    throw "Baan Malur ferry inspection failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Baan Malur ferry inspection did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Baan Malur ferry inspection did not create its report."
}

$report = Get-Content -LiteralPath $reportPath
$selectedLine = $report | Where-Object { $_ -match '^SELECTED=' }
if (@($selectedLine).Count -ne 1) {
    throw "Baan Malur ferry report did not identify its selected record count."
}
Write-Output $report[0]
Write-Output $report[1]
Write-Output $report[2]
Write-Output $selectedLine
Write-Output "Report: $reportPath"
