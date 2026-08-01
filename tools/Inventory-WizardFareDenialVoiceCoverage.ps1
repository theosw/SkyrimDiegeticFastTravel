param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$FormID = "000C6E2D",
    [string]$PluginName = "Skyrim.esm",
    [switch]$ShowAnyObjectIDMatch,
    [string]$NameContains = ""
)

$ErrorActionPreference = "Stop"

if ($FormID -notmatch '^[0-9A-Fa-f]{8}$') {
    throw "FormID must be exactly eight hexadecimal digits."
}
$normalizedFormID = $FormID.ToLowerInvariant()
$voiceArchive = Join-Path (
    Join-Path $LoreRimRoot "Stock Game\Data"
) "Skyrim - Voices_en0.bsa"
if (-not (Test-Path -LiteralPath $voiceArchive -PathType Leaf)) {
    throw "Required vanilla voice archive not found: $voiceArchive"
}

$voiceTypes = @(
    "MaleEvenTonedAccented",
    "FemaleEvenToned",
    "FemaleSultry",
    "MaleOldGrumpy",
    "MaleCondescending",
    "MaleOldKindly",
    "MaleCoward",
    "MaleSlyCynical",
    "FemaleElfHaughty",
    "FemaleShrill",
    "MaleEvenToned",
    "MaleOrc",
    "FemaleUniqueMirabelleErvine"
)
$wantedFolders = @{}
$matches = @{}
foreach ($voiceType in $voiceTypes) {
    $folder = (
        "sound\voice\" + $PluginName.ToLowerInvariant() + "\" +
        $voiceType.ToLowerInvariant()
    )
    $wantedFolders[$folder] = $voiceType
    $matches[$voiceType] = $null
}
$audioFormID = $normalizedFormID.Substring(2).PadLeft(8, '0')
$suffix = "_$($audioFormID)_1.fuz"
$anyObjectIDMatches = [System.Collections.Generic.List[string]]::new()
$nameMatches = [System.Collections.Generic.List[string]]::new()

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
        $folder = $foldersByFile[$i]
        $fileName = $fileNames[$i].ToLowerInvariant()
        if (
            $NameContains -and
            $fileName.Contains($NameContains.ToLowerInvariant())
        ) {
            $nameMatches.Add("$folder\$fileName")
        }
        if (
            $ShowAnyObjectIDMatch -and
            $fileName.EndsWith($suffix)
        ) {
            $anyObjectIDMatches.Add("$folder\$fileName")
        }
        if (-not $wantedFolders.ContainsKey($folder)) {
            continue
        }
        if (-not $fileName.EndsWith($suffix)) {
            continue
        }
        $voiceType = $wantedFolders[$folder]
        $matches[$voiceType] = "$folder\$fileName"
    }
}
finally {
    $reader.Dispose()
    $stream.Dispose()
}

$available = 0
foreach ($voiceType in $voiceTypes) {
    if ($matches[$voiceType]) {
        Write-Host "AVAILABLE $voiceType | $($matches[$voiceType])"
        $available++
    } else {
        Write-Host "MISSING $voiceType"
    }
}
Write-Host "VOICE_COVERAGE=$available/$($voiceTypes.Count)"
if ($ShowAnyObjectIDMatch) {
    Write-Host "ANY_OBJECT_ID_MATCHES=$($anyObjectIDMatches.Count)"
    foreach ($path in $anyObjectIDMatches) {
        Write-Host "ANY $path"
    }
}
if ($NameContains) {
    Write-Host "NAME_MATCHES=$($nameMatches.Count)"
    foreach ($path in $nameMatches) {
        Write-Host "NAME $path"
    }
}
