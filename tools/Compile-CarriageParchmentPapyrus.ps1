param(
    [string]$LoreRimRoot = "D:\Lorerim"
)

$ErrorActionPreference = "Stop"

$compilerRoot = Join-Path $LoreRimRoot `
    "mods\Project New Reign - Nemesis Unlimited Behavior Engine\Nemesis_Engine\Papyrus Compiler"
$compiler = Join-Path $compilerRoot "PapyrusCompiler.exe"
$flags = Join-Path $compilerRoot "scripts\TESV_Papyrus_Flags.flg"
$jcontainersSource = Join-Path $LoreRimRoot "mods\JContainers SE\scripts\source"
$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\carriage-parchment"
$source = Join-Path $moduleRoot "mod\Scripts\Source"
$coreSource = Join-Path $projectRoot "mod\Scripts\Source"
$parchmentSource = Join-Path $projectRoot `
    "modules\parchment-picker\mod\Scripts\Source"
$stubs = Join-Path $projectRoot "tools\papyrus-stubs"
$output = Join-Path $moduleRoot "mod\Scripts"

foreach ($requiredPath in @(
    $compiler,
    $flags,
    $jcontainersSource,
    $source,
    $coreSource,
    $parchmentSource,
    $stubs
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required carriage parchment Papyrus input not found: $requiredPath"
    }
}

New-Item -ItemType Directory -Force -Path $output | Out-Null
$imports = "$source;$coreSource;$parchmentSource;$stubs;$jcontainersSource"
$scripts = Get-ChildItem -LiteralPath $source -File `
    -Filter "DNT_CarriageParchment*.psc" | Sort-Object Name
if ($scripts.Count -ne 2) {
    throw "Expected exactly two carriage parchment scripts, found $($scripts.Count)."
}

foreach ($script in $scripts) {
    Write-Host "Compiling $($script.Name)"
    & $compiler $script.FullName "-f=$flags" "-i=$imports" "-o=$output"
    if ($LASTEXITCODE -ne 0) {
        throw "Papyrus compilation failed for $($script.Name)"
    }
}

Write-Host "Compiled $($scripts.Count) carriage parchment scripts to $output"
