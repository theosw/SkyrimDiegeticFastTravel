param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\carriage-parchment"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$generationRoot = Join-Path $buildRoot "carriage-parchment-generation"
$stagingData = Join-Path $generationRoot "data"
$pluginsList = Join-Path $generationRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "carriage-parchment.status"
$errorPath = Join-Path $buildRoot "carriage-parchment.error"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_GenerateCarriageParchment.pas"
$corePlugin = Join-Path $buildRoot "DiegeticTravel.esp"
$pluginOutput = Join-Path $modRoot "DiegeticTravelCarriageParchment.esp"
$seqOutput = Join-Path $modRoot "SEQ\DiegeticTravelCarriageParchment.seq"
$seqFormIdsPath = Join-Path $buildRoot "carriage-parchment-seq-formids.txt"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

if (-not $SkipCompile) {
    & (Join-Path $PSScriptRoot "Compile-CarriageParchmentPapyrus.ps1") `
        -LoreRimRoot $LoreRimRoot
}

$xeditPath = Resolve-ProjectPath $XEdit
$resolvedBuild = [System.IO.Path]::GetFullPath($buildRoot)
$resolvedGeneration = [System.IO.Path]::GetFullPath($generationRoot)
if (-not $resolvedGeneration.StartsWith(
    $resolvedBuild,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean carriage parchment staging outside build."
}
foreach ($required in @($xeditPath, $scriptPath, $corePlugin)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required carriage parchment generation input not found: $required"
    }
}

if (Test-Path -LiteralPath $generationRoot) {
    Remove-Item -LiteralPath $generationRoot -Recurse -Force
}
foreach ($resultFile in @(
    $statusPath,
    $errorPath,
    $pluginOutput,
    $seqOutput,
    $seqFormIdsPath
)) {
    if (Test-Path -LiteralPath $resultFile -PathType Leaf) {
        Remove-Item -LiteralPath $resultFile -Force
    }
}
New-Item -ItemType Directory -Force -Path $stagingData | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $seqOutput) |
    Out-Null

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
        throw "Required carriage parchment input not found: $inputPath"
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
Copy-Item -LiteralPath $corePlugin `
    -Destination (Join-Path $stagingData "DiegeticTravel.esp") -Force

[System.IO.File]::WriteAllText(
    $pluginsList,
    "*CFTO.esp`r`n*DiegeticTravel.esp`r`n",
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
$deadline = [DateTime]::UtcNow.AddMinutes(4)
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
    throw "Carriage parchment generation failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Carriage parchment generation did not report success."
}
foreach ($outputPath in @($pluginOutput, $seqFormIdsPath)) {
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "Carriage parchment generation did not create: $outputPath"
    }
}

$seqFormIds = @(Get-Content -LiteralPath $seqFormIdsPath |
    ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
if ($seqFormIds.Count -ne 1 -or $seqFormIds[0] -notmatch "^[0-9A-Fa-f]{8}$") {
    throw "Carriage parchment generator did not report one valid SEQ FormID."
}
$formId = [Convert]::ToUInt32($seqFormIds[0], 16)
$seqBytes = [byte[]]@(
    [byte]($formId -band 0xFF),
    [byte](($formId -shr 8) -band 0xFF),
    [byte](($formId -shr 16) -band 0xFF),
    [byte](($formId -shr 24) -band 0xFF)
)
[System.IO.File]::WriteAllBytes($seqOutput, $seqBytes)
Write-Host "Generated carriage parchment candidate: $pluginOutput"
Write-Host "Generated carriage parchment SEQ: $seqOutput ($($seqFormIds[0]))"
