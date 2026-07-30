param(
    [string]$LoreRimRoot = "D:\Games\US SSE\Lorerim\game-files",
    [string]$XEdit = "D:\Lorerim\tools\SSE Edit (4.0.4)\SSEEdit64.exe",
    [string]$Manifest = "build\dialogue_manifest.json",
    [string]$DialogueRuntime = "build\dialogue_runtime.json",
    [string]$PluginOutput = "build\DiegeticTravel.esp",
    [string]$StagingData = "build\xedit-data"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Find-XEditControl(
    [System.Diagnostics.Process]$Process,
    [string]$Name,
    [System.Windows.Automation.ControlType]$ControlType
) {
    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $processCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
        $Process.Id
    )
    $elements = $desktop.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        $processCondition
    )

    foreach ($element in $elements) {
        if (
            $element.Current.Name -eq $Name -and
            $element.Current.ControlType -eq $ControlType
        ) {
            return $element
        }
    }
    return $null
}

function Find-XEditWindow(
    [System.Diagnostics.Process]$Process,
    [string]$ExcludedName
) {
    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $processCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
        $Process.Id
    )
    $elements = $desktop.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        $processCondition
    )

    foreach ($element in $elements) {
        if (
            $element.Current.ControlType -eq
                [System.Windows.Automation.ControlType]::Window -and
            $element.Current.Name -ne $ExcludedName
        ) {
            return $element
        }
    }
    return $null
}

$manifestPath = Resolve-ProjectPath $Manifest
$dialogueRuntimePath = Resolve-ProjectPath $DialogueRuntime
$pluginOutputPath = Resolve-ProjectPath $PluginOutput
$stagingDataPath = Resolve-ProjectPath $StagingData
$generatorConfigPath = Join-Path $projectRoot "build\xedit_generator_config.json"
$pluginsListPath = Join-Path $projectRoot "build\xedit_plugins.txt"
$xeditLogPath = Join-Path $projectRoot "build\xedit_generator.log"
$xeditStatusPath = Join-Path $projectRoot "build\xedit_generator.status"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_GeneratePlugin.pas"
$gameData = Join-Path $LoreRimRoot "Stock Game\Data"
$cftoPlugin = Join-Path $LoreRimRoot "mods\Carriage and Ferry Travel Overhaul - Fixes and Winterhold\CFTO.esp"

foreach ($required in @($XEdit, $manifestPath, $scriptPath, $cftoPlugin)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required build input not found: $required"
    }
}

New-Item -ItemType Directory -Force -Path $stagingDataPath | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $pluginOutputPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dialogueRuntimePath) | Out-Null

foreach ($master in @("Skyrim.esm", "Update.esm", "Dawnguard.esm", "HearthFires.esm", "Dragonborn.esm")) {
    $source = Join-Path $gameData $master
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required Skyrim master not found: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $stagingDataPath $master) -Force
}
Copy-Item -LiteralPath $cftoPlugin -Destination (Join-Path $stagingDataPath "CFTO.esp") -Force

$stagedGeneratedPlugin = Join-Path $stagingDataPath "DiegeticTravel.esp"
foreach ($oldOutput in @(
    $stagedGeneratedPlugin,
    $pluginOutputPath,
    $dialogueRuntimePath,
    $xeditLogPath,
    $xeditStatusPath
)) {
    if (Test-Path -LiteralPath $oldOutput -PathType Leaf) {
        Remove-Item -LiteralPath $oldOutput -Force
    }
}

