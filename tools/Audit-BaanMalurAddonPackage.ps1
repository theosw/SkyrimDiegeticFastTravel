param(
    [string]$PackageRoot = "build\DiegeticTravel-BaanMalur-Addon"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [IO.Path]::IsPathRooted($PackageRoot)) {
    $PackageRoot = Join-Path $projectRoot $PackageRoot
}
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    throw "Baan Malur add-on package root not found: $PackageRoot"
}

$expectedFiles = @(
    "DiegeticTravelBoatBaanMalur.esp",
    "README-BoatBaanMalur.txt",
    "SEQ\DiegeticTravelBoatBaanMalur.seq",
    "Scripts\DNT_BaanMalurBoatParchmentFragment.pex",
    "Scripts\DNT_BaanMalurBoatParchmentPicker.pex",
    "Scripts\DNT_BaanMalurBoatTravelService.pex",
    "Scripts\Source\DNT_BaanMalurBoatParchmentFragment.psc",
    "Scripts\Source\DNT_BaanMalurBoatParchmentPicker.psc",
    "Scripts\Source\DNT_BaanMalurBoatTravelService.psc"
)

$actualFiles = @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File |
    ForEach-Object {
        $_.FullName.Substring($PackageRoot.Length).TrimStart('\')
    } |
    Sort-Object)
$missing = @($expectedFiles | Where-Object { $_ -notin $actualFiles })
$unexpected = @($actualFiles | Where-Object { $_ -notin $expectedFiles })
if ($missing.Count -gt 0) {
    throw "Baan Malur add-on package is missing: $($missing -join ', ')"
}
if ($unexpected.Count -gt 0) {
    throw "Baan Malur add-on package contains unexpected files: $($unexpected -join ', ')"
}

$seqPath = Join-Path $PackageRoot "SEQ\DiegeticTravelBoatBaanMalur.seq"
if ((Get-Item -LiteralPath $seqPath).Length -ne 4) {
    throw "Baan Malur add-on SEQ must contain exactly one 4-byte FormID."
}

$pluginPath = Join-Path $PackageRoot "DiegeticTravelBoatBaanMalur.esp"
$pluginAscii = [Text.Encoding]::ASCII.GetString(
    [IO.File]::ReadAllBytes($pluginPath)
)
foreach ($requiredRecord in @(
    "DNT_ShowBaanMalurNativeDialogue",
    "DNT_BaanMalurBoatProviders"
)) {
    if (-not $pluginAscii.Contains($requiredRecord)) {
        throw "Baan Malur add-on is missing compatibility record: $requiredRecord"
    }
}

$readmePath = Join-Path $PackageRoot "README-BoatBaanMalur.txt"
$readme = Get-Content -LiteralPath $readmePath -Raw
if ($readme -notmatch [regex]::Escape(
    "set DNT_ShowBaanMalurNativeDialogue to 1"
)) {
    throw "Baan Malur README does not document the native-dialogue diagnostic gate."
}

$forbiddenExtensions = @(
    ".dll", ".pdb", ".dds", ".png", ".jpg", ".jpeg", ".svg",
    ".wav", ".xwm", ".fuz"
)
$forbidden = @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File |
    Where-Object { $forbiddenExtensions -contains $_.Extension.ToLowerInvariant() })
if ($forbidden.Count -gt 0) {
    throw "Baan Malur add-on must not bundle runtime binaries or external art/audio: $($forbidden.FullName -join ', ')"
}

Write-Host "Baan Malur add-on package audit passed."
Write-Host "Files: $($actualFiles.Count)"
Write-Host "Plugin: 1 ESP-FE candidate (semantic ESL audit runs before packaging)"
Write-Host "Native dialogue: provider-scoped gate present and documented"
Write-Host "External artwork/audio bundled: 0"
