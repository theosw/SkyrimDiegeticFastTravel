param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [string]$PackageRoot = "build\DiegeticTravel-beta"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"

function Resolve-ProjectPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$package = Resolve-ProjectPath $PackageRoot
$xedit = Resolve-ProjectPath $XEdit
$plugin = Join-Path $package "DiegeticTravel.esp"
$seq = Join-Path $package "SEQ\DiegeticTravel.seq"
$report = Join-Path $buildRoot "release-package-audit.txt"
$expectedMasters = @(
    "Skyrim.esm",
    "Update.esm",
    "Dawnguard.esm",
    "HearthFires.esm",
    "Dragonborn.esm",
    "CFTO.esp"
)

foreach ($required in @($package, $xedit, $plugin, $seq)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required release-audit input not found: $required"
    }
}

$plugins = @(Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object {
    $_.Extension.ToLowerInvariant() -in @(".esp", ".esm", ".esl")
})
if ($plugins.Count -ne 1 -or $plugins[0].Name -ne "DiegeticTravel.esp") {
    throw "Release must contain exactly one plugin: DiegeticTravel.esp"
}

$sequences = @(Get-ChildItem -LiteralPath $package -Recurse -File -Filter "*.seq")
if ($sequences.Count -ne 1 -or $sequences[0].Name -ne "DiegeticTravel.seq") {
    throw "Release must contain exactly one combined SEQ: DiegeticTravel.seq"
}
if ((Get-Item -LiteralPath $seq).Length -ne (17 * 4)) {
    throw "Combined SEQ must contain exactly 17 FormIDs"
}

$forbiddenNames = @(
    "DiegeticTravelWizardGuides.esp",
    "DiegeticTravelWizardParchment.esp",
    "DiegeticTravelCarriageParchment.esp",
    "DiegeticTravelBoatHonrich.esp",
    "DiegeticTravelBoatIlinalta.esp",
    "DiegeticTravelBoatNorthCoast.esp",
    "DiegeticTravelBoatSolstheim.esp",
    "DiegeticTravelBoatBaanMalur.esp",
    "DiegeticTravelWizardMap.esp"
)
foreach ($forbidden in $forbiddenNames) {
    if (Get-ChildItem -LiteralPath $package -Recurse -File -Filter $forbidden) {
        throw "Release contains a development-only plugin: $forbidden"
    }
}
if (Get-ChildItem -LiteralPath $package -Recurse -File -Filter "*.pdb") {
    throw "Release must not contain developer PDB files"
}

$pluginBytes = [IO.File]::ReadAllBytes($plugin)
if ($pluginBytes.Length -lt 24 -or
    [Text.Encoding]::ASCII.GetString($pluginBytes, 0, 4) -ne "TES4") {
    throw "Release plugin has an invalid TES4 header"
}
$flags = [BitConverter]::ToUInt32($pluginBytes, 8)
if (($flags -band 0x200) -eq 0) {
    throw "Release plugin is not ESL-flagged"
}
$recordDataSize = [BitConverter]::ToUInt32($pluginBytes, 4)
$recordEnd = 24 + $recordDataSize
$cursor = 24
$masters = [Collections.Generic.List[string]]::new()
$nextObjectId = $null
while ($cursor + 6 -le $recordEnd) {
    $signature = [Text.Encoding]::ASCII.GetString($pluginBytes, $cursor, 4)
    $size = [BitConverter]::ToUInt16($pluginBytes, $cursor + 4)
    $dataOffset = $cursor + 6
    if ($dataOffset + $size -gt $recordEnd) {
        throw "Release plugin contains a malformed TES4 subrecord"
    }
    if ($signature -eq "MAST") {
        $name = [Text.Encoding]::ASCII.GetString($pluginBytes, $dataOffset, $size)
        $masters.Add($name.TrimEnd([char]0))
    } elseif ($signature -eq "HEDR" -and $size -ge 12) {
        $nextObjectId = [BitConverter]::ToUInt32($pluginBytes, $dataOffset + 8)
    }
    $cursor = $dataOffset + $size
}
if (@($masters).Count -ne $expectedMasters.Count) {
    throw "Release plugin master count mismatch: $($masters -join ', ')"
}
for ($index = 0; $index -lt $expectedMasters.Count; $index++) {
    if ($masters[$index] -ne $expectedMasters[$index]) {
        throw "Release plugin master order mismatch at $index"
    }
}
if ($null -eq $nextObjectId -or $nextObjectId -gt 0x1000) {
    throw ("Release plugin exceeds the ESL local-ID ceiling: 0x{0:X}" -f $nextObjectId)
}

