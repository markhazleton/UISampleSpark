#!/usr/bin/env pwsh
#requires -Version 7.0
# Extract PR context for review
#
# This script fetches Pull Request information from GitHub and provides it
# in JSON format for the pr-review command.
#
# Usage: ./get-pr-context.ps1 [PR_NUMBER] [-Json]
#        ./get-pr-context.ps1 -Json           # Auto-detect PR from current branch
#        ./get-pr-context.ps1 123 -Json       # Specific PR number
#        ./get-pr-context.ps1 "#123" -Json    # Also accepts # prefix
#        ./get-pr-context.ps1 123 -Json -IncludeAllFiles

param(
    [Parameter(Position=0)]
    [string]$PrNumber,
    
    [Parameter()]
    [switch]$Json,

    [Parameter()]
    [switch]$IncludeAllFiles,

    [Parameter()]
    [int]$FileSampleLimit = 200
)

$ErrorActionPreference = "Stop"

#==============================================================================
# Configuration
#==============================================================================

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path "$scriptPath\..\..")

#==============================================================================
# Utility Functions
#==============================================================================

function Write-JsonError {
    param(
        [string]$Message,
        [string]$Details = ""
    )
    
    if ($Json) {
        $errorObj = @{
            error = $true
            message = $Message
            details = $Details
        } | ConvertTo-Json
        Write-Output $errorObj
    } else {
        Write-Error $Message
        if ($Details) {
            Write-Error $Details
        }
    }
}

if ($FileSampleLimit -lt 1) {
    $FileSampleLimit = 200
}

#==============================================================================
# PR Number Detection
#==============================================================================

function Get-DetectedPrNumber {
    # Method 1: Check environment variables
    if ($env:GITHUB_PR_NUMBER) {
        return $env:GITHUB_PR_NUMBER
    }
    
    if ($env:PR_NUMBER) {
        return $env:PR_NUMBER
    }
    
    # Method 2: Try GitHub CLI for current branch
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $prData = gh pr view --json number 2>$null | ConvertFrom-Json
            if ($prData.number) {
                return $prData.number
            }
        } catch {
            # Continue to next method
        }
    }
    
    return $null
}

#==============================================================================
# Main Execution
#==============================================================================

# Parse PR number from argument (strip # prefix if present)
if ($PrNumber) {
    $PrNumber = $PrNumber -replace '^#', ''
}

# Detect PR number if not provided
if ([string]::IsNullOrWhiteSpace($PrNumber)) {
    $PrNumber = Get-DetectedPrNumber
    if (-not $PrNumber) {
        Write-JsonError -Message "Unable to detect PR number" `
            -Details "Please provide PR number explicitly: /speckit.pr-review #123"
        exit 1
    }
}

# Validate PR number is numeric
if ($PrNumber -notmatch '^\d+$') {
    Write-JsonError -Message "Invalid PR number: $PrNumber" `
        -Details "PR number must be a positive integer"
    exit 1
}

# Check if GitHub CLI is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-JsonError -Message "GitHub CLI (gh) is required but not installed" `
        -Details "Install from: https://cli.github.com/"
    exit 1
}

# Check GitHub CLI authentication
try {
    gh auth status 2>$null | Out-Null
} catch {
    Write-JsonError -Message "GitHub CLI not authenticated" `
        -Details "Run: gh auth login"
    exit 1
}

# Fetch PR data
try {
    $prDataJson = gh pr view $PrNumber --json number,title,body,state,author,headRefName,baseRefName,commits,files,additions,deletions,createdAt,updatedAt 2>$null
    $prData = $prDataJson | ConvertFrom-Json
} catch {
    Write-JsonError -Message "Failed to fetch PR #$PrNumber" `
        -Details "Verify PR exists and you have access. Error: $_"
    exit 1
}

# Extract commit SHA (most recent commit)
$commitSha = "unknown"
if ($prData.commits -and $prData.commits.Count -gt 0) {
    $commitSha = $prData.commits[-1].oid
}

# Check if diff is available
$diffAvailable = $false
try {
    gh pr diff $PrNumber 2>$null | Out-Null
    $diffAvailable = $true
} catch {
    $diffAvailable = $false
}

# Extract file list
$allFilesChanged = @($prData.files | ForEach-Object { $_.path })
$filesChangedTotal = $allFilesChanged.Count
$filesChangedTruncated = $false
$filesChanged = $allFilesChanged
if (-not $IncludeAllFiles -and $filesChangedTotal -gt $FileSampleLimit) {
    $filesChanged = @($allFilesChanged | Select-Object -First $FileSampleLimit)
    $filesChangedTruncated = $true
}

# Check for constitution
$constitutionPath = Join-Path $repoRoot.Path ".documentation\memory\constitution.md"
$constitutionExists = Test-Path $constitutionPath

# Prepare review directory
$reviewDir = Join-Path $repoRoot.Path ".documentation\specs\pr-review"

# Build output
if ($Json) {
    $output = @{
        REPO_ROOT = $repoRoot.Path
        PR_CONTEXT = @{
            enabled = $true
            pr_number = $prData.number
            pr_title = $prData.title
            pr_body = $prData.body ?? ""
            pr_state = $prData.state
            pr_author = $prData.author.login
            source_branch = $prData.headRefName
            target_branch = $prData.baseRefName
            commit_sha = $commitSha
            commit_count = $prData.commits.Count
            files_changed = $filesChanged
            files_changed_total = $filesChangedTotal
            files_changed_truncated = $filesChangedTruncated
            lines_added = $prData.additions ?? 0
            lines_deleted = $prData.deletions ?? 0
            created_at = $prData.createdAt
            updated_at = $prData.updatedAt
            diff_available = $diffAvailable
            file_sample_limit = $FileSampleLimit
            include_all_files = [bool]$IncludeAllFiles
        }
        CONSTITUTION_PATH = $constitutionPath
        CONSTITUTION_EXISTS = $constitutionExists
        REVIEW_DIR = $reviewDir
    } | ConvertTo-Json -Depth 10
    
    Write-Output $output
} else {
    # Human-readable output
    Write-Output "PR Context for #$($prData.number)"
    Write-Output "========================="
    Write-Output "Title: $($prData.title)"
    Write-Output "Author: $($prData.author.login)"
    Write-Output "State: $($prData.state)"
    Write-Output "Branch: $($prData.headRefName) → $($prData.baseRefName)"
    Write-Output "Commit: $commitSha"
    Write-Output "Files: $($prData.files.Count)"
    Write-Output "Lines: +$($prData.additions ?? 0) -$($prData.deletions ?? 0)"
    Write-Output ""
    Write-Output "Constitution: $(if ($constitutionExists) { '✓ Found' } else { '✗ Missing' })"
    Write-Output "Review will be saved to: $reviewDir\pr-$($prData.number).md"
}
