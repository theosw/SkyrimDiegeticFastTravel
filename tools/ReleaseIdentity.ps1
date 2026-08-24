function Get-DntConfiguredReleaseVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $configPath = Join-Path $ProjectRoot "config\release.json"
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw "Release configuration not found: $configPath"
    }
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $version = [string]$config.version
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "Release configuration has no version: $configPath"
    }
    if ($version -notmatch '^[0-9A-Za-z][0-9A-Za-z.-]*$') {
        throw "Release version is not filename-safe: $version"
    }
    return $version
}

function New-DntReleaseIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [string]$Version = "",
        [string]$BuildTimestampUtc = ""
    )

    if ([string]::IsNullOrWhiteSpace($Version)) {
        $Version = Get-DntConfiguredReleaseVersion -ProjectRoot $ProjectRoot
    }
    if ($Version -notmatch '^[0-9A-Za-z][0-9A-Za-z.-]*$') {
        throw "Release version is not filename-safe: $Version"
    }
    if ([string]::IsNullOrWhiteSpace($BuildTimestampUtc)) {
        $BuildTimestampUtc = [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'")
    }
    if ($BuildTimestampUtc -notmatch '^\d{8}T\d{6}Z$') {
        throw "Build timestamp must use compact UTC form yyyyMMddTHHmmssZ: $BuildTimestampUtc"
    }

    return [pscustomobject][ordered]@{
        schemaVersion = 1
        version = $Version
        timestampUtc = $BuildTimestampUtc
        buildId = "$Version-$BuildTimestampUtc"
    }
}

function Write-DntReleaseIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Identity,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $json = $Identity | ConvertTo-Json
    [IO.File]::WriteAllText(
        $Path,
        ($json + "`r`n"),
        [Text.UTF8Encoding]::new($false)
    )
}

function Read-DntReleaseIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [string]$Path = "build\release-identity.json"
    )

    $resolved = if ([IO.Path]::IsPathRooted($Path)) {
        [IO.Path]::GetFullPath($Path)
    } else {
        [IO.Path]::GetFullPath((Join-Path $ProjectRoot $Path))
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Release identity not found: $resolved. Build the main release first."
    }
    $stored = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
    $identity = New-DntReleaseIdentity `
        -ProjectRoot $ProjectRoot `
        -Version ([string]$stored.version) `
        -BuildTimestampUtc ([string]$stored.timestampUtc)
    if ([string]$stored.buildId -ne $identity.buildId) {
        throw "Release identity buildId does not match its version and timestamp: $resolved"
    }
    return $identity
}

function Write-DntMo2ArchiveMeta {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [psobject]$Identity
    )

    if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
        throw "Cannot write MO2 metadata for a missing archive: $ArchivePath"
    }
    if ([string]::IsNullOrWhiteSpace($DisplayName) -or $DisplayName -match '[\r\n=]') {
        throw "MO2 display name is empty or not INI-safe: $DisplayName"
    }

    $metaPath = "$ArchivePath.meta"
    $lines = @(
        "[General]",
        "installed=false",
        "gameName=skyrimse",
        "modID=0",
        "name=$DisplayName",
        "modName=$DisplayName",
        "version=$($Identity.buildId)",
        "newestVersion=$($Identity.buildId)"
    )
    [IO.File]::WriteAllLines(
        $metaPath,
        $lines,
        [Text.UTF8Encoding]::new($false)
    )
    return $metaPath
}

function Write-DntReleaseChecksums {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [psobject]$Identity
    )

    $distRoot = Join-Path $ProjectRoot "dist"
    if (-not (Test-Path -LiteralPath $distRoot -PathType Container)) {
        throw "Release distribution directory was not found: $distRoot"
    }

    $archiveSuffix = "-$($Identity.buildId).zip"
    $archives = @(Get-ChildItem -LiteralPath $distRoot -File -Filter "*.zip" |
        Where-Object {
            $_.Name.EndsWith(
                $archiveSuffix,
                [StringComparison]::OrdinalIgnoreCase
            )
        } |
        Sort-Object Name)
    if ($archives.Count -eq 0) {
        throw "No release archives match identity $($Identity.buildId) in $distRoot"
    }

    $checksumPath = Join-Path $distRoot `
        "DiegeticTravel-$($Identity.buildId)-SHA256SUMS.txt"
    $lines = @($archives | ForEach-Object {
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        "$hash  $($_.Name)"
    })
    [IO.File]::WriteAllLines(
        $checksumPath,
        $lines,
        [Text.UTF8Encoding]::new($false)
    )
    return $checksumPath
}
