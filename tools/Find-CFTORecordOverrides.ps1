param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$ProfileName = "UltraDiegeticTravel",
    [uint32[]]$ObjectIds = @(
        0x001C355D, # Winterhold driver
        0x001AA04B, # Winterhold carriage seat
        0x0006AE94  # CFTO carriage-driver base template
    )
)

$ErrorActionPreference = "Stop"

function Read-UInt16LE([byte[]]$Bytes, [int]$Offset) {
    return [BitConverter]::ToUInt16($Bytes, $Offset)
}

function Read-UInt32LE([byte[]]$Bytes, [int]$Offset) {
    return [BitConverter]::ToUInt32($Bytes, $Offset)
}

function Read-Signature([byte[]]$Bytes, [int]$Offset) {
    return [Text.Encoding]::ASCII.GetString($Bytes, $Offset, 4)
}

function Get-Tes4Masters([byte[]]$Bytes) {
    if ($Bytes.Length -lt 24 -or (Read-Signature $Bytes 0) -ne "TES4") {
        return @()
    }
    $recordEnd = 24 + [int](Read-UInt32LE $Bytes 4)
    if ($recordEnd -gt $Bytes.Length) {
        throw "TES4 header extends beyond the file."
    }
    $masters = [Collections.Generic.List[string]]::new()
    $offset = 24
    $extendedSize = 0
    while ($offset + 6 -le $recordEnd) {
        $signature = Read-Signature $Bytes $offset
        $size = [int](Read-UInt16LE $Bytes ($offset + 4))
        $offset += 6
        if ($signature -eq "XXXX") {
            if ($size -ne 4 -or $offset + 4 -gt $recordEnd) {
                throw "Malformed XXXX subrecord in TES4 header."
            }
            $extendedSize = [int](Read-UInt32LE $Bytes $offset)
            $offset += 4
            continue
        }
        if ($extendedSize -gt 0) {
            $size = $extendedSize
            $extendedSize = 0
        }
        if ($offset + $size -gt $recordEnd) {
            throw "TES4 subrecord extends beyond the header."
        }
        if ($signature -eq "MAST") {
            $master = [Text.Encoding]::ASCII.GetString($Bytes, $offset, $size)
            $masters.Add($master.TrimEnd([char]0))
        }
        $offset += $size
    }
    return $masters.ToArray()
}

function Get-SubrecordSummary([byte[]]$Bytes, [int]$Offset, [int]$DataSize, [uint32]$Flags) {
    if (($Flags -band 0x00040000) -ne 0) {
        return [pscustomobject]@{
            Names = "<compressed>"
            LinkedRefCount = -1
            LinkedRefData = "<compressed>"
        }
    }
    $names = [Collections.Generic.List[string]]::new()
    $linkedRefCount = 0
    $linkedRefData = [Collections.Generic.List[string]]::new()
    $cursor = $Offset + 24
    $end = $cursor + $DataSize
    $extendedSize = 0
    while ($cursor + 6 -le $end) {
        $signature = Read-Signature $Bytes $cursor
        $size = [int](Read-UInt16LE $Bytes ($cursor + 4))
        $cursor += 6
        if ($signature -eq "XXXX") {
            if ($size -ne 4 -or $cursor + 4 -gt $end) { break }
            $extendedSize = [int](Read-UInt32LE $Bytes $cursor)
            $cursor += 4
            continue
        }
        if ($extendedSize -gt 0) {
            $size = $extendedSize
            $extendedSize = 0
        }
        if ($cursor + $size -gt $end) { break }
        $names.Add($signature)
        if ($signature -eq "XLKR") {
            $linkedRefCount++
            $linkedRefData.Add(
                [BitConverter]::ToString($Bytes, $cursor, $size).Replace("-", "")
            )
        }
        $cursor += $size
    }
    return [pscustomobject]@{
        Names = ($names -join ",")
        LinkedRefCount = $linkedRefCount
        LinkedRefData = ($linkedRefData -join ";")
    }
}

