param(
    [int]$TimeoutSeconds = 1800,
    [switch]$NoLaunch,
    [switch]$ValidateOnly,
    [string]$ModOrganizerPath = "D:\Lorerim\ModOrganizer.exe",
    [string]$ProfileName = "UltraDiegeticTravel",
    [string]$Shortcut = "moshortcut://:LoreRim",
    [string]$BoatModName = "DiegeticTravel - North Coast Boat Test",
    [string]$BoatPluginName = "DiegeticTravelBoatNorthCoast.esp",
    [string]$ParchmentModName = "DiegeticTravel - Parchment Picker Test",
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
    foreach ($requiredMod in @($BoatModName, $ParchmentModName)) {
        if ($modlist -notcontains "+$requiredMod") {
            throw "Enable '$requiredMod' in the '$ProfileName' profile."
        }
    }
    foreach ($requiredPlugin in @($BoatPluginName, "CFTO.esp")) {
        if ($plugins -notcontains "*$requiredPlugin") {
            throw "Enable '$requiredPlugin' in the MO2 right pane."
        }
    }

    $boatRoot = Join-Path (Join-Path $instanceRoot "mods") $BoatModName
    $parchmentRoot = Join-Path (Join-Path $instanceRoot "mods") $ParchmentModName
    $requiredRuntime = @(
        (Join-Path $boatRoot $BoatPluginName),
        (Join-Path $boatRoot "SEQ\DiegeticTravelBoatNorthCoast.seq"),
        (Join-Path $boatRoot "Scripts\DNT_NorthCoastBoatParchmentFragment.pex"),
        (Join-Path $boatRoot "Scripts\DNT_NorthCoastBoatParchmentPicker.pex"),
        (Join-Path $boatRoot "Scripts\DNT_NorthCoastBoatTravelService.pex"),
        (Join-Path $parchmentRoot "Scripts\DNT_ParchmentNative.pex"),
        (Join-Path $parchmentRoot "SKSE\Plugins\DNTParchmentPicker.dll"),
        (Join-Path $parchmentRoot "textures\DiegeticTravel\docks-marker.dds"),
        (Join-Path $parchmentRoot "textures\DiegeticTravel\shipwreck-marker.dds"),
        (Join-Path $parchmentRoot "textures\DiegeticTravel\winterhold-college.dds")
    )
    foreach ($runtimeFile in $requiredRuntime) {
        if (-not (Test-Path -LiteralPath $runtimeFile -PathType Leaf)) {
            throw "North-coast test runtime file was not found: $runtimeFile"
        }
    }

    if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
        if (-not $NoLaunch) {
            throw "SkyrimSE is already running. Use -NoLaunch to attach the watcher."
        }
    } elseif ($NoLaunch) {
        throw "SkyrimSE is not running; omit -NoLaunch to start it through MO2."
    }

    $resolvedModOrganizer = (Resolve-Path -LiteralPath $ModOrganizerPath).Path
    $otherInstances = Get-Process ModOrganizer -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Path -and
            ((Resolve-Path -LiteralPath $_.Path).Path -ne $resolvedModOrganizer)
        }
    if ($otherInstances) {
        $instanceList = ($otherInstances | ForEach-Object {
            "'$($_.MainWindowTitle)' ($($_.Path))"
        }) -join "; "
        throw "A different MO2 instance would receive the shortcut: $instanceList"
    }
}

Assert-TestReady
Write-Output "North-coast boat preflight passed for profile '$ProfileName'."
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
$completionCount = 0
$observedFreshPapyrus = $false
$observedFreshNative = $false

Write-Output "Monitoring fresh North-coast boat and parchment output."
while ((Get-Date) -lt $deadline) {
    $skyrim = Get-Process -Id $skyrim.Id -ErrorAction SilentlyContinue
    if (-not $skyrim) {
        Write-Output "SkyrimSE exited. Observed $completionCount completed North-coast trip(s)."
        exit 0
    }

    if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
        $logFile = Get-Item -LiteralPath $LogPath
        if ($logFile.LastWriteTime -ge $launchTime) {
            $lines = @(Get-Content -LiteralPath $LogPath)
            if (-not $observedFreshPapyrus) {
                $observedFreshPapyrus = $true
                Write-Output "Fresh Papyrus log detected; North-coast listener is live."
            }
            if ($lines.Count -lt $papyrusLineCount) {
                $papyrusLineCount = 0
            }
            if ($lines.Count -gt $papyrusLineCount) {
                $newLines = @($lines[$papyrusLineCount..($lines.Count - 1)])
                foreach ($line in $newLines) {
                    if ($line -match "\[DNT\].*lane=north_coast") {
                        Write-Output "NORTH COAST LOG: $line"
                        if ($line -match "BOAT_TRAVEL_COMPLETE") {
                            $completionCount += 1
                            Write-Output "NORTH COAST TRIP SUCCESS #${completionCount}"
                        }
                    } elseif (
                        $line -match "(?i)(DNT_NorthCoast|lane=north_coast).*(error|warning)" -or
                        $line -match "(?i)(error|warning).*(DNT_NorthCoast|lane=north_coast)"
                    ) {
                        Write-Warning "NORTH COAST SCRIPT ISSUE: $line"
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
            if (-not $observedFreshNative) {
                $observedFreshNative = $true
                Write-Output "Fresh parchment native log detected; picker listener is live."
            }
            if ($nativeLines.Count -lt $nativeLineCount) {
                $nativeLineCount = 0
            }
            if ($nativeLines.Count -gt $nativeLineCount) {
                $newNativeLines = @(
                    $nativeLines[$nativeLineCount..($nativeLines.Count - 1)]
                )
                foreach ($nativeLine in $newNativeLines) {
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

throw "Timed out after $TimeoutSeconds seconds. Observed $completionCount completed North-coast trip(s)."