$sourceRoots = @(
    "mod\Scripts\Source",
    "modules\wizard-guides\mod\Scripts\Source",
    "modules\parchment-picker\mod\Scripts\Source",
    "modules\carriage-parchment\mod\Scripts\Source",
    "modules\boat-honrich\mod\Scripts\Source",
    "modules\boat-ilinalta\mod\Scripts\Source",
    "modules\boat-north-coast\mod\Scripts\Source",
    "modules\boat-solstheim\mod\Scripts\Source"
)
$expectedScripts = @($sourceRoots | ForEach-Object {
    Get-ChildItem -LiteralPath (Join-Path $projectRoot $_) -File -Filter "DNT_*.psc"
} | Select-Object -ExpandProperty BaseName -Unique | Sort-Object)
if ($expectedScripts.Count -ne 22) {
    throw "Release source inventory changed; expected 22 scripts, found $($expectedScripts.Count)"
}
foreach ($scriptName in $expectedScripts) {
    foreach ($extension in @("psc", "pex")) {
        $path = if ($extension -eq "psc") {
            Join-Path $package "Scripts\Source\$scriptName.$extension"
        } else {
            Join-Path $package "Scripts\$scriptName.$extension"
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Release is missing $scriptName.$extension"
        }
    }
}
$packagedSources = @(Get-ChildItem -LiteralPath (Join-Path $package "Scripts\Source") `
    -File -Filter "DNT_*.psc" | Select-Object -ExpandProperty BaseName | Sort-Object)
$packagedScripts = @(Get-ChildItem -LiteralPath (Join-Path $package "Scripts") `
    -File -Filter "DNT_*.pex" | Select-Object -ExpandProperty BaseName | Sort-Object)
if (($packagedSources -join "`n") -ne ($expectedScripts -join "`n") -or
    ($packagedScripts -join "`n") -ne ($expectedScripts -join "`n")) {
    throw "Release contains an unexpected or stale DNT script"
}

$originServiceSourcePath = Join-Path $package "Scripts\Source\DNT_OriginService.psc"
$nativePapyrusSourcePath = Join-Path $package "Scripts\Source\DNT_ParchmentNative.psc"
$wizardPickerSourcePath = Join-Path $package "Scripts\Source\DNT_WizardParchmentPicker.psc"
$coordinatorSourcePath = Join-Path $package "Scripts\Source\DNT_TravelCoordinator.psc"
$originServiceSource = Get-Content -LiteralPath $originServiceSourcePath -Raw
$nativePapyrusSource = Get-Content -LiteralPath $nativePapyrusSourcePath -Raw
$wizardPickerSource = Get-Content -LiteralPath $wizardPickerSourcePath -Raw
$coordinatorSource = Get-Content -LiteralPath $coordinatorSourcePath -Raw
if ($originServiceSource -notmatch [regex]::Escape("DNT_ParchmentNative.ResolveCarriageDestinationMarker(destinationId)")) {
    throw "Packaged carriage purchase does not use the native catalogue marker resolver"
}
if ($originServiceSource -match "Function\s+GetCarriageDestinationMarker" -or
    $originServiceSource -match [regex]::Escape("DNT_ParchmentNative.GetCarriageHours")) {
    throw "Packaged carriage purchase contains a retired duplicated marker/quote path"
}
if ($coordinatorSource -match 'Bool\s+Function\s+Purchase\s*\(' -or
    $originServiceSource -match 'Bool\s+Function\s+(CommitDestination|PurchaseDestination)\s*\(') {
    throw "Packaged carriage runtime contains retired purchase wrappers"
}
if ($nativePapyrusSource -notmatch [regex]::Escape("ObjectReference Function ResolveCarriageDestinationMarker(String DestinationId) Global Native")) {
    throw "Packaged native Papyrus contract is missing its ObjectReference marker resolver"
}
if ($nativePapyrusSource -notmatch [regex]::Escape("Int Function BuildWizardRequest(String RequestId, ObjectReference SourceRef, Int Fare) Global Native") -or
    $wizardPickerSource -notmatch [regex]::Escape("DNT_ParchmentNative.BuildWizardRequest(ActiveRequest, SourceRef, Fare)")) {
    throw "Packaged wizard picker is missing its single-call native request builder"
}
if ($wizardPickerSource -match "MirabellePresentation" -or
    $wizardPickerSource -match [regex]::Escape("DNT_ParchmentNative.PlayPresentation") -or
    $wizardPickerSource -match [regex]::Escape("DNT_ParchmentNative.BeginRequest")) {
    throw "Packaged wizard picker contains the retired Mirabelle/slow request path"
}
foreach ($retiredNativeName in @("PlayPresentation", "SetDestinationMarkerTexture")) {
    if ($nativePapyrusSource -match [regex]::Escape($retiredNativeName)) {
        throw "Packaged native Papyrus contract contains retired API: $retiredNativeName"
    }
}

