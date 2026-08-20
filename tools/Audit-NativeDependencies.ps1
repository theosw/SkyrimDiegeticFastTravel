param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$CommonLibRoot = "C:\Users\Theo\Documents\SKSE Plugins\FrameGenTest\extern\CommonLibSSE-NG"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$lockPath = Join-Path $projectRoot "dependencies.lock.json"
if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
    throw "Dependency lock was not found: $lockPath"
}
$lock = Get-Content -Raw -LiteralPath $lockPath | ConvertFrom-Json

function Resolve-LoreRimPath([string]$RelativePath) {
    return [System.IO.Path]::GetFullPath((Join-Path $LoreRimRoot ($RelativePath -replace '/', '\')))
}

function Assert-Hash([string]$Label, [pscustomobject]$Entry) {
    $path = Resolve-LoreRimPath $Entry.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "$Label dependency was not found: $path"
    }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($actual -ne $Entry.sha256) {
        throw "$Label hash mismatch. Expected $($Entry.sha256), found $actual at $path"
    }
    return $path
}

function Assert-OptionalHash([string]$Label, [pscustomobject]$Entry) {
    $path = Resolve-LoreRimPath $Entry.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host "$Label is not installed; the native fallback will be used."
        return $null
    }
    return Assert-Hash $Label $Entry
}

$runtime = $lock.targetRuntime
$skyrimPath = Assert-Hash "Skyrim" $runtime.skyrim
$skyrimVersion = (Get-Item -LiteralPath $skyrimPath).VersionInfo.ProductVersion
if ($skyrimVersion -ne $runtime.skyrim.version) {
    throw "Skyrim version mismatch. Expected $($runtime.skyrim.version), found $skyrimVersion"
}

$null = Assert-Hash "SKSE" $runtime.skse
$null = Assert-Hash "Address Library" $runtime.addressLibrary
$null = Assert-Hash "SKSE Menu Framework" $runtime.menuFramework
$null = Assert-OptionalHash "recommended RUSTIC MAPS artwork" $runtime.artwork
$null = Assert-OptionalHash "recommended Caro Tuts wizard artwork" $runtime.wizardArtwork
if ($runtime.artwork.dependencyType -notmatch "optional visual recommendation" -or
    $runtime.wizardArtwork.dependencyType -notmatch "optional visual recommendation") {
    throw "RUSTIC MAPS and the Caro Tuts chart must remain optional visual recommendations."
}
$null = Assert-Hash "CFTO base" $runtime.cftoBase
$null = Assert-Hash "CFTO Fixes and Winterhold" $runtime.cftoFixesAndWinterhold
$null = Assert-Hash "optional Wait Carriage in Inns" $runtime.optionalWaitCarriageInInns
if ($runtime.optionalWaitCarriageInInns.dependencyType -notmatch "optional soft lookup") {
    throw "Wait Carriage in Inns compatibility must remain an optional soft lookup."
}
$null = Assert-Hash "optional Wizarding Traversal" $runtime.optionalApparitionTravel
if ($runtime.optionalApparitionTravel.dependencyType -notmatch "optional soft lookup" -or
    $runtime.optionalApparitionTravel.holderMagicEffectLocalFormId -ne "000808") {
    throw "Wizarding Traversal compatibility must remain a soft lookup of holder effect 000808."
}

$wizardMarkerSource = $lock.assetSources.wizardTravelMarker
$wizardMarkerSourcePath = [System.IO.Path]::GetFullPath((Join-Path `
    $projectRoot `
    ($wizardMarkerSource.repositoryPath -replace '/', '\')))
if (-not (Test-Path -LiteralPath $wizardMarkerSourcePath -PathType Leaf)) {
    throw "Credited wizard-marker source was not found: $wizardMarkerSourcePath"
}
$wizardMarkerSourceHash = (Get-FileHash -LiteralPath `
    $wizardMarkerSourcePath -Algorithm SHA256).Hash
if ($wizardMarkerSourceHash -ne $wizardMarkerSource.sha256) {
    throw "Credited wizard-marker source hash mismatch. Expected $($wizardMarkerSource.sha256), found $wizardMarkerSourceHash"
}

if (-not (Test-Path -LiteralPath $CommonLibRoot -PathType Container)) {
    throw "CommonLibSSE-NG checkout was not found: $CommonLibRoot"
}
$commonLibCommit = (& git -C $CommonLibRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commonLibCommit -ne $lock.buildDependencies.commonLibSseNg.commit) {
    throw "CommonLib commit mismatch. Expected $($lock.buildDependencies.commonLibSseNg.commit), found $commonLibCommit"
}
$commonLibRemote = (& git -C $CommonLibRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $commonLibRemote -ne $lock.buildDependencies.commonLibSseNg.repository) {
    throw "CommonLib origin mismatch. Expected $($lock.buildDependencies.commonLibSseNg.repository), found $commonLibRemote"
}

$vcpkg = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "vcpkg.json") | ConvertFrom-Json
if ($vcpkg.'builtin-baseline' -ne $lock.buildDependencies.vcpkgBaseline) {
    throw "vcpkg baseline mismatch. Expected $($lock.buildDependencies.vcpkgBaseline), found $($vcpkg.'builtin-baseline')"
}

Write-Host "Native dependency audit passed."
Write-Host "Skyrim runtime: $skyrimVersion"
Write-Host "Optional Apparition compatibility: Wizarding Traversal $($runtime.optionalApparitionTravel.version), holder effect 000808"
Write-Host "CommonLib commit: $commonLibCommit"
Write-Host "Credited wizard marker source: $($wizardMarkerSource.name) $($wizardMarkerSource.version) ($wizardMarkerSourceHash)"
