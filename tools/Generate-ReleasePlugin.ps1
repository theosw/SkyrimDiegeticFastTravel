param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$XEdit = "build\xedit-patched\SSEEdit64.exe",
    [string]$Manifest = "config\carriage_provider.json"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$releaseRoot = Join-Path $buildRoot "release"
$generationRoot = Join-Path $buildRoot "release-generation"
$stagingData = Join-Path $generationRoot "data"
$pluginsList = Join-Path $generationRoot "plugins.txt"
$releasePlugin = Join-Path $releaseRoot "DiegeticTravel.esp"
$releaseSeq = Join-Path $releaseRoot "SEQ\DiegeticTravel.seq"
$releaseMode = Join-Path $buildRoot "consolidated-release.mode"
$generatorConfigPath = Join-Path $buildRoot "xedit_generator_config.json"
$coreSeqManifest = Join-Path $buildRoot "release-core-seq-formids.txt"
$finalSeqManifest = Join-Path $buildRoot "release-seq-formids.txt"
$manifestPath = if ([IO.Path]::IsPathRooted($Manifest)) {
    [IO.Path]::GetFullPath($Manifest)
} else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $Manifest))
}
$xeditPath = if ([IO.Path]::IsPathRooted($XEdit)) {
    [IO.Path]::GetFullPath($XEdit)
} else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $XEdit))
}
$wizardSeed = Join-Path $projectRoot `
    "modules\wizard-guides\mod\DiegeticTravelWizardGuides.esp"

$resolvedBuild = [IO.Path]::GetFullPath($buildRoot)
$resolvedRelease = [IO.Path]::GetFullPath($releaseRoot)
$resolvedGeneration = [IO.Path]::GetFullPath($generationRoot)
foreach ($ownedPath in @($resolvedRelease, $resolvedGeneration)) {
    if (-not $ownedPath.StartsWith(
        $resolvedBuild,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to clean release path outside build: $ownedPath"
    }
}

foreach ($required in @($xeditPath, $manifestPath, $wizardSeed)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required consolidated release input not found: $required"
    }
}

$stockData = Join-Path $LoreRimRoot "Stock Game\Data"
$cftoPlugin = Join-Path $LoreRimRoot `
    "mods\Carriage and Ferry Travel Overhaul - Fixes and Winterhold\CFTO.esp"
foreach ($required in @($stockData, $cftoPlugin)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required LoreRim release input not found: $required"
    }
}