$releaseTextureManifest = Join-Path $projectRoot "config\release-textures.txt"
$expectedTextureNames = @(Get-Content -LiteralPath $releaseTextureManifest | Where-Object {
    $_ -and -not $_.StartsWith("#")
} | Sort-Object)
$packagedTextures = @(Get-ChildItem -LiteralPath (Join-Path $package "textures\DiegeticTravel") `
    -File -Filter "*.dds" | Select-Object -ExpandProperty Name | Sort-Object)
if (($expectedTextureNames -join "`n") -ne ($packagedTextures -join "`n")) {
    throw "Release DDS inventory does not match config/release-textures.txt"
}
$unexpectedMedia = @(Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object {
    $_.Extension.ToLowerInvariant() -in @(".png", ".jpg", ".jpeg", ".svg", ".wav", ".xwm", ".fuz")
})
if ($unexpectedMedia.Count -gt 0) {
    throw "Release contains unexpected artwork/audio: $($unexpectedMedia.FullName -join ', ')"
}

$dlls = @(Get-ChildItem -LiteralPath $package -Recurse -File -Filter "*.dll")
if ($dlls.Count -ne 1 -or $dlls[0].Name -ne "DNTParchmentPicker.dll") {
    throw "Release must contain only DNTParchmentPicker.dll"
}
$nativePexPath = Join-Path $package "Scripts\DNT_ParchmentNative.pex"
foreach ($nativeContractArtifact in @($dlls[0].FullName, $nativePexPath)) {
    $nativeContractBytes = [IO.File]::ReadAllBytes($nativeContractArtifact)
    $nativeContractText = [Text.Encoding]::ASCII.GetString($nativeContractBytes)
    foreach ($nativeContractName in @("ResolveCarriageDestinationMarker", "BuildWizardRequest")) {
        if (-not $nativeContractText.Contains($nativeContractName)) {
            throw "Release contains a mismatched DLL/PEX native contract ($nativeContractName): $nativeContractArtifact"
        }
    }
}
$pricingIniPath = Join-Path $package "SKSE\Plugins\DiegeticTravel.ini"
if (-not (Test-Path -LiteralPath $pricingIniPath -PathType Leaf)) {
    throw "Release is missing DiegeticTravel.ini"
}
$pricingIni = Get-Content -LiteralPath $pricingIniPath -Raw
foreach ($pricingToken in @(
    "[Carriage]",
    "HoursPerMapUnit=10.0",
    "FarePerMapUnit=1600.0",
    "MinimumFare=100",
    "FareStep=50",
    "[Wizard]",
    "FarePerTrip=250",
    "[Ferries]",
    "UseCFTOFares=true",
    "LocalFareOverride=-1",
    "RegionalFareOverride=-1",
    "ExtraFareOverride=-1",
    "[Display]",
    "ShowEstimatedHours=true",
    "MarkHoursAsApproximate=true"
)) {
    if ($pricingIni -notmatch [regex]::Escape($pricingToken)) {
        throw "DiegeticTravel.ini is missing default contract: $pricingToken"
    }
}
$travelCatalogPath = Join-Path $package `
    "SKSE\Plugins\DiegeticTravel\travel_catalog.tsv"
if (-not (Test-Path -LiteralPath $travelCatalogPath -PathType Leaf)) {
    throw "Release is missing travel_catalog.tsv"
}
$travelCatalogLines = @(Get-Content -LiteralPath $travelCatalogPath | Where-Object {
    $_ -and -not $_.StartsWith("#")
})
if ($travelCatalogLines[0] -ne "schema`t1") {
    throw "travel_catalog.tsv has an unsupported schema"
}
$travelCatalogPolicies = @($travelCatalogLines | Where-Object { $_.StartsWith("policy`t") })
$travelCatalogLocations = @($travelCatalogLines | Where-Object { $_.StartsWith("location`t") })
if ($travelCatalogPolicies.Count -ne 1 -or $travelCatalogLocations.Count -ne 28) {
    throw "travel_catalog.tsv must contain one policy and 28 carriage locations"
}
$embassyRow = "location`tthalmor_embassy`tThalmor Embassy`t0.317566`t0.169034`tCFTO.esp`t0x0B6E54`tone_way"
if ($travelCatalogLocations -notcontains $embassyRow) {
    throw "travel_catalog.tsv is missing the authored CFTO Thalmor Embassy handoff"
}
foreach ($obsolete in @("runtime.json", "dialogue_runtime.json")) {
    $obsoletePath = Join-Path $package "SKSE\Plugins\DiegeticTravel\$obsolete"
    if (Test-Path -LiteralPath $obsoletePath -PathType Leaf) {
        throw "Release contains obsolete graph artifact: $obsolete"
    }
}

$auditRoot = Join-Path $buildRoot "release-check-for-errors"
$staging = Join-Path $auditRoot "data"
$pluginsList = Join-Path $auditRoot "plugins.txt"
$scriptPath = Join-Path $projectRoot "tools\xedit\DNT_AuditReleasePlugin.pas"
$statusPath = Join-Path $buildRoot "release-package-xedit-audit.status"
$errorPath = Join-Path $buildRoot "release-package-xedit-audit.error"
$xeditReportPath = Join-Path $buildRoot `
    "release-package-xedit-audit.report.txt"
$resolvedAudit = [IO.Path]::GetFullPath($auditRoot)
$resolvedBuild = [IO.Path]::GetFullPath($buildRoot)
if (-not $resolvedAudit.StartsWith($resolvedBuild, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean release audit outside build"
}
if (Test-Path -LiteralPath $auditRoot) {
    Remove-Item -LiteralPath $auditRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $staging | Out-Null
$stockData = Join-Path $LoreRimRoot "Stock Game\Data"
foreach ($master in @($expectedMasters[0..4] + "Skyrim - Interface.bsa")) {
    Copy-Item -LiteralPath (Join-Path $stockData $master) `
        -Destination (Join-Path $staging $master) -Force
}
$cfto = Join-Path $LoreRimRoot `
    "mods\Carriage and Ferry Travel Overhaul - Fixes and Winterhold\CFTO.esp"
Copy-Item -LiteralPath $cfto -Destination (Join-Path $staging "CFTO.esp") -Force
Copy-Item -LiteralPath $plugin -Destination (Join-Path $staging "DiegeticTravel.esp") -Force
[IO.File]::WriteAllText(
    $pluginsList,
    "*CFTO.esp`r`n*DiegeticTravel.esp`r`n",
    [Text.UTF8Encoding]::new($false)
)
foreach ($auditOutput in @($statusPath, $errorPath, $xeditReportPath)) {
    if (Test-Path -LiteralPath $auditOutput -PathType Leaf) {
        Remove-Item -LiteralPath $auditOutput -Force
    }
}
$arguments = @(
    "-sse",
    "-D:$staging",
    "-P:$pluginsList",
    "-IKnowWhatImDoing",
    "-nobuildrefs",
    "-autoload",
    "-autoexit",
    "-script:$scriptPath"
)
$process = Start-Process -FilePath $xedit -ArgumentList $arguments `
    -WindowStyle Hidden -PassThru
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
    throw "Consolidated xEdit audit failed: $detail"
}
if ($terminalStatus -ne "success") {
    throw "Consolidated xEdit audit did not report success"
}
$xeditReport = @(Get-Content -LiteralPath $xeditReportPath)
foreach ($expectedLine in @(
    "PASS masters=6",
    "PASS esl=true",
    "PASS start_game_quests=17",
    "PASS origin_services=9",
    "PASS critical_quest_scripts=8"
)) {
    if ($expectedLine -notin $xeditReport) {
        throw "Consolidated xEdit audit omitted: $expectedLine"
    }
}

$lines = @(
    "PASS plugin=DiegeticTravel.esp",
    "PASS esl_flag=true",
    ("PASS next_object_id=0x{0:X}" -f $nextObjectId),
    "PASS masters=$($masters -join ',')",
    "PASS seq_quests=17",
    "PASS papyrus_scripts=$($expectedScripts.Count)",
    "PASS textures=$($expectedTextureNames.Count)",
    "PASS native_dll=DNTParchmentPicker.dll",
    "PASS pricing_ini=DiegeticTravel.ini",
    "PASS xedit_semantic_audit=true"
)
[IO.File]::WriteAllLines($report, $lines, [Text.UTF8Encoding]::new($false))
$lines | ForEach-Object { Write-Host $_ }
Write-Host "Release audit report: $report"
