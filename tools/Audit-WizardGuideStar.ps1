param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$Plugin = (
        "modules\wizard-guides\mod\DiegeticTravelWizardGuides.esp"
    ),
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$auditRoot = Join-Path $buildRoot "wizard-guide-audit"
$stagingData = Join-Path $auditRoot "data"
$pluginsList = Join-Path $auditRoot "plugins.txt"
$statusPath = Join-Path $buildRoot "wizard-guide-audit.status"
$errorPath = Join-Path $buildRoot "wizard-guide-audit.error"
$reportPath = Join-Path $buildRoot "wizard-guide-audit.report.txt"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_AuditWizardGuideStar.pas"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$pluginPath = Resolve-ProjectPath $Plugin
$xeditPath = Resolve-ProjectPath $XEdit
$resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot)
$resolvedAuditRoot = [System.IO.Path]::GetFullPath($auditRoot)

if (-not $resolvedAuditRoot.StartsWith(
    $resolvedBuildRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean audit directory outside build: $resolvedAuditRoot"
}

foreach ($required in @($pluginPath, $xeditPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required wizard-guide audit input not found: $required"
    }
}

if (Test-Path -LiteralPath $auditRoot) {
    Remove-Item -LiteralPath $auditRoot -Recurse -Force
}
foreach ($resultFile in @($statusPath, $errorPath, $reportPath)) {
    if (Test-Path -LiteralPath $resultFile -PathType Leaf) {
        Remove-Item -LiteralPath $resultFile -Force
    }
}

New-Item -ItemType Directory -Force -Path $stagingData | Out-Null
foreach ($master in @("Skyrim.esm", "Update.esm")) {
    $masterPath = Join-Path $LoreRimRoot "Stock Game\Data\$master"
    if (-not (Test-Path -LiteralPath $masterPath -PathType Leaf)) {
        throw "Required Skyrim master not found: $masterPath"
    }
    Copy-Item -LiteralPath $masterPath `
        -Destination (Join-Path $stagingData $master) -Force
}
Copy-Item -LiteralPath $pluginPath `
    -Destination (Join-Path $stagingData "DiegeticTravelWizardGuides.esp") `
    -Force

[System.IO.File]::WriteAllText(
    $pluginsList,
    "*DiegeticTravelWizardGuides.esp`r`n",
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
    throw "Wizard-guide star audit failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Wizard-guide star audit did not report success."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Wizard-guide star audit did not create its compact report."
}

Get-Content -LiteralPath $reportPath
