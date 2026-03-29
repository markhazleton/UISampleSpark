#!/usr/bin/env pwsh
# Build repository history context for /speckit.repo-story
# Usage:
#   .\repo-story-context.ps1 [-Output <path>] [-Months 12] [-Scope full] [-CompareBaseline YYYY-MM] [-Stdout]

[CmdletBinding()]
param(
    [string]$Output = ".documentation/repo-story/history.json",
    [int]$Months = 12,
    [ValidateSet("full", "velocity", "quality", "business", "team")]
    [string]$Scope = "full",
    [string]$CompareBaseline = "",
    [switch]$Stdout,
    [switch]$Help
)

if ($Help) {
    Write-Output @"
Usage: repo-story-context.ps1 [-Output <path>] [-Months 12] [-Scope full] [-CompareBaseline YYYY-MM] [-Stdout]

Generates a history.json file with full-repository historical context:
- commit timeline
- contributor trends
- tag milestones
- README evolution
- file change hotspots
- commit-audit metrics (velocity, quality, governance)

Options:
    -Output <path>           Output JSON path (default: .documentation/repo-story/history.json)
    -Months <N>              Audit window in months from now (default: 12)
    -Scope <name>            full | velocity | quality | business | team
    -CompareBaseline YYYY-MM Optional baseline month override
    -Stdout                  Also print generated JSON to stdout
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

if ($Months -lt 1) {
        Write-Error "Months must be >= 1"
        exit 1
}

function Invoke-Git {
    param([string[]]$GitCommand)
    $result = & git @GitCommand 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "git command failed: git $($GitCommand -join ' ')"
    }
    if ($null -eq $result) {
        return ""
    }
    if ($result -is [System.Array]) {
        return (($result | ForEach-Object { $_.ToString() }) -join "`n").Trim()
    }
    return $result.ToString().Trim()
}

function Invoke-GitSafe {
    param([string[]]$GitCommand)
    try {
        $result = & git @GitCommand 2>$null
        if ($LASTEXITCODE -ne 0) {
            return ""
        }
        if ($null -eq $result) {
            return ""
        }
        if ($result -is [System.Array]) {
            return (($result | ForEach-Object { $_.ToString() }) -join "`n").Trim()
        }
        return $result.ToString().Trim()
    } catch {
        return ""
    }
}

if (-not (Invoke-GitSafe @("rev-parse", "--show-toplevel"))) {
    Write-Error "Not inside a git repository."
    exit 1
}

$repoRoot = Invoke-Git @("rev-parse", "--show-toplevel")
Set-Location $repoRoot

$auditEnd = Get-Date
$auditStart = $auditEnd.AddMonths(-$Months)
$sinceDate = $auditStart.ToString("yyyy-MM-dd")
$auditStartMonth = $auditStart.ToString("yyyy-MM")
$auditEndMonth = $auditEnd.ToString("yyyy-MM")
$baselineMonth = if ($CompareBaseline) { $CompareBaseline } else { $auditStartMonth }

$sinceArgs = @("--since=$sinceDate")

$firstCommitRaw = Invoke-Git @("rev-list", "--max-parents=0", "HEAD")
$firstCommitSha = @($firstCommitRaw -split "`r?`n" | Where-Object { $_ -and $_.ToString().Trim() -ne "" } | Select-Object -Last 1)[0].ToString().Trim()
$lastCommitSha = Invoke-Git @("rev-parse", "HEAD")

$defaultBranch = Invoke-GitSafe @("symbolic-ref", "refs/remotes/origin/HEAD")
if ($defaultBranch) {
    $defaultBranch = $defaultBranch -replace '^refs/remotes/origin/', ''
} else {
    if (Invoke-GitSafe @("show-ref", "--verify", "refs/heads/main")) {
        $defaultBranch = "main"
    } elseif (Invoke-GitSafe @("show-ref", "--verify", "refs/heads/master")) {
        $defaultBranch = "master"
    } else {
        $defaultBranch = Invoke-Git @("rev-parse", "--abbrev-ref", "HEAD")
    }
}

$totalCommits = [int](Invoke-Git @("rev-list", "--count", "--all"))
$totalCommitsInWindow = [int](Invoke-Git @("rev-list", "--count", "--all", "--since=$sinceDate"))
$totalTags = [int]((Invoke-GitSafe @("tag", "--list") -split "`n" | Where-Object { $_ -ne "" }).Count)
$remoteOrigin = Invoke-GitSafe @("config", "--get", "remote.origin.url")

