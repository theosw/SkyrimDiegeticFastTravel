param(
    [string]$LoreRimRoot = "D:\Lorerim"
)

$ErrorActionPreference = "Stop"

$compilerRoot = Join-Path $LoreRimRoot `
    "mods\Project New Reign - Nemesis Unlimited Behavior Engine\Nemesis_Engine\Papyrus Compiler"
$compiler = Join-Path $compilerRoot "PapyrusCompiler.exe"
$flags = Join-Path $compilerRoot "scripts\TESV_Papyrus_Flags.flg"
$projectRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $projectRoot "modules\parchment-picker"
$source = Join-Path $moduleRoot "mod\Scripts\Source"
$wizardSource = Join-Path $projectRoot "modules\wizard-guides\mod\Scripts\Source"
$stubs = Join-Path $projectRoot "tools\papyrus-stubs"
$output = Join-Path $moduleRoot "mod\Scripts"

foreach ($requiredPath in @($compiler, $flags, $source, $wizardSource, $stubs)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required parchment-picker Papyrus input not found: $requiredPath"
    }
}

New-Item -ItemType Directory -Force -Path $output | Out-Null
$imports = "$source;$wizardSource;$stubs"
$scripts = Get-ChildItem -LiteralPath $source -File -Filter "DNT_*.psc" | Sort-Object Name
if ($scripts.Count -ne 4) {
    throw "Expected exactly four parchment-picker scripts, found $($scripts.Count)."
}

foreach ($script in $scripts) {
    $attempt = 1
    while ($true) {
        Write-Host "Compiling $($script.Name) (attempt $attempt of 3)"
        & $compiler $script.FullName "-f=$flags" "-i=$imports" "-o=$output"
        if ($LASTEXITCODE -eq 0) {
            break
        }
        if ($attempt -ge 3) {
            throw "Papyrus compilation failed for $($script.Name)"
        }
        # Windows Defender can briefly retain a newly emitted PEX while the
        # preceding script is scanned. A bounded retry keeps release builds
        # deterministic without deleting or replacing the last good output.
        Start-Sleep -Milliseconds 750
        $attempt += 1
    }
}

Write-Host "Compiled $($scripts.Count) parchment-picker scripts to $output"
