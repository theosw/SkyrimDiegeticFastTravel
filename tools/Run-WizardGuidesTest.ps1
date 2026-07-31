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
    [string]$OriginalModName = "DiegeticTravel",
    [string]$OriginalPluginName = "DiegeticTravel.esp",
    [string]$AuditModName = "houseCARL - houseCARL_PapyrusAudit",
    [string]$LogPath = (
        Join-Path $env:USERPROFILE `
            "Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log"
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
                    if ($line -match "\[DNT\].*WIZARD_TRAVEL") {
                        Write-Output "WIZARD LOG: $line"
                        if ($line -match "WIZARD_TRAVEL_COMPLETE") {
                            $completionCount += 1
                            Write-Output "WIZARD TRIP SUCCESS #${completionCount}"
                        }
                    } elseif (
                        $line -match "(?i)(error|warning).*(DNT_WizardTravel|WIZARD_TRAVEL)" -or
                        $line -match "(?i)(DNT_WizardTravel|WIZARD_TRAVEL).*(error|warning)"
                    ) {
                        Write-Warning "WIZARD SCRIPT ISSUE: $line"
                    }
                }
                $lineCount = $lines.Count
            }
        }
    }

    Start-Sleep -Milliseconds 500
}

throw "Timed out after $TimeoutSeconds seconds. Observed $completionCount completed wizard trip(s)."
