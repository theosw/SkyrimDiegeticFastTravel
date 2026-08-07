param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$inventoryRoot = Join-Path $buildRoot "cfto-ferry-network"
$stagingData = Join-Path $inventoryRoot "data"
$pluginsList = Join-Path $inventoryRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "cfto-ferry-network.status"
$errorPath = Join-Path $buildRoot "cfto-ferry-network.error"
$reportPath = Join-Path $buildRoot "cfto-ferry-network.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_InventoryCFTOFerryNetwork.pas"

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
    throw "Refusing to clean inventory directory outside build."
}

foreach ($required in @($xeditPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required ferry inventory input not found: $required"
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
        throw "Required ferry inventory input not found: $inputPath"
    }
    Copy-Item -LiteralPath $inputPath -Destination (Join-Path $stagingData $inputName) -Force
}

$modInputs = @(
    @(
        "Carriage and Ferry Travel Overhaul - Fixes and Winterhold",
        "CFTO.esp"
    ),
    @(
        "Better Carriage Destinations",
        "Better Carriage Destinations.esp"
    ),
    @(
        "Better Carriage Destinations CFTO",
        "Better Carriage Destinations - CFTO.esp"
    )
)
foreach ($input in $modInputs) {
    $inputPath = Join-Path $LoreRimRoot ("mods\{0}\{1}" -f $input[0], $input[1])
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
        throw "Required ferry inventory input not found: $inputPath"
    }
    Copy-Item -LiteralPath $inputPath -Destination (Join-Path $stagingData $input[1]) -Force
}

$pluginNames = @(
    "Skyrim.esm",
    "Update.esm",
    "Dawnguard.esm",
    "HearthFires.esm",
    "Dragonborn.esm",
    "CFTO.esp",
    "Better Carriage Destinations.esp",
    "Better Carriage Destinations - CFTO.esp"
)
[System.IO.File]::WriteAllText(
    $pluginsList,
    (($pluginNames | ForEach-Object { "*$_" }) -join "`r`n") + "`r`n",
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

$deadline = [DateTime]::UtcNow.AddMinutes(6)
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
    throw "CFTO ferry inventory failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "CFTO ferry inventory did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "CFTO ferry inventory did not create its report."
}

Get-Content -LiteralPath $reportPath
