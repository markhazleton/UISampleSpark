#!/usr/bin/env pwsh
#requires -Version 7.0
<#
.SYNOPSIS
    Gathers codebase data for site-audit as JSON for LLM context efficiency.

.DESCRIPTION
    Pre-scans the repository to collect file listings, dependency information,
    code metrics, and pattern detection results for the speckit.site-audit command.

.PARAMETER Scope
    Audit scope: full, constitution, packages, quality, unused, duplicate
    Default: full

.PARAMETER OutputFormat
    Output format: json, summary
    Default: json

.PARAMETER Json
    Alias for -OutputFormat json (for consistency with other scripts)

.PARAMETER IncludeFullInventory
    Include full file inventories and full pattern findings in JSON output.
    By default, output is sampled for performance.

.PARAMETER SampleLimit
    Maximum files per category to include by default.
    Default: 25

.PARAMETER LargeFileLimit
    Maximum large files to include in metrics output.
    Default: 20

.PARAMETER PatternSampleLimit
    Maximum findings per pattern category to include by default.
    Default: 25

.EXAMPLE
    ./site-audit.ps1
    ./site-audit.ps1 --scope=constitution
    ./site-audit.ps1 -Scope packages -OutputFormat summary
    ./site-audit.ps1 -Json
#>

param(
    [string]$Scope = 'full',
    
    [ValidateSet('json', 'summary')]
    [string]$OutputFormat = 'json',
    
    [switch]$Json,

    [switch]$IncludeFullInventory,

    [int]$SampleLimit = 25,

    [int]$LargeFileLimit = 20,

    [int]$PatternSampleLimit = 25,
    
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$RemainingArgs
)

# Import common functions
. (Join-Path $PSScriptRoot 'common.ps1')

# Override OutputFormat if -Json switch is used
if ($Json) {
    $OutputFormat = 'json'
}

# Parse scope from various input formats
# Handle --scope=value format if passed directly to $Scope parameter
if ($Scope -match '^--scope=(.+)$') {
    $Scope = $matches[1].ToLower()
}

# Also check remaining args for --scope=value
if ($RemainingArgs) {
    foreach ($arg in $RemainingArgs) {
        if ($arg -match '^--scope=(.+)$') {
            $Scope = $matches[1].ToLower()
            continue
        }
        if ($arg -in @('--full-inventory', '--include-full-inventory')) {
            $IncludeFullInventory = $true
            continue
        }
        if ($arg -match '^--sample-limit=(\d+)$') {
            $SampleLimit = [int]$matches[1]
            continue
        }
        if ($arg -match '^--large-file-limit=(\d+)$') {
            $LargeFileLimit = [int]$matches[1]
            continue
        }
        if ($arg -match '^--pattern-sample-limit=(\d+)$') {
            $PatternSampleLimit = [int]$matches[1]
        }
    }
}

# Guardrails to avoid huge pre-scan payloads on large repositories
if ($SampleLimit -lt 1) { $SampleLimit = 25 }
if ($LargeFileLimit -lt 1) { $LargeFileLimit = 20 }
if ($PatternSampleLimit -lt 1) { $PatternSampleLimit = 25 }

# Validate scope
$validScopes = @('full', 'constitution', 'packages', 'quality', 'unused', 'duplicate')
if ($Scope -notin $validScopes) {
    Write-Error "Invalid scope '$Scope'. Valid options: $($validScopes -join ', ')"
    exit 1
}

