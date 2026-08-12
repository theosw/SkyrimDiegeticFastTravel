param(
    [int]$TimeoutSeconds = 1800,
    [switch]$NoLaunch,
    [switch]$ValidateOnly,
    [string]$ModOrganizerPath = "D:\Lorerim\ModOrganizer.exe",
    [string]$ProfileName = "UltraDiegeticTravel",
    [string]$Shortcut = "moshortcut://:LoreRim",
    [string]$LogPath = (Join-Path $env:USERPROFILE `
        "Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log"),
    [string]$NativeLogPath = (Join-Path $env:USERPROFILE `
        "Documents\My Games\Skyrim Special Edition\SKSE\DNTParchmentPicker.log")
)

$ErrorActionPreference = "Stop"

function Assert-ConsolidatedReleaseReady {
    if (-not (Test-Path -LiteralPath $ModOrganizerPath -PathType Leaf)) {
        throw "MO2 not found: $ModOrganizerPath"
    }
    $instanceRoot = Split-Path -Parent $ModOrganizerPath
    $profileRoot = Join-Path (Join-Path $instanceRoot "profiles") $ProfileName
    $ini = Join-Path $instanceRoot "ModOrganizer.ini"
    $modlistPath = Join-Path $profileRoot "modlist.txt"
    $pluginsPath = Join-Path $profileRoot "plugins.txt"
    foreach ($path in @($ini, $modlistPath, $pluginsPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required MO2 profile file is missing: $path"
        }
    }
    $selected = Select-String -LiteralPath $ini -Pattern "^selected_profile=" |
        Select-Object -First 1 -ExpandProperty Line
    if ($selected -ne "selected_profile=@ByteArray($ProfileName)") {
        throw "Select MO2 profile '$ProfileName'. Found: $selected"
    }

    $mods = @(Get-Content -LiteralPath $modlistPath)
    $plugins = @(Get-Content -LiteralPath $pluginsPath)
    if ($mods -notcontains "+DiegeticTravel") {
        throw "Enable the consolidated 'DiegeticTravel' mod in MO2's left pane"
    }
    $legacyMods = @(
        "DiegeticTravel - State Gate Test Harness",
        "DiegeticTravel - Baan Malur Boat Test",
        "DiegeticTravel - Carriage Parchment Test",
        "DiegeticTravel - Carriage Core Test",
        "DiegeticTravel - North Coast Boat Test",
        "DiegeticTravel - Solstheim Boat Test",
        "DiegeticTravel - Lake Ilinalta Boat Test",
        "DiegeticTravel - Parchment Picker Test",
        "DiegeticTravel - Lake Honrich Boat Test",
        "houseCARL - DiegeticTravelWizardGuides"
    )
    foreach ($legacy in $legacyMods) {
        if ($mods -contains "+$legacy") {
            throw "Disable legacy development mod: $legacy"
        }
    }
    if ($plugins -notcontains "*DiegeticTravel.esp") {
        throw "Enable DiegeticTravel.esp in MO2's right pane"
    }
    foreach ($legacyPlugin in @(
        "DiegeticTravelWizardGuides.esp",
        "DiegeticTravelWizardMap.esp",
        "DiegeticTravelWizardParchment.esp",
        "DiegeticTravelCarriageParchment.esp",
        "DiegeticTravelBoatHonrich.esp",
        "DiegeticTravelBoatIlinalta.esp",
        "DiegeticTravelBoatNorthCoast.esp",
        "DiegeticTravelBoatSolstheim.esp",
        "DiegeticTravelBoatBaanMalur.esp"
    )) {
        if ($plugins -contains "*$legacyPlugin") {
            throw "Disable legacy development plugin: $legacyPlugin"
        }
    }

    $modRoot = Join-Path (Join-Path $instanceRoot "mods") "DiegeticTravel"
    $pluginPath = Join-Path $modRoot "DiegeticTravel.esp"
    $seqPath = Join-Path $modRoot "SEQ\DiegeticTravel.seq"
    foreach ($required in @($pluginPath, $seqPath)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Consolidated release file is missing: $required"
        }
    }
    $header = [IO.File]::ReadAllBytes($pluginPath)
    if (([BitConverter]::ToUInt32($header, 8) -band 0x200) -eq 0) {
        throw "Installed DiegeticTravel.esp is not ESL-flagged"
    }
    if ((Get-Item -LiteralPath $seqPath).Length -ne 68) {
        throw "Installed consolidated SEQ does not contain 17 quests"
    }
    if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
        if (-not $NoLaunch) {
            throw "SkyrimSE is already running; use -NoLaunch to attach"
        }
    } elseif ($NoLaunch) {
        throw "SkyrimSE is not running; omit -NoLaunch to launch it"
    }
}

