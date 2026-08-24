param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [string]$ReleaseIdentityPath = "build\release-identity.json"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "ReleaseIdentity.ps1")
$releaseIdentity = Read-DntReleaseIdentity `
    -ProjectRoot $projectRoot `
    -Path $ReleaseIdentityPath
$buildRoot = Join-Path $projectRoot "build"
$workRoot = Join-Path $buildRoot "bcd-lorerim-compat"
$stagingData = Join-Path $workRoot "data"
$pluginsList = Join-Path $workRoot "plugins.txt"
$pluginName = "DiegeticTravelLoreRimBcdCompat.esp"
$pluginPath = Join-Path $workRoot $pluginName
$packageRoot = Join-Path $buildRoot "bcd-lorerim-compat-package"
$archiveBaseName = "DiegeticTravel-LoreRim-BCD-Compat-$($releaseIdentity.buildId)"
$archive = Join-Path $projectRoot "dist\$archiveBaseName.zip"
$mo2DisplayName = "DiegeticTravel LoreRim BCD Compat $($releaseIdentity.buildId)"
$releasePlugin = Join-Path $buildRoot "release\DiegeticTravel.esp"
$generateScript = Join-Path $PSScriptRoot "xedit\DNT_GenerateBcdLoreRimCompat.pas"
$auditScript = Join-Path $PSScriptRoot "xedit\DNT_AuditBcdLoreRimCompat.pas"
$generateStatus = Join-Path $buildRoot "bcd-lorerim-compat.status"
$generateError = Join-Path $buildRoot "bcd-lorerim-compat.error"
$auditStatus = Join-Path $buildRoot "bcd-lorerim-compat-audit.status"
$auditError = Join-Path $buildRoot "bcd-lorerim-compat-audit.error"
$auditReport = Join-Path $buildRoot "bcd-lorerim-compat-audit.report.txt"
$readmeSource = Join-Path $projectRoot "modules\bcd-lorerim-compat\mod\README.txt"

