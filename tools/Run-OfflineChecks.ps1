param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [switch]$FullBuild
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Check([string]$Name, [scriptblock]$Action) {
    Write-Host "[offline] $Name"
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Offline check failed: $Name (exit $LASTEXITCODE)"
    }
}

# This suite deliberately contains no deployment, MO2 profile editing, VFS
# launch, gameplay launch, or overwrite operation. xEdit-based build/audit
# scripts use copies in this repository's ignored build directory.
Invoke-Check "repository scope" {
    & (Join-Path $PSScriptRoot "Audit-RepositoryScope.ps1")
}
Invoke-Check "dependency lock" {
    & (Join-Path $PSScriptRoot "Audit-NativeDependencies.ps1") `
        -LoreRimRoot $LoreRimRoot
}
Invoke-Check "pure core build" {
    & cmake --build --preset parchment-core
}
Invoke-Check "pure core tests" {
    & ctest --preset parchment-core
}
Invoke-Check "source and package-boundary audit" {
    & (Join-Path $PSScriptRoot "Audit-ParchmentPicker.ps1")
}

if ($FullBuild) {
    Invoke-Check "consolidated release build and audits" {
        & (Join-Path $PSScriptRoot "Build-Release.ps1") `
            -LoreRimRoot $LoreRimRoot
    }
}

Write-Host "Offline checks passed. LoreRim deployment and gameplay were not touched."