Assert-ConsolidatedReleaseReady
Write-Output "Consolidated release preflight passed for '$ProfileName'."
Write-Output "Use a fresh/disposable save; modular-development saves are invalid."
if ($ValidateOnly) { exit 0 }

if ($NoLaunch) {
    $skyrim = Get-Process SkyrimSE -ErrorAction Stop | Select-Object -First 1
    $launchTime = $skyrim.StartTime
    Write-Output "Attached to SkyrimSE process $($skyrim.Id)."
} else {
    $launchTime = Get-Date
    Start-Process -FilePath $ModOrganizerPath -ArgumentList $Shortcut | Out-Null
    Write-Output "Launched '$Shortcut' through profile '$ProfileName'."
    $launchDeadline = (Get-Date).AddSeconds(120)
    $skyrim = $null
    while (-not $skyrim -and (Get-Date) -lt $launchDeadline) {
        $skyrim = Get-Process SkyrimSE -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $skyrim) { Start-Sleep -Milliseconds 500 }
    }
    if (-not $skyrim) { throw "SkyrimSE did not start within 120 seconds" }
}

$papyrusCount = 0
$nativeCount = 0
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
Write-Output "Monitoring Diegetic Travel purchase, travel, and parchment events."
while ((Get-Date) -lt $deadline) {
    if (-not (Get-Process -Id $skyrim.Id -ErrorAction SilentlyContinue)) {
        Write-Output "SkyrimSE exited."
        exit 0
    }
    if (Test-Path -LiteralPath $LogPath) {
        $file = Get-Item -LiteralPath $LogPath
        if ($file.LastWriteTime -ge $launchTime) {
            $lines = @(Get-Content -LiteralPath $LogPath)
            if ($lines.Count -lt $papyrusCount) { $papyrusCount = 0 }
            if ($lines.Count -gt $papyrusCount) {
                foreach ($line in @($lines[$papyrusCount..($lines.Count - 1)])) {
                    if ($line -match "\[DNT\].*(TRAVEL_|PURCHASE_|CARRIAGE_|PARCHMENT_)") {
                        Write-Output "STATE LOG: $line"
                    } elseif ($line -match "(?i)(error|stack dump|cannot call|none object)") {
                        Write-Warning "PAPYRUS ISSUE: $line"
                    }
                }
                $papyrusCount = $lines.Count
            }
        }
    }
    if (Test-Path -LiteralPath $NativeLogPath) {
        $file = Get-Item -LiteralPath $NativeLogPath
        if ($file.LastWriteTime -ge $launchTime) {
            $lines = @(Get-Content -LiteralPath $NativeLogPath)
            if ($lines.Count -lt $nativeCount) { $nativeCount = 0 }
            if ($lines.Count -gt $nativeCount) {
                foreach ($line in @($lines[$nativeCount..($lines.Count - 1)])) {
                    if ($line -match "PARCHMENT_") {
                        Write-Output "NATIVE LOG: $line"
                    } elseif ($line -match "(?i)(error|warning|critical)") {
                        Write-Warning "NATIVE ISSUE: $line"
                    }
                }
                $nativeCount = $lines.Count
            }
        }
    }
    Start-Sleep -Milliseconds 500
}
throw "Timed out after $TimeoutSeconds seconds"