$contributorEmailCounts = @{}
$emailToName = @{}
$emailStream = Invoke-GitSafe @("log", "--all", "--since=$sinceDate", "--format=%ae%x09%an")
if ($emailStream) {
    foreach ($line in ($emailStream -split "`n")) {
        $parts = $line -split "`t", 2
        if ($parts.Count -lt 2) { continue }
        $email = $parts[0].Trim().ToLowerInvariant()
        $name = $parts[1].Trim()
        if (-not $email) { continue }
        if (-not $contributorEmailCounts.ContainsKey($email)) { $contributorEmailCounts[$email] = 0 }
        $contributorEmailCounts[$email] += 1
        if (-not $emailToName.ContainsKey($email)) { $emailToName[$email] = $name }
    }
}

$sortedContributors = $contributorEmailCounts.GetEnumerator() | Sort-Object -Property Value -Descending
$roleByEmail = @{}
$anonymizedContributors = @()
$developerIndex = 0
foreach ($entry in $sortedContributors) {
    $role = ""
    if ($developerIndex -eq 0) {
        $role = "Lead Architect"
    } else {
        $suffix = [char]([int][char]'A' + ($developerIndex - 1))
        $role = "Developer $suffix"
    }
    $developerIndex += 1
    $email = $entry.Key
    $roleByEmail[$email] = $role
    $anonymizedContributors += [PSCustomObject]@{
        role = $role
        commits = [int]$entry.Value
    }
}
$totalContributors = $anonymizedContributors.Count

function Get-RoleId {
    param([string]$Email)
    $k = $Email.Trim().ToLowerInvariant()
    if ($roleByEmail.ContainsKey($k)) {
        return $roleByEmail[$k]
    }
    return "External Contributor"
}

$years = @{}
$yearLines = Invoke-GitSafe @("log", "--all", "--since=$sinceDate", "--date=format:%Y", "--format=%ad")
if ($yearLines) {
    foreach ($line in ($yearLines -split "`n")) {
        $k = $line.Trim()
        if ($k) {
            if (-not $years.ContainsKey($k)) { $years[$k] = 0 }
            $years[$k] += 1
        }
    }
}

$commitsByMonth = @{}
$monthLines = Invoke-GitSafe @("log", "--all", "--since=$sinceDate", "--date=format:%Y-%m", "--format=%ad")
if ($monthLines) {
    foreach ($line in ($monthLines -split "`n")) {
        $k = $line.Trim()
        if ($k) {
            if (-not $commitsByMonth.ContainsKey($k)) { $commitsByMonth[$k] = 0 }
            $commitsByMonth[$k] += 1
        }
    }
}

$readmeCommits = @()
if (Test-Path (Join-Path $repoRoot "README.md")) {
    $readmeRaw = Invoke-GitSafe @("log", "--all", "--since=$sinceDate", "--follow", "--date=iso-strict", "--pretty=format:%H%x09%ad%x09%ae%x09%s", "--", "README.md")
    if ($readmeRaw) {
        foreach ($line in ($readmeRaw -split "`n")) {
            $parts = $line -split "`t", 4
            if ($parts.Count -ge 4) {
                $readmeCommits += [PSCustomObject]@{
                    sha = $parts[0]
                    date = $parts[1]
                    role = (Get-RoleId -Email $parts[2])
                    subject = $parts[3]
                }
            }
        }
    }
}

$hotspotMap = @{}
$hotspotRaw = Invoke-GitSafe @("log", "--all", "--since=$sinceDate", "--name-only", "--pretty=format:")
if ($hotspotRaw) {
    foreach ($line in ($hotspotRaw -split "`n")) {
        $k = $line.Trim()
        if ($k) {
            if (-not $hotspotMap.ContainsKey($k)) { $hotspotMap[$k] = 0 }
            $hotspotMap[$k] += 1
        }
    }
}
$hotspots = $hotspotMap.GetEnumerator() |
    Sort-Object -Property Value -Descending |
    Select-Object -First 50 |
    ForEach-Object {
        [PSCustomObject]@{ path = $_.Key; changes = [int]$_.Value }
    }

$tags = @()
$tagRaw = Invoke-GitSafe @("for-each-ref", "refs/tags", "--sort=creatordate", "--format=%(refname:short)%x09%(creatordate:iso-strict)%x09%(objectname:short)")
if ($tagRaw) {
    foreach ($line in ($tagRaw -split "`n")) {
        $parts = $line -split "`t", 3
        if ($parts.Count -ge 3) {
            $tags += [PSCustomObject]@{
                tag = $parts[0]
                date = $parts[1]
                sha = $parts[2]
            }
        }
    }
}

