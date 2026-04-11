#!/usr/bin/env pwsh
# Platform detection and adapter for DevSpark scripts
# Detects GitHub, Azure DevOps, or GitLab and exports platform-specific values.
#
# Usage: . "$PSScriptRoot/platform.ps1"
#        Then use $DevSparkPlatform.Name, $DevSparkPlatform.PrCli, etc.
#
# Override: Set DEVSPARK_PLATFORM env var to force a platform (github|azdo|gitlab)
# Config:   Or set "platform" in .documentation/devspark.json

# Load common if not already loaded
if (-not (Get-Command Get-RepoRoot -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot/common.ps1"
}

function Detect-Platform {
    # 1. Explicit env var override
    if ($env:DEVSPARK_PLATFORM) {
        return $env:DEVSPARK_PLATFORM.ToLower()
    }

    # 2. Config file override
    $repoRoot = Get-RepoRoot
    $configFile = Join-Path $repoRoot '.documentation/devspark.json'
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            if ($config.platform) {
                return $config.platform.ToLower()
            }
        } catch {
            # Invalid JSON, continue detection
        }
    }

    # 3. CI environment variable detection
    if ($env:GITHUB_ACTIONS -or $env:GITHUB_REPOSITORY) {
        return 'github'
    }
    if ($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI -or $env:BUILD_REPOSITORY_PROVIDER) {
        return 'azdo'
    }
    if ($env:GITLAB_CI -or $env:CI_PROJECT_ID) {
        return 'gitlab'
    }

    # 4. Repository structure detection
    if (Test-Path (Join-Path $repoRoot '.github')) {
        return 'github'
    }
    if (Test-Path (Join-Path $repoRoot 'azure-pipelines.yml')) {
        return 'azdo'
    }
    if (Test-Path (Join-Path $repoRoot '.gitlab-ci.yml')) {
        return 'gitlab'
    }

    # 5. Remote URL detection
    try {
        $remoteUrl = git remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and $remoteUrl) {
            if ($remoteUrl -match 'github\.com') { return 'github' }
            if ($remoteUrl -match 'dev\.azure\.com|visualstudio\.com') { return 'azdo' }
            if ($remoteUrl -match 'gitlab\.com|gitlab\.' ) { return 'gitlab' }
        }
    } catch { }

    return 'github'  # Default fallback
}

function Get-PlatformConfig {
    param([string]$PlatformName)

    switch ($PlatformName) {
        'github' {
            [PSCustomObject]@{
                Name             = 'github'
                DisplayName      = 'GitHub'
                PrCli            = 'gh'
                PrCliInstallUrl  = 'https://cli.github.com/'
                CiDir            = '.github/workflows'
                CiFilePattern    = '*.yml'
                AgentConfigPath  = '.github/agents/copilot-instructions.md'
                BranchNameLimit  = 244
                PrEnvVar         = 'GITHUB_PR_NUMBER'
                AuthCheck        = { gh auth status 2>$null; $LASTEXITCODE -eq 0 }
            }
        }
        'azdo' {
            [PSCustomObject]@{
                Name             = 'azdo'
                DisplayName      = 'Azure DevOps'
                PrCli            = 'az'
                PrCliInstallUrl  = 'https://learn.microsoft.com/en-us/cli/azure/install-azure-cli'
                CiDir            = '.'
                CiFilePattern    = 'azure-pipelines*.yml'
                AgentConfigPath  = '.github/agents/copilot-instructions.md'
                BranchNameLimit  = 250
                PrEnvVar         = 'SYSTEM_PULLREQUEST_PULLREQUESTID'
                AuthCheck        = { az account show 2>$null | Out-Null; $LASTEXITCODE -eq 0 }
            }
        }
        'gitlab' {
            [PSCustomObject]@{
                Name             = 'gitlab'
                DisplayName      = 'GitLab'
                PrCli            = 'glab'
                PrCliInstallUrl  = 'https://gitlab.com/gitlab-org/cli#installation'
                CiDir            = '.'
                CiFilePattern    = '.gitlab-ci.yml'
                AgentConfigPath  = '.github/agents/copilot-instructions.md'
                BranchNameLimit  = 255
                PrEnvVar         = 'CI_MERGE_REQUEST_IID'
                AuthCheck        = { glab auth status 2>$null; $LASTEXITCODE -eq 0 }
            }
        }
        default {
            throw "Unknown platform: $PlatformName. Supported: github, azdo, gitlab"
        }
    }
}

# Auto-detect and export on source
$script:DevSparkPlatformName = Detect-Platform
$script:DevSparkPlatform = Get-PlatformConfig -PlatformName $script:DevSparkPlatformName

# Resolve script path: team override in .documentation/scripts/ takes priority
function Resolve-DevSparkScript {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptName,
        [ValidateSet('powershell', 'bash')]
        [string]$Shell = 'powershell'
    )

    $repoRoot = Get-RepoRoot
    $teamPath = Join-Path $repoRoot ".documentation/scripts/$Shell/$ScriptName"
    $stockPath = Join-Path $repoRoot ".devspark/scripts/$Shell/$ScriptName"
    $devPath = Join-Path $repoRoot "scripts/$Shell/$ScriptName"

    if (Test-Path $teamPath)  { return $teamPath }
    if (Test-Path $stockPath) { return $stockPath }
    if (Test-Path $devPath)   { return $devPath }

    return $null
}
