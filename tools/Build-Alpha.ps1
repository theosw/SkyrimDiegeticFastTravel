param(
    [string]$Graph = "C:\Users\Theo\Documents\LoreRim Info\travel-network\graph.json",
    [string]$LoreRimRoot = "D:\Games\US SSE\Lorerim\game-files",
    [string]$XEdit = "D:\Lorerim\tools\SSE Edit (4.0.4)\SSEEdit64.exe",
    [string]$PackageName = "DiegeticTravel-alpha"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$packageRoot = Join-Path $buildRoot $PackageName
$distRoot = Join-Path $projectRoot "dist"
$archive = Join-Path $distRoot "$PackageName.zip"
$runtimeDirectory = Join-Path $packageRoot "SKSE\Plugins\DiegeticTravel"
$scriptDirectory = Join-Path $packageRoot "Scripts"

$oldPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = Join-Path $projectRoot "src"
    & python -m diegetic_travel compile `
        --graph $Graph `
        --endpoints (Join-Path $projectRoot "config\cfto_endpoints.json") `
        --sensors (Join-Path $projectRoot "config\hazard_sensors.json") `
        --out $buildRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Runtime compilation failed with exit code $LASTEXITCODE"
    }
}
finally {
    $env:PYTHONPATH = $oldPythonPath
}

& (Join-Path $PSScriptRoot "Compile-Papyrus.ps1") `
    -LoreRimRoot $LoreRimRoot `
    -Output "build\Scripts"

& (Join-Path $PSScriptRoot "Generate-Plugin.ps1") `
    -LoreRimRoot $LoreRimRoot `
    -XEdit $XEdit

if (Test-Path -LiteralPath $packageRoot) {
    $resolvedPackage = [System.IO.Path]::GetFullPath($packageRoot)
    $resolvedBuild = [System.IO.Path]::GetFullPath($buildRoot)
    if (-not $resolvedPackage.StartsWith($resolvedBuild, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean package directory outside build: $resolvedPackage"
    }
    Remove-Item -LiteralPath $resolvedPackage -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $runtimeDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $scriptDirectory | Out-Null
Copy-Item -Path (Join-Path $projectRoot "mod\*") -Destination $packageRoot -Recurse -Force
Copy-Item -Path (Join-Path $buildRoot "Scripts\*.pex") -Destination $scriptDirectory -Force
Copy-Item -LiteralPath (Join-Path $buildRoot "runtime.json") -Destination $runtimeDirectory -Force
Copy-Item -LiteralPath (Join-Path $buildRoot "dialogue_runtime.json") -Destination $runtimeDirectory -Force
Copy-Item -LiteralPath (Join-Path $buildRoot "DiegeticTravel.esp") -Destination $packageRoot -Force

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
if (Test-Path -LiteralPath $archive -PathType Leaf) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $archive -CompressionLevel Optimal

Write-Host "Packaged alpha: $archive"
