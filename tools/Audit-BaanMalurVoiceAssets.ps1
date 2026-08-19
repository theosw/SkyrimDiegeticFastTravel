param(
    [string]$LoreRimRoot = "D:\Lorerim"
)

$ErrorActionPreference = "Stop"

$voiceArchive = Join-Path $LoreRimRoot `
    "mods\Journey to Baan Malur and Morrowind\Journey to Baan Malur0.bsa"
if (-not (Test-Path -LiteralPath $voiceArchive -PathType Leaf)) {
    throw "Required Journey voice archive not found: $voiceArchive"
}

$expectedPath = (
    "sound\voice\journey to baan malur.esp\maleeventoned\" +
    "somrferrys_somrferrysystem_00337093_1.fuz"
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
    $null = $reader.ReadUInt32() # Folder-record offset
    $null = $reader.ReadUInt32() # Archive flags
    $folderCount = $reader.ReadUInt32()
    $fileCount = $reader.ReadUInt32()
    $null = $reader.ReadUInt32() # Total folder-name bytes
    $fileNameBytes = $reader.ReadUInt32()
    $null = $reader.ReadUInt32() # File flags
    if ($magic -ne "BSA`0" -or $version -ne 105) {
        throw "Unexpected Journey voice archive header."
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
        throw "Journey voice archive filename count mismatch."
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
    throw "Missing Journey shared ferry response FUZ: $expectedPath"
}

Write-Host "PASS voice asset Captain Remyris/public captains: Where are you headed?"
Write-Host "PASS Baan Malur voice asset audit complete"
