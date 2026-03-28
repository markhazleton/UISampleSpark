#!/usr/bin/env pwsh
#requires -Version 7.0
<#
.SYNOPSIS
    Sync Spec Kit Spark with upstream github.com/github/spec-kit repository

.DESCRIPTION
    This script helps maintain the Spec Kit Spark fork by:
    - Fetching latest upstream changes
    - Categorizing commits by decision criteria
    - Auto-applying safe bug fixes (with --auto flag)
    - Creating integration plans for commits needing evaluation (interactive mode)
    - Generating reports for manual review
    - Updating FORK_DIVERGENCE.md with applied changes

.PARAMETER Mode
    Operation mode:
    - review: Show categorized commits (default)
    - interactive: Review each commit with detailed implications and prompt for action
                   Actions: Apply, Skip, Plan (create integration evaluation), Defer
    - auto: Auto-apply safe cherry-picks
    - report: Generate detailed report only
    - update-doc: Update FORK_DIVERGENCE.md with current status

.PARAMETER Since
    Git ref to compare from (default: finds last sync point)

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\sync-upstream.ps1 -Mode review
    Review new upstream commits categorized by decision criteria

.EXAMPLE
    .\sync-upstream.ps1 -Mode interactive
    Interactively review each commit with detailed implications and choose actions

.EXAMPLE
    .\sync-upstream.ps1 -Mode auto
    Automatically apply safe bug fixes and security patches

.EXAMPLE
    .\sync-upstream.ps1 -Mode report > sync-report.md
    Generate detailed markdown report
#>

param(
    [Parameter()]
    [ValidateSet('review', 'interactive', 'auto', 'report', 'update-doc')]
    [string]$Mode = 'review',

    [Parameter()]
    [string]$Since = '',

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Color helpers
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Header { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Magenta }

# Find repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Error "Must be run from within a git repository"
    exit 1
}

$divergenceDoc = Join-Path $repoRoot "FORK_DIVERGENCE.md"

# Decision criteria patterns (regex)
$autoPatterns = @(
    'fix:.*dependency',
    'fix:.*version',
    'fix:.*typo',
    'fix:.*path.*error',
    'security:',
    'fix:.*cli',
    'fix:.*preserve constitution'
)

$adaptPatterns = @(
    'refactor:.*template',
    'docs:.*readme',
    'refactor:.*bias',
    'fix:.*markdown',
    'feat:.*template',
    'docs:.*'
)

$ignorePatterns = @(
    'chore\(deps\):.*bump',
    'chore:.*version',
    'workflow:',
    'ci:.*workflow',
    'Add.*agent:.*',
    'stale.*workflow'
)

$evaluatePatterns = @(
    'extension.*system',
    'generic.*agent',
    'ai.*skills',
    'plugin',
    'modular'
)

function Get-CommitCategory {
    param([string]$CommitMessage)
    
    $lowerMsg = $CommitMessage.ToLower()
    
    if ($autoPatterns | Where-Object { $lowerMsg -match $_ }) {
        return 'AUTO'
    } elseif ($adaptPatterns | Where-Object { $lowerMsg -match $_ }) {
        return 'ADAPT'
    } elseif ($ignorePatterns | Where-Object { $lowerMsg -match $_ }) {
        return 'IGNORE'
    } elseif ($evaluatePatterns | Where-Object { $lowerMsg -match $_ }) {
        return 'EVALUATE'
    } else {
        return 'REVIEW'  # Needs manual categorization
    }
}

function Get-LastSyncPoint {
    # Try to find base divergence point from FORK_DIVERGENCE.md
    if (Test-Path $divergenceDoc) {
        $content = Get-Content $divergenceDoc -Raw
        if ($content -match 'Upstream Commit.*?`([a-f0-9]+)`') {
            return $Matches[1]
        }
    }
    # Fallback: find merge base
    return (git merge-base main upstream/main)
}

function Get-UpstreamCommits {
    param([string]$Since)
    
    $commits = @()
    $gitLog = git log --oneline --no-merges "${Since}..upstream/main"
    
    foreach ($line in $gitLog) {
        if ($line -match '^([a-f0-9]+)\s+(.+)$') {
            $commits += @{
                Hash = $Matches[1]
                Message = $Matches[2]
                Category = Get-CommitCategory $Matches[2]
            }
        }
    }
    
    return $commits
}

