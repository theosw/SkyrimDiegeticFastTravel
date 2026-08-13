param()

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$scopePath = Join-Path $projectRoot "config\repository-scope.json"
if (-not (Test-Path -LiteralPath $scopePath -PathType Leaf)) {
    throw "Repository scope manifest not found: $scopePath"
}

$scope = Get-Content -LiteralPath $scopePath -Raw | ConvertFrom-Json
if ($scope.schema_version -ne 1) {
    throw "Unsupported repository scope schema: $($scope.schema_version)"
}

$maintainedSections = @(
    "release_modules",
    "release_entrypoints",
    "release_support_scripts",
    "release_support_inputs",
    "release_xedit_scripts",
    "tracked_runtime_seeds",
    "maintained_developer_tools",
    "retained_evidence_tools",
    "retained_test_harnesses"
)

$maintainedCount = 0
foreach ($sectionName in $maintainedSections) {
    $entries = @($scope.$sectionName)
    if ($entries.Count -eq 0) {
        throw "Repository scope section is empty: $sectionName"
    }

    $duplicates = @($entries | Group-Object | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) {
        throw "Duplicate paths in ${sectionName}: $($duplicates.Name -join ', ')"
    }

    foreach ($entry in $entries) {
        if ([IO.Path]::IsPathRooted($entry) -or $entry -match '(^|/|\\)\.\.(/|\\|$)') {
            throw "Repository scope path must be project-relative: $entry"
        }
        $resolved = Join-Path $projectRoot ($entry -replace '/', '\\')
        if (-not (Test-Path -LiteralPath $resolved)) {
            throw "Maintained repository path is missing ($sectionName): $entry"
        }
        $maintainedCount++
    }
}

foreach ($seed in @($scope.tracked_runtime_seeds)) {
    & git -C $projectRoot ls-files --error-unmatch -- $seed 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Runtime seed is not tracked by Git: $seed"
    }
}

$declaredToolRoots = @($maintainedSections | ForEach-Object {
    @($scope.$_) | Where-Object { $_ -like "tools/*" }
}) | ForEach-Object { $_.TrimEnd([char[]]@('/', '\')) }
$trackedTools = @(& git -C $projectRoot ls-files -- "tools")
if ($LASTEXITCODE -ne 0) {
    throw "Could not inventory tracked repository tooling"
}
$unclassifiedTools = @($trackedTools | Where-Object {
    $trackedPath = $_
    -not ($declaredToolRoots | Where-Object {
        $trackedPath -eq $_ -or $trackedPath.StartsWith("$_/", [StringComparison]::Ordinal)
    })
})
if ($unclassifiedTools.Count -gt 0) {
    throw "Tracked tools are outside the maintained scope: $($unclassifiedTools -join ', ')"
}

Write-Host "Repository scope audit passed."
Write-Host "Maintained paths: $maintainedCount"
Write-Host "Tracked runtime seeds: $(@($scope.tracked_runtime_seeds).Count)"
Write-Host "Classified tool files: $($trackedTools.Count)"
