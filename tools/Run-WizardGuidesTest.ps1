param(
    [int]$TimeoutSeconds = 1800,
    [switch]$NoLaunch,
    [switch]$ValidateOnly,
    [switch]$AllowOriginalCarriageModule,
    [string]$ModOrganizerPath = "D:\Lorerim\ModOrganizer.exe",
    [string]$ProfileName = "UltraDiegeticTravel",
    [string]$Shortcut = "moshortcut://:LoreRim",
    [string]$WizardModName = "houseCARL - DiegeticTravelWizardGuides",
    [string]$WizardPluginName = "DiegeticTravelWizardGuides.esp",
    [switch]$RequireMapAdapter,
    [string]$WizardMapPluginName = "DiegeticTravelWizardMap.esp",
    [string]$BCDPluginName = "Better Carriage Destinations.esp",
    [switch]$RequireParchmentPicker,
    [string]$ParchmentModName = "DiegeticTravel - Parchment Picker Test",
    [string]$ParchmentPluginName = "DiegeticTravelWizardParchment.esp",
    [string]$ParchmentArtworkModName = "Skyrim Paper Map by Caro Tuts for FWMF",
    [string]$OriginalModName = "DiegeticTravel",
    [string]$OriginalPluginName = "DiegeticTravel.esp",
    [string]$AuditModName = "houseCARL - houseCARL_PapyrusAudit",
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

    foreach ($requiredFile in @($modOrganizerIni, $modlistPath, $pluginsPath)) {
        if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
            throw "Required MO2 file was not found: $requiredFile"
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

    if ($modlist -notcontains "+$WizardModName") {
        throw "Enable '$WizardModName' in the '$ProfileName' profile."
    }
    if ($plugins -notcontains "*$WizardPluginName") {
        throw "Enable '$WizardPluginName' in the MO2 right pane."
    }
    if ($RequireMapAdapter) {
        if ($plugins -notcontains "*$WizardMapPluginName") {
            throw "Enable '$WizardMapPluginName' in the MO2 right pane."
        }
        if ($plugins -notcontains "*$BCDPluginName") {
            throw "Enable '$BCDPluginName'; the wizard map adapter requires BCD."
        }
    }
    if ($RequireParchmentPicker) {
        if ($modlist -notcontains "+$ParchmentModName") {
            throw "Enable '$ParchmentModName' in the '$ProfileName' profile."
        }
        if ($plugins -notcontains "*$ParchmentPluginName") {
            throw "Enable '$ParchmentPluginName' in the MO2 right pane."
        }
        if ($modlist -notcontains "+$ParchmentArtworkModName") {
            throw "Enable '$ParchmentArtworkModName'; the wizard picker references its loose formal-map texture."
        }
    }
    if ($modlist -contains "+$AuditModName") {
        throw "Disable '$AuditModName'; it is audit output, not a runtime dependency."
    }

    if (-not $AllowOriginalCarriageModule) {
        if ($modlist -contains "+$OriginalModName") {
            throw "Disable '$OriginalModName' for the isolated wizard-only test."
        }
        if ($plugins -contains "*$OriginalPluginName") {
            throw "Disable '$OriginalPluginName' for the isolated wizard-only test."
        }
    }

    $wizardRoot = Join-Path (Join-Path $instanceRoot "mods") $WizardModName
    $requiredWizardFiles = @(
        (Join-Path $wizardRoot $WizardPluginName),
        (Join-Path $wizardRoot "SEQ\DiegeticTravelWizardGuides.seq"),
        (Join-Path $wizardRoot "Scripts\DNT_WizardTravelService.pex"),
        (Join-Path $wizardRoot "Scripts\DNT_WizardTravelFragment.pex")
    )
    if ($RequireMapAdapter) {
        $requiredWizardFiles += @(
            (Join-Path $wizardRoot $WizardMapPluginName),
            (Join-Path $wizardRoot "SEQ\DiegeticTravelWizardMap.seq"),
            (Join-Path $wizardRoot "Scripts\DNT_WizardMapPicker.pex"),
            (Join-Path $wizardRoot "Scripts\DNT_WizardMapFragment.pex")
        )
    }
    if ($RequireParchmentPicker) {
        $parchmentRoot = Join-Path (Join-Path $instanceRoot "mods") $ParchmentModName
        $requiredWizardFiles += @(
            (Join-Path $parchmentRoot $ParchmentPluginName),
            (Join-Path $parchmentRoot "SEQ\DiegeticTravelWizardParchment.seq"),
            (Join-Path $parchmentRoot "Scripts\DNT_ParchmentNative.pex"),
            (Join-Path $parchmentRoot "Scripts\DNT_WizardParchmentFragment.pex"),
            (Join-Path $parchmentRoot "Scripts\DNT_WizardParchmentPicker.pex"),
            (Join-Path $parchmentRoot "SKSE\Plugins\DNTParchmentPicker.dll"),
            (Join-Path $parchmentRoot "textures\DiegeticTravel\winterhold-college.dds"),
            (Join-Path (Join-Path (Join-Path $instanceRoot "mods") $ParchmentArtworkModName) `
                "textures\terrain\tamriel\skyrim.dds")
        )
    }
    foreach ($requiredWizardFile in $requiredWizardFiles) {
        if (-not (Test-Path -LiteralPath $requiredWizardFile -PathType Leaf)) {
            throw "Wizard-guide runtime file was not found: $requiredWizardFile"
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
        $instanceList = (
            $otherInstances |
            ForEach-Object { "'$($_.MainWindowTitle)' ($($_.Path))" }
        ) -join "; "
        throw "A different MO2 instance would receive the shortcut: $instanceList"
    }
}

Assert-TestReady
Write-Output "Wizard-guide preflight passed for profile '$ProfileName'."
Write-Output "Runtime module: $WizardPluginName"
Write-Output "Map adapter: $(if ($RequireMapAdapter) { "$WizardMapPluginName with $BCDPluginName" } else { 'not required' })"
Write-Output "Parchment picker: $(if ($RequireParchmentPicker) { $ParchmentPluginName } else { 'not required' })"
Write-Output "Original carriage module: $(if ($AllowOriginalCarriageModule) { 'allowed' } else { 'disabled' })"

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
$observedFreshLog = $false
$lineCount = 0
$completionCount = 0
$selectionCount = 0
$nativeLineCount = 0
$observedFreshNativeLog = $false

Write-Output "Monitoring fresh Papyrus output at: $LogPath"
while ((Get-Date) -lt $deadline) {
    $skyrim = Get-Process -Id $skyrim.Id -ErrorAction SilentlyContinue
    if (-not $skyrim) {
        Write-Output "SkyrimSE exited. Observed $completionCount completed wizard trip(s)."
        exit 0
    }

    if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
        $logFile = Get-Item -LiteralPath $LogPath
        if ($logFile.LastWriteTime -ge $launchTime) {
            $lines = @(Get-Content -LiteralPath $LogPath)
            if (-not $observedFreshLog) {
                $observedFreshLog = $true
                Write-Output "Fresh Papyrus log detected; wizard trace listener is live."
            }

            if ($lines.Count -lt $lineCount) {
                $lineCount = 0
            }
            if ($lines.Count -gt $lineCount) {
                $newLines = @($lines[$lineCount..($lines.Count - 1)])
                foreach ($line in $newLines) {
                    if ($line -match "\[DNT\].*WIZARD_(TRAVEL|MAP|PARCHMENT)") {
                        Write-Output "WIZARD LOG: $line"
                        if ($line -match "WIZARD_TRAVEL_COMPLETE") {
                            $completionCount += 1
                            Write-Output "WIZARD TRIP SUCCESS #${completionCount}"
                        }
                    } elseif (
                        $line -match "(?i)(error|warning).*(DNT_(Parchment|Wizard(Map|Travel|Parchment))|WIZARD_(MAP|TRAVEL|PARCHMENT))" -or
                        $line -match "(?i)(DNT_(Parchment|Wizard(Map|Travel|Parchment))|WIZARD_(MAP|TRAVEL|PARCHMENT)).*(error|warning)"
                    ) {
                        Write-Warning "WIZARD SCRIPT ISSUE: $line"
                    }
                }
                $lineCount = $lines.Count
            }
        }
    }

    if ($RequireParchmentPicker -and (Test-Path -LiteralPath $ParchmentLogPath -PathType Leaf)) {
        $nativeLogFile = Get-Item -LiteralPath $ParchmentLogPath
        if ($nativeLogFile.LastWriteTime -ge $launchTime) {
            $nativeLines = @(Get-Content -LiteralPath $ParchmentLogPath)
            if (-not $observedFreshNativeLog) {
                $observedFreshNativeLog = $true
                Write-Output "Fresh parchment native log detected; picker listener is live."
            }
            if ($nativeLines.Count -lt $nativeLineCount) {
                $nativeLineCount = 0
            }
            if ($nativeLines.Count -gt $nativeLineCount) {
                $newNativeLines = @($nativeLines[$nativeLineCount..($nativeLines.Count - 1)])
                foreach ($nativeLine in $newNativeLines) {
                    if ($nativeLine -match "PARCHMENT_") {
                        Write-Output "PARCHMENT LOG: $nativeLine"
                        if ($nativeLine -match "PARCHMENT_SELECT") {
                            $selectionCount += 1
                            Write-Output "PARCHMENT SELECTION #${selectionCount}"
                        }
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

throw "Timed out after $TimeoutSeconds seconds. Observed $completionCount completed wizard trip(s)."