function Resolve-ProjectPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Invoke-XEditStep {
    param(
        [string]$Name,
        [string]$Script,
        [string]$Status,
        [string]$ErrorFile
    )

    foreach ($old in @($Status, $ErrorFile)) {
        if (Test-Path -LiteralPath $old -PathType Leaf) {
            Remove-Item -LiteralPath $old -Force
        }
    }
    $log = Join-Path $workRoot "$Name.log"
    if (Test-Path -LiteralPath $log -PathType Leaf) {
        Remove-Item -LiteralPath $log -Force
    }
    $arguments = @(
        "-sse",
        "-D:$stagingData",
        "-P:$pluginsList",
        "-R:$log",
        "-IKnowWhatImDoing",
        "-nobuildrefs",
        "-autoload",
        "-autoexit",
        "-script:$Script"
    )
    Write-Host "[bcd-compat] $Name"
    $process = Start-Process -FilePath $xeditPath -ArgumentList $arguments `
        -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddMinutes(5)
    $terminalStatus = $null
    while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $Status -PathType Leaf) {
            $terminalStatus = (Get-Content -LiteralPath $Status -Raw).Trim()
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
        $null = $process.WaitForExit(5000)
        if ($terminalStatus -notin @("success", "failed")) {
            throw "$Name timed out. See: $log"
        }
    }
    if ($terminalStatus -ne "success" -or $process.ExitCode -ne 0) {
        $detail = if (Test-Path -LiteralPath $ErrorFile -PathType Leaf) {
            (Get-Content -LiteralPath $ErrorFile -Raw).Trim()
        } else {
            "status=$terminalStatus exit=$($process.ExitCode); see $log"
        }
        throw "$Name failed: $detail"
    }
}

$xeditPath = Resolve-ProjectPath $XEdit
$resolvedBuild = [IO.Path]::GetFullPath($buildRoot)
foreach ($ownedPath in @($workRoot, $packageRoot)) {
    $resolvedOwned = [IO.Path]::GetFullPath($ownedPath)
    if (-not $resolvedOwned.StartsWith(
        $resolvedBuild,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to clean BCD compatibility path outside build: $resolvedOwned"
    }
}
foreach ($required in @(
    $xeditPath,
    $generateScript,
    $auditScript,
    $releasePlugin,
    $readmeSource
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required BCD compatibility input not found: $required"
    }
}

foreach ($owned in @($workRoot, $packageRoot)) {
    if (Test-Path -LiteralPath $owned) {
        Remove-Item -LiteralPath $owned -Recurse -Force
    }
}
foreach ($result in @($generateStatus, $generateError, $auditStatus, $auditError, $auditReport)) {
    if (Test-Path -LiteralPath $result -PathType Leaf) {
        Remove-Item -LiteralPath $result -Force
    }
}
New-Item -ItemType Directory -Force -Path $stagingData | Out-Null
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null

$stockData = Join-Path $LoreRimRoot "Stock Game\Data"
$inputs = [ordered]@{
    "Skyrim.esm" = Join-Path $stockData "Skyrim.esm"
    "Update.esm" = Join-Path $stockData "Update.esm"
    "Dawnguard.esm" = Join-Path $stockData "Dawnguard.esm"
    "HearthFires.esm" = Join-Path $stockData "HearthFires.esm"
    "Dragonborn.esm" = Join-Path $stockData "Dragonborn.esm"
    "Skyrim - Interface.bsa" = Join-Path $stockData "Skyrim - Interface.bsa"
    "SkyUI_SE.esp" = Join-Path $LoreRimRoot "mods\SkyUI\SkyUI_SE.esp"
    "WaitCarriageInns.esp" = Join-Path $LoreRimRoot "mods\Wait Carriage in Inns - Fast Travel Improvement\WaitCarriageInns.esp"
    "Better Carriage Destinations.esp" = Join-Path $LoreRimRoot "mods\Better Carriage Destinations\Better Carriage Destinations.esp"
    "Better Carriage Destinations - Wait Carriage in Inns Patch.esp" = Join-Path $LoreRimRoot "mods\Better Carriage Destinations WCII\Better Carriage Destinations - Wait Carriage in Inns Patch.esp"
    "CFTO.esp" = Join-Path $LoreRimRoot "mods\Carriage and Ferry Travel Overhaul - Fixes and Winterhold\CFTO.esp"
    "Better Carriage Destinations - CFTO.esp" = Join-Path $LoreRimRoot "mods\Better Carriage Destinations CFTO\Better Carriage Destinations - CFTO.esp"
    "DiegeticTravel.esp" = $releasePlugin
}
foreach ($entry in $inputs.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) {
        throw "Required BCD compatibility input not found: $($entry.Value)"
    }
    Copy-Item -LiteralPath $entry.Value -Destination (Join-Path $stagingData $entry.Key) -Force
}

$basePluginList = @(
    "*SkyUI_SE.esp",
    "*WaitCarriageInns.esp",
    "*Better Carriage Destinations.esp",
    "*Better Carriage Destinations - Wait Carriage in Inns Patch.esp",
    "*CFTO.esp",
    "*Better Carriage Destinations - CFTO.esp",
    "*DiegeticTravel.esp"
)
[IO.File]::WriteAllText(
    $pluginsList,
    (($basePluginList -join "`r`n") + "`r`n"),
    [Text.UTF8Encoding]::new($false)
)
Invoke-XEditStep -Name "generate" -Script $generateScript `
    -Status $generateStatus -ErrorFile $generateError
if (-not (Test-Path -LiteralPath $pluginPath -PathType Leaf)) {
    throw "BCD compatibility generator did not create $pluginPath"
}
Copy-Item -LiteralPath $pluginPath -Destination (Join-Path $stagingData $pluginName) -Force
[IO.File]::WriteAllText(
    $pluginsList,
    ((@($basePluginList + "*$pluginName") -join "`r`n") + "`r`n"),
    [Text.UTF8Encoding]::new($false)
)
Invoke-XEditStep -Name "audit" -Script $auditScript `
    -Status $auditStatus -ErrorFile $auditError

Copy-Item -LiteralPath $pluginPath -Destination (Join-Path $packageRoot $pluginName) -Force
Copy-Item -LiteralPath $readmeSource -Destination (Join-Path $packageRoot "README.txt") -Force
$packageFiles = @(Get-ChildItem -LiteralPath $packageRoot -File)
if ($packageFiles.Count -ne 2 -or
    -not (Test-Path -LiteralPath (Join-Path $packageRoot $pluginName)) -or
    -not (Test-Path -LiteralPath (Join-Path $packageRoot "README.txt"))) {
    throw "BCD compatibility package must contain exactly its ESL and README."
}
if (Test-Path -LiteralPath $archive -PathType Leaf) {
    Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") `
    -DestinationPath $archive -CompressionLevel Optimal
$metaPath = Write-DntMo2ArchiveMeta `
    -ArchivePath $archive `
    -DisplayName $mo2DisplayName `
    -Identity $releaseIdentity
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
$checksumPath = Write-DntReleaseChecksums `
    -ProjectRoot $projectRoot `
    -Identity $releaseIdentity

Get-Content -LiteralPath $auditReport
Write-Host "LoreRim BCD compatibility package: $archive"
Write-Host "MO2 sidecar metadata: $metaPath"
Write-Host "MO2 suggested name: $mo2DisplayName"
Write-Host "Release checksums: $checksumPath"
Write-Host "SHA-256: $archiveHash"
