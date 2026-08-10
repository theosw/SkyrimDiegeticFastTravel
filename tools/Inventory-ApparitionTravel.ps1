param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$inventoryRoot = Join-Path $buildRoot "apparition-travel-inventory"
$stagingData = Join-Path $inventoryRoot "data"
$pluginsList = Join-Path $inventoryRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "apparition-travel-inventory.status"
$errorPath = Join-Path $buildRoot "apparition-travel-inventory.error"
$reportPath = Join-Path $buildRoot "apparition-travel-inventory.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_InventoryApparitionTravel.pas"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$xeditPath = Resolve-ProjectPath $XEdit
foreach ($required in @($xeditPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Apparition inventory input not found: $required"
    }
}
if (Test-Path -LiteralPath $inventoryRoot) {
    Remove-Item -LiteralPath $inventoryRoot -Recurse -Force
}
foreach ($result in @($statusPath, $errorPath, $reportPath)) {
    if (Test-Path -LiteralPath $result -PathType Leaf) {
        Remove-Item -LiteralPath $result -Force
    }
}
New-Item -ItemType Directory -Force -Path $stagingData | Out-Null

$stockData = Join-Path $LoreRimRoot "Stock Game\Data"
foreach ($name in @(
    "Skyrim.esm",
    "Update.esm",
    "Dawnguard.esm",
    "HearthFires.esm",
    "Dragonborn.esm",
    "Skyrim - Interface.bsa"
)) {
    Copy-Item -LiteralPath (Join-Path $stockData $name) `
        -Destination (Join-Path $stagingData $name) -Force
}
$sourcePlugin = Join-Path $LoreRimRoot `
    "mods\Wizarding Traversal Magic\WizardingTraversal.esl"
if (-not (Test-Path -LiteralPath $sourcePlugin -PathType Leaf)) {
    throw "Required Apparition plugin not found: $sourcePlugin"
}
Copy-Item -LiteralPath $sourcePlugin `
    -Destination (Join-Path $stagingData "WizardingTraversal.esl") -Force

[System.IO.File]::WriteAllText(
    $pluginsList,
    "*WizardingTraversal.esl`r`n",
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
    if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
        $terminalStatus = (Get-Content -LiteralPath $statusPath -Raw).Trim()
        if ($terminalStatus -in @("success", "failed")) { break }
    }
    Start-Sleep -Milliseconds 200
    $process.Refresh()
}
if ($terminalStatus -in @("success", "failed") -and -not $process.HasExited) {
    $null = $process.WaitForExit(15000)
    $process.Refresh()
}
if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
if ($terminalStatus -eq "failed") {
    $detail = if (Test-Path -LiteralPath $errorPath) {
        (Get-Content -LiteralPath $errorPath -Raw).Trim()
    } else { "no error detail was written" }
    throw "Apparition inventory failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Apparition inventory did not report success."
}
Get-Content -LiteralPath $reportPath