function Find-TargetRecords(
    [byte[]]$Bytes,
    [byte]$FileIndex,
    [Collections.Generic.HashSet[uint32]]$TargetIds
) {
    $matches = [Collections.Generic.List[object]]::new()
    $offset = 0
    while ($offset + 24 -le $Bytes.Length) {
        $signature = Read-Signature $Bytes $offset
        if ($signature -eq "GRUP") {
            $groupSize = [int](Read-UInt32LE $Bytes ($offset + 4))
            if ($groupSize -lt 24 -or $offset + $groupSize -gt $Bytes.Length) {
                break
            }
            $offset += 24
            continue
        }
        $dataSize = [int](Read-UInt32LE $Bytes ($offset + 4))
        $nextOffset = $offset + 24 + $dataSize
        if ($dataSize -lt 0 -or $nextOffset -gt $Bytes.Length) {
            break
        }
        $formId = Read-UInt32LE $Bytes ($offset + 12)
        $flags = Read-UInt32LE $Bytes ($offset + 8)
        if ([byte]($formId -shr 24) -eq $FileIndex) {
            $objectId = $formId -band 0x00FFFFFF
            if ($TargetIds.Contains([uint32]$objectId)) {
                $subrecords = Get-SubrecordSummary $Bytes $offset $dataSize $flags
                $matches.Add([pscustomobject]@{
                    Signature = $signature
                    ObjectId = ('{0:X6}' -f $objectId)
                    RawFormId = ('{0:X8}' -f $formId)
                    Flags = ('{0:X8}' -f $flags)
                    LinkedRefCount = $subrecords.LinkedRefCount
                    LinkedRefData = $subrecords.LinkedRefData
                    Subrecords = $subrecords.Names
                    Offset = $offset
                })
            }
        }
        $offset = $nextOffset
    }
    return $matches.ToArray()
}

$profileRoot = Join-Path $LoreRimRoot ("profiles\" + $ProfileName)
$pluginsPath = Join-Path $profileRoot "plugins.txt"
$modsRoot = Join-Path $LoreRimRoot "mods"
if (-not (Test-Path -LiteralPath $pluginsPath -PathType Leaf)) {
    throw "Profile plugin list not found: $pluginsPath"
}

$activeOrder = [Collections.Generic.Dictionary[string,int]]::new(
    [StringComparer]::OrdinalIgnoreCase
)
$loadOrder = 0
foreach ($line in Get-Content -LiteralPath $pluginsPath) {
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith("*") -and $trimmed.Length -gt 1) {
        $pluginName = $trimmed.Substring(1)
        $activeOrder[$pluginName] = $loadOrder
        $loadOrder++
    }
}

$targets = [Collections.Generic.HashSet[uint32]]::new()
foreach ($objectId in $ObjectIds) {
    $null = $targets.Add($objectId -band 0x00FFFFFF)
}

$pluginPaths = & rg --files $modsRoot -g "*.esp" -g "*.esm" -g "*.esl"
$results = [Collections.Generic.List[object]]::new()
foreach ($pluginPath in $pluginPaths) {
    $pluginName = Split-Path -Leaf $pluginPath
    if (-not $activeOrder.ContainsKey($pluginName)) {
        continue
    }
    $bytes = [IO.File]::ReadAllBytes($pluginPath)
    $masters = @(Get-Tes4Masters $bytes)
    $cftoIndex = -1
    for ($i = 0; $i -lt $masters.Count; $i++) {
        if ($masters[$i] -ieq "CFTO.esp") {
            $cftoIndex = $i
            break
        }
    }
    if ($pluginName -ieq "CFTO.esp") {
        $cftoIndex = $masters.Count
    }
    if ($cftoIndex -lt 0 -or $cftoIndex -gt 255) {
        continue
    }
    foreach ($match in Find-TargetRecords $bytes ([byte]$cftoIndex) $targets) {
        $results.Add([pscustomobject]@{
            LoadOrder = $activeOrder[$pluginName]
            Plugin = $pluginName
            Signature = $match.Signature
            ObjectId = $match.ObjectId
            RawFormId = $match.RawFormId
            Flags = $match.Flags
            LinkedRefCount = $match.LinkedRefCount
            LinkedRefData = $match.LinkedRefData
            Subrecords = $match.Subrecords
            Path = $pluginPath
        })
    }
}

$results |
    Sort-Object LoadOrder,ObjectId,Path |
    Format-Table -AutoSize
