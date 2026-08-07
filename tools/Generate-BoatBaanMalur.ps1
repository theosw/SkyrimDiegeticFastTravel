param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\boat-baan-malur"
$modRoot = Join-Path $moduleRoot "mod"
$buildRoot = Join-Path $projectRoot "build"
$generationRoot = Join-Path $buildRoot "boat-baan-malur-generation"
$stagingData = Join-Path $generationRoot "data"
$pluginsList = Join-Path $generationRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "boat-baan-malur.status"
$errorPath = Join-Path $buildRoot "boat-baan-malur.error"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_GenerateBoatBaanMalur.pas"
$pluginOutput = Join-Path $modRoot "DiegeticTravelBoatBaanMalur.esp"
$seqOutput = Join-Path $modRoot "SEQ\DiegeticTravelBoatBaanMalur.seq"
$seqFormIdsPath = Join-Path $buildRoot "boat-baan-malur-seq-formids.txt"
$sourcePlugin = Join-Path $LoreRimRoot `
    "mods\Journey to Baan Malur and Morrowind\Journey to Baan Malur.esp"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

if (-not $SkipCompile) {
    & (Join-Path $PSScriptRoot "Compile-BoatBaanMalurPapyrus.ps1") `
        -LoreRimRoot $LoreRimRoot
}

$xeditPath = Resolve-ProjectPath $XEdit
$resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot)
$resolvedGenerationRoot = [System.IO.Path]::GetFullPath($generationRoot)
if (-not $resolvedGenerationRoot.StartsWith(
    $resolvedBuildRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean Baan Malur staging outside build."
}
foreach ($required in @($xeditPath, $scriptPath, $sourcePlugin)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Baan Malur generation input not found: $required"
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
    throw "Baan Malur generation failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Baan Malur generation did not report success."
}
foreach ($outputPath in @($pluginOutput, $seqFormIdsPath)) {
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "Baan Malur generation did not create: $outputPath"
    }
}

$seqFormIds = @(
    Get-Content -LiteralPath $seqFormIdsPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" }
)
if ($seqFormIds.Count -ne 1 -or $seqFormIds[0] -notmatch "^[0-9A-Fa-f]{8}$") {
    throw "Baan Malur generator did not report exactly one valid SEQ FormID."
}
$formId = [Convert]::ToUInt32($seqFormIds[0], 16)
$seqBytes = [byte[]]::new(4)
$seqBytes[0] = [byte]($formId -band 0xFF)
$seqBytes[1] = [byte](($formId -shr 8) -band 0xFF)
$seqBytes[2] = [byte](($formId -shr 16) -band 0xFF)
$seqBytes[3] = [byte](($formId -shr 24) -band 0xFF)
[System.IO.File]::WriteAllBytes($seqOutput, $seqBytes)

Write-Host "Generated Baan Malur boat candidate: $pluginOutput"
Write-Host "Generated Baan Malur boat SEQ: $seqOutput ($($seqFormIds[0]))"
