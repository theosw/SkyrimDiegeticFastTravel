param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [string]$PackageName = "DiegeticTravel-beta",
    [string]$Version = "",
    [string]$BuildTimestampUtc = "",
    [switch]$PackageOnly
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "ReleaseIdentity.ps1")
$releaseIdentity = New-DntReleaseIdentity `
    -ProjectRoot $projectRoot `
    -Version $Version `
    -BuildTimestampUtc $BuildTimestampUtc
$buildRoot = Join-Path $projectRoot "build"
$releaseRoot = Join-Path $buildRoot "release"
$packageRoot = Join-Path $buildRoot $PackageName
$distRoot = Join-Path $projectRoot "dist"
$archiveBaseName = "DiegeticTravel-$($releaseIdentity.buildId)"
$archive = Join-Path $distRoot "$archiveBaseName.zip"
$mo2DisplayName = "DiegeticTravel $($releaseIdentity.buildId)"
$identityPath = Join-Path $buildRoot "release-identity.json"
$releaseTextureManifest = Join-Path $projectRoot "config\release-textures.txt"
$supportedModules = @(
    "wizard-guides",
    "parchment-picker",
    "carriage-parchment",
    "boat-honrich",
    "boat-ilinalta",
    "boat-north-coast",
    "boat-solstheim"
)

function Invoke-BuildStep([string]$Name, [scriptblock]$Action) {
    Write-Host "[release-build] $Name"
    $global:LASTEXITCODE = 0
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Release build step failed: $Name (exit $LASTEXITCODE)"
    }
}

if (-not $PackageOnly) {
    Invoke-BuildStep "dependency lock" {
        & (Join-Path $PSScriptRoot "Audit-NativeDependencies.ps1") `
            -LoreRimRoot $LoreRimRoot
    }
    Invoke-BuildStep "native parchment menu" {
        & cmake --build --preset parchment-ae-release
    }
    Invoke-BuildStep "native tests" {
        & ctest --preset parchment-ae-release
    }
    Invoke-BuildStep "source and data parity" {
        & (Join-Path $PSScriptRoot "Audit-ParchmentPicker.ps1")
    }

    $compilers = @(
        "Compile-Papyrus.ps1",
        "Compile-WizardGuidesPapyrus.ps1",
        "Compile-ParchmentPickerPapyrus.ps1",
        "Compile-CarriageParchmentPapyrus.ps1",
        "Compile-BoatHonrichPapyrus.ps1",
        "Compile-BoatIlinaltaPapyrus.ps1",
        "Compile-BoatNorthCoastPapyrus.ps1",
        "Compile-BoatSolstheimPapyrus.ps1"
    )
    foreach ($compiler in $compilers) {
        Invoke-BuildStep $compiler {
            & (Join-Path $PSScriptRoot $compiler) -LoreRimRoot $LoreRimRoot
        }
    }
    Invoke-BuildStep "consolidated ESP-FE" {
        & (Join-Path $PSScriptRoot "Generate-ReleasePlugin.ps1") `
            -LoreRimRoot $LoreRimRoot -XEdit $XEdit
    }
}

# Release packaging always proves every borrowed presentation asset, including
# PackageOnly rebuilds. This prevents a dependency update or stale workspace
# from producing an archive with a silent shared response.
Invoke-BuildStep "wizard voice assets" {
    & (Join-Path $PSScriptRoot "Audit-WizardVoiceAssets.ps1") `
        -LoreRimRoot $LoreRimRoot
}
Invoke-BuildStep "north-coast ferry voice assets" {
    & (Join-Path $PSScriptRoot "Audit-BoatNorthCoastVoiceAssets.ps1") `
        -LoreRimRoot $LoreRimRoot -XEdit $XEdit
}
Invoke-BuildStep "Solstheim ferry voice assets" {
    & (Join-Path $PSScriptRoot "Audit-BoatSolstheimVoiceAssets.ps1") `
        -LoreRimRoot $LoreRimRoot -XEdit $XEdit
}
Invoke-BuildStep "Lake Honrich ferry voice assets" {
    & (Join-Path $PSScriptRoot "Audit-BoatHonrichVoiceAssets.ps1") `
        -LoreRimRoot $LoreRimRoot -XEdit $XEdit
}
Invoke-BuildStep "Lake Ilinalta ferry voice assets" {
    & (Join-Path $PSScriptRoot "Audit-BoatIlinaltaVoiceAssets.ps1") `
        -LoreRimRoot $LoreRimRoot -XEdit $XEdit
}

$required = @(
    (Join-Path $releaseRoot "DiegeticTravel.esp"),
    (Join-Path $releaseRoot "SEQ\DiegeticTravel.seq"),
    (Join-Path $projectRoot "THIRD_PARTY_NOTICES.txt"),
    $releaseTextureManifest
)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required consolidated release input not found: $path"
    }
}

