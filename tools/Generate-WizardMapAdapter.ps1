param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\wizard-map-picker"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$generationRoot = Join-Path $buildRoot "wizard-map-adapter-generation"
$stagingData = Join-Path $generationRoot "data"
$pluginsList = Join-Path $generationRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "wizard-map-adapter.status"
$errorPath = Join-Path $buildRoot "wizard-map-adapter.error"
$scriptPath = Join-Path $PSScriptRoot `
    "xedit\DNT_GenerateWizardMapAdapter.pas"
$pluginOutput = Join-Path $modRoot "DiegeticTravelWizardMap.esp"
$seqOutput = Join-Path $modRoot "SEQ\DiegeticTravelWizardMap.seq"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

if (-not $SkipCompile) {
    & (Join-Path $PSScriptRoot "Compile-WizardMapAdapterPapyrus.ps1") `
        -LoreRimRoot $LoreRimRoot
}

$xeditPath = Resolve-ProjectPath $XEdit
$resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot)
$resolvedGenerationRoot = [System.IO.Path]::GetFullPath($generationRoot)
if (-not $resolvedGenerationRoot.StartsWith(
    $resolvedBuildRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean wizard map-adapter staging outside build."
}

foreach ($required in @($xeditPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required wizard map-adapter generation input not found: $required"
    }
}

if (Test-Path -LiteralPath $generationRoot) {
    Remove-Item -LiteralPath $generationRoot -Recurse -Force
}
foreach ($resultFile in @($statusPath, $errorPath)) {
    if (Test-Path -LiteralPath $resultFile -PathType Leaf) {
        Remove-Item -LiteralPath $resultFile -Force
    }
}

New-Item -ItemType Directory -Force -Path $stagingData | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $seqOutput) `
    | Out-Null

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
        throw "Required wizard map-adapter generation input not found: $inputPath"
    }
    Copy-Item -LiteralPath $inputPath `
        -Destination (Join-Path $stagingData $inputName) -Force
}

$wizardPlugin = Join-Path $projectRoot `
    "modules\wizard-guides\mod\DiegeticTravelWizardGuides.esp"
$bcdPlugin = Join-Path $LoreRimRoot `
    "mods\Better Carriage Destinations\Better Carriage Destinations.esp"
foreach ($pluginInput in @($wizardPlugin, $bcdPlugin)) {
    if (-not (Test-Path -LiteralPath $pluginInput -PathType Leaf)) {
        throw "Required wizard map-adapter plugin not found: $pluginInput"
    }
    Copy-Item -LiteralPath $pluginInput `
        -Destination (Join-Path $stagingData (Split-Path -Leaf $pluginInput)) `
        -Force
}

[System.IO.File]::WriteAllText(
    $pluginsList,
    (
        "*DiegeticTravelWizardGuides.esp`r`n" +
        "*Better Carriage Destinations.esp`r`n"
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
    throw "Wizard map-adapter generation failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Wizard map-adapter generation did not report success."
}

foreach ($outputPath in @($pluginOutput, $seqOutput)) {
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "Wizard map-adapter generation did not create: $outputPath"
    }
}

Write-Host "Generated wizard map adapter: $pluginOutput"
Write-Host "Generated wizard map adapter SEQ: $seqOutput"