$subjectTypes = @{
    features = 0
    fixes = 0
    docs = 0
    refactor = 0
    tests = 0
    ci_build = 0
    chore = 0
    other = 0
}
$subjectRaw = Invoke-GitSafe @("log", "--all", "--since=$sinceDate", "--pretty=format:%s")
if ($subjectRaw) {
    foreach ($s in ($subjectRaw -split "`n")) {
        $t = $s.ToLowerInvariant()
        if ($t -match 'feat|feature|^add\s|introduce') { $subjectTypes.features++ }
        elseif ($t -match 'fix|bug|hotfix|patch') { $subjectTypes.fixes++ }
        elseif ($t -match 'doc|readme|guide|wiki') { $subjectTypes.docs++ }
        elseif ($t -match 'refactor|restructure|cleanup') { $subjectTypes.refactor++ }
        elseif ($t -match 'test|spec|coverage') { $subjectTypes.tests++ }
        elseif ($t -match 'ci|build|workflow|pipeline') { $subjectTypes.ci_build++ }
        elseif ($t -match 'chore|deps|bump|upgrade') { $subjectTypes.chore++ }
        else { $subjectTypes.other++ }
    }
}

# Commit message quality metrics aligned to audit prompt.
$conventionalCommitCount = 0
$informalCommitCount = 0
$specReferenceCount = 0
if ($subjectRaw) {
    foreach ($s in ($subjectRaw -split "`n")) {
        if ($s -match '^(feat|fix|refactor|perf|test|docs|chore|ci|build)(\([^\)]*\))?:\s.+$') {
            $conventionalCommitCount++
        }
        if ($s.ToLowerInvariant() -match '^(bug fix|fix|testing|cleanup|checkpoint|update|wip|temp|minor|misc)$') {
            $informalCommitCount++
        }
        if ($s.ToLowerInvariant() -match '(spec|feature)\s+[0-9]|docs/specs/[0-9]') {
            $specReferenceCount++
        }
    }
}

$mergedPrCount = 0
$mergeSubjects = Invoke-GitSafe @("log", "--all", "--since=$sinceDate", "--oneline")
if ($mergeSubjects) {
    foreach ($line in ($mergeSubjects -split "`n")) {
        if ($line -match 'Merged PR|Merge pull request') {
            $mergedPrCount++
        }
    }
}

$fileTypeCounts = @{}
if ($hotspotRaw) {
    foreach ($line in ($hotspotRaw -split "`n")) {
        $path = $line.Trim()
        if (-not $path) { continue }
        $ext = [System.IO.Path]::GetExtension($path)
        if ([string]::IsNullOrWhiteSpace($ext)) {
            $ext = "(no-ext)"
        } else {
            $ext = $ext.TrimStart('.').ToLowerInvariant()
        }
        if (-not $fileTypeCounts.ContainsKey($ext)) { $fileTypeCounts[$ext] = 0 }
        $fileTypeCounts[$ext] += 1
    }
}
$fileTypesTop = $fileTypeCounts.GetEnumerator() |
    Sort-Object -Property Value -Descending |
    Select-Object -First 20 |
    ForEach-Object {
        [PSCustomObject]@{ extension = $_.Key; touched_files = [int]$_.Value }
    }

$roleMonthlyMap = @{}
$roleMonthRaw = Invoke-GitSafe @("log", "--all", "--since=$sinceDate", "--date=format:%Y-%m", "--format=%ae%x09%ad")
if ($roleMonthRaw) {
    foreach ($line in ($roleMonthRaw -split "`n")) {
        $parts = $line -split "`t", 2
        if ($parts.Count -lt 2) { continue }
        $role = Get-RoleId -Email $parts[0]
        $month = $parts[1].Trim()
        if (-not $roleMonthlyMap.ContainsKey($month)) {
            $roleMonthlyMap[$month] = @{}
        }
        if (-not $roleMonthlyMap[$month].ContainsKey($role)) {
            $roleMonthlyMap[$month][$role] = 0
        }
        $roleMonthlyMap[$month][$role] += 1
    }
}

