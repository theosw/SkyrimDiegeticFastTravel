param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$PackageRoot = "build\DiegeticTravel-beta",
    [string]$ModName = "DiegeticTravel"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$package = if ([IO.Path]::IsPathRooted($PackageRoot)) {
    [IO.Path]::GetFullPath($PackageRoot)
} else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $PackageRoot))
}
$modsRoot = [IO.Path]::GetFullPath((Join-Path $LoreRimRoot "mods"))
$target = [IO.Path]::GetFullPath((Join-Path $modsRoot $ModName))
if ([IO.Path]::GetDirectoryName($target) -ne $modsRoot -or
    [IO.Path]::GetFileName($target) -ne $ModName) {
    throw "Refusing to deploy outside the exact LoreRim mod target: $target"
}
if (-not (Test-Path -LiteralPath $package -PathType Container)) {
    throw "Release package directory was not found: $package"
}

$blockedProcesses = @(
    "SkyrimSE",
    "skse64_loader",
    "ModOrganizer",
    "usvfs_proxy_x64",
    "usvfs_proxy_x86"
)
$running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $blockedProcesses -contains $_.ProcessName
})
if ($running.Count -gt 0) {
    throw "Close Skyrim and MO2 before deployment: $($running.ProcessName -join ', ')"
}

$plugins = @(Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object {
    $_.Extension.ToLowerInvariant() -in @(".esp", ".esm", ".esl")
})
if ($plugins.Count -ne 1 -or $plugins[0].Name -ne "DiegeticTravel.esp") {
    throw "Deployment package must contain exactly one DiegeticTravel.esp"
}
$seqs = @(Get-ChildItem -LiteralPath $package -Recurse -File -Filter "*.seq")
if ($seqs.Count -ne 1 -or $seqs[0].Name -ne "DiegeticTravel.seq") {
    throw "Deployment package must contain exactly one DiegeticTravel.seq"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $buildRoot "deployment-backup-$timestamp-consolidated"
if (Test-Path -LiteralPath $target) {
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    Copy-Item -LiteralPath $target -Destination $backup -Recurse -Force
}

if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Path (Join-Path $package "*") -Destination $target -Recurse -Force

$deployedPlugins = @(Get-ChildItem -LiteralPath $target -Recurse -File | Where-Object {
    $_.Extension.ToLowerInvariant() -in @(".esp", ".esm", ".esl")
})
$deployedSeqs = @(Get-ChildItem -LiteralPath $target -Recurse -File -Filter "*.seq")
if ($deployedPlugins.Count -ne 1 -or
    $deployedPlugins[0].Name -ne "DiegeticTravel.esp" -or
    $deployedSeqs.Count -ne 1 -or
    $deployedSeqs[0].Name -ne "DiegeticTravel.seq") {
    throw "Post-deployment topology verification failed; restore from $backup"
}

Write-Host "Deployed consolidated release: $target"
if (Test-Path -LiteralPath $backup) {
    Write-Host "Recoverable previous-mod backup: $backup"
}
Write-Host "MO2 profile state was not changed. Disable the separate development modules before testing."
