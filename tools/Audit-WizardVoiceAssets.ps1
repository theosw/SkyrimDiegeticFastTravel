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

$expected = [System.Collections.Generic.List[object]]::new()
$expected.Add(
    [pscustomobject]@{
        Label = "Farengar: Yes."
        Path = (
            "sound\voice\skyrim.esm\maleeventonedaccented\" +
            "wisharedin_wisharedinfosto_000730fa_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Wylandriah: Of course."
        Path = (
            "sound\voice\skyrim.esm\femaleeventoned\" +
            "dialoguege_dialoguegeneric_000dba22_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Sybille Stentor: Of course."
        Path = (
            "sound\voice\skyrim.esm\femalesultry\" +
            "dialoguege_dialoguegeneric_000dba22_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Wuunferth the Unliving: Of course."
        Path = (
            "sound\voice\skyrim.esm\maleoldgrumpy\" +
            "dialoguege_dialoguegeneric_000dba22_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Calcelmo: Of course."
        Path = (
            "sound\voice\skyrim.esm\maleoldkindly\" +
            "dialoguege_dialoguegeneric_000dba22_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Madena: Of course."
        Path = (
            "sound\voice\skyrim.esm\femalecondescending\" +
            "dialoguege_dialoguegeneric_000dba22_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Falion: Of course."
        Path = (
            "sound\voice\skyrim.esm\maleslycynical\" +
            "dialoguege_dialoguegeneric_000dba22_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Falion: insufficient funds"
        Path = (
            "sound\voice\skyrim.esm\maleslycynical\" +
            "dialoguege_dialoguegeneric_000dba24_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Farengar: insufficient funds"
        Path = (
            "sound\voice\skyrim.esm\maleeventonedaccented\" +
            "housepurch_housepurchasesh_000c6e2d_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Wylandriah: insufficient funds"
        Path = (
            "sound\voice\skyrim.esm\femaleeventoned\" +
            "housepurch_housepurchasesh_000c6e2d_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Sybille Stentor: insufficient funds"
        Path = (
            "sound\voice\hearthfires.esm\femalesultry\" +
            "byohhousebuilding__0000b0b2_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Calcelmo: insufficient funds"
        Path = (
            "sound\voice\skyrim.esm\maleoldkindly\" +
            "housepurch_housepurchasesh_000c6e2d_1.fuz"
        )
    }
)
$expected.Add(
    [pscustomobject]@{
        Label = "Madena: insufficient funds"
        Path = (
            "sound\voice\skyrim.esm\femalecondescending\" +
            "housepurch_housepurchasesh_000c6e2d_1.fuz"
        )
    }
)

$facultyVoiceTypes = [ordered]@{
    "Sergius Turrianus" = "MaleOldGrumpy"
    "Phinis Gestor / Savos Aren" = "MaleCondescending"
    "Tolfdir" = "MaleOldKindly"
    "Arniel Gane" = "MaleCoward"
    "Enthir" = "MaleSlyCynical"
    "Nirya" = "FemaleElfHaughty"
    "Colette Marence" = "FemaleShrill"
    "Drevis Neloren" = "MaleEvenToned"
    "Faralda" = "FemaleSultry"
    "Urag gro-Shub" = "MaleOrc"
}
foreach ($facultyEntry in $facultyVoiceTypes.GetEnumerator()) {
    $expected.Add(
        [pscustomobject]@{
            Label = "$($facultyEntry.Key): Of course."
            Path = (
                "sound\voice\skyrim.esm\" +
                $facultyEntry.Value.ToLowerInvariant() + "\" +
                "dialoguege_dialoguegeneric_000dba22_1.fuz"
            )
        }
    )
}
$wantedPaths = @{}
foreach ($entry in $expected) {
    $wantedPaths[$entry.Path.ToLowerInvariant()] = $false
}

$stream = [System.IO.File]::OpenRead($voiceArchive)
$reader = [System.IO.BinaryReader]::new(
    $stream,
    [System.Text.Encoding]::ASCII
)
try {
    $magic = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
    $version = $reader.ReadUInt32()
    $null = $reader.ReadUInt32() # Folder-record offset
    $null = $reader.ReadUInt32() # Archive flags
    $folderCount = $reader.ReadUInt32()
    $fileCount = $reader.ReadUInt32()
    $null = $reader.ReadUInt32() # Total folder-name bytes
    $fileNameBytes = $reader.ReadUInt32()
    $null = $reader.ReadUInt32() # File flags

    if ($magic -ne "BSA`0" -or $version -ne 105) {
        throw (
            "Unexpected voice archive header: magic='$magic', " +
            "version=$version"
        )
    }

    $folderFileCounts = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $folderCount; $i++) {
        $null = $reader.ReadUInt64() # Folder hash
        $count = $reader.ReadUInt32()
        $null = $reader.ReadUInt32() # SSE padding
        $null = $reader.ReadUInt64() # Folder offset
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
        $stream.Position += 16L * $count # BSA file records
    }

    $fileNameBlob = [System.Text.Encoding]::ASCII.GetString(
        $reader.ReadBytes($fileNameBytes)
    )
    $fileNames = $fileNameBlob.Split(
        [char[]]@([char]0),
        [System.StringSplitOptions]::RemoveEmptyEntries
    )
    if ($fileNames.Count -ne $fileCount) {
        throw (
            "Voice archive filename count mismatch: " +
            "$($fileNames.Count) != $fileCount"
        )
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

foreach ($entry in $expected) {
    $key = $entry.Path.ToLowerInvariant()
    if (-not $wantedPaths[$key]) {
        throw "Missing vanilla voice asset for $($entry.Label): $($entry.Path)"
    }
    Write-Host "PASS voice asset $($entry.Label)"
}
Write-Host "PASS wizard voice asset audit complete"