$largestMerges = @()
$mergeRaw = Invoke-GitSafe @("log", "--all", "--since=$sinceDate", "--merges", "--format=%H%x09%s")
if ($mergeRaw) {
    $mergeCandidates = @($mergeRaw -split "`n" | Where-Object { $_ -ne "" } | Select-Object -First 40)
    foreach ($candidate in $mergeCandidates) {
        $parts = $candidate -split "`t", 2
        if ($parts.Count -lt 2) { continue }
        $sha = $parts[0]
        $subject = $parts[1]
        $numstat = Invoke-GitSafe @("show", "--numstat", "--format=", $sha)
        $filesChanged = 0
        $additions = 0
        $deletions = 0
        if ($numstat) {
            foreach ($l in ($numstat -split "`n")) {
                $cols = $l -split "`t"
                if ($cols.Count -lt 3) { continue }
                $filesChanged++
                if ($cols[0] -match '^\d+$') { $additions += [int]$cols[0] }
                if ($cols[1] -match '^\d+$') { $deletions += [int]$cols[1] }
            }
        }
        $largestMerges += [PSCustomObject]@{
            sha = $sha
            subject = $subject
            files_changed = $filesChanged
            additions = $additions
            deletions = $deletions
            total_lines = ($additions + $deletions)
        }
    }
    $largestMerges = @($largestMerges | Sort-Object -Property total_lines -Descending | Select-Object -First 10)
}

$testFileCount = 0
$testPatterns = @("*.test.*", "*.spec.*", "test*.py")
try {
    $testFileCount = @(Get-ChildItem -Path $repoRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -match '(\\|/)test' -or
            $_.Name -like '*.test.*' -or
            $_.Name -like '*.spec.*' -or
            $_.Name -like 'test*.py'
        }).Count
} catch {
    $testFileCount = 0
}

$testRelatedCommitCount = 0
if ($subjectRaw) {
    foreach ($s in ($subjectRaw -split "`n")) {
        if ($s.ToLowerInvariant() -match 'test|spec|coverage') {
            $testRelatedCommitCount++
        }
    }
}

$governancePath = ""
if (Test-Path (Join-Path $repoRoot ".documentation/memory/constitution.md")) {
    $governancePath = Join-Path $repoRoot ".documentation/memory/constitution.md"
} elseif (Test-Path (Join-Path $repoRoot ".specify/memory/constitution.md")) {
    $governancePath = Join-Path $repoRoot ".specify/memory/constitution.md"
}

$constitutionVersion = ""
$constitutionAmendmentCount = 0
if ($governancePath) {
    $constitutionText = Get-Content -Path $governancePath -Raw -ErrorAction SilentlyContinue
    if ($constitutionText -match '(?im)^.*version.*[:\-]\s*([^\r\n]+)$') {
        $constitutionVersion = $matches[1].Trim()
    }
    $constitutionAmendmentCount = ([regex]::Matches($constitutionText, '(?im)^##\s+amendment\b|CAP-\d{4}-\d{3}')).Count
}

$specDirs = @(Get-ChildItem -Path (Join-Path $repoRoot ".documentation/specs") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "pr-review" })
$archivedSpecs = @(Get-ChildItem -Path (Join-Path $repoRoot ".archive") -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '(\\|/)specs(\\|/)' })
$governanceArtifactsCount = @(Get-ChildItem -Path (Join-Path $repoRoot ".documentation") -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'audit|harvest|pr-review|constitution-history' }).Count

$recent = @()
$recentRaw = Invoke-GitSafe @("log", "--all", "--since=$sinceDate", "-n", "40", "--date=iso-strict", "--pretty=format:%H%x09%ad%x09%ae%x09%s")
if ($recentRaw) {
    foreach ($line in ($recentRaw -split "`n")) {
        $parts = $line -split "`t", 4
        if ($parts.Count -ge 4) {
            $recent += [PSCustomObject]@{
                sha = $parts[0]
                date = $parts[1]
                role = (Get-RoleId -Email $parts[2])
                subject = $parts[3]
            }
        }
    }
}

function Get-CommitMeta {
    param([string]$Sha)
    $line = Invoke-Git @("show", "-s", "--date=iso-strict", "--format=%H%x09%ad%x09%ae%x09%s", $Sha)
    $parts = $line -split "`t", 4
    return [PSCustomObject]@{
        sha = $parts[0]
        date = $parts[1]
        role = (Get-RoleId -Email $parts[2])
        subject = if ($parts.Count -ge 4) { $parts[3] } else { "" }
    }
}

$firstCommit = Get-CommitMeta -Sha $firstCommitSha
$latestCommit = Get-CommitMeta -Sha $lastCommitSha

$historySpanDays = $null
try {
    $start = [DateTimeOffset]::Parse($firstCommit.date)
    $end = [DateTimeOffset]::Parse($latestCommit.date)
    $historySpanDays = [Math]::Max(0, ($end - $start).Days)
} catch { }