function Get-FileCategories {
    param([string]$RepoRoot)
    
    $categories = @{
        source = @()
        config = @()
        documentation = @()
        tests = @()
        scripts = @()
        build = @()
    }
    
    # Define extension sets
    $sourceExtensions = @('.py', '.ts', '.tsx', '.js', '.jsx', '.cs', '.java', '.go', '.rs', '.rb', '.php')
    $configExtensions = @('.json', '.yaml', '.yml', '.toml', '.ini', '.cfg')
    $docExtensions = @('.md', '.rst', '.txt', '.adoc')
    $scriptExtensions = @('.sh', '.ps1', '.bash', '.bat', '.cmd')
    
    # Exclusion patterns
    $excludeDirs = @('node_modules', 'venv', '.venv', '__pycache__', '.git', '.vs', '.idea',
                     'dist', 'build', 'bin', 'obj', '.next', 'coverage', '.pytest_cache',
                     '.mypy_cache', '.tox', 'eggs', '.egg-info', '.genreleases', '.archive')
    
    $excludePattern = '(^|[/\\])(' + (($excludeDirs | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')([/\\]|$)'
    
    # Get all files, excluding common directories
    $allFiles = Get-ChildItem -Path $RepoRoot -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.FullName -notmatch $excludePattern }
    
    foreach ($file in $allFiles) {
        $relativePath = $file.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
        $ext = $file.Extension.ToLower()
        $name = $file.Name.ToLower()
        
        # Skip minified files
        if ($name -match '\.min\.(js|css)$' -or $ext -eq '.map') { continue }
        
        # Categorize by tests first (check path patterns)
        if ($relativePath -match '(^|/)tests?/' -or 
            $name -match '(_test|\.test|_spec|\.spec)\.' -or
            $name -match '^test_') {
            $categories.tests += $relativePath
            continue
        }
        
        # Check source by extension
        if ($ext -in $sourceExtensions) {
            $categories.source += $relativePath
            continue
        }
        
        # Check config by extension or env files
        if ($ext -in $configExtensions -or $name -match '^\.env' -or $name -match 'rc$') {
            $categories.config += $relativePath
            continue
        }
        
        # Check documentation by extension
        if ($ext -in $docExtensions) {
            $categories.documentation += $relativePath
            continue
        }
        
        # Check scripts by extension
        if ($ext -in $scriptExtensions) {
            $categories.scripts += $relativePath
            continue
        }
        
        # Check build files
        if ($relativePath -match '\.github/workflows/' -or
            $name -match '^dockerfile' -or
            $name -eq 'makefile' -or
            $ext -in @('.gradle', '.maven')) {
            $categories.build += $relativePath
        }
    }
    
    return $categories
}

function Get-PackageInfo {
    param([string]$RepoRoot)
    
    $packages = @{
        manager = $null
        manifest = $null
        lockfile = $null
        dependencies = @{
            direct = @()
            dev = @()
        }
        analysis = @{
            outdated = @()
            vulnerable = @()
            unused = @()
        }
    }
    
    # Detect Python
    $pyprojectPath = Join-Path $RepoRoot 'pyproject.toml'
    $requirementsPath = Join-Path $RepoRoot 'requirements.txt'
    
    if (Test-Path $pyprojectPath) {
        $packages.manager = 'pip'
        $packages.manifest = 'pyproject.toml'
        
        # Parse pyproject.toml for dependencies
        $content = Get-Content $pyprojectPath -Raw -ErrorAction SilentlyContinue
        if ($content -match '\[project\.dependencies\]') {
            $depSection = $content -split '\[project\.dependencies\]' | Select-Object -Last 1
            $depSection = $depSection -split '\[' | Select-Object -First 1
            $deps = $depSection -split "`n" | Where-Object { $_ -match '^\s*"?[\w-]+' } | 
                ForEach-Object { ($_ -split '[<>=!~\[]')[0].Trim(' "') }
            $packages.dependencies.direct = @($deps | Where-Object { $_ })
        }
        
        # Check for pip-audit
        try {
            $auditResult = pip-audit --format=json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($auditResult) {
                $packages.analysis.vulnerable = @($auditResult | ForEach-Object {
                    @{
                        name = $_.name
                        version = $_.version
                        vulnerability = $_.id
                        fix_versions = $_.fix_versions
                    }
                })
            }
        } catch {
            # pip-audit not available or failed
        }
    }
    elseif (Test-Path $requirementsPath) {
        $packages.manager = 'pip'
        $packages.manifest = 'requirements.txt'
        
        $deps = Get-Content $requirementsPath -ErrorAction SilentlyContinue | 
            Where-Object { $_ -match '^\s*[\w-]' -and $_ -notmatch '^\s*#' } |
            ForEach-Object { ($_ -split '[<>=!~\[]')[0].Trim() }
        $packages.dependencies.direct = @($deps | Where-Object { $_ })
    }
    
    # Detect Node.js
    $packageJsonPath = Join-Path $RepoRoot 'package.json'
    if (Test-Path $packageJsonPath) {
        $packages.manager = 'npm'
        $packages.manifest = 'package.json'
        
        $lockFiles = @('package-lock.json', 'yarn.lock', 'pnpm-lock.yaml')
        foreach ($lock in $lockFiles) {
            if (Test-Path (Join-Path $RepoRoot $lock)) {
                $packages.lockfile = $lock
                break
            }
        }
        
        try {
            $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
            if ($packageJson.dependencies) {
                $packages.dependencies.direct = @($packageJson.dependencies.PSObject.Properties.Name)
            }
            if ($packageJson.devDependencies) {
                $packages.dependencies.dev = @($packageJson.devDependencies.PSObject.Properties.Name)
            }
        } catch {
            # JSON parsing failed
        }
    }
    
    # Detect Go
    $goModPath = Join-Path $RepoRoot 'go.mod'
    if (Test-Path $goModPath) {
        $packages.manager = 'go'
        $packages.manifest = 'go.mod'
        $packages.lockfile = 'go.sum'
    }
    
    # Detect Rust
    $cargoPath = Join-Path $RepoRoot 'Cargo.toml'
    if (Test-Path $cargoPath) {
        $packages.manager = 'cargo'
        $packages.manifest = 'Cargo.toml'
        $packages.lockfile = 'Cargo.lock'
    }
    
    # Detect .NET
    $csprojFiles = Get-ChildItem -Path $RepoRoot -Filter '*.csproj' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($csprojFiles) {
        $packages.manager = 'nuget'
        $packages.manifest = $csprojFiles.Name
    }
    
    return $packages
}

function Get-CodeMetrics {
    param(
        [string]$RepoRoot,
        [array]$SourceFiles
    )
    
    $metrics = @{
        total_files = $SourceFiles.Count
        total_lines = 0
        lines_by_extension = @{}
        files_by_extension = @{}
        large_files = @()
        avg_lines_per_file = 0
        max_lines = 0
        max_lines_file = $null
    }
    
    foreach ($relPath in $SourceFiles) {
        $fullPath = Join-Path $RepoRoot $relPath
        if (-not (Test-Path $fullPath)) { continue }
        
        $ext = [System.IO.Path]::GetExtension($relPath).ToLower()
        $lineCount = (Get-Content $fullPath -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
        
        $metrics.total_lines += $lineCount
        
        if (-not $metrics.lines_by_extension.ContainsKey($ext)) {
            $metrics.lines_by_extension[$ext] = 0
            $metrics.files_by_extension[$ext] = 0
        }
        $metrics.lines_by_extension[$ext] += $lineCount
        $metrics.files_by_extension[$ext] += 1
        
        if ($lineCount -gt $metrics.max_lines) {
            $metrics.max_lines = $lineCount
            $metrics.max_lines_file = $relPath
        }
        
        if ($lineCount -gt 500) {
            $metrics.large_files += @{
                file = $relPath
                lines = $lineCount
            }
        }
    }
    
    if ($SourceFiles.Count -gt 0) {
        $metrics.avg_lines_per_file = [math]::Round($metrics.total_lines / $SourceFiles.Count, 1)
    }
    
    return $metrics
}

function Get-PatternDetection {
    param(
        [string]$RepoRoot,
        [array]$SourceFiles,
        [string]$Scope
    )
    
    $patterns = @{
        security = @{
            hardcoded_secrets = @()
            insecure_patterns = @()
        }
        quality = @{
            todo_comments = @()
            long_functions = @()
            deep_nesting = @()
        }
        unused = @{
            potential_dead_code = @()
        }
    }
    
    # Skip pattern detection for certain scopes
    if ($Scope -eq 'packages') {
        return $patterns
    }
    
    # Secret patterns to detect
    $secretPatterns = @(
        @{ name = 'API Key'; pattern = '(?i)(api[_-]?key|apikey)\s*[=:]\s*[''"][a-zA-Z0-9]{16,}[''"]' }
        @{ name = 'Password'; pattern = '(?i)(password|passwd|pwd)\s*[=:]\s*[''"][^''"]{4,}[''"]' }
        @{ name = 'Secret'; pattern = '(?i)(secret|token|auth)\s*[=:]\s*[''"][a-zA-Z0-9+/=]{16,}[''"]' }
        @{ name = 'AWS Key'; pattern = 'AKIA[0-9A-Z]{16}' }
        @{ name = 'Private Key'; pattern = '-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----' }
    )
    
    # Insecure pattern detection
    $insecurePatterns = @(
        @{ name = 'eval()'; pattern = '(?i)\beval\s*\(' }
        @{ name = 'exec()'; pattern = '(?i)\bexec\s*\(' }
        @{ name = 'SQL Injection'; pattern = '(?i)(execute|query)\s*\(\s*[''"].*\s*\+\s*' }
    )
    
    $todoPattern = '(?i)(TODO|FIXME|HACK|XXX|BUG)[\s:]+(.+)$'
    
    $fileLimit = 100  # Limit files to scan for performance
    $scannedCount = 0
    
    foreach ($relPath in $SourceFiles) {
        if ($scannedCount -ge $fileLimit) { break }
        
        $fullPath = Join-Path $RepoRoot $relPath
        if (-not (Test-Path $fullPath)) { continue }
        
        $scannedCount++
        $lines = Get-Content $fullPath -ErrorAction SilentlyContinue
        if (-not $lines) { continue }
        
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            
            # Check for secrets
            if ($Scope -in @('full', 'constitution')) {
                foreach ($sp in $secretPatterns) {
                    if ($line -match $sp.pattern) {
                        $patterns.security.hardcoded_secrets += @{
                            file = $relPath
                            line = $lineNum
                            type = $sp.name
                            snippet = $line.Trim().Substring(0, [Math]::Min(80, $line.Trim().Length))
                        }
                        break
                    }
                }
                
                foreach ($ip in $insecurePatterns) {
                    if ($line -match $ip.pattern) {
                        $patterns.security.insecure_patterns += @{
                            file = $relPath
                            line = $lineNum
                            type = $ip.name
                        }
                        break
                    }
                }
            }
            
            # Check for TODOs
            if ($Scope -in @('full', 'quality')) {
                if ($line -match $todoPattern) {
                    $patterns.quality.todo_comments += @{
                        file = $relPath
                        line = $lineNum
                        type = $matches[1].ToUpper()
                        text = $matches[2].Trim().Substring(0, [Math]::Min(60, $matches[2].Trim().Length))
                    }
                }
            }
        }
    }
    
    return $patterns
}

function Get-ConstitutionInfo {
    param([string]$RepoRoot)
    
    $constitutionPath = Join-Path $RepoRoot '.documentation/memory/constitution.md'
    $info = @{
        exists = $false
        path = '.documentation/memory/constitution.md'
        principles = @()
        version = $null
    }
    
    if (Test-Path $constitutionPath) {
        $info.exists = $true
        $content = Get-Content $constitutionPath -Raw -ErrorAction SilentlyContinue
        
        # Extract principles (look for ### headers under Core Principles)
        $principleMatches = [regex]::Matches($content, '###\s+(.+?)[\r\n]')
        foreach ($match in $principleMatches) {
            $info.principles += $match.Groups[1].Value.Trim()
        }
        
        # Extract version
        if ($content -match '\*\*Version\*\*:\s*([^\|]+)') {
            $info.version = $matches[1].Trim()
        }
    }
    
    return $info
}

function Get-SampledItems {
    param(
        [array]$Items,
        [int]$Limit
    )

    if (-not $Items) {
        return @()
    }

    return @($Items | Select-Object -First $Limit)
}

# Main execution
$repoRoot = Get-RepoRoot
$constitutionInfo = Get-ConstitutionInfo -RepoRoot $repoRoot

# Build result object
$result = @{
    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    scope = $Scope
    repo_root = $repoRoot
    constitution = $constitutionInfo
    audit_dir = '.documentation/copilot/audit'
}

# Get file categories (always needed for context)
$fileCategories = Get-FileCategories -RepoRoot $repoRoot
$result.files = @{
    source = Get-SampledItems -Items $fileCategories.source -Limit $SampleLimit
    config = Get-SampledItems -Items $fileCategories.config -Limit $SampleLimit
    documentation = Get-SampledItems -Items $fileCategories.documentation -Limit $SampleLimit
    tests = Get-SampledItems -Items $fileCategories.tests -Limit $SampleLimit
    scripts = Get-SampledItems -Items $fileCategories.scripts -Limit $SampleLimit
    build = Get-SampledItems -Items $fileCategories.build -Limit $SampleLimit
    counts = @{
        source = $fileCategories.source.Count
        config = $fileCategories.config.Count
        documentation = $fileCategories.documentation.Count
        tests = $fileCategories.tests.Count
        scripts = $fileCategories.scripts.Count
        build = $fileCategories.build.Count
    }
}

if ($IncludeFullInventory) {
    $result.files.full_inventory = @{
        source = $fileCategories.source
        config = $fileCategories.config
        documentation = $fileCategories.documentation
        tests = $fileCategories.tests
        scripts = $fileCategories.scripts
        build = $fileCategories.build
    }
}

# Get package info (if scope includes packages)
if ($Scope -in @('full', 'packages')) {
    $result.packages = Get-PackageInfo -RepoRoot $repoRoot
}

# Get code metrics (if scope includes quality)
if ($Scope -in @('full', 'quality')) {
    $result.metrics = Get-CodeMetrics -RepoRoot $repoRoot -SourceFiles $fileCategories.source

    $allLargeFiles = @($result.metrics.large_files)
    $result.metrics.large_files_total = $allLargeFiles.Count
    if (-not $IncludeFullInventory) {
        $result.metrics.large_files = Get-SampledItems -Items $allLargeFiles -Limit $LargeFileLimit
    }
}

# Get pattern detection (security, quality patterns)
if ($Scope -in @('full', 'constitution', 'quality', 'unused')) {
    $result.patterns = Get-PatternDetection -RepoRoot $repoRoot -SourceFiles $fileCategories.source -Scope $Scope

    $allHardcodedSecrets = @($result.patterns.security.hardcoded_secrets)
    $allInsecurePatterns = @($result.patterns.security.insecure_patterns)
    $allTodoComments = @($result.patterns.quality.todo_comments)

    $result.patterns.security.hardcoded_secrets_total = $allHardcodedSecrets.Count
    $result.patterns.security.insecure_patterns_total = $allInsecurePatterns.Count
    $result.patterns.quality.todo_comments_total = $allTodoComments.Count

    if (-not $IncludeFullInventory) {
        $result.patterns.security.hardcoded_secrets = Get-SampledItems -Items $allHardcodedSecrets -Limit $PatternSampleLimit
        $result.patterns.security.insecure_patterns = Get-SampledItems -Items $allInsecurePatterns -Limit $PatternSampleLimit
        $result.patterns.quality.todo_comments = Get-SampledItems -Items $allTodoComments -Limit $PatternSampleLimit
    }
}

$result.pre_scan_limits = @{
    include_full_inventory = [bool]$IncludeFullInventory
    sample_limit = $SampleLimit
    large_file_limit = $LargeFileLimit
    pattern_sample_limit = $PatternSampleLimit
}

# Output
if ($OutputFormat -eq 'json') {
    # Use multiline JSON to avoid large single-line rendering overhead in chat UI.
    $result | ConvertTo-Json -Depth 10
} else {
    # Summary format
    Write-Output "Site Audit Pre-Scan Summary"
    Write-Output "=========================="
    Write-Output "Repository: $repoRoot"
    Write-Output "Scope: $Scope"
    Write-Output "Constitution: $(if ($constitutionInfo.exists) { 'Found' } else { 'MISSING' })"
    Write-Output ""
    Write-Output "File Counts:"
    Write-Output "  Source files: $($fileCategories.source.Count)"
    Write-Output "  Config files: $($fileCategories.config.Count)"
    Write-Output "  Documentation: $($fileCategories.documentation.Count)"
    Write-Output "  Test files: $($fileCategories.tests.Count)"
    Write-Output "  Scripts: $($fileCategories.scripts.Count)"
    Write-Output "  Build files: $($fileCategories.build.Count)"
    
    if ($result.packages) {
        Write-Output ""
        Write-Output "Package Manager: $($result.packages.manager ?? 'None detected')"
        if ($result.packages.dependencies.direct) {
            Write-Output "  Direct deps: $($result.packages.dependencies.direct.Count)"
        }
    }
    
    if ($result.metrics) {
        Write-Output ""
        Write-Output "Code Metrics:"
        Write-Output "  Total lines: $($result.metrics.total_lines)"
        Write-Output "  Avg lines/file: $($result.metrics.avg_lines_per_file)"
        Write-Output "  Large files (>500 lines): $($result.metrics.large_files.Count)"
    }
    
    if ($result.patterns) {
        Write-Output ""
        Write-Output "Pattern Detection:"
        Write-Output "  Potential secrets: $($result.patterns.security.hardcoded_secrets.Count)"
        Write-Output "  Insecure patterns: $($result.patterns.security.insecure_patterns.Count)"
        Write-Output "  TODO/FIXME comments: $($result.patterns.quality.todo_comments.Count)"
    }
}
