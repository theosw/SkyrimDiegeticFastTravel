param(
    [int]$TimeoutSeconds = 1800,
    [switch]$NoLaunch,
    [switch]$ValidateOnly,
    [string]$ModOrganizerPath = "D:\Lorerim\ModOrganizer.exe",
    [string]$ProfileName = "UltraDiegeticTravel",
    [string]$Shortcut = "moshortcut://:LoreRim",
    [string]$CoreModName = "DiegeticTravel - Carriage Core Test",
    [string]$AdapterModName = "DiegeticTravel - Carriage Parchment Test",
    [string]$ParchmentModName = "DiegeticTravel - Parchment Picker Test",
    [string]$OriginalModName = "DiegeticTravel",
    [string]$CorePluginName = "DiegeticTravel.esp",
    [string]$AdapterPluginName = "DiegeticTravelCarriageParchment.esp",
    [string]$ParchmentPluginName = "DiegeticTravelWizardParchment.esp",
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

function Assert-CarriageTestReady {
    if (-not (Test-Path -LiteralPath $ModOrganizerPath -PathType Leaf)) {
        throw "Mod Organizer was not found: $ModOrganizerPath"
    }
    $instanceRoot = Split-Path -Parent $ModOrganizerPath
    $profileRoot = Join-Path (Join-Path $instanceRoot "profiles") $ProfileName
    $modOrganizerIni = Join-Path $instanceRoot "ModOrganizer.ini"
    $modlistPath = Join-Path $profileRoot "modlist.txt"
    $pluginsPath = Join-Path $profileRoot "plugins.txt"
    foreach ($path in @($modOrganizerIni, $modlistPath, $pluginsPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required MO2 profile file was not found: $path"
        }
    }

    $selectedProfile = Select-String -LiteralPath $modOrganizerIni `
        -Pattern "^selected_profile=" |
        Select-Object -First 1 -ExpandProperty Line
    if ($selectedProfile -ne "selected_profile=@ByteArray($ProfileName)") {
        throw "MO2 must have profile '$ProfileName' selected. Found: $selectedProfile"
    }

    $modlist = @(Get-Content -LiteralPath $modlistPath)
    $plugins = @(Get-Content -LiteralPath $pluginsPath)
    foreach ($mod in @($CoreModName, $AdapterModName, $ParchmentModName)) {
        if ($modlist -notcontains "+$mod") {
            throw "Enable '$mod' in the '$ProfileName' profile."
        }
    }
    if ($modlist -contains "+$OriginalModName") {
        throw "Disable the original '$OriginalModName' entry; use the isolated carriage core test mod."
    }
    foreach ($plugin in @($CorePluginName, $AdapterPluginName, $ParchmentPluginName)) {
        if ($plugins -notcontains "*$plugin") {
            throw "Enable '$plugin' in the MO2 right pane."
        }
    }

    $cftoIndex = [array]::IndexOf($plugins, "*CFTO.esp")
    $coreIndex = [array]::IndexOf($plugins, "*$CorePluginName")
    $adapterIndex = [array]::IndexOf($plugins, "*$AdapterPluginName")
    if ($cftoIndex -lt 0 -or $coreIndex -le $cftoIndex) {
        throw "$CorePluginName must load after CFTO.esp."
    }
    if ($adapterIndex -le $coreIndex) {
        throw "$AdapterPluginName must load after $CorePluginName."
    }
    $bcdIndices = for ($index = 0; $index -lt $plugins.Count; $index += 1) {
        if ($plugins[$index] -match '^\*Better Carriage Destinations.*\.esp$') {
            $index
        }
    }
    if ($bcdIndices -and $adapterIndex -le ($bcdIndices | Measure-Object -Maximum).Maximum) {
        throw "$AdapterPluginName must load after enabled Better Carriage Destinations plugins so its paid/free root overrides win."
    }

    $modsRoot = Join-Path $instanceRoot "mods"
    $required = @(
        (Join-Path (Join-Path $modsRoot $CoreModName) $CorePluginName),
        (Join-Path (Join-Path $modsRoot $CoreModName) "Seq\DiegeticTravel.seq"),
        (Join-Path (Join-Path $modsRoot $CoreModName) "SKSE\Plugins\DiegeticTravel\runtime.json"),
        (Join-Path (Join-Path $modsRoot $AdapterModName) $AdapterPluginName),
        (Join-Path (Join-Path $modsRoot $AdapterModName) "SEQ\DiegeticTravelCarriageParchment.seq"),
        (Join-Path (Join-Path $modsRoot $AdapterModName) "Scripts\DNT_CarriageParchmentPicker.pex"),
        (Join-Path (Join-Path $modsRoot $ParchmentModName) "SKSE\Plugins\DNTParchmentPicker.dll")
    )
    $nordenMarkerNames = @(
        "norden-town.dds",
        "norden-settlement.dds",
        "norden-farm.dds",
        "norden-wood-mill.dds",
        "norden-mine.dds",
        "norden-riften-capital.dds",
        "norden-windhelm-capital.dds",
        "norden-whiterun-capital.dds",
        "norden-solitude-capital.dds",
        "norden-markarth-capital.dds",
        "norden-winterhold-capital.dds",
        "norden-morthal-capital.dds",
        "norden-falkreath-capital.dds",
        "norden-dawnstar-capital.dds"
    )
    $required += $nordenMarkerNames | ForEach-Object {
        Join-Path (Join-Path $modsRoot $ParchmentModName) `
            "textures\DiegeticTravel\$_"
    }
    foreach ($path in $required) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required carriage test file was not found: $path"
        }
    }

    if (Get-Process SkyrimSE -ErrorAction SilentlyContinue) {
        if (-not $NoLaunch) {
            throw "SkyrimSE is already running. Use -NoLaunch to attach the watcher."
        }
    } elseif ($NoLaunch) {
        throw "SkyrimSE is not running; omit -NoLaunch to launch it through MO2."
    }
}

