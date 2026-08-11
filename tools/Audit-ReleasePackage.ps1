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
if ((Get-Item -LiteralPath $seq).Length -ne (18 * 4)) {
    throw "Combined SEQ must contain exactly 18 FormIDs"
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
if ($expectedScripts.Count -ne 26) {
    throw "Release source inventory changed; expected 26 scripts, found $($expectedScripts.Count)"
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

$dlls = @(Get-ChildItem -LiteralPath $package -Recurse -File -Filter "*.dll")
if ($dlls.Count -ne 1 -or $dlls[0].Name -ne "DNTParchmentPicker.dll") {
    throw "Release must contain only DNTParchmentPicker.dll"
}
$dialogueRuntimePath = Join-Path $package `
    "SKSE\Plugins\DiegeticTravel\dialogue_runtime.json"
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
if ($travelCatalogPolicies.Count -ne 1 -or $travelCatalogLocations.Count -ne 27) {
    throw "travel_catalog.tsv must contain one policy and 27 carriage locations"
}
foreach ($jsonName in @("runtime.json", "dialogue_runtime.json")) {
    $jsonPath = Join-Path $package "SKSE\Plugins\DiegeticTravel\$jsonName"
    if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) {
        throw "Release is missing $jsonName"
    }
    $null = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
}

# The consolidated core generator reserves 0x900-0x9FF for every form that is
# embedded in dialogue_runtime.json. A stale xEdit load-order mapping once
# emitted otherwise-plausible 0x800-range references; the ESP passed Check for
# Errors, but JContainers resolved those references to None at runtime and the
# carriage parchment could not open. Keep this a package-level invariant.
$dialogueRuntimeRaw = Get-Content -LiteralPath $dialogueRuntimePath -Raw
$dialogueRuntime = $dialogueRuntimeRaw | ConvertFrom-Json
$selfFormMatches = [regex]::Matches(
    $dialogueRuntimeRaw,
    '__formData\|DiegeticTravel\.esp\|0x([0-9A-Fa-f]{6})'
)
if ($selfFormMatches.Count -eq 0) {
    throw "dialogue_runtime.json contains no DiegeticTravel form references"
}
foreach ($match in $selfFormMatches) {
    $objectId = [Convert]::ToUInt32($match.Groups[1].Value, 16)
    if ($objectId -lt 0x900 -or $objectId -ge 0xA00) {
        throw (
            "dialogue_runtime.json contains a stale core FormID: 0x{0:X6}" -f `
                $objectId
        )
    }
}
$originServices = @($dialogueRuntime.origin_services)
if ($originServices.Count -ne 9) {
    throw "dialogue_runtime.json must contain exactly 9 carriage origin services"
}
$serviceRefs = @($originServices | Select-Object -ExpandProperty service -Unique)
if ($serviceRefs.Count -ne $originServices.Count) {
    throw "dialogue_runtime.json contains duplicate carriage service references"
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
    "PASS start_game_quests=18",
    "PASS origin_services=9",
    "PASS critical_quest_scripts=9"
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
    "PASS seq_quests=18",
    "PASS papyrus_scripts=$($expectedScripts.Count)",
    "PASS native_dll=DNTParchmentPicker.dll",
    "PASS xedit_semantic_audit=true"
)
[IO.File]::WriteAllLines($report, $lines, [Text.UTF8Encoding]::new($false))
$lines | ForEach-Object { Write-Host $_ }
Write-Host "Release audit report: $report"
