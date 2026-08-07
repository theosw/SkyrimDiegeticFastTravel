param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [string[]]$AdditionalPluginPaths = @()
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$inventoryRoot = Join-Path $buildRoot "carriage-parchment-inventory"
$stagingData = Join-Path $inventoryRoot "data"
$pluginsList = Join-Path $inventoryRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "carriage-parchment-inventory.status"
$errorPath = Join-Path $buildRoot "carriage-parchment-inventory.error"
$reportPath = Join-Path $buildRoot "carriage-parchment-inventory.report.txt"
$scriptPath = Join-Path $PSScriptRoot `
    "xedit\DNT_InventoryCarriageParchment.pas"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$xeditPath = Resolve-ProjectPath $XEdit
$resolvedBuild = [System.IO.Path]::GetFullPath($buildRoot)
$resolvedInventory = [System.IO.Path]::GetFullPath($inventoryRoot)
if (-not $resolvedInventory.StartsWith(
    $resolvedBuild,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean carriage inventory outside build."
}
foreach ($required in @($xeditPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required carriage inventory input not found: $required"
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
        throw "Required carriage inventory input not found: $inputPath"
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

$pluginLines = [System.Collections.Generic.List[string]]::new()
$pluginLines.Add("*CFTO.esp")
foreach ($additionalPlugin in $AdditionalPluginPaths) {
    if (-not (Test-Path -LiteralPath $additionalPlugin -PathType Leaf)) {
        throw "Additional carriage inventory plugin not found: $additionalPlugin"
    }
    $pluginName = Split-Path -Leaf $additionalPlugin
    Copy-Item -LiteralPath $additionalPlugin `
        -Destination (Join-Path $stagingData $pluginName) -Force
    $pluginLines.Add("*$pluginName")
}

[System.IO.File]::WriteAllText(
    $pluginsList,
    (($pluginLines -join "`r`n") + "`r`n"),
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
if ($AdditionalPluginPaths.Count -gt 0) {
    $arguments += (Split-Path -Leaf $AdditionalPluginPaths[-1])
}
$argumentString = (($arguments | ForEach-Object {
    if ($_ -match '\s') {
        '"' + $_.Replace('"', '\"') + '"'
    } else {
        $_
    }
}) -join ' ')
$process = Start-Process -FilePath $xeditPath -ArgumentList $argumentString `
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
    throw "Carriage inventory failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Carriage inventory did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Carriage inventory did not create its report."
}
Get-Content -LiteralPath $reportPath
