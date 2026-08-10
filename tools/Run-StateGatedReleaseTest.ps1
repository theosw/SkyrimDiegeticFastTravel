param(
    [int]$TimeoutSeconds = 1800,
    [switch]$NoLaunch,
    [switch]$ValidateOnly,
    [string]$ModOrganizerPath = 'D:\Lorerim\ModOrganizer.exe',
    [string]$ProfileName = 'UltraDiegeticTravel',
    [string]$Shortcut = 'moshortcut://:LoreRim',
    [string]$HarnessModName = 'DiegeticTravel - State Gate Test Harness',
    [string]$LogPath = (Join-Path $env:USERPROFILE 'Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log'),
    [string]$NativeLogPath = (Join-Path $env:USERPROFILE 'Documents\My Games\Skyrim Special Edition\SKSE\DNTParchmentPicker.log')
)

$ErrorActionPreference = 'Stop'
function Assert-Ready {
    if (-not (Test-Path -LiteralPath $ModOrganizerPath -PathType Leaf)) { throw "MO2 not found: $ModOrganizerPath" }
    $instanceRoot = Split-Path -Parent $ModOrganizerPath
    $profileRoot = Join-Path (Join-Path $instanceRoot 'profiles') $ProfileName
    $ini = Join-Path $instanceRoot 'ModOrganizer.ini'
    $modlistPath = Join-Path $profileRoot 'modlist.txt'
    $pluginsPath = Join-Path $profileRoot 'plugins.txt'
    foreach ($path in @($ini,$modlistPath,$pluginsPath)) { if (-not (Test-Path -LiteralPath $path)) { throw "Required MO2 file missing: $path" } }
    $selected = Select-String -LiteralPath $ini -Pattern '^selected_profile=' | Select-Object -First 1 -ExpandProperty Line
    if ($selected -ne "selected_profile=@ByteArray($ProfileName)") { throw "Select MO2 profile '$ProfileName'. Found: $selected" }
    $mods = @(Get-Content -LiteralPath $modlistPath)
    $plugins = @(Get-Content -LiteralPath $pluginsPath)
    $requiredMods = @(
        $HarnessModName,
        'DiegeticTravel - Lake Honrich Boat Test',
        'DiegeticTravel - Lake Ilinalta Boat Test',
        'DiegeticTravel - North Coast Boat Test',
        'DiegeticTravel - Carriage Core Test',
        'DiegeticTravel - Carriage Parchment Test',
        'DiegeticTravel - Parchment Picker Test'
    )
    foreach ($mod in $requiredMods) { if ($mods -notcontains "+$mod") { throw "Enable '$mod' in MO2's left pane." } }
    $requiredPlugins = @(
        'CFTO.esp','DiegeticTravelBoatHonrich.esp','DiegeticTravelBoatIlinalta.esp',
        'DiegeticTravelBoatNorthCoast.esp','DiegeticTravel.esp',
        'DiegeticTravelCarriageParchment.esp','DiegeticTravelWizardParchment.esp'
    )
    foreach ($plugin in $requiredPlugins) { if ($plugins -notcontains "*$plugin") { throw "Enable '$plugin' in MO2's right pane." } }
    $harnessRoot = Join-Path (Join-Path $instanceRoot 'mods') $HarnessModName
    foreach ($name in @('dnt_gates_lock_all.txt','dnt_gates_unlock_all.txt','dnt_apparition_add.txt')) {
        if (-not (Test-Path -LiteralPath (Join-Path $harnessRoot $name))) { throw "Harness runtime file missing: $name" }
    }
    if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
        if (-not $NoLaunch) { throw 'SkyrimSE is already running; use -NoLaunch to attach.' }
    } elseif ($NoLaunch) { throw 'SkyrimSE is not running; omit -NoLaunch to launch it.' }
}

Assert-Ready
Write-Output "State-gated release preflight passed for '$ProfileName'."
Write-Output 'Use only a disposable save; reload it between scenarios.'
Write-Output 'Matrix: docs\STATE_GATED_RELEASE_TEST.md'
if ($ValidateOnly) { exit 0 }

if ($NoLaunch) {
    $skyrim = Get-Process SkyrimSE -ErrorAction Stop | Select-Object -First 1
    $launchTime = $skyrim.StartTime
    Write-Output "Attached to SkyrimSE process $($skyrim.Id)."
} else {
    $launchTime = Get-Date
    Start-Process -FilePath $ModOrganizerPath -ArgumentList $Shortcut | Out-Null
    Write-Output "Launched '$Shortcut' through profile '$ProfileName'."
    $deadline = (Get-Date).AddSeconds(120)
    $skyrim = $null
    while (-not $skyrim -and (Get-Date) -lt $deadline) {
        $skyrim = Get-Process SkyrimSE -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $skyrim) { Start-Sleep -Milliseconds 500 }
    }
    if (-not $skyrim) { throw 'SkyrimSE did not start within 120 seconds.' }
}

$papyrusCount = 0
$nativeCount = 0
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
Write-Output 'Monitoring all Diegetic Travel state, purchase, time-mode, and native parchment events.'
while ((Get-Date) -lt $deadline) {
    if (-not (Get-Process -Id $skyrim.Id -ErrorAction SilentlyContinue)) {
        Write-Output 'SkyrimSE exited; generating gameplay evidence report.'
        & (Join-Path $PSScriptRoot 'Analyze-StateGatedReleaseLog.ps1') -PapyrusLogPath $LogPath -NativeLogPath $NativeLogPath | Out-Host
        exit 0
    }
    if (Test-Path -LiteralPath $LogPath) {
        $file = Get-Item $LogPath
        if ($file.LastWriteTime -ge $launchTime) {
            $lines = @(Get-Content $LogPath)
            if ($lines.Count -lt $papyrusCount) { $papyrusCount = 0 }
            if ($lines.Count -gt $papyrusCount) {
                foreach ($line in @($lines[$papyrusCount..($lines.Count-1)])) {
                    if ($line -match '\[DNT\].*(TRAVEL_|PURCHASE_|CARRIAGE_|PARCHMENT_)') { Write-Output "STATE LOG: $line" }
                }
                $papyrusCount = $lines.Count
            }
        }
    }
    if (Test-Path -LiteralPath $NativeLogPath) {
        $file = Get-Item $NativeLogPath
        if ($file.LastWriteTime -ge $launchTime) {
            $lines = @(Get-Content $NativeLogPath)
            if ($lines.Count -lt $nativeCount) { $nativeCount = 0 }
            if ($lines.Count -gt $nativeCount) {
                foreach ($line in @($lines[$nativeCount..($lines.Count-1)])) {
                    if ($line -match 'PARCHMENT_') { Write-Output "NATIVE LOG: $line" }
                    elseif ($line -match '(?i)(error|warning|critical)') { Write-Warning "NATIVE ISSUE: $line" }
                }
                $nativeCount = $lines.Count
            }
        }
    }
    Start-Sleep -Milliseconds 500
}
throw "Timed out after $TimeoutSeconds seconds."
