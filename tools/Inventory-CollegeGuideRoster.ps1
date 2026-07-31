param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$inventoryRoot = Join-Path $buildRoot "college-guide-roster"
$stagingData = Join-Path $inventoryRoot "data"
$pluginsList = Join-Path $inventoryRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "college-guide-roster.status"
$errorPath = Join-Path $buildRoot "college-guide-roster.error"
$reportPath = Join-Path $buildRoot "college-guide-roster.report.txt"
$scriptPath = Join-Path $PSScriptRoot `
    "xedit\DNT_InventoryCollegeGuideRoster.pas"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$xeditPath = Resolve-ProjectPath $XEdit
$resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot)
$resolvedInventoryRoot = [System.IO.Path]::GetFullPath($inventoryRoot)
if (-not $resolvedInventoryRoot.StartsWith(
    $resolvedBuildRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean College roster directory outside build."
}

foreach ($required in @($xeditPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required College roster input not found: $required"
    }
}

if (Test-Path -LiteralPath $inventoryRoot) {
    Remove-Item -LiteralPath $inventoryRoot -Recurse -Force
}
foreach ($resultFile in @($statusPath, $errorPath, $reportPath)) {
    if (Test-Path -LiteralPath $resultFile -PathType Leaf) {
        Remove-Item -LiteralPath $resultFile -Force
    }
}

New-Item -ItemType Directory -Force -Path $stagingData | Out-Null
$stockData = Join-Path $LoreRimRoot "Stock Game\Data"
foreach ($inputName in @("Skyrim.esm", "Skyrim - Interface.bsa")) {
    $inputPath = Join-Path $stockData $inputName
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
        throw "Required College roster input not found: $inputPath"
    }
    Copy-Item -LiteralPath $inputPath `
        -Destination (Join-Path $stagingData $inputName) -Force
}

[System.IO.File]::WriteAllText(
    $pluginsList,
    "*Skyrim.esm`r`n",
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

$deadline = [DateTime]::UtcNow.AddMinutes(2)
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
    throw "College guide roster inventory failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "College guide roster inventory did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "College guide roster inventory did not create its report."
}

Get-Content -LiteralPath $reportPath
