param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\boat-honrich"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$generationRoot = Join-Path $buildRoot "boat-honrich-generation"
$stagingData = Join-Path $generationRoot "data"
$pluginsList = Join-Path $generationRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "boat-honrich.status"
$errorPath = Join-Path $buildRoot "boat-honrich.error"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_GenerateBoatHonrich.pas"
$pluginOutput = Join-Path $modRoot "DiegeticTravelBoatHonrich.esp"
$seqOutput = Join-Path $modRoot "SEQ\DiegeticTravelBoatHonrich.seq"
$seqFormIdsPath = Join-Path $buildRoot "boat-honrich-seq-formids.txt"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

if (-not $SkipCompile) {
    & (Join-Path $PSScriptRoot "Compile-BoatHonrichPapyrus.ps1") `
        -LoreRimRoot $LoreRimRoot
}

$xeditPath = Resolve-ProjectPath $XEdit
$resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot)
$resolvedGenerationRoot = [System.IO.Path]::GetFullPath($generationRoot)
if (-not $resolvedGenerationRoot.StartsWith(
    $resolvedBuildRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean Lake Honrich staging outside build."
}

foreach ($required in @($xeditPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Lake Honrich generation input not found: $required"
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
        throw "Required Lake Honrich generation input not found: $inputPath"
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

[System.IO.File]::WriteAllText(
    $pluginsList,
    "*CFTO.esp`r`n",
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
    throw "Lake Honrich generation failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Lake Honrich generation did not report success."
}
foreach ($outputPath in @($pluginOutput, $seqFormIdsPath)) {
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "Lake Honrich generation did not create: $outputPath"
    }
}

$seqFormIds = @(
    Get-Content -LiteralPath $seqFormIdsPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" }
)
if ($seqFormIds.Count -ne 1 -or $seqFormIds[0] -notmatch "^[0-9A-Fa-f]{8}$") {
    throw "Lake Honrich generator did not report exactly one valid SEQ FormID."
}
$formId = [Convert]::ToUInt32($seqFormIds[0], 16)
$seqBytes = [byte[]]::new(4)
$seqBytes[0] = [byte]($formId -band 0xFF)
$seqBytes[1] = [byte](($formId -shr 8) -band 0xFF)
$seqBytes[2] = [byte](($formId -shr 16) -band 0xFF)
$seqBytes[3] = [byte](($formId -shr 24) -band 0xFF)
[System.IO.File]::WriteAllBytes($seqOutput, $seqBytes)

Write-Host "Generated Lake Honrich boat candidate: $pluginOutput"
Write-Host "Generated Lake Honrich boat SEQ: $seqOutput ($($seqFormIds[0]))"
