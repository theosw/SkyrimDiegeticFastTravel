param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$exportRoot = Join-Path $buildRoot "fwmf-transform"
$stagingData = Join-Path $exportRoot "data"
$pluginsList = Join-Path $exportRoot "plugins.txt"
$statusPath = Join-Path $exportRoot "export.status"
$errorPath = Join-Path $exportRoot "export.error"
$outputPath = Join-Path $exportRoot "tamriel.json"
$stagedMesh = Join-Path $exportRoot "tamriel.nif"
$sourceMesh = Join-Path $LoreRimRoot `
    "mods\Flat World Map Framework (FWMF)\meshes\terrain\tamriel\tamriel.32.0.0.btr"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_ExportFwmfMeshJson.pas"

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$xeditPath = Resolve-ProjectPath $XEdit
foreach ($required in @($xeditPath, $scriptPath, $sourceMesh)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required FWMF export input not found: $required"
    }
}

$resolvedExportRoot = [System.IO.Path]::GetFullPath($exportRoot)
$resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot)
if (-not $resolvedExportRoot.StartsWith(
    $resolvedBuildRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean FWMF export outside build."
}

if (Test-Path -LiteralPath $exportRoot) {
    Remove-Item -LiteralPath $exportRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stagingData | Out-Null

$skyrimEsm = Join-Path $LoreRimRoot "Stock Game\Data\Skyrim.esm"
if (-not (Test-Path -LiteralPath $skyrimEsm -PathType Leaf)) {
    throw "Required stock master not found: $skyrimEsm"
}
Copy-Item -LiteralPath $skyrimEsm `
    -Destination (Join-Path $stagingData "Skyrim.esm") -Force
Copy-Item -LiteralPath $sourceMesh -Destination $stagedMesh -Force
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
    throw "FWMF mesh export failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "FWMF mesh export did not report success."
}
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "FWMF mesh export did not create tamriel.json."
}

Write-Host "Exported FWMF Tamriel mesh JSON: $outputPath"