$resolvedPackage = [IO.Path]::GetFullPath($packageRoot)
$resolvedBuild = [IO.Path]::GetFullPath($buildRoot)
if (-not $resolvedPackage.StartsWith($resolvedBuild, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean package directory outside build: $resolvedPackage"
}
if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}
foreach ($directory in @(
    $packageRoot,
    (Join-Path $packageRoot "SEQ"),
    (Join-Path $packageRoot "Scripts"),
    (Join-Path $packageRoot "Scripts\Source"),
    (Join-Path $packageRoot "SKSE\Plugins"),
    (Join-Path $packageRoot "SKSE\Plugins\DiegeticTravel"),
    (Join-Path $packageRoot "textures\DiegeticTravel")
)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Copy-Item -LiteralPath (Join-Path $projectRoot "mod\README.txt") `
    -Destination (Join-Path $packageRoot "README.txt") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "THIRD_PARTY_NOTICES.txt") `
    -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $releaseRoot "DiegeticTravel.esp") `
    -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $releaseRoot "SEQ\DiegeticTravel.seq") `
    -Destination (Join-Path $packageRoot "SEQ") -Force
$sourceRoots = @("mod\Scripts\Source") + @($supportedModules | ForEach-Object {
    "modules\$_\mod\Scripts\Source"
})
$sourceFiles = @($sourceRoots | ForEach-Object {
    Get-ChildItem -LiteralPath (Join-Path $projectRoot $_) `
        -File -Filter "DNT_*.psc"
})
if ($sourceFiles.Count -ne 22) {
    throw "Release source inventory changed; expected 22 scripts, found $($sourceFiles.Count)"
}
$duplicateNames = @($sourceFiles | Group-Object BaseName | Where-Object Count -ne 1)
if ($duplicateNames.Count -gt 0) {
    throw "Release script names must be unique: $($duplicateNames.Name -join ', ')"
}
foreach ($sourceFile in $sourceFiles) {
    $compiledRoot = if ($sourceFile.FullName.StartsWith(
        (Join-Path $projectRoot "mod\Scripts\Source"),
        [StringComparison]::OrdinalIgnoreCase
    )) {
        Join-Path $buildRoot "Scripts"
    } else {
        $sourceFile.Directory.Parent.FullName
    }
    $compiledFile = Join-Path $compiledRoot ($sourceFile.BaseName + ".pex")
    if (-not (Test-Path -LiteralPath $compiledFile -PathType Leaf)) {
        throw "Compiled release script not found: $compiledFile"
    }
    Copy-Item -LiteralPath $sourceFile.FullName `
        -Destination (Join-Path $packageRoot "Scripts\Source") -Force
    Copy-Item -LiteralPath $compiledFile `
        -Destination (Join-Path $packageRoot "Scripts") -Force
}

$parchmentMod = Join-Path $projectRoot "modules\parchment-picker\mod"
Copy-Item -LiteralPath (Join-Path $parchmentMod "SKSE\Plugins\DNTParchmentPicker.dll") `
    -Destination (Join-Path $packageRoot "SKSE\Plugins") -Force
Copy-Item -LiteralPath (Join-Path $parchmentMod "SKSE\Plugins\DiegeticTravel.ini") `
    -Destination (Join-Path $packageRoot "SKSE\Plugins") -Force
Copy-Item -LiteralPath (Join-Path $parchmentMod "SKSE\Plugins\DiegeticTravel\travel_catalog.tsv") `
    -Destination (Join-Path $packageRoot "SKSE\Plugins\DiegeticTravel") -Force
$releaseTextureNames = @(Get-Content -LiteralPath $releaseTextureManifest | Where-Object {
    $_ -and -not $_.StartsWith("#")
})
if ($releaseTextureNames.Count -ne 22 -or
    @($releaseTextureNames | Sort-Object -Unique).Count -ne $releaseTextureNames.Count) {
    throw "Release texture manifest must contain exactly 22 unique DDS names"
}
foreach ($textureName in $releaseTextureNames) {
    $textureSource = Join-Path $parchmentMod "textures\DiegeticTravel\$textureName"
    if (-not (Test-Path -LiteralPath $textureSource -PathType Leaf)) {
        throw "Release texture input not found: $textureSource"
    }
    Copy-Item -LiteralPath $textureSource `
        -Destination (Join-Path $packageRoot "textures\DiegeticTravel") -Force
}

$manifestLines = Get-ChildItem -LiteralPath $packageRoot -Recurse -File |
    Sort-Object FullName |
    ForEach-Object {
        $relative = $_.FullName.Substring($packageRoot.Length + 1)
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        "$hash  $relative"
    }
[IO.File]::WriteAllLines(
    (Join-Path $packageRoot "PACKAGE-MANIFEST.txt"),
    $manifestLines,
    [Text.UTF8Encoding]::new($false)
)

Invoke-BuildStep "consolidated package audit" {
    & (Join-Path $PSScriptRoot "Audit-ReleasePackage.ps1") `
        -LoreRimRoot $LoreRimRoot -XEdit $XEdit -PackageRoot $packageRoot
}

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
if (Test-Path -LiteralPath $archive -PathType Leaf) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") `
    -DestinationPath $archive -CompressionLevel Optimal
$metaPath = Write-DntMo2ArchiveMeta `
    -ArchivePath $archive `
    -DisplayName $mo2DisplayName `
    -Identity $releaseIdentity
Write-DntReleaseIdentity -Identity $releaseIdentity -Path $identityPath
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Host "Consolidated release package: $archive"
Write-Host "MO2 sidecar metadata: $metaPath"
Write-Host "MO2 suggested name: $mo2DisplayName"
Write-Host "SHA-256: $archiveHash"