$generatorConfig = @{
    manifest = $manifestPath
    dialogue_runtime = $dialogueRuntimePath
    plugin_output = $pluginOutputPath
} | ConvertTo-Json
[System.IO.File]::WriteAllText(
    $generatorConfigPath,
    $generatorConfig,
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::WriteAllText(
    $pluginsListPath,
    "*CFTO.esp`r`n",
    [System.Text.UTF8Encoding]::new($false)
)

$xeditArguments = @(
    "-D:$stagingDataPath",
    "-P:$pluginsListPath",
    "-R:$xeditLogPath",
    "-IKnowWhatImDoing",
    "-nobuildrefs",
    "-autoload",
    "-autoexit",
    "-script:$scriptPath"
)

# Official xEdit 4.1.5f parses -autoload/-autoexit only in Edit mode even
# though Script mode already contains the corresponding load and shutdown
# behavior. Keep a managed UI Automation fallback for the stock executable.
# A patched xEdit accepts the switches and will need no UI interaction.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$xeditProcess = Start-Process `
    -FilePath $XEdit `
    -ArgumentList $xeditArguments `
    -WindowStyle Hidden `
    -PassThru
$confirmedModules = $false
$terminalStatusSeen = $false
$automationDeadline = [DateTime]::UtcNow.AddMinutes(2)

while (-not $xeditProcess.HasExited -and [DateTime]::UtcNow -lt $automationDeadline) {
    $xeditProcess.Refresh()

    if (-not $confirmedModules) {
        $moduleDialog = Find-XEditControl `
            -Process $xeditProcess `
            -Name "Module Selection" `
            -ControlType ([System.Windows.Automation.ControlType]::Window)
        $okButton = Find-XEditControl `
            -Process $xeditProcess `
            -Name "OK" `
            -ControlType ([System.Windows.Automation.ControlType]::Button)

        if (
            $null -ne $moduleDialog -and
            $null -ne $okButton -and
            $moduleDialog.Current.IsEnabled -and
            $okButton.Current.IsEnabled
        ) {
            $invoke = $okButton.GetCurrentPattern(
                [System.Windows.Automation.InvokePattern]::Pattern
            )
            $invoke.Invoke()
            $confirmedModules = $true
        }
    }

    if (Test-Path -LiteralPath $xeditStatusPath -PathType Leaf) {
        $generatorStatus = (
            Get-Content -LiteralPath $xeditStatusPath -Raw
        ).Trim()
        $terminalStatusSeen = $generatorStatus -in @("success", "failed")
    }

    if ($terminalStatusSeen) {
        Start-Sleep -Milliseconds 250
        $xeditProcess.Refresh()
        if (-not $xeditProcess.HasExited) {
            $mainWindow = Find-XEditWindow `
                -Process $xeditProcess `
                -ExcludedName "Module Selection"
            if ($null -ne $mainWindow) {
                $window = $mainWindow.GetCurrentPattern(
                    [System.Windows.Automation.WindowPattern]::Pattern
                )
                $window.Close()
            }
            else {
                Write-Warning (
                    "xEdit completed, but its main window was not available " +
                    "for managed shutdown."
                )
            }
        }
        break
    }

    Start-Sleep -Milliseconds 200
}

if (-not $xeditProcess.HasExited) {
    $null = $xeditProcess.WaitForExit(15000)
}
$xeditProcess.Refresh()

if (-not $xeditProcess.HasExited) {
    throw "xEdit did not finish automatically; its window was left open for inspection."
}
if ($xeditProcess.ExitCode -ne 0) {
    throw "xEdit plugin generation failed with exit code $($xeditProcess.ExitCode)"
}
if (-not $confirmedModules) {
    throw "xEdit exited before its preselected module list could be confirmed."
}
if (-not $terminalStatusSeen) {
    throw "xEdit exited without reporting generator completion. See: $xeditLogPath"
}
if ($generatorStatus -ne "success") {
    throw "xEdit generator reported failure. See: $xeditLogPath"
}

if (Test-Path -LiteralPath $xeditLogPath -PathType Leaf) {
    $scriptFailure = Select-String -LiteralPath $xeditLogPath `
        -Pattern "Exception in unit|Aborted: Applying script|Error assigning to" `
        -Quiet
    if ($scriptFailure) {
        throw "xEdit reported a generator script failure. See: $xeditLogPath"
    }
}

foreach ($generated in @($pluginOutputPath, $dialogueRuntimePath)) {
    if (-not (Test-Path -LiteralPath $generated -PathType Leaf)) {
        throw "xEdit exited without creating: $generated"
    }
}

Write-Host "Generated plugin: $pluginOutputPath"
Write-Host "Generated dialogue data: $dialogueRuntimePath"
