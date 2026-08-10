param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$CoreModName = "DiegeticTravel - Carriage Core Test",
    [string]$AdapterModName = "DiegeticTravel - Carriage Parchment Test",
    [string]$CoreArchive = "dist\DiegeticTravel-alpha.zip",
    [string]$AdapterArchive = "dist\DiegeticTravelCarriageParchment-offline-candidate.zip",
    [string]$ParchmentModName = "DiegeticTravel - Parchment Picker Test"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$modsRoot = [System.IO.Path]::GetFullPath((Join-Path $LoreRimRoot "mods"))

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Resolve-OwnedTarget([string]$Name) {
    $target = [System.IO.Path]::GetFullPath((Join-Path $modsRoot $Name))
    $prefix = $modsRoot.TrimEnd('\') + '\'
    if (-not $target.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        $target -eq $modsRoot) {
        throw "Unsafe carriage test deployment target: $target"
    }
    return $target
}

function Expand-IsolatedArchive([string]$Archive, [string]$Target) {
    if (Test-Path -LiteralPath $Target) {
        Remove-Item -LiteralPath $Target -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    $targetPrefix = $Target.TrimEnd('\') + '\'
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) {
                continue
            }
            $destination = [System.IO.Path]::GetFullPath(
                (Join-Path $Target $entry.FullName)
            )
            if (-not $destination.StartsWith(
                $targetPrefix,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
                throw "Archive entry escapes carriage test target: $($entry.FullName)"
            }
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) `
                -Force | Out-Null
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile(
                $entry,
                $destination,
                $true
            )
        }
    }
    finally {
        $zip.Dispose()
    }
}

if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
    throw "Close Skyrim before deploying the carriage test modules."
}
if (-not (Test-Path -LiteralPath $modsRoot -PathType Container)) {
    throw "LoreRim mods directory was not found: $modsRoot"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$coreArchivePath = Resolve-ProjectPath $CoreArchive
$adapterArchivePath = Resolve-ProjectPath $AdapterArchive
foreach ($archive in @($coreArchivePath, $adapterArchivePath)) {
    if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        throw "Carriage test archive was not found: $archive"
    }
}

$coreTarget = Resolve-OwnedTarget $CoreModName
$adapterTarget = Resolve-OwnedTarget $AdapterModName
$parchmentTarget = Resolve-OwnedTarget $ParchmentModName
Expand-IsolatedArchive $coreArchivePath $coreTarget
Expand-IsolatedArchive $adapterArchivePath $adapterTarget

# The adapter deployment is archive-based. Catch the easy-to-miss case where
# Papyrus was recompiled but the candidate ZIP was not rebuilt.
$workspaceAdapterRoot = Join-Path $projectRoot "modules\carriage-parchment\mod"
foreach ($relativePath in @(
    "DiegeticTravelCarriageParchment.esp",
    "SEQ\DiegeticTravelCarriageParchment.seq",
    "Scripts\DNT_CarriageParchmentFragment.pex",
    "Scripts\DNT_CarriageParchmentPicker.pex"
)) {
    $workspacePath = Join-Path $workspaceAdapterRoot $relativePath
    $deployedPath = Join-Path $adapterTarget $relativePath
    $workspaceHash = (Get-FileHash -LiteralPath $workspacePath -Algorithm SHA256).Hash
    $deployedHash = (Get-FileHash -LiteralPath $deployedPath -Algorithm SHA256).Hash
    if ($workspaceHash -ne $deployedHash) {
        throw "Stale carriage parchment candidate archive: rebuild before deploy. Workspace '$workspacePath' does not match archive '$deployedPath'."
    }
}

$required = @(
    (Join-Path $coreTarget "DiegeticTravel.esp"),
    (Join-Path $coreTarget "Seq\DiegeticTravel.seq"),
    (Join-Path $coreTarget "Scripts\DNT_DialogueMenuListener.pex"),
    (Join-Path $coreTarget "Scripts\DNT_OriginService.pex"),
    (Join-Path $coreTarget "Scripts\DNT_RouteService.pex"),
    (Join-Path $coreTarget "Scripts\DNT_TravelCoordinator.pex"),
    (Join-Path $coreTarget "SKSE\Plugins\DiegeticTravel\runtime.json"),
    (Join-Path $coreTarget "SKSE\Plugins\DiegeticTravel\dialogue_runtime.json"),
    (Join-Path $adapterTarget "DiegeticTravelCarriageParchment.esp"),
    (Join-Path $adapterTarget "SEQ\DiegeticTravelCarriageParchment.seq"),
    (Join-Path $adapterTarget "Scripts\DNT_CarriageParchmentPicker.pex"),
    (Join-Path $adapterTarget "Scripts\DNT_CarriageParchmentFragment.pex"),
    (Join-Path $parchmentTarget "SKSE\Plugins\DNTParchmentPicker.dll"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\town-marker.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\falkreath-jarl-longhouse.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-town.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-settlement.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-farm.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-wood-mill.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-mine.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-riften-capital.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-windhelm-capital.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-whiterun-capital.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-solitude-capital.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-markarth-capital.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-winterhold-capital.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-morthal-capital.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-falkreath-capital.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-dawnstar-capital.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-roundtrip-selection-ring.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\norden-oneway-selection-ring.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\thin-circle-selection-ring.dds"),
    (Join-Path $parchmentTarget "textures\DiegeticTravel\thin-circle-oneway-selection-ring.dds")
)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
        (Get-Item -LiteralPath $path).Length -le 0) {
        throw "Required carriage test runtime file is missing: $path"
    }
}

$coreHash = (Get-FileHash -LiteralPath (Join-Path $coreTarget "DiegeticTravel.esp") `
    -Algorithm SHA256).Hash
$adapterHash = (Get-FileHash -LiteralPath `
    (Join-Path $adapterTarget "DiegeticTravelCarriageParchment.esp") `
    -Algorithm SHA256).Hash
$pickerHash = (Get-FileHash -LiteralPath `
    (Join-Path $adapterTarget "Scripts\DNT_CarriageParchmentPicker.pex") `
    -Algorithm SHA256).Hash

Write-Host "Deployed isolated carriage core: $coreTarget"
Write-Host "Deployed isolated carriage parchment adapter: $adapterTarget"
Write-Host "Core ESP SHA-256: $coreHash"
Write-Host "Adapter ESP SHA-256: $adapterHash"
Write-Host "Adapter picker PEX SHA-256: $pickerHash"
Write-Host "MO2 profile files were not changed."
