param(
    [string]$LoreRimRoot = "D:\Lorerim",
    [string]$Output = "build\Scripts"
)

$ErrorActionPreference = "Stop"

$compilerRoot = Join-Path $LoreRimRoot "mods\Project New Reign - Nemesis Unlimited Behavior Engine\Nemesis_Engine\Papyrus Compiler"
$compiler = Join-Path $compilerRoot "PapyrusCompiler.exe"
$flags = Join-Path $compilerRoot "scripts\TESV_Papyrus_Flags.flg"
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot "mod\Scripts\Source"
$stubs = Join-Path $projectRoot "tools\papyrus-stubs"
$outputPath = Join-Path $projectRoot $Output

if (-not (Test-Path -LiteralPath $compiler)) {
    throw "Papyrus compiler not found: $compiler"
}

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$parchmentSource = Join-Path $projectRoot "modules\parchment-picker\mod\Scripts\Source"
$imports = "$source;$parchmentSource;$stubs"
$scripts = Get-ChildItem -LiteralPath $source -File -Filter "DNT_*.psc" | Sort-Object Name

foreach ($script in $scripts) {
    Write-Host "Compiling $($script.Name)"
    & $compiler $script.FullName "-f=$flags" "-i=$imports" "-o=$outputPath"
    if ($LASTEXITCODE -ne 0) {
        throw "Papyrus compilation failed for $($script.Name)"
    }
}

Write-Host "Compiled $($scripts.Count) scripts to $outputPath"