$languagePresence = [PSCustomObject]@{
    python = [bool](Get-ChildItem -Path $repoRoot -Recurse -Filter *.py -ErrorAction SilentlyContinue | Select-Object -First 1)
    javascript = [bool](Get-ChildItem -Path $repoRoot -Recurse -Filter *.js -ErrorAction SilentlyContinue | Select-Object -First 1)
    typescript = [bool](Get-ChildItem -Path $repoRoot -Recurse -Filter *.ts -ErrorAction SilentlyContinue | Select-Object -First 1)
    powershell = [bool](Get-ChildItem -Path $repoRoot -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue | Select-Object -First 1)
    shell = [bool](Get-ChildItem -Path $repoRoot -Recurse -Filter *.sh -ErrorAction SilentlyContinue | Select-Object -First 1)
    markdown = [bool](Get-ChildItem -Path $repoRoot -Recurse -Filter *.md -ErrorAction SilentlyContinue | Select-Object -First 1)
}

$history = [PSCustomObject]@{
    generated_at = [DateTimeOffset]::UtcNow.ToString("o")
    audit_parameters = [PSCustomObject]@{
        months = $Months
        scope = $Scope
        compare_baseline = $baselineMonth
        since_date = $sinceDate
        start_month = $auditStartMonth
        end_month = $auditEndMonth
    }
    repo = [PSCustomObject]@{
        name = (Split-Path $repoRoot -Leaf)
        root = $repoRoot
        remote_origin = $remoteOrigin
        default_branch = $defaultBranch
    }
    summary = [PSCustomObject]@{
        total_commits = $totalCommits
        total_commits_in_window = $totalCommitsInWindow
        total_contributors = $totalContributors
        total_tags = $totalTags
        history_span_days = $historySpanDays
    }
    timeline = [PSCustomObject]@{
        first_commit = $firstCommit
        latest_commit = $latestCommit
        commits_by_year = $years
        commits_by_month = $commitsByMonth
    }
    contributors = [PSCustomObject]@{
        top = @($anonymizedContributors | Select-Object -First 25)
        all_count = $totalContributors
        monthly_by_role = $roleMonthlyMap
    }
    contributor_census = [PSCustomObject]@{
        role_assignments = @($anonymizedContributors)
    }
    volume_metrics = [PSCustomObject]@{
        total_commits = $totalCommitsInWindow
        monthly_commit_distribution = $commitsByMonth
        merged_pr_count = $mergedPrCount
        file_types_top = @($fileTypesTop)
        largest_merges = @($largestMerges)
    }
    commit_message_metrics = [PSCustomObject]@{
        conventional_commit_count = $conventionalCommitCount
        informal_commit_count = $informalCommitCount
        spec_reference_commit_count = $specReferenceCount
    }
    test_metrics = [PSCustomObject]@{
        test_file_count = $testFileCount
        test_related_commit_count = $testRelatedCommitCount
    }
    governance_maturity = [PSCustomObject]@{
        constitution_path = $governancePath
        constitution_exists = [bool]$governancePath
        constitution_version = $constitutionVersion
        constitution_amendment_count = $constitutionAmendmentCount
        active_spec_count = $specDirs.Count
        archived_spec_directory_count = $archivedSpecs.Count
        governance_artifact_count = $governanceArtifactsCount
    }
    milestones = [PSCustomObject]@{
        tags = @($tags)
        readme_evolution = [PSCustomObject]@{
            total_readme_commits = $readmeCommits.Count
            commits = @($readmeCommits | Select-Object -First 200)
        }
    }
    change_patterns = [PSCustomObject]@{
        subject_type_estimates = [PSCustomObject]$subjectTypes
        hotspots = @($hotspots)
    }
    technical_signals = [PSCustomObject]@{
        language_presence = $languagePresence
        has_pyproject_toml = (Test-Path (Join-Path $repoRoot "pyproject.toml"))
        has_package_json = (Test-Path (Join-Path $repoRoot "package.json"))
        has_dockerfile = [bool](Get-ChildItem -Path $repoRoot -Recurse -Filter "Dockerfile*" -ErrorAction SilentlyContinue | Select-Object -First 1)
        has_github_actions = (Test-Path (Join-Path $repoRoot ".github/workflows"))
    }
    recent = [PSCustomObject]@{
        commits = @($recent)
    }
}

$outputPath = if ([System.IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $repoRoot $Output }
$outputDir = Split-Path $outputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$json = $history | ConvertTo-Json -Depth 10
Set-Content -Path $outputPath -Value $json -Encoding utf8

if ($Stdout) {
    Write-Output $json
}

Write-Output "history.json written to: $outputPath"