function Invoke-XEditReleaseStep {
    param(
        [string]$Name,
        [string]$Script,
        [string]$Status,
        [string]$Error,
        [switch]$PseudoESL
    )

    foreach ($old in @($Status, $Error)) {
        if (Test-Path -LiteralPath $old -PathType Leaf) {
            Remove-Item -LiteralPath $old -Force
        }
    }

    $log = Join-Path $generationRoot "$Name.log"
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
        "-autoexit"
    )
    if ($PseudoESL) {
        $arguments += "-PseudoESL"
    }
    $arguments += "-script:$Script"

    Write-Host "[release] $Name"
    $process = Start-Process -FilePath $xeditPath `
        -ArgumentList $arguments -WindowStyle Hidden -PassThru
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
        $detail = if (Test-Path -LiteralPath $Error -PathType Leaf) {
            (Get-Content -LiteralPath $Error -Raw).Trim()
        } else {
            "xEdit did not report an error"
        }
        throw "$Name timed out: $detail"
    }
    if ($terminalStatus -ne "success") {
        $detail = if (Test-Path -LiteralPath $Error -PathType Leaf) {
            (Get-Content -LiteralPath $Error -Raw).Trim()
        } else {
            "status was '$terminalStatus'; see $log"
        }
        throw "$Name failed: $detail"
    }
    if ($process.ExitCode -ne 0) {
        throw "$Name exited with code $($process.ExitCode). See: $log"
    }
    $scriptFailure = Select-String -LiteralPath $log `
        -Pattern "Exception in unit|Aborted: Applying script|Error assigning to" `
        -Quiet
    if ($scriptFailure) {
        throw "$Name reported a script failure. See: $log"
    }
}

$configBackup = $null
$hadConfig = Test-Path -LiteralPath $generatorConfigPath -PathType Leaf
if ($hadConfig) {
    $configBackup = [IO.File]::ReadAllBytes($generatorConfigPath)
}

try {
    foreach ($owned in @($generationRoot, $releaseRoot)) {
        if (Test-Path -LiteralPath $owned) {
            Remove-Item -LiteralPath $owned -Recurse -Force
        }
    }
    New-Item -ItemType Directory -Force -Path $stagingData | Out-Null
    New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
    New-Item -ItemType Directory -Force `
        -Path (Split-Path -Parent $releaseSeq) | Out-Null

    foreach ($master in @(
        "Skyrim.esm",
        "Update.esm",
        "Dawnguard.esm",
        "HearthFires.esm",
        "Dragonborn.esm",
        "Skyrim - Interface.bsa"
    )) {
        $source = Join-Path $stockData $master
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Required stock-game input not found: $source"
        }
        Copy-Item -LiteralPath $source `
            -Destination (Join-Path $stagingData $master) -Force
    }
    Copy-Item -LiteralPath $cftoPlugin `
        -Destination (Join-Path $stagingData "CFTO.esp") -Force
    Copy-Item -LiteralPath $wizardSeed `
        -Destination (Join-Path $stagingData "DiegeticTravel.esp") -Force

    [IO.File]::WriteAllText(
        $pluginsList,
        "*CFTO.esp`r`n*DiegeticTravel.esp`r`n",
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $releaseMode,
        "consolidated-release`r`n",
        [Text.UTF8Encoding]::new($false)
    )
    $generatorConfig = @{
        manifest = $manifestPath
        plugin_output = $releasePlugin
        seq_formids = $coreSeqManifest
        append_existing = $true
    } | ConvertTo-Json
    [IO.File]::WriteAllText(
        $generatorConfigPath,
        $generatorConfig,
        [Text.UTF8Encoding]::new($false)
    )

    $steps = @(
        @{
            Name = "core"
            Script = Join-Path $PSScriptRoot "xedit\DNT_GeneratePlugin.pas"
            Status = Join-Path $buildRoot "xedit_generator.status"
            Error = Join-Path $buildRoot "xedit_generator.error"
        },
        @{
            Name = "wizard-parchment"
            Script = Join-Path $PSScriptRoot "xedit\DNT_GenerateWizardParchmentAdapter.pas"
            Status = Join-Path $buildRoot "wizard-parchment.status"
            Error = Join-Path $buildRoot "wizard-parchment.error"
        },
        @{
            Name = "carriage-parchment"
            Script = Join-Path $PSScriptRoot "xedit\DNT_GenerateCarriageParchment.pas"
            Status = Join-Path $buildRoot "carriage-parchment.status"
            Error = Join-Path $buildRoot "carriage-parchment.error"
        },
        @{
            Name = "boat-honrich"
            Script = Join-Path $PSScriptRoot "xedit\DNT_GenerateBoatHonrich.pas"
            Status = Join-Path $buildRoot "boat-honrich.status"
            Error = Join-Path $buildRoot "boat-honrich.error"
        },
        @{
            Name = "boat-ilinalta"
            Script = Join-Path $PSScriptRoot "xedit\DNT_GenerateBoatIlinalta.pas"
            Status = Join-Path $buildRoot "boat-ilinalta.status"
            Error = Join-Path $buildRoot "boat-ilinalta.error"
        },
        @{
            Name = "boat-north-coast"
            Script = Join-Path $PSScriptRoot "xedit\DNT_GenerateBoatNorthCoast.pas"
            Status = Join-Path $buildRoot "boat-north-coast.status"
            Error = Join-Path $buildRoot "boat-north-coast.error"
        },
        @{
            Name = "boat-solstheim"
            Script = Join-Path $PSScriptRoot "xedit\DNT_GenerateBoatSolstheim.pas"
            Status = Join-Path $buildRoot "boat-solstheim.status"
            Error = Join-Path $buildRoot "boat-solstheim.error"
        },
        @{
            Name = "legacy-dialogue-gate"
            Script = Join-Path $PSScriptRoot "xedit\DNT_GateLegacyDialogue.pas"
            Status = Join-Path $buildRoot "legacy-dialogue-gate.status"
            Error = Join-Path $buildRoot "legacy-dialogue-gate.error"
        }
    )

    foreach ($step in $steps) {
        Invoke-XEditReleaseStep @step
        if (-not (Test-Path -LiteralPath $releasePlugin -PathType Leaf)) {
            throw "$($step.Name) did not produce the consolidated plugin"
        }
        Copy-Item -LiteralPath $releasePlugin `
            -Destination (Join-Path $stagingData "DiegeticTravel.esp") -Force
    }

    Invoke-XEditReleaseStep `
        -Name "finalize-esl" `
        -Script (Join-Path $PSScriptRoot "xedit\DNT_FinalizeReleasePlugin.pas") `
        -Status (Join-Path $buildRoot "release-finalize.status") `
        -Error (Join-Path $buildRoot "release-finalize.error") `
        -PseudoESL

    $seqFormIds = @(
        Get-Content -LiteralPath $finalSeqManifest |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne "" }
    )
    if ($seqFormIds.Count -ne 17) {
        throw "Expected 17 combined SEQ FormIDs, found $($seqFormIds.Count)"
    }
    $seqBytes = [byte[]]::new($seqFormIds.Count * 4)
    for ($index = 0; $index -lt $seqFormIds.Count; $index++) {
        if ($seqFormIds[$index] -notmatch "^[0-9A-Fa-f]{8}$") {
            throw "Invalid combined SEQ FormID: $($seqFormIds[$index])"
        }
        $formId = [Convert]::ToUInt32($seqFormIds[$index], 16)
        $offset = $index * 4
        $seqBytes[$offset] = [byte]($formId -band 0xFF)
        $seqBytes[$offset + 1] = [byte](($formId -shr 8) -band 0xFF)
        $seqBytes[$offset + 2] = [byte](($formId -shr 16) -band 0xFF)
        $seqBytes[$offset + 3] = [byte](($formId -shr 24) -band 0xFF)
    }
    [IO.File]::WriteAllBytes($releaseSeq, $seqBytes)

    $header = [IO.File]::ReadAllBytes($releasePlugin)
    $flags = [BitConverter]::ToUInt32($header, 8)
    if (($flags -band 0x200) -eq 0) {
        throw "Consolidated release plugin was not ESL-flagged"
    }
    $hedr = [Text.Encoding]::ASCII.GetString($header).IndexOf("HEDR")
    if ($hedr -lt 0) {
        throw "Consolidated release plugin has no HEDR"
    }
    $nextObjectId = [BitConverter]::ToUInt32($header, $hedr + 14)
    if ($nextObjectId -gt 0x1000) {
        throw ("Consolidated release exceeded ESL range: 0x{0:X}" -f $nextObjectId)
    }

    Write-Host "Generated consolidated ESP-FE: $releasePlugin"
    Write-Host "Generated combined SEQ:       $releaseSeq (17 quests)"
    Write-Host ("Next local FormID:             0x{0:X}" -f $nextObjectId)
    Write-Host "ESP SHA-256: $((Get-FileHash $releasePlugin -Algorithm SHA256).Hash)"
} finally {
    if (Test-Path -LiteralPath $releaseMode -PathType Leaf) {
        Remove-Item -LiteralPath $releaseMode -Force
    }
    if ($hadConfig) {
        [IO.File]::WriteAllBytes($generatorConfigPath, $configBackup)
    } elseif (Test-Path -LiteralPath $generatorConfigPath -PathType Leaf) {
        Remove-Item -LiteralPath $generatorConfigPath -Force
    }
}
