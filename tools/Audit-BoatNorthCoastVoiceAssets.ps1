param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$reportPath = Join-Path $projectRoot `
    "build\boat-north-coast-inventory.report.txt"

& (Join-Path $PSScriptRoot "Inventory-BoatNorthCoast.ps1") `
    -LoreRimRoot $LoreRimRoot `
    -XEdit $XEdit | Out-Host

if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "North-coast inventory report is missing."
}
$report = @(Get-Content -LiteralPath $reportPath)
$expectedActors = @(
    "KmodFerrymanDawnstar",
    "KmodFerrymanSolitude",
    "KmodFerrymanWindhelm",
    "KmodFerrymanMorthal",
    "KmodFerrymanLighthouse",
    "KmodFerrymanWinterhold",
    "KmodFerrymanDragonBridge"
)
foreach ($actor in $expectedActors) {
    $matches = @($report | Where-Object {
        $_ -like "ACTOR=$actor|*|VOICE=MaleEvenToned|*"
    })
    if ($matches.Count -ne 1) {
        throw "$actor does not resolve exactly once to MaleEvenToned."
    }
    Write-Host "PASS voice type $actor -> MaleEvenToned"
}
$sharedInfo = @($report | Where-Object {
    $_ -eq (
        "SHARED_INFO=DialogueFerryWhereDoYouWantToGo|" +
        "FORM=0201683A|TEXT=Where are you headed?"
    )
})
if ($sharedInfo.Count -ne 1) {
    throw "North-coast shared ferry response does not match."
}
$excludedActor = @($report | Where-Object {
    $_ -like "ACTOR=KmodFerrymanVolkihar|*|VOICE=MaleEvenToned|*"
})
if ($excludedActor.Count -ne 1) {
    throw "The excluded Volkihar ferryman could not be independently verified."
}
Write-Host "PASS excluded voice provider KmodFerrymanVolkihar -> not public"

$voiceArchive = Join-Path (
    Join-Path $LoreRimRoot "Stock Game\Data"
) "Skyrim - Voices_en0.bsa"
if (-not (Test-Path -LiteralPath $voiceArchive -PathType Leaf)) {
    throw "Required vanilla voice archive not found: $voiceArchive"
}
$expectedPath = (
    "sound\voice\dawnguard.esm\maleeventoned\" +
    "dlc1dialogueferrysystem__0001683a_1.fuz"
).ToLowerInvariant()
$found = $false

$stream = [System.IO.File]::OpenRead($voiceArchive)
$reader = [System.IO.BinaryReader]::new(
    $stream,
    [System.Text.Encoding]::ASCII
)
try {
    $magic = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
    $version = $reader.ReadUInt32()
    $null = $reader.ReadUInt32()
    $null = $reader.ReadUInt32()
    $folderCount = $reader.ReadUInt32()
    $fileCount = $reader.ReadUInt32()
    $null = $reader.ReadUInt32()
    $fileNameBytes = $reader.ReadUInt32()
    $null = $reader.ReadUInt32()
    if ($magic -ne "BSA`0" -or $version -ne 105) {
        throw "Unexpected vanilla voice archive header."
    }

    $folderFileCounts = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $folderCount; $i++) {
        $null = $reader.ReadUInt64()
        $count = $reader.ReadUInt32()
        $null = $reader.ReadUInt32()
        $null = $reader.ReadUInt64()
        $folderFileCounts.Add([int]$count)
    }

    $foldersByFile = [System.Collections.Generic.List[string]]::new(
        [int]$fileCount
    )
    foreach ($count in $folderFileCounts) {
        $length = $reader.ReadByte()
        $folder = [System.Text.Encoding]::ASCII.GetString(
            $reader.ReadBytes($length)
        ).TrimEnd([char]0).ToLowerInvariant()
        for ($i = 0; $i -lt $count; $i++) {
            $foldersByFile.Add($folder)
        }
        $stream.Position += 16L * $count
    }

    $fileNameBlob = [System.Text.Encoding]::ASCII.GetString(
        $reader.ReadBytes($fileNameBytes)
    )
    $fileNames = $fileNameBlob.Split(
        [char[]]@([char]0),
        [System.StringSplitOptions]::RemoveEmptyEntries
    )
    if ($fileNames.Count -ne $fileCount) {
        throw "Vanilla voice archive filename count mismatch."
    }
    for ($i = 0; $i -lt $fileCount; $i++) {
        $fullPath = (
            $foldersByFile[$i] + "\" + $fileNames[$i]
        ).ToLowerInvariant()
        if ($fullPath -eq $expectedPath) {
            $found = $true
            break
        }
    }
}
finally {
    $reader.Dispose()
    $stream.Dispose()
}

if (-not $found) {
    throw "Missing vanilla North-coast shared-response FUZ: $expectedPath"
}
Write-Host "PASS voice asset $expectedPath"
Write-Host "PASS North-coast ferryman voice audit complete"
