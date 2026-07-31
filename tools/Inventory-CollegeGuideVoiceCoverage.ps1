param(
    [string]$LoreRimRoot = "D:\Lorerim"
)

$ErrorActionPreference = "Stop"

$voiceArchive = Join-Path (
    Join-Path $LoreRimRoot "Stock Game\Data"
) "Skyrim - Voices_en0.bsa"
if (-not (Test-Path -LiteralPath $voiceArchive -PathType Leaf)) {
    throw "Required vanilla voice archive not found: $voiceArchive"
}

$voiceTypes = @(
    "MaleOldGrumpy",
    "FemaleUniqueMirabelleErvine",
    "MaleCondescending",
    "MaleOldKindly",
    "MaleCoward",
    "MaleSlyCynical",
    "FemaleElfHaughty",
    "FemaleShrill",
    "MaleEvenToned",
    "FemaleSultry",
    "MaleOrc"
)
$targetFile = "dialoguege_dialoguegeneric_000dba22_1.fuz"
$wantedPaths = @{}
foreach ($voiceType in $voiceTypes) {
    $path = (
        "sound\voice\skyrim.esm\" + $voiceType.ToLowerInvariant() +
        "\" + $targetFile
    )
    $wantedPaths[$path] = $false
}

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
        throw "Unexpected voice archive header."
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
        [char]0,
        [System.StringSplitOptions]::RemoveEmptyEntries
    )
    if ($fileNames.Count -ne $fileCount) {
        throw "Voice archive filename count mismatch."
    }

    for ($i = 0; $i -lt $fileCount; $i++) {
        $fullPath = (
            $foldersByFile[$i] + "\" + $fileNames[$i]
        ).ToLowerInvariant()
        if ($wantedPaths.ContainsKey($fullPath)) {
            $wantedPaths[$fullPath] = $true
        }
    }
}
finally {
    $reader.Dispose()
    $stream.Dispose()
}

$missing = 0
foreach ($voiceType in $voiceTypes) {
    $path = (
        "sound\voice\skyrim.esm\" + $voiceType.ToLowerInvariant() +
        "\" + $targetFile
    )
    if ($wantedPaths[$path]) {
        Write-Host "AVAILABLE $voiceType | Of course. | $path"
    } else {
        Write-Host "MISSING $voiceType | Of course. | $path"
        $missing++
    }
}
Write-Host "VOICE_COVERAGE=$($voiceTypes.Count - $missing)/$($voiceTypes.Count)"
