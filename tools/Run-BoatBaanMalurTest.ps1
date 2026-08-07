param(
    [int]$TimeoutSeconds = 1800,
    [switch]$NoLaunch,
    [switch]$ValidateOnly,
    [string]$ModOrganizerPath = "D:\Lorerim\ModOrganizer.exe",
    [string]$ProfileName = "UltraDiegeticTravel",
    [string]$Shortcut = "moshortcut://:LoreRim",
    [string]$BoatModName = "DiegeticTravel - Baan Malur Boat Test",
    [string]$BoatPluginName = "DiegeticTravelBoatBaanMalur.esp",
    [string]$ParchmentModName = "DiegeticTravel - Parchment Picker Test",
    [string]$SourceModName = "Journey to Baan Malur and Morrowind",
    [string]$MapModName = "Solstheim and Baan Malur Paper Map for FWMF",
    [string]$LogPath = (
        Join-Path $env:USERPROFILE `
            "Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log"
    ),
    [string]$ParchmentLogPath = (
        Join-Path $env:USERPROFILE `
            "Documents\My Games\Skyrim Special Edition\SKSE\DNTParchmentPicker.log"
    )
)

$ErrorActionPreference = "Stop"

function Assert-TestReady {
    if (-not (Test-Path -LiteralPath $ModOrganizerPath -PathType Leaf)) {
        throw "Mod Organizer was not found: $ModOrganizerPath"
    }

    $instanceRoot = Split-Path -Parent $ModOrganizerPath
    $modOrganizerIni = Join-Path $instanceRoot "ModOrganizer.ini"
    $profileRoot = Join-Path (Join-Path $instanceRoot "profiles") $ProfileName
    $modlistPath = Join-Path $profileRoot "modlist.txt"
    $pluginsPath = Join-Path $profileRoot "plugins.txt"
    foreach ($required in @($modOrganizerIni, $modlistPath, $pluginsPath)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Required MO2 file was not found: $required"
        }
    }

    $selectedProfile = Select-String -LiteralPath $modOrganizerIni `
        -Pattern "^selected_profile=" |
        Select-Object -First 1 -ExpandProperty Line
    $expectedProfile = "selected_profile=@ByteArray($ProfileName)"
    if ($selectedProfile -ne $expectedProfile) {
        throw "MO2 must have profile '$ProfileName' selected. Found: $selectedProfile"
    }

    $modlist = Get-Content -LiteralPath $modlistPath
    $plugins = Get-Content -LiteralPath $pluginsPath
    foreach ($requiredMod in @(
        $BoatModName,
        $ParchmentModName,
        $SourceModName,
        $MapModName
    )) {
        if ($modlist -notcontains "+$requiredMod") {
            throw "Enable '$requiredMod' in the '$ProfileName' profile."
        }
    }
    foreach ($requiredPlugin in @(
        $BoatPluginName,
        "Journey to Baan Malur.esp"
    )) {
        if ($plugins -notcontains "*$requiredPlugin") {
            throw "Enable '$requiredPlugin' in the MO2 right pane."
        }
    }

    $boatRoot = Join-Path (Join-Path $instanceRoot "mods") $BoatModName
    $parchmentRoot = Join-Path (Join-Path $instanceRoot "mods") $ParchmentModName
    $mapRoot = Join-Path (Join-Path $instanceRoot "mods") $MapModName
    $requiredRuntime = @(
        (Join-Path $boatRoot $BoatPluginName),
        (Join-Path $boatRoot "SEQ\DiegeticTravelBoatBaanMalur.seq"),
        (Join-Path $boatRoot "Scripts\DNT_BaanMalurBoatParchmentFragment.pex"),
        (Join-Path $boatRoot "Scripts\DNT_BaanMalurBoatParchmentPicker.pex"),
        (Join-Path $boatRoot "Scripts\DNT_BaanMalurBoatTravelService.pex"),
        (Join-Path $parchmentRoot "Scripts\DNT_ParchmentNative.pex"),
        (Join-Path $parchmentRoot "SKSE\Plugins\DNTParchmentPicker.dll"),
        (Join-Path $mapRoot "textures\terrain\dlc2solstheimworld\solstheim.dds")
    )
    foreach ($runtimeFile in $requiredRuntime) {
        if (-not (Test-Path -LiteralPath $runtimeFile -PathType Leaf)) {
            throw "Baan Malur test runtime file was not found: $runtimeFile"
        }
    }

    if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
        if (-not $NoLaunch) {
            throw "SkyrimSE is already running. Use -NoLaunch to attach the watcher."
        }
    } elseif ($NoLaunch) {
        throw "SkyrimSE is not running; omit -NoLaunch to start it through MO2."
    }
}

Assert-TestReady
Write-Output "Baan Malur boat preflight passed for profile '$ProfileName'."
Write-Output "Runtime module: $BoatPluginName"

if ($ValidateOnly) {
    exit 0
}

if ($NoLaunch) {
    $skyrim = Get-Process SkyrimSE -ErrorAction Stop | Select-Object -First 1
    $launchTime = $skyrim.StartTime
    Write-Output "Attached to SkyrimSE process $($skyrim.Id)."
} else {
    $launchTime = Get-Date
    Start-Process -FilePath $ModOrganizerPath -ArgumentList $Shortcut | Out-Null
    Write-Output "Launched '$Shortcut' through profile '$ProfileName'."

    $processDeadline = (Get-Date).AddSeconds(120)
    $skyrim = $null
    while (-not $skyrim -and (Get-Date) -lt $processDeadline) {
        $skyrim = Get-Process SkyrimSE -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $skyrim) {
            Start-Sleep -Milliseconds 500
        }
    }
    if (-not $skyrim) {
        throw "SkyrimSE did not start within 120 seconds."
    }
    Write-Output "SkyrimSE process $($skyrim.Id) started."
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$papyrusLineCount = 0
$nativeLineCount = 0
$delegateCount = 0

Write-Output "Monitoring fresh Baan Malur boat and parchment output."
while ((Get-Date) -lt $deadline) {
    $skyrim = Get-Process -Id $skyrim.Id -ErrorAction SilentlyContinue
    if (-not $skyrim) {
        Write-Output "SkyrimSE exited. Observed $delegateCount Journey travel delegation(s)."
        exit 0
    }

    if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
        $logFile = Get-Item -LiteralPath $LogPath
        if ($logFile.LastWriteTime -ge $launchTime) {
            $lines = @(Get-Content -LiteralPath $LogPath)
            if ($lines.Count -lt $papyrusLineCount) {
                $papyrusLineCount = 0
            }
            if ($lines.Count -gt $papyrusLineCount) {
                foreach ($line in @($lines[$papyrusLineCount..($lines.Count - 1)])) {
                    if ($line -match "\[DNT\].*lane=baan_malur") {
                        Write-Output "BAAN MALUR LOG: $line"
                        if ($line -match "BOAT_TRAVEL_DELEGATE") {
                            $delegateCount += 1
                            Write-Output "JOURNEY DELEGATION #${delegateCount}"
                        }
                    } elseif (
                        $line -match "(?i)(DNT_BaanMalur|lane=baan_malur).*(error|warning)" -or
                        $line -match "(?i)(error|warning).*(DNT_BaanMalur|lane=baan_malur)"
                    ) {
                        Write-Warning "BAAN MALUR SCRIPT ISSUE: $line"
                    }
                }
                $papyrusLineCount = $lines.Count
            }
        }
    }

    if (Test-Path -LiteralPath $ParchmentLogPath -PathType Leaf) {
        $nativeLogFile = Get-Item -LiteralPath $ParchmentLogPath
        if ($nativeLogFile.LastWriteTime -ge $launchTime) {
            $nativeLines = @(Get-Content -LiteralPath $ParchmentLogPath)
            if ($nativeLines.Count -lt $nativeLineCount) {
                $nativeLineCount = 0
            }
            if ($nativeLines.Count -gt $nativeLineCount) {
                foreach ($nativeLine in @(
                    $nativeLines[$nativeLineCount..($nativeLines.Count - 1)]
                )) {
                    if ($nativeLine -match "PARCHMENT_") {
                        Write-Output "PARCHMENT LOG: $nativeLine"
                    } elseif ($nativeLine -match "(?i)(error|warning|critical)") {
                        Write-Warning "PARCHMENT NATIVE ISSUE: $nativeLine"
                    }
                }
                $nativeLineCount = $nativeLines.Count
            }
        }
    }

    Start-Sleep -Milliseconds 500
}

throw "Timed out after $TimeoutSeconds seconds. Observed $delegateCount Journey travel delegation(s)."
