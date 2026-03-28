#!/usr/bin/env pwsh
# Constitution evolution context gathering script
# Analyzes PR reviews and audits to propose constitution amendments

param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]]$Arguments,
    [switch]$Json
)

. (Join-Path $PSScriptRoot 'common.ps1')

# Parse arguments
$action = "analyze"
$capId = ""
$fromPr = ""
$fromAudit = ""
$suggestion = ""

$i = 0
while ($i -lt $Arguments.Count) {
    $arg = $Arguments[$i]
    switch -Regex ($arg) {
        "^--from-pr=(.+)$" { $fromPr = $matches[1] }
        "^--from-pr$" { $i++; if ($i -lt $Arguments.Count) { $fromPr = $Arguments[$i] } }
        "^--from-audit=(.+)$" { $fromAudit = $matches[1] }
        "^--from-audit$" { $i++; if ($i -lt $Arguments.Count) { $fromAudit = $Arguments[$i] } }
        "^suggest$" {
            $action = "suggest"
            $suggestion = ($Arguments[($i+1)..($Arguments.Count-1)]) -join " "
            break
        }
        "^approve$" { $action = "approve" }
        "^reject$" { $action = "reject" }
        "^CAP-" { $capId = $arg }
    }
    $i++
}

# Get repository context
$repoRoot = Get-RepoRoot
$constitutionPath = Join-Path $repoRoot ".documentation/memory/constitution.md"
$prReviewDir = Join-Path $repoRoot ".documentation/specs/pr-review"
$auditDir = Join-Path $repoRoot ".documentation/copilot/audit"
$proposalsDir = Join-Path $repoRoot ".documentation/memory/proposals"
$historyFile = Join-Path $repoRoot ".documentation/memory/constitution-history.md"

# Check constitution exists
$constitutionExists = Test-Path $constitutionPath
$constitutionVersion = "1.0.0"
$constitutionPrinciples = @()

if ($constitutionExists) {
    $content = Get-Content $constitutionPath -Raw -ErrorAction SilentlyContinue
    if ($content -match '\*\*Version\*\*:\s*([^\s|]+)') {
        $constitutionVersion = $matches[1]
    }
    $constitutionPrinciples = [regex]::Matches($content, '^###\s+(.+)$', 'Multiline') |
        ForEach-Object { $_.Groups[1].Value }
}

# List PR reviews
$prReviews = @()
$prReviewCount = 0
if (Test-Path $prReviewDir) {
    $prReviews = Get-ChildItem -Path $prReviewDir -Filter "pr-*.md" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 20 |
        ForEach-Object { $_.BaseName }
    $prReviewCount = (Get-ChildItem -Path $prReviewDir -Filter "pr-*.md" -ErrorAction SilentlyContinue).Count
}

# List audit reports
$auditReports = @()
$auditCount = 0
if (Test-Path $auditDir) {
    $auditReports = Get-ChildItem -Path $auditDir -Filter "*_results.md" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 10 |
        ForEach-Object { $_.Name }
    $auditCount = (Get-ChildItem -Path $auditDir -Filter "*_results.md" -ErrorAction SilentlyContinue).Count
}

# List existing proposals
$proposals = @()
if (Test-Path $proposalsDir) {
    $proposals = Get-ChildItem -Path $proposalsDir -Filter "CAP-*.md" -ErrorAction SilentlyContinue |
        ForEach-Object { $_.BaseName }
}

# Calculate next proposal ID (CAP-YYYY-NNN format)
$year = Get-Date -Format "yyyy"
$nextCapNum = 1
if (Test-Path $proposalsDir) {
    $existing = Get-ChildItem -Path $proposalsDir -Filter "CAP-$year-*.md" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($existing -and $existing.Name -match "CAP-$year-(\d+)\.md") {
        $nextCapNum = [int]$matches[1] + 1
    }
}
$nextCapId = "CAP-{0}-{1:D3}" -f $year, $nextCapNum

# Aggregate violation patterns
$patternSummary = @()
$criticalCount = 0
$highCount = 0

if (Test-Path $prReviewDir) {
    $allContent = Get-ChildItem -Path $prReviewDir -Filter "*.md" -ErrorAction SilentlyContinue |
        ForEach-Object { Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue }
    $allContentJoined = $allContent -join "`n"

    $criticalCount = ([regex]::Matches($allContentJoined, 'CRITICAL')).Count
    $highCount = ([regex]::Matches($allContentJoined, 'HIGH')).Count
}

# Get timestamp
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Output
if ($Json) {
    @{
        REPO_ROOT                = $repoRoot
        CONSTITUTION_PATH        = $constitutionPath
        CONSTITUTION_EXISTS      = $constitutionExists
        CONSTITUTION_VERSION     = $constitutionVersion
        CONSTITUTION_PRINCIPLES  = $constitutionPrinciples
        PR_REVIEW_DIR            = $prReviewDir
        AUDIT_DIR                = $auditDir
        PROPOSALS_DIR            = $proposalsDir
        HISTORY_FILE             = $historyFile
        PR_REVIEWS               = $prReviews
        PR_REVIEW_COUNT          = $prReviewCount
        AUDIT_REPORTS            = $auditReports
        AUDIT_COUNT              = $auditCount
        PROPOSALS                = $proposals
        NEXT_CAP_ID              = $nextCapId
        PATTERN_SUMMARY          = $patternSummary
        CRITICAL_COUNT           = $criticalCount
        HIGH_COUNT               = $highCount
        ACTION                   = $action
        CAP_ID                   = $capId
        FROM_PR                  = $fromPr
        FROM_AUDIT               = $fromAudit
        SUGGESTION               = $suggestion
        TIMESTAMP                = $timestamp
    } | ConvertTo-Json
}
else {
    Write-Output "Constitution Evolution Context"
    Write-Output "=============================="
    Write-Output "Constitution: $constitutionPath (exists: $constitutionExists, version: $constitutionVersion)"
    Write-Output "Principles: $($constitutionPrinciples.Count)"
    Write-Output ""
    Write-Output "PR Reviews: $prReviewCount (analyzing last 20)"
    Write-Output "Audit Reports: $auditCount (analyzing last 10)"
    Write-Output "Existing Proposals: $($proposals.Count)"
    Write-Output ""
    Write-Output "Violation Summary:"
    Write-Output "  Critical: $criticalCount"
    Write-Output "  High: $highCount"
    Write-Output ""
    Write-Output "Action: $action"
    Write-Output "Next Proposal ID: $nextCapId"
}
