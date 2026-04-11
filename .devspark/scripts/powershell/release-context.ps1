#!/usr/bin/env pwsh
# Release context gathering script
# Supports archiving development artifacts and generating release documentation

param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]]$Arguments,
    [switch]$Json,
    [switch]$DryRun
)

. (Join-Path $PSScriptRoot 'common.ps1')

# Multi-app support (T086)
if (-not (Get-Command Detect-DevSparkMode -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot/common.ps1"
}

# Parse arguments
$versionArg = ""
foreach ($arg in $Arguments) {
    if ($arg -match '^v?\d+\.\d+') {
        $versionArg = $arg -replace '^v', ''
    }
}

# Get repository context
$repoRoot = Get-RepoRoot
$specsDir = Join-Path $repoRoot ".documentation/specs"
$releasesDir = Join-Path $repoRoot ".documentation/releases"
$quickfixDir = Join-Path $repoRoot ".documentation/quickfixes"
$decisionsDir = Join-Path $repoRoot ".documentation/decisions"
$constitutionPath = Join-Path $repoRoot ".documentation/memory/constitution.md"

# Detect current version from package files
$currentVersion = "0.0.0"
$versionSource = "default"

$packageJson = Join-Path $repoRoot "package.json"
$pyprojectToml = Join-Path $repoRoot "pyproject.toml"
$cargoToml = Join-Path $repoRoot "Cargo.toml"

if (Test-Path $packageJson) {
    try {
        $pkg = Get-Content $packageJson -Raw | ConvertFrom-Json
        if ($pkg.version) {
            $currentVersion = $pkg.version
            $versionSource = "package.json"
        }
    } catch { }
}
elseif (Test-Path $pyprojectToml) {
    try {
        $content = Get-Content $pyprojectToml -Raw
        if ($content -match 'version\s*=\s*"([^"]+)"') {
            $currentVersion = $matches[1]
            $versionSource = "pyproject.toml"
        }
    } catch { }
}
elseif (Test-Path $cargoToml) {
    try {
        $content = Get-Content $cargoToml -Raw
        if ($content -match '^version\s*=\s*"([^"]+)"') {
            $currentVersion = $matches[1]
            $versionSource = "Cargo.toml"
        }
    } catch { }
}

# Get last release info from git tags
$lastTag = ""
$lastReleaseDate = ""
$commitsSince = 0

if (Test-HasGit) {
    try {
        $lastTag = git describe --tags --abbrev=0 2>$null
        if ($lastTag) {
            $lastReleaseDate = git log -1 --format=%ci $lastTag 2>$null
            $commitsSince = [int](git rev-list "$lastTag..HEAD" --count 2>$null)
        }
        else {
            $commitsSince = [int](git rev-list HEAD --count 2>$null)
        }
    } catch {
        $lastTag = ""
    }
}

# Find completed and pending specs
$completedSpecs = @()
$pendingSpecs = @()

if (Test-Path $specsDir) {
    Get-ChildItem -Path $specsDir -Directory | ForEach-Object {
        $specName = $_.Name
        # Skip pr-review directory
        if ($specName -eq "pr-review") { return }

        $tasksFile = Join-Path $_.FullName "tasks.md"
        $specFile = Join-Path $_.FullName "spec.md"

        if (Test-Path $tasksFile) {
            $content = Get-Content $tasksFile -Raw -ErrorAction SilentlyContinue
            $unchecked = ([regex]::Matches($content, '^\s*- \[ \]', 'Multiline')).Count
            $checked = ([regex]::Matches($content, '^\s*- \[[xX]\]', 'Multiline')).Count

            if ($unchecked -eq 0 -and $checked -gt 0) {
                $completedSpecs += $specName
            }
            elseif (Test-Path $specFile) {
                $pendingSpecs += $specName
            }
        }
        elseif (Test-Path $specFile) {
            $pendingSpecs += $specName
        }
    }
}

# Find quickfixes
$quickfixes = @()
if (Test-Path $quickfixDir) {
    $quickfixes = Get-ChildItem -Path $quickfixDir -Filter "QF-*.md" -ErrorAction SilentlyContinue |
        ForEach-Object { $_.BaseName }
}

# Calculate next version if not provided
$nextVersion = $versionArg
$versionBump = "patch"

if (-not $nextVersion) {
    $versionParts = $currentVersion -split '\.'
    $major = [int]($versionParts[0] -replace '[^\d]', '')
    $minor = if ($versionParts.Length -gt 1) { [int]($versionParts[1] -replace '[^\d]', '') } else { 0 }
    $patch = if ($versionParts.Length -gt 2) { [int]($versionParts[2] -replace '[^\d]', '') } else { 0 }

    if ($completedSpecs.Count -gt 0) {
        $versionBump = "minor"
        $nextVersion = "$major.$($minor + 1).0"
    }
    elseif ($quickfixes.Count -gt 0) {
        $versionBump = "patch"
        $nextVersion = "$major.$minor.$($patch + 1)"
    }
    else {
        $versionBump = "patch"
        $nextVersion = "$major.$minor.$($patch + 1)"
    }
}

# Get contributors
$contributors = @()
if (Test-HasGit) {
    try {
        if ($lastTag) {
            $contributors = git log "$lastTag..HEAD" --format='%aN' 2>$null | Sort-Object -Unique
        }
        else {
            $contributors = git log --format='%aN' 2>$null | Sort-Object -Unique | Select-Object -First 20
        }
    } catch { }
}

# Get timestamp
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$releaseDate = Get-Date -Format "yyyy-MM-dd"

# DevSpark version stamp info
$versionStampPath = Join-Path $repoRoot ".devspark/VERSION"
$legacyVersionStampPath = Join-Path $repoRoot ".documentation/DEVSPARK_VERSION"
$installedVersion = ""
if (Test-Path $versionStampPath) {
    try {
        $installedVersion = ((Get-Content $versionStampPath -ErrorAction SilentlyContinue) | Select-String '^version:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
    } catch { }
} elseif (Test-Path $legacyVersionStampPath) {
    try {
        $installedVersion = (Get-Content $legacyVersionStampPath -TotalCount 1 -ErrorAction SilentlyContinue).Trim()
    } catch { }
}

# Output
if ($Json) {
    @{
        REPO_ROOT              = $repoRoot
        SPECS_DIR              = $specsDir
        RELEASES_DIR           = $releasesDir
        QUICKFIX_DIR           = $quickfixDir
        DECISIONS_DIR          = $decisionsDir
        CONSTITUTION_PATH      = $constitutionPath
        CURRENT_VERSION        = $currentVersion
        VERSION_SOURCE         = $versionSource
        NEXT_VERSION           = $nextVersion
        VERSION_BUMP           = $versionBump
        COMPLETED_SPECS        = $completedSpecs
        PENDING_SPECS          = $pendingSpecs
        QUICKFIXES             = $quickfixes
        LAST_TAG               = $lastTag
        LAST_RELEASE_DATE      = $lastReleaseDate
        COMMITS_SINCE_RELEASE  = $commitsSince
        CONTRIBUTORS           = $contributors
        TIMESTAMP              = $timestamp
        RELEASE_DATE           = $releaseDate
        DRY_RUN                = [bool]$DryRun
        DEVSPARK_VERSION_PATH   = $versionStampPath
        LEGACY_DEVSPARK_VERSION_PATH = $legacyVersionStampPath
        INSTALLED_VERSION      = $installedVersion
    } | ConvertTo-Json
}
else {
    Write-Output "Release Context"
    Write-Output "==============="
    Write-Output "Repository: $repoRoot"
    Write-Output "Current Version: $currentVersion (from $versionSource)"
    Write-Output "Next Version: $nextVersion ($versionBump bump)"
    Write-Output "Last Release: $lastTag ($lastReleaseDate)"
    Write-Output "Commits Since: $commitsSince"
    Write-Output ""
    Write-Output "Completed Specs: $($completedSpecs.Count)"
    Write-Output "Pending Specs: $($pendingSpecs.Count)"
    Write-Output "Quickfixes: $($quickfixes.Count)"
    Write-Output "Contributors: $($contributors.Count)"
    Write-Output ""
    if ($installedVersion) {
        Write-Output "Installed DevSpark Version: $installedVersion"
    } else {
        Write-Output "Installed DevSpark Version: (VERSION stamp not found)"
    }
    if ($DryRun) {
        Write-Output ""
        Write-Output "** DRY RUN MODE - No changes will be made **"
    }
}
