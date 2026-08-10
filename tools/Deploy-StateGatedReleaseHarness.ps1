param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$DeploymentMod = "DiegeticTravel - State Gate Test Harness"
)

$ErrorActionPreference = "Stop"
if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
    throw "Close SkyrimSE before deploying the state-gated release harness."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'Audit-StateGatedReleaseHarness.ps1') | Out-Host
$sourceRoot = Join-Path $projectRoot 'test-harness\state-gated-release\mod'
$modsRoot = [IO.Path]::GetFullPath((Join-Path $LoreRimRoot 'mods'))
if (-not (Test-Path -LiteralPath $modsRoot -PathType Container)) {
    throw "LoreRim mods directory was not found: $modsRoot"
}
$targetRoot = [IO.Path]::GetFullPath((Join-Path $modsRoot $DeploymentMod))
$prefix = $modsRoot.TrimEnd('\') + '\'
if (-not $targetRoot.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or $targetRoot -eq $modsRoot) {
    throw "Refusing to deploy outside LoreRim's mods directory: $targetRoot"
}
$marker = Join-Path $targetRoot 'DNT_STATE_GATE_TEST_OWNED.txt'
if (Test-Path -LiteralPath $targetRoot) {
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
        throw "Refusing to overwrite a mod not owned by this helper: $targetRoot"
    }
} else {
    New-Item -ItemType Directory -Path $targetRoot | Out-Null
    Set-Content -LiteralPath $marker -Encoding UTF8 -Value @(
        'Owned local development mod for Diegetic Travel state-gate tests.',
        'No plugin, script, native code, or runtime asset belongs in this mod.'
    )
}

$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File)
foreach ($source in $sourceFiles) {
    $destination = Join-Path $targetRoot $source.Name
    Copy-Item -LiteralPath $source.FullName -Destination $destination -Force
    if ((Get-FileHash $source.FullName -Algorithm SHA256).Hash -ne
        (Get-FileHash $destination -Algorithm SHA256).Hash) {
        throw "Deployment hash mismatch: $($source.Name)"
    }
}
$allowed = @($sourceFiles.Name + (Split-Path -Leaf $marker))
$extra = @(Get-ChildItem -LiteralPath $targetRoot -Recurse -File | Where-Object {
    $allowed -notcontains $_.Name
})
if ($extra) { throw "Unexpected file in owned harness mod: $($extra.FullName -join ', ')" }

Write-Output "Deployed isolated state-gate harness: $targetRoot"
Write-Output "Verified test files: $($sourceFiles.Count)"
Write-Output 'Plugin payload: none'
Write-Output 'MO2 profile files were not changed; enable the left-pane mod manually.'
