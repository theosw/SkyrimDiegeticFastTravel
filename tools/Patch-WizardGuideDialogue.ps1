param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$SourcePlugin = (
        "modules\wizard-guides\mod\DiegeticTravelWizardGuides.esp"
    ),
    [string]$XEdit = (
        "build\xedit-patched\SSEEdit64.exe"
    ),
    [string]$DeployPlugin = (
        "D:\Lorerim\mods\houseCARL - DiegeticTravelWizardGuides\" +
        "DiegeticTravelWizardGuides.esp"
    ),
    [switch]$Deploy
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$fixRoot = Join-Path $buildRoot "wizard-guide-fix"
$stagingData = Join-Path $fixRoot "data"
$beforeRoot = Join-Path $fixRoot "before"
$outputPlugin = Join-Path $fixRoot "DiegeticTravelWizardGuides.esp"
$pluginsList = Join-Path $fixRoot "plugins.txt"
$xeditLog = Join-Path $fixRoot "xedit.log"
$statusPath = Join-Path $buildRoot "wizard-guide-fix.status"
$errorPath = Join-Path $buildRoot "wizard-guide-fix.error"
$scriptPath = Join-Path $PSScriptRoot "xedit\DNT_FixWizardRootInfo.pas"
$workspacePlugin = Join-Path (
    Join-Path $projectRoot "modules\wizard-guides\mod"
) "DiegeticTravelWizardGuides.esp"
$workspaceModRoot = Split-Path -Parent $workspacePlugin

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$sourcePluginPath = Resolve-ProjectPath $SourcePlugin
$xeditPath = Resolve-ProjectPath $XEdit
$deployPluginPath = Resolve-ProjectPath $DeployPlugin
$resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot)
$resolvedFixRoot = [System.IO.Path]::GetFullPath($fixRoot)

if (-not $resolvedFixRoot.StartsWith(
    $resolvedBuildRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to clean fix directory outside build: $resolvedFixRoot"
}

foreach ($required in @($sourcePluginPath, $xeditPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required wizard-guide patch input not found: $required"
    }
}

if (Test-Path -LiteralPath $fixRoot) {
    Remove-Item -LiteralPath $fixRoot -Recurse -Force
}
if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
    Remove-Item -LiteralPath $statusPath -Force
}
if (Test-Path -LiteralPath $errorPath -PathType Leaf) {
    Remove-Item -LiteralPath $errorPath -Force
}

New-Item -ItemType Directory -Force -Path $stagingData | Out-Null
New-Item -ItemType Directory -Force -Path $beforeRoot | Out-Null

foreach ($master in @("Skyrim.esm", "Update.esm")) {
    $masterPath = Join-Path $LoreRimRoot "Stock Game\Data\$master"
    if (-not (Test-Path -LiteralPath $masterPath -PathType Leaf)) {
        throw "Required Skyrim master not found: $masterPath"
    }
    Copy-Item -LiteralPath $masterPath `
        -Destination (Join-Path $stagingData $master) -Force
}

$stagedPlugin = Join-Path $stagingData "DiegeticTravelWizardGuides.esp"
$beforePlugin = Join-Path $beforeRoot "DiegeticTravelWizardGuides.esp"
Copy-Item -LiteralPath $sourcePluginPath -Destination $stagedPlugin -Force
Copy-Item -LiteralPath $sourcePluginPath -Destination $beforePlugin -Force

[System.IO.File]::WriteAllText(
    $pluginsList,
    "*DiegeticTravelWizardGuides.esp`r`n",
    [System.Text.UTF8Encoding]::new($false)
)

$xeditArguments = @(
    "-sse",
    "-D:$stagingData",
    "-P:$pluginsList",
    "-R:$xeditLog",
    "-IKnowWhatImDoing",
    "-nobuildrefs",
    "-autoload",
    "-autoexit",
    "-script:$scriptPath"
)

$xeditProcess = Start-Process `
    -FilePath $xeditPath `
    -ArgumentList $xeditArguments `
    -WindowStyle Hidden `
    -PassThru

$deadline = [DateTime]::UtcNow.AddMinutes(2)
$terminalStatus = $null
while (-not $xeditProcess.HasExited -and [DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
        $terminalStatus = (Get-Content -LiteralPath $statusPath -Raw).Trim()
        if ($terminalStatus -in @("success", "failed")) {
            break
        }
    }
    Start-Sleep -Milliseconds 200
    $xeditProcess.Refresh()
}

if (
    $terminalStatus -in @("success", "failed") -and
    -not $xeditProcess.HasExited
) {
    $null = $xeditProcess.WaitForExit(15000)
    $xeditProcess.Refresh()
}

if (-not $xeditProcess.HasExited) {
    Stop-Process -Id $xeditProcess.Id -Force
    if (Test-Path -LiteralPath $errorPath -PathType Leaf) {
        $scriptError = (Get-Content -LiteralPath $errorPath -Raw).Trim()
        throw "xEdit wizard-guide patch failed: $scriptError"
    }
    throw (
        "xEdit did not finish automatically. The staged source and original " +
        "plugin were left unchanged."
    )
}
if ($xeditProcess.ExitCode -ne 0) {
    throw "xEdit wizard-guide patch failed with exit code $($xeditProcess.ExitCode)"
}
if ($terminalStatus -ne "success") {
    throw "xEdit wizard-guide patch did not report success. See: $xeditLog"
}
if (-not (Test-Path -LiteralPath $outputPlugin -PathType Leaf)) {
    throw "xEdit did not create the patched plugin: $outputPlugin"
}

$scriptFailure = Select-String -LiteralPath $xeditLog `
    -Pattern "Exception in unit|Aborted: Applying script|Error assigning to" `
    -Quiet
if ($scriptFailure) {
    throw "xEdit reported a wizard-guide patch failure. See: $xeditLog"
}

Copy-Item -LiteralPath $outputPlugin -Destination $workspacePlugin -Force

$deployed = $false
if ($Deploy) {
    $skyrimProcess = Get-Process -Name "SkyrimSE" -ErrorAction SilentlyContinue
    if ($skyrimProcess) {
        throw (
            "Refusing to deploy while SkyrimSE is running. The workspace " +
            "plugin was patched successfully and can be deployed after exit."
        )
    }
    $deployRoot = Split-Path -Parent $deployPluginPath
    if (-not (Test-Path -LiteralPath $deployRoot -PathType Container)) {
        throw "Wizard-guide deployment directory not found: $deployRoot"
    }
    Copy-Item -Path (Join-Path $workspaceModRoot "*") `
        -Destination $deployRoot -Recurse -Force
    $deployed = $true
}

$beforeHash = (Get-FileHash -LiteralPath $beforePlugin -Algorithm SHA256).Hash
$afterHash = (Get-FileHash -LiteralPath $outputPlugin -Algorithm SHA256).Hash

Write-Host (
    "Patched the College-centred wizard star: direct court-wizard routes, " +
    "a Phinis destination hub, and owned OnBegin travel responses."
)
Write-Host "Before SHA-256: $beforeHash"
Write-Host "After SHA-256:  $afterHash"
Write-Host "Workspace copy: $workspacePlugin"
if ($deployed) {
    Write-Host "LoreRim copy:   $deployRoot (complete module payload)"
} else {
    Write-Host "LoreRim copy:   not deployed (pass -Deploy when Skyrim is closed)"
}