function Show-CommitsByCategory {
    param([array]$Commits)
    
    $byCategory = $Commits | Group-Object Category
    
    Write-Header "Upstream Commits by Category"
    
    foreach ($group in $byCategory) {
        $icon = switch ($group.Name) {
            'AUTO' { '🟢' }
            'ADAPT' { '🟡' }
            'IGNORE' { '🔴' }
            'EVALUATE' { '🔵' }
            'REVIEW' { '⚪' }
        }
        
        Write-Host "`n$icon $($group.Name) ($($group.Count) commits)" -ForegroundColor Cyan
        
        foreach ($commit in $group.Group) {
            Write-Host "  $($commit.Hash) - $($commit.Message)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Info "Total: $($Commits.Count) new commits"
    Write-Info "Auto-applicable: $(($byCategory | Where-Object Name -eq 'AUTO').Count ?? 0)"
    Write-Info "Need adaptation: $(($byCategory | Where-Object Name -eq 'ADAPT').Count ?? 0)"
    Write-Info "For evaluation: $(($byCategory | Where-Object Name -eq 'EVALUATE').Count ?? 0)"
}

function Invoke-AutoApply {
    param([array]$Commits, [switch]$DryRun)
    
    $autoCommits = $Commits | Where-Object Category -eq 'AUTO'
    
    if (-not $autoCommits) {
        Write-Info "No auto-applicable commits found"
        return @{
            Applied = @()
            Failed = @()
        }
    }
    
    Write-Header "Auto-Applying Safe Cherry-Picks"
    Write-Info "Found $($autoCommits.Count) commits to apply"
    
    if ($DryRun) {
        Write-Warning "DRY RUN MODE - No changes will be made"
    }
    
    $results = @{
        Applied = @()
        Failed = @()
    }
    
    # Create a checkpoint branch
    $checkpointBranch = "sync-checkpoint-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (-not $DryRun) {
        git branch $checkpointBranch
        Write-Info "Created checkpoint branch: $checkpointBranch"
    }
    
    foreach ($commit in $autoCommits) {
        Write-Host "`nProcessing: $($commit.Hash) - $($commit.Message)"
        
        if ($DryRun) {
            Write-Info "Would cherry-pick: $($commit.Hash)"
            $results.Applied += $commit
            continue
        }
        
        try {
            # Attempt cherry-pick
            git cherry-pick $commit.Hash 2>&1 | Out-Null
            
            # Check for conflicts
            $status = git status --porcelain
            if ($status -match '^(DD|AU|UD|UA|DU|AA|UU)') {
                throw "Cherry-pick has conflicts"
            }
            
            Write-Success "Applied: $($commit.Hash)"
            $results.Applied += $commit
            
        } catch {
            Write-Error "Failed: $($commit.Hash) - $($_.Exception.Message)"
            
            # Abort the cherry-pick
            git cherry-pick --abort 2>&1 | Out-Null
            
            $results.Failed += @{
                Commit = $commit
                Error = $_.Exception.Message
            }
        }
    }
    
    Write-Header "Auto-Apply Summary"
    Write-Success "Applied: $($results.Applied.Count)"
    Write-Error "Failed: $($results.Failed.Count)"
    
    if ($results.Failed.Count -gt 0) {
        Write-Warning "Failed commits need manual attention:"
        foreach ($fail in $results.Failed) {
            Write-Host "  $($fail.Commit.Hash) - $($fail.Commit.Message)" -ForegroundColor Yellow
        }
    }
    
    if (-not $DryRun -and $results.Applied.Count -gt 0) {
        Write-Info "Checkpoint branch available if rollback needed: $checkpointBranch"
        Write-Info "To rollback: git reset --hard $checkpointBranch"
    }
    
    return $results
}

function New-SyncReport {
    param([array]$Commits, [string]$Since)
    
    $date = Get-Date -Format 'yyyy-MM-dd'
    $upstreamHead = git rev-parse upstream/main
    
    $report = @"
# Upstream Sync Report
**Generated**: $date  
**Upstream HEAD**: ``$upstreamHead``  
**Base**: ``$Since``  
**New Commits**: $($Commits.Count)

---

"@
    
    $byCategory = $Commits | Group-Object Category
    
    foreach ($group in $byCategory) {
        $icon = switch ($group.Name) {
            'AUTO' { '🟢 AUTO-CHERRY-PICK' }
            'ADAPT' { '🟡 ADAPT & MERGE' }
            'IGNORE' { '🔴 IGNORE' }
            'EVALUATE' { '🔵 EVALUATE' }
            'REVIEW' { '⚪ NEEDS REVIEW' }
        }
        
        $report += "## $icon ($($group.Count) commits)`n`n"
        
        foreach ($commit in $group.Group) {
            # Get commit details
            $details = git show --stat --format="%an%n%ai%n%b" $commit.Hash
            $author = ($details | Select-Object -First 1)
            $date = ($details | Select-Object -Skip 1 -First 1)
            
            $report += "### ``$($commit.Hash)`` - $($commit.Message)`n`n"
            $report += "**Author**: $author  `n"
            $report += "**Date**: $date  `n`n"
            
            # Get files changed
            $files = git diff-tree --no-commit-id --name-only -r $commit.Hash
            $report += "**Files Changed**:`n"
            foreach ($file in $files) {
                $report += "- ``$file```n"
            }
            $report += "`n"
            
            # Decision guidance
            $report += "**Decision**: "
            switch ($group.Name) {
                'AUTO' { $report += "✅ Safe to auto-apply`n" }
                'ADAPT' { $report += "⚠️ Requires path adaptation (docs/ → .documentation/)`n" }
                'IGNORE' { $report += "🚫 Skip - not applicable to Spark`n" }
                'EVALUATE' { $report += "🤔 Needs team evaluation - major feature`n" }
                'REVIEW' { $report += "👀 Manual categorization required`n" }
            }
            $report += "`n---`n`n"
        }
    }
    
    $report += @"
## Recommendations

### Immediate Actions
1. Review AUTO commits and run: ``.\sync-upstream.ps1 -Mode auto``
2. Manually adapt ADAPT commits (adjust paths, test commands)
3. Schedule evaluation meetings for EVALUATE commits

### Next Steps
- Update FORK_DIVERGENCE.md with absorbed changes
- Test all commands after applying changes
- Run full test suite if available
- Update documentation if behavior changes

---

*Report generated by sync-upstream.ps1*
"@
    
    return $report
}

function Update-DivergenceDoc {
    param(
        [array]$AppliedCommits,
        [string]$UpstreamHead
    )
    
    if (-not (Test-Path $divergenceDoc)) {
        Write-Warning "FORK_DIVERGENCE.md not found, skipping update"
        return
    }
    
    $content = Get-Content $divergenceDoc -Raw
    $date = Get-Date -Format 'yyyy-MM-dd'
    
    # Update header metadata
    $content = $content -replace '(\*\*Last Sync\*\*: )[^\n]+', "`$1$date"
    $content = $content -replace '(\*\*Current Upstream\*\*: `)[a-f0-9]+(`)', "`$1$UpstreamHead`$2"
    
    # Add sync entry
    if ($AppliedCommits.Count -gt 0) {
        $syncEntry = @"

### $date`: Auto-Applied Cherry-Picks

**Upstream Commit**: ``$UpstreamHead``  
**Applied**: $($AppliedCommits.Count) commits

"@
        foreach ($commit in $AppliedCommits) {
            $syncEntry += "- ``$($commit.Hash)`` - $($commit.Message)`n"
        }
        
        # Insert after "## Sync History" header
        $content = $content -replace '(## Sync History[^\#]+)', "`$1`n$syncEntry"
    }
    
    Set-Content -Path $divergenceDoc -Value $content
    Write-Success "Updated FORK_DIVERGENCE.md"
}

function Create-IntegrationPlan {
    param(
        [PSCustomObject]$Commit,
        [string]$Note = ""
    )
    
    $incomingDir = Join-Path $repoRoot "incoming"
    $commitDir = Join-Path $incomingDir $Commit.Hash
    
    # Create directory structure
    if (-not (Test-Path $incomingDir)) {
        New-Item -ItemType Directory -Path $incomingDir -Force | Out-Null
        Write-Info "Created incoming directory"
    }
    
    if (Test-Path $commitDir) {
        Write-Warning "Plan already exists for $($Commit.Hash)"
        return $commitDir
    }
    
    New-Item -ItemType Directory -Path $commitDir -Force | Out-Null
    
    # Collect detailed commit metadata
    $author = git show -s --format='%an <%ae>' $Commit.Hash
    $authorDate = git show -s --format='%ai' $Commit.Hash
    $committer = git show -s --format='%cn <%ce>' $Commit.Hash
    $commitDate = git show -s --format='%ci' $Commit.Hash
    $body = git show -s --format='%b' $Commit.Hash
    $filesChanged = git diff-tree --no-commit-id --name-status -r $Commit.Hash
    $diffStats = git diff --stat "$($Commit.Hash)^..$($Commit.Hash)"
    
    # Parse PR number if exists
    $prNumber = ""
    if ($Commit.Message -match '#(\d+)') {
        $prNumber = $Matches[1]
    }
    
    # Get full diff
    $fullDiff = git show $Commit.Hash
    
    # Create integration plan document
    $planContent = @"
# Integration Plan: $($Commit.Message)

**Status**: 📋 Pending Evaluation  
**Created**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Evaluator**: _[Your Name]_

---

## Upstream Commit Metadata

| Field | Value |
|-------|-------|
| **Commit Hash** | ``$($Commit.Hash)`` |
| **Category** | $($Commit.Category) |
| **Author** | $author |
| **Author Date** | $authorDate |
| **Committer** | $committer |
| **Commit Date** | $commitDate |
| **PR Number** | $(if ($prNumber) { "#$prNumber ([View](https://github.com/github/spec-kit/pull/$prNumber))" } else { "N/A" }) |

### Commit Message
``````
$($Commit.Message)
``````

### Full Description
``````
$(if ($body -and $body.Trim()) { $body.Trim() } else { "_No additional description_" })
``````

---

## Files Changed

``````
$filesChanged
``````

### Diff Statistics
``````
$diffStats
``````

---

## Integration Analysis

### 1. What Does This Change Do?
_Describe in plain language what this upstream commit accomplishes._

**Key Changes:**
- [ ] _Change 1_
- [ ] _Change 2_
- [ ] _Change 3_

**Upstream Problem Solved:**
_What issue or need does this address in the upstream repository?_

---

### 2. Relevance to Spec Kit Spark

**Does this apply to Spark?**  
- [ ] Yes - Directly applicable
- [ ] Partially - Needs adaptation
- [ ] No - Not relevant to Spark's goals
- [ ] Uncertain - Requires discussion

**Reasoning:**
_Why is this relevant or not relevant to Spark users?_

---

### 3. Conflicts & Dependencies

**File Conflicts:**
- [ ] No conflicts with Spark-specific files
- [ ] Conflicts with: _[list files]_

**Spark-Specific Files Affected:**
$(
    $sparkFiles = @('.documentation/', 'templates/commands/critic.md', 'templates/commands/pr-review.md', 
                   'templates/commands/site-audit.md', 'templates/commands/quickfix.md',
                   'templates/commands/evolve-constitution.md', 'templates/commands/release.md',
                   'templates/commands/discover-constitution.md', 'templates/commands/clarify.md',
                   'templates/commands/analyze.md')
    
    $affected = @()
    foreach ($pattern in $sparkFiles) {
        if ($filesChanged -match [regex]::Escape($pattern)) {
            $affected += "- ⚠️ ``$pattern``"
        }
    }
    
    if ($affected.Count -gt 0) {
        $affected -join "`n"
    } else {
        "- ✅ None"
    }
)

**Dependencies:**
_Does this depend on other upstream commits or features?_

---

### 4. Adaptation Strategy

**Integration Approach:**
- [ ] Cherry-pick as-is
- [ ] Cherry-pick with modifications
- [ ] Reimplement from scratch
- [ ] Extract concept only
- [ ] Skip entirely

**Required Adaptations:**
1. _[Adaptation 1]_
2. _[Adaptation 2]_
3. _[Adaptation 3]_

**Path Adjustments Needed:**
- [ ] ``.specify/`` → ``.documentation/``
- [ ] ``docs/`` → ``.documentation/``
- [ ] ``memory/`` → ``.documentation/memory/``
- [ ] Other: _[specify]_

---

### 5. Testing & Validation

**Test Plan:**
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing in sample project
- [ ] Documentation updated
- [ ] All AI agent commands work

**Validation Criteria:**
_How will you know this integration is successful?_

---

### 6. Impact Assessment

**User Impact:**
- [ ] No user-facing changes
- [ ] Minor UX improvement
- [ ] Major feature addition
- [ ] Breaking change

**Risk Level:**
- [ ] Low - Isolated change
- [ ] Medium - Touches multiple areas
- [ ] High - Core functionality change

**Effort Estimate:**
- [ ] Trivial (< 1 hour)
- [ ] Small (1-4 hours)
- [ ] Medium (1-2 days)
- [ ] Large (> 2 days)

---

### 7. Decision & Next Steps

**Decision:** _[Approve / Modify / Reject / Defer]_

**Rationale:**
_Why was this decision made?_

**Action Items:**
- [ ] _[Action 1]_
- [ ] _[Action 2]_
- [ ] _[Action 3]_

**Timeline:** _[Target date or sprint]_

---

## Notes

$(if ($Note) { $Note } else { "_Add any additional notes, concerns, or discussion points here._" })

---

## Reference: Full Diff

<details>
<summary>Click to expand full diff</summary>

``````diff
$fullDiff
``````

</details>

---

**Generated by**: ``sync-upstream.ps1``  
**Script Version**: 1.0  
**Repository**: [github/spec-kit](https://github.com/github/spec-kit)

"@
    
    # Save integration plan
    $planFile = Join-Path $commitDir "integration-plan.md"
    Set-Content -Path $planFile -Value $planContent -Encoding UTF8
    
    Write-Success "Created integration plan at: $commitDir"
    Write-Info "Edit: $planFile"
    
    return $commitDir
}

function Invoke-InteractiveReview {
    param([array]$Commits)
    
    if ($Commits.Count -eq 0) {
        Write-Info "No commits to review"
        return @{
            Applied = @()
            Skipped = @()
            Planned = @()
            Deferred = @()
        }
    }
    
    Write-Header "Interactive Commit Review"
    Write-Info "Review each commit and decide: Apply, Skip, Plan, or Defer"
    Write-Info "Total commits: $($Commits.Count)"
    
    $results = @{
        Applied = @()
        Skipped = @()
        Planned = @()
        Deferred = @()
    }
    
    # Create checkpoint branch
    $checkpointBranch = "sync-checkpoint-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    git branch $checkpointBranch
    Write-Info "Created checkpoint branch: $checkpointBranch"
    
    $commitNumber = 0
    foreach ($commit in $Commits) {
        $commitNumber++
        
        Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
        Write-Host "COMMIT $commitNumber OF $($Commits.Count)" -ForegroundColor Cyan
        Write-Host "$('=' * 80)" -ForegroundColor Cyan
        
        # Show commit details
        Write-Host "`n📋 Commit: " -NoNewline -ForegroundColor Yellow
        Write-Host "$($commit.Hash) - $($commit.Message)"
        
        Write-Host "🏷️  Category: " -NoNewline -ForegroundColor Yellow
        $categoryColor = switch ($commit.Category) {
            'AUTO' { 'Green' }
            'ADAPT' { 'Yellow' }
            'IGNORE' { 'Red' }
            'EVALUATE' { 'Cyan' }
            'REVIEW' { 'White' }
        }
        Write-Host $commit.Category -ForegroundColor $categoryColor
        
        # Get detailed commit info
        $author = git show -s --format='%an' $commit.Hash
        $date = git show -s --format='%ai' $commit.Hash
        $body = git show -s --format='%b' $commit.Hash
        
        Write-Host "`n👤 Author: " -NoNewline -ForegroundColor Yellow
        Write-Host $author
        Write-Host "📅 Date: " -NoNewline -ForegroundColor Yellow
        Write-Host $date
        
        if ($body -and $body.Trim()) {
            Write-Host "`n📝 Description:" -ForegroundColor Yellow
            Write-Host $body.Trim() -ForegroundColor Gray
        }
        
        # Show files changed
        Write-Host "`n📂 Files Changed:" -ForegroundColor Yellow
        $filesChanged = git diff-tree --no-commit-id --name-status -r $commit.Hash
        foreach ($line in $filesChanged) {
            if ($line -match '^([AMD])\s+(.+)$') {
                $status = $Matches[1]
                $file = $Matches[2]
                $statusIcon = switch ($status) {
                    'A' { '✨' }
                    'M' { '📝' }
                    'D' { '🗑️ ' }
                }
                Write-Host "  $statusIcon $file" -ForegroundColor Gray
            }
        }
        
        # Show diff stats
        Write-Host "`n📊 Changes:" -ForegroundColor Yellow
        $commitHash = $commit.Hash
        $diffStats = git diff --stat "$commitHash^..$commitHash"
        $diffStats | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        
        # Explain implications based on category
        Write-Host "`n💡 Implications for Spark:" -ForegroundColor Magenta
        switch ($commit.Category) {
            'AUTO' {
                Write-Host "  ✅ SAFE TO APPLY - This is a bug fix or security patch" -ForegroundColor Green
                Write-Host "  • Should apply cleanly with no conflicts" -ForegroundColor Gray
                Write-Host "  • No Spark-specific adaptations needed" -ForegroundColor Gray
                Write-Host "  • Improves stability or security" -ForegroundColor Gray
            }
            'ADAPT' {
                Write-Host "  ⚠️  REQUIRES ADAPTATION - Template or documentation change" -ForegroundColor Yellow
                Write-Host "  • May need path adjustments (docs/ → .documentation/)" -ForegroundColor Gray
                Write-Host "  • Test all commands after applying" -ForegroundColor Gray
                Write-Host "  • Verify no conflicts with Spark enhancements" -ForegroundColor Gray
            }
            'IGNORE' {
                Write-Host "  🚫 RECOMMENDED TO SKIP - Not applicable to Spark" -ForegroundColor Red
                Write-Host "  • Tied to upstream-specific infrastructure" -ForegroundColor Gray
                Write-Host "  • Conflicts with Spark architecture" -ForegroundColor Gray
                Write-Host "  • No value for Spark users" -ForegroundColor Gray
            }
            'EVALUATE' {
                Write-Host "  🤔 NEEDS EVALUATION - Major feature" -ForegroundColor Cyan
                Write-Host "  • Large architectural change" -ForegroundColor Gray
                Write-Host "  • Requires team discussion" -ForegroundColor Gray
                Write-Host "  • Should be tested in isolation first" -ForegroundColor Gray
                Write-Host "  • Consider deferring for separate RFC" -ForegroundColor Gray
            }
            'REVIEW' {
                Write-Host "  👀 NEEDS MANUAL CATEGORIZATION" -ForegroundColor White
                Write-Host "  • Doesn't match automatic patterns" -ForegroundColor Gray
                Write-Host "  • Review changes carefully" -ForegroundColor Gray
            }
        }
        
        # Check for potential conflicts with Spark-specific files
        $sparkFiles = @('.documentation/', 'templates/commands/critic.md', 'templates/commands/pr-review.md', 
                       'templates/commands/site-audit.md', 'templates/commands/quickfix.md',
                       'templates/commands/evolve-constitution.md', 'templates/commands/release.md')
        
        $conflictRisk = $false
        foreach ($sparkPattern in $sparkFiles) {
            if ($filesChanged -match [regex]::Escape($sparkPattern)) {
                $conflictRisk = $true
                break
            }
        }
        
        if ($conflictRisk) {
            Write-Host "`n⚠️  WARNING: This commit modifies Spark-specific files!" -ForegroundColor Red
            Write-Host "   Extra care needed - may conflict with Spark enhancements" -ForegroundColor Yellow
        }
        
        # Prompt for action
        Write-Host "`n❓ What would you like to do?" -ForegroundColor Cyan
        Write-Host "  [A] Apply this commit now" -ForegroundColor Green
        Write-Host "  [S] Skip this commit" -ForegroundColor Yellow
        Write-Host "  [P] Plan - Create integration evaluation folder" -ForegroundColor Blue
        Write-Host "  [D] Defer for later (add note)" -ForegroundColor Cyan
        Write-Host "  [V] View full diff" -ForegroundColor Magenta
        Write-Host "  [Q] Quit interactive review" -ForegroundColor Red
        
        do {
            $choice = Read-Host "`nChoice (A/S/P/D/V/Q)"
            $choice = $choice.ToUpper()
            
            switch ($choice) {
                'V' {
                    Write-Host "`n📄 Full Diff:" -ForegroundColor Cyan
                    git show $commit.Hash | Out-Host
                    Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                    Read-Host
                    
                    # Re-show menu
                    Write-Host "`n❓ What would you like to do?" -ForegroundColor Cyan
                    Write-Host "  [A] Apply this commit now" -ForegroundColor Green
                    Write-Host "  [S] Skip this commit" -ForegroundColor Yellow
                    Write-Host "  [P] Plan - Create integration evaluation folder" -ForegroundColor Blue
                    Write-Host "  [D] Defer for later (add note)" -ForegroundColor Cyan
                    Write-Host "  [Q] Quit interactive review" -ForegroundColor Red
                }
                'A' {
                    Write-Host "`n⏳ Applying commit..." -ForegroundColor Cyan
                    try {
                        git cherry-pick $commit.Hash 2>&1 | Out-Null
                        
                        # Check for conflicts
                        $status = git status --porcelain
                        if ($status -match '^(DD|AU|UD|UA|DU|AA|UU)') {
                            Write-Error "Cherry-pick has conflicts!"
                            Write-Host "`n❓ How to resolve?" -ForegroundColor Yellow
                            Write-Host "  [R] Resolve manually and continue" -ForegroundColor Cyan
                            Write-Host "  [A] Abort this cherry-pick" -ForegroundColor Red
                            
                            $resolveChoice = Read-Host "`nChoice (R/A)"
                            if ($resolveChoice.ToUpper() -eq 'R') {
                                Write-Host "`nResolve conflicts, then run: git cherry-pick --continue" -ForegroundColor Yellow
                                Write-Host "Press Enter when ready..." -ForegroundColor Gray
                                Read-Host
                            } else {
                                git cherry-pick --abort 2>&1 | Out-Null
                                throw "Cherry-pick aborted by user"
                            }
                        }
                        
                        Write-Success "Successfully applied: $($commit.Hash)"
                        $results.Applied += $commit
                    } catch {
                        Write-Error "Failed to apply: $($_.Exception.Message)"
                        git cherry-pick --abort 2>&1 | Out-Null
                        
                        Write-Host "`n❓ Mark as deferred for manual handling?" -ForegroundColor Yellow
                        $deferChoice = Read-Host "Defer? (Y/N)"
                        if ($deferChoice.ToUpper() -eq 'Y') {
                            $note = Read-Host "Add note (optional)"
                            $results.Deferred += @{
                                Commit = $commit
                                Reason = "Failed auto-apply: $($_.Exception.Message)"
                                Note = $note
                            }
                        } else {
                            $results.Skipped += $commit
                        }
                    }
                }
                'S' {
                    Write-Warning "Skipping commit"
                    $results.Skipped += $commit
                }
                'P' {
                    Write-Host "`n📋 Creating integration plan..." -ForegroundColor Cyan
                    $note = Read-Host "Add initial notes (optional)"
                    $planDir = Create-IntegrationPlan -Commit $commit -Note $note
                    $results.Planned += @{
                        Commit = $commit
                        PlanDir = $planDir
                        Note = $note
                    }
                    Write-Success "Integration plan created - review and update as needed"
                }
                'D' {
                    $reason = Read-Host "`nReason for deferring"
                    $results.Deferred += @{
                        Commit = $commit
                        Reason = $reason
                        Note = ""
                    }
                    Write-Info "Deferred for later review"
                }
                'Q' {
                    Write-Warning "Exiting interactive review"
                    
                    Write-Header "Interactive Review Summary"
                    Write-Success "Applied: $($results.Applied.Count)"
                    Write-Warning "Skipped: $($results.Skipped.Count)"
                    Write-Host "Planned: $($results.Planned.Count)" -ForegroundColor Blue
                    Write-Info "Deferred: $($results.Deferred.Count)"
                    Write-Host "Remaining: $(($Commits.Count - $commitNumber))" -ForegroundColor Gray
                    
                    if ($results.Planned.Count -gt 0) {
                        Write-Host "`n📋 Integration Plans Created:" -ForegroundColor Cyan
                        foreach ($item in $results.Planned) {
                            Write-Host "  • $($item.PlanDir)" -ForegroundColor Gray
                        }
                    }
                    
                    return $results
                }
                default {
                    Write-Warning "Invalid choice. Please enter A, S, P, D, V, or Q"
                    $choice = "" # Force re-prompt
                }
            }
        } while (-not $choice -or $choice -eq 'V')
    }
    
    Write-Header "Interactive Review Complete"
    Write-Success "Applied: $($results.Applied.Count)"
    Write-Warning "Skipped: $($results.Skipped.Count)"
    Write-Host "Planned: $($results.Planned.Count)" -ForegroundColor Blue
    Write-Info "Deferred: $($results.Deferred.Count)"
    
    if ($results.Planned.Count -gt 0) {
        Write-Host "`n📋 Integration Plans Created:" -ForegroundColor Cyan
        foreach ($item in $results.Planned) {
            Write-Host "  • $($item.Commit.Hash) - $($item.Commit.Message)" -ForegroundColor Gray
            Write-Host "    Location: $($item.PlanDir)" -ForegroundColor DarkGray
        }
        Write-Host "`n💡 Next: Review integration plans and execute when ready" -ForegroundColor Magenta
    }
    
    # Show deferred commits
    if ($results.Deferred.Count -gt 0) {
        Write-Host "`n📋 Deferred Commits:" -ForegroundColor Yellow
        foreach ($deferred in $results.Deferred) {
            Write-Host "  • $($deferred.Commit.Hash) - $($deferred.Commit.Message)" -ForegroundColor Gray
            Write-Host "    Reason: $($deferred.Reason)" -ForegroundColor DarkGray
            if ($deferred.Note) {
                Write-Host "    Note: $($deferred.Note)" -ForegroundColor DarkGray
            }
        }
    }
    
    if ($results.Applied.Count -gt 0) {
        Write-Info "Checkpoint branch available if rollback needed: $checkpointBranch"
        Write-Info "To rollback: git reset --hard $checkpointBranch"
        
        # Update divergence doc
        $upstreamHead = git rev-parse upstream/main
        Update-DivergenceDoc -AppliedCommits $results.Applied -UpstreamHead $upstreamHead
    }
    
    return $results
}

# Main execution
Write-Header "Spec Kit Spark - Upstream Sync Tool"
Write-Info "Mode: $Mode"

# Ensure we have upstream remote
$remotes = git remote
if ($remotes -notcontains 'upstream') {
    Write-Error "Upstream remote not configured"
    Write-Info "Run: git remote add upstream https://github.com/github/spec-kit.git"
    exit 1
}

# Fetch latest upstream
Write-Info "Fetching upstream changes..."
git fetch upstream 2>&1 | Out-Null
Write-Success "Fetch complete"

# Determine sync point
if (-not $Since) {
    $Since = Get-LastSyncPoint
    Write-Info "Using sync point: $Since"
} else {
    Write-Info "Using specified sync point: $Since"
}

# Get new commits
$commits = Get-UpstreamCommits -Since $Since

if ($commits.Count -eq 0) {
    Write-Success "Already up-to-date with upstream!"
    exit 0
}

# Execute requested mode
switch ($Mode) {
    'review' {
        Show-CommitsByCategory -Commits $commits
        
        Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
        Write-Host "  • Interactive review: .\sync-upstream.ps1 -Mode interactive"
        Write-Host "  • Auto-apply safe fixes: .\sync-upstream.ps1 -Mode auto"
        Write-Host "  • Generate full report: .\sync-upstream.ps1 -Mode report > report.md"
        Write-Host "  • Cherry-pick manually: git cherry-pick <hash>"
    }
    
    'interactive' {
        $results = Invoke-InteractiveReview -Commits $commits
        
        Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
        if ($results.Planned.Count -gt 0) {
            Write-Host "  • Review integration plans in incoming/ folder"
            Write-Host "  • Update plans with integration strategy"
            Write-Host "  • Execute planned integrations when ready"
        }
        if ($results.Deferred.Count -gt 0) {
            Write-Host "  • Review deferred commits and handle manually"
        }
        if ($results.Skipped.Count -gt 0) {
            Write-Host "  • Skipped commits can be cherry-picked later if needed"
        }
        Write-Host "  • Run tests to verify applied changes"
        Write-Host "  • Update documentation if behavior changed"
    }
    
    'auto' {
        $results = Invoke-AutoApply -Commits $commits -DryRun:$DryRun
        
        if (-not $DryRun -and $results.Applied.Count -gt 0) {
            $upstreamHead = git rev-parse upstream/main
            Update-DivergenceDoc -AppliedCommits $results.Applied -UpstreamHead $upstreamHead
        }
    }
    
    'report' {
        $report = New-SyncReport -Commits $commits -Since $Since
        Write-Output $report
    }
    
    'update-doc' {
        $upstreamHead = git rev-parse upstream/main
        Update-DivergenceDoc -AppliedCommits @() -UpstreamHead $upstreamHead
        Write-Success "Updated sync metadata in FORK_DIVERGENCE.md"
    }
}

Write-Host ""
Write-Success "Sync operation complete"
