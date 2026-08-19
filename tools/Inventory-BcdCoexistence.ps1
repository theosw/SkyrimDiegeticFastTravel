param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$inventoryRoot = Join-Path $buildRoot "bcd-coexistence-inventory"
$stagingData = Join-Path $inventoryRoot "data"
$pluginsList = Join-Path $inventoryRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "bcd-coexistence-inventory.status"
$errorPath = Join-Path $buildRoot "bcd-coexistence-inventory.error"
$reportPath = Join-Path $buildRoot "bcd-coexistence-inventory.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_InventoryBcdCoexistence.pas"

function Resolve-ProjectPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$xeditPath = Resolve-ProjectPath $XEdit
$resolvedBuild = [IO.Path]::GetFullPath($buildRoot)
$resolvedInventory = [IO.Path]::GetFullPath($inventoryRoot)
if (-not $resolvedInventory.StartsWith(
    $resolvedBuild,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean BCD inventory outside build."
}
foreach ($required in @($xeditPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required BCD inventory input not found: $required"
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
$inputs = [ordered]@{
    "Skyrim.esm" = Join-Path $stockData "Skyrim.esm"
    "Update.esm" = Join-Path $stockData "Update.esm"
    "Dawnguard.esm" = Join-Path $stockData "Dawnguard.esm"
    "HearthFires.esm" = Join-Path $stockData "HearthFires.esm"
    "Dragonborn.esm" = Join-Path $stockData "Dragonborn.esm"
    "Skyrim - Interface.bsa" = Join-Path $stockData "Skyrim - Interface.bsa"
    "CFTO.esp" = Join-Path $LoreRimRoot "mods\Carriage and Ferry Travel Overhaul - Fixes and Winterhold\CFTO.esp"
    "SkyUI_SE.esp" = Join-Path $LoreRimRoot "mods\SkyUI\SkyUI_SE.esp"
    "WaitCarriageInns.esp" = Join-Path $LoreRimRoot "mods\Wait Carriage in Inns - Fast Travel Improvement\WaitCarriageInns.esp"
    "Better Carriage Destinations.esp" = Join-Path $LoreRimRoot "mods\Better Carriage Destinations\Better Carriage Destinations.esp"
    "Better Carriage Destinations - CFTO.esp" = Join-Path $LoreRimRoot "mods\Better Carriage Destinations CFTO\Better Carriage Destinations - CFTO.esp"
    "Better Carriage Destinations - Wait Carriage in Inns Patch.esp" = Join-Path $LoreRimRoot "mods\Better Carriage Destinations WCII\Better Carriage Destinations - Wait Carriage in Inns Patch.esp"
}
foreach ($entry in $inputs.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) {
        throw "Required BCD inventory input not found: $($entry.Value)"
    }
    Copy-Item -LiteralPath $entry.Value -Destination (Join-Path $stagingData $entry.Key) -Force
}

[IO.File]::WriteAllText(
    $pluginsList,
    "*SkyUI_SE.esp`r`n*WaitCarriageInns.esp`r`n*Better Carriage Destinations.esp`r`n*CFTO.esp`r`n*Better Carriage Destinations - CFTO.esp`r`n*Better Carriage Destinations - Wait Carriage in Inns Patch.esp`r`n",
    [Text.UTF8Encoding]::new($false)
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
    $null = $process.WaitForExit(5000)
}
if ($terminalStatus -eq "failed") {
    $detail = if (Test-Path -LiteralPath $errorPath -PathType Leaf) {
        (Get-Content -LiteralPath $errorPath -Raw).Trim()
    } else {
        "no error detail was written"
    }
    throw "BCD coexistence inventory failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "BCD coexistence inventory did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "BCD coexistence inventory did not create its report."
}
Get-Content -LiteralPath $reportPath