Assert-CarriageTestReady
Write-Output "Carriage parchment preflight passed for profile '$ProfileName'."
Write-Output "Core: $CorePluginName"
Write-Output "Adapter: $AdapterPluginName"
Write-Output "LoreRim BCD stack: retained; adapter winner verified by load order"
Write-Output "Execution: marker click -> atomic purchase -> direct CFTO arrival travel"
Write-Output "Carriage art: exact authorized Norden discovered-map symbols"

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
$purchaseCount = 0
$selectionCount = 0
$freshPapyrus = $false
$freshNative = $false
Write-Output "Monitoring carriage and parchment output."

while ((Get-Date) -lt $deadline) {
    $skyrim = Get-Process -Id $skyrim.Id -ErrorAction SilentlyContinue
    if (-not $skyrim) {
        Write-Output "SkyrimSE exited. Observed $selectionCount carriage selection(s) and $purchaseCount committed purchase(s)."
        exit 0
    }

    if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
        $file = Get-Item -LiteralPath $LogPath
        if ($file.LastWriteTime -ge $launchTime) {
            $lines = @(Get-Content -LiteralPath $LogPath)
            if (-not $freshPapyrus) {
                $freshPapyrus = $true
                Write-Output "Fresh Papyrus log detected; carriage listener is live."
            }
            if ($lines.Count -lt $papyrusLineCount) { $papyrusLineCount = 0 }
            if ($lines.Count -gt $papyrusLineCount) {
                foreach ($line in @($lines[$papyrusLineCount..($lines.Count - 1)])) {
                    if ($line -match '\[DNT\].*(CARRIAGE_|PURCHASE_|ORIGIN_|MENU_QUOTES_)') {
                        Write-Output "CARRIAGE LOG: $line"
                        if ($line -match 'CARRIAGE_PARCHMENT_SELECT') { $selectionCount += 1 }
                        if ($line -match 'PURCHASE_COMMITTED') {
                            $purchaseCount += 1
                            Write-Output "CARRIAGE PURCHASE SUCCESS #${purchaseCount}"
                        }
                    } elseif ($line -match '(?i)(error|warning).*DNT|DNT.*(error|warning)') {
                        Write-Warning "CARRIAGE SCRIPT ISSUE: $line"
                    }
                }
                $papyrusLineCount = $lines.Count
            }
        }
    }

    if (Test-Path -LiteralPath $ParchmentLogPath -PathType Leaf) {
        $file = Get-Item -LiteralPath $ParchmentLogPath
        if ($file.LastWriteTime -ge $launchTime) {
            $lines = @(Get-Content -LiteralPath $ParchmentLogPath)
            if (-not $freshNative) {
                $freshNative = $true
                Write-Output "Fresh native parchment log detected; picker listener is live."
            }
            if ($lines.Count -lt $nativeLineCount) { $nativeLineCount = 0 }
            if ($lines.Count -gt $nativeLineCount) {
                foreach ($line in @($lines[$nativeLineCount..($lines.Count - 1)])) {
                    if ($line -match 'PARCHMENT_') {
                        Write-Output "PARCHMENT LOG: $line"
                    } elseif ($line -match '(?i)(error|warning|critical)') {
                        Write-Warning "PARCHMENT NATIVE ISSUE: $line"
                    }
                }
                $nativeLineCount = $lines.Count
            }
        }
    }
    Start-Sleep -Milliseconds 500
}

throw "Timed out after $TimeoutSeconds seconds. Observed $selectionCount carriage selection(s) and $purchaseCount committed purchase(s)."
