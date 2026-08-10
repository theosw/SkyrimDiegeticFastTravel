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

function Get-AddressLibraryMappings([string]$Path, [uint64[]]$TargetIds) {
    $stream = [System.IO.File]::OpenRead($Path)
    $reader = [System.IO.BinaryReader]::new($stream)
    try {
        $format = $reader.ReadInt32()
        if ($format -ne 2) {
            throw "Unsupported Address Library format: $format"
        }
        $version = @(
            $reader.ReadInt32(),
            $reader.ReadInt32(),
            $reader.ReadInt32(),
            $reader.ReadInt32()
        )
        $nameLength = $reader.ReadInt32()
        $databaseName = [Text.Encoding]::UTF8.GetString($reader.ReadBytes($nameLength))
        $pointerSize = $reader.ReadInt32()
        $addressCount = $reader.ReadInt32()

        [uint64]$id = 0
        [uint64]$offset = 0
        [uint64]$previousId = 0
        [uint64]$previousOffset = 0
        $targetSet = @{}
        foreach ($targetId in $TargetIds) {
            $targetSet[[string]$targetId] = $null
        }

        for ($index = 0; $index -lt $addressCount; $index += 1) {
            $type = $reader.ReadByte()
            $low = $type -band 0xF
            $high = $type -shr 4

            switch ($low) {
                0 { $id = $reader.ReadUInt64() }
                1 { $id = $previousId + 1 }
                2 { $id = $previousId + $reader.ReadByte() }
                3 { $id = $previousId - $reader.ReadByte() }
                4 { $id = $previousId + $reader.ReadUInt16() }
                5 { $id = $previousId - $reader.ReadUInt16() }
                6 { $id = $reader.ReadUInt16() }
                7 { $id = $reader.ReadUInt32() }
                default { throw "Unhandled Address Library ID encoding: $low" }
            }

            [uint64]$temporaryOffset = if (($high -band 8) -ne 0) {
                [uint64]($previousOffset / $pointerSize)
            } else {
                $previousOffset
            }
            switch ($high -band 7) {
                0 { $offset = $reader.ReadUInt64() }
                1 { $offset = $temporaryOffset + 1 }
                2 { $offset = $temporaryOffset + $reader.ReadByte() }
                3 { $offset = $temporaryOffset - $reader.ReadByte() }
                4 { $offset = $temporaryOffset + $reader.ReadUInt16() }
                5 { $offset = $temporaryOffset - $reader.ReadUInt16() }
                6 { $offset = $reader.ReadUInt16() }
                7 { $offset = $reader.ReadUInt32() }
            }
            if (($high -band 8) -ne 0) {
                $offset *= $pointerSize
            }

            $key = [string]$id
            if ($targetSet.ContainsKey($key)) {
                $targetSet[$key] = $offset
            }
            $previousId = $id
            $previousOffset = $offset
        }

        return [pscustomobject]@{
            Version = $version -join '.'
            DatabaseName = $databaseName
            PointerSize = $pointerSize
            AddressCount = $addressCount
            Mappings = $targetSet
        }
    } finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

$runtime = $lock.targetRuntime
$skyrimPath = Assert-Hash "Skyrim" $runtime.skyrim
$skyrimVersion = (Get-Item -LiteralPath $skyrimPath).VersionInfo.ProductVersion
if ($skyrimVersion -ne $runtime.skyrim.version) {
    throw "Skyrim version mismatch. Expected $($runtime.skyrim.version), found $skyrimVersion"
}

$null = Assert-Hash "SKSE" $runtime.skse
$addressLibraryPath = Assert-Hash "Address Library" $runtime.addressLibrary
$null = Assert-Hash "SKSE Menu Framework" $runtime.menuFramework
$null = Assert-Hash "RUSTIC MAPS artwork" $runtime.artwork
$null = Assert-Hash "Caro Tuts wizard artwork" $runtime.wizardArtwork
$null = Assert-Hash "Wizard core" $runtime.wizardCore
$apparitionPath = Assert-Hash "optional Wizarding Traversal" $runtime.optionalApparitionTravel
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

$relocation = $lock.runtimeRelocations.scriptCompileAndRun
$targetIds = @(
    [uint64]$relocation.legacyAeId,
    [uint64]$relocation.modernAeId,
    [uint64]$relocation.nextLegacyId
)
$database = Get-AddressLibraryMappings $addressLibraryPath $targetIds
if ($database.Version -ne $runtime.skyrim.version) {
    throw "Address Library version mismatch. Expected $($runtime.skyrim.version), found $($database.Version)"
}
if ($database.DatabaseName -ne "SkyrimSE.exe") {
    throw "Unexpected Address Library target: $($database.DatabaseName)"
}

$legacyOffset = $database.Mappings[[string]$relocation.legacyAeId]
if ($relocation.legacyIdMustBeAbsentOnTarget -and $null -ne $legacyOffset) {
    throw "Legacy CompileAndRun ID $($relocation.legacyAeId) unexpectedly exists at 0x$('{0:X}' -f $legacyOffset)"
}
$modernOffset = $database.Mappings[[string]$relocation.modernAeId]
if ($null -eq $modernOffset) {
    throw "Modern CompileAndRun ID $($relocation.modernAeId) is missing from the target Address Library."
}
$modernOffsetHex = "0x{0:X}" -f $modernOffset
if ($modernOffsetHex -ne $relocation.targetOffset) {
    throw "Modern CompileAndRun offset mismatch. Expected $($relocation.targetOffset), found $modernOffsetHex"
}
$nextLegacyOffset = $database.Mappings[[string]$relocation.nextLegacyId]
$nextLegacyOffsetHex = "0x{0:X}" -f $nextLegacyOffset
if ($nextLegacyOffsetHex -ne $relocation.nextLegacyOffset) {
    throw "Legacy neighbor offset mismatch. Expected $($relocation.nextLegacyOffset), found $nextLegacyOffsetHex"
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
Write-Host "CompileAndRun legacy ID $($relocation.legacyAeId): absent (expected)"
Write-Host "CompileAndRun modern ID $($relocation.modernAeId): $modernOffsetHex"
Write-Host "Rejected fallback target ID $($relocation.nextLegacyId): $nextLegacyOffsetHex"
