# Dependency & Security Resolution Plan
**Date**: February 3, 2026  
**Repository**: markhazleton/UISampleSpark

## Executive Summary

5 open Dependabot PRs require resolution - 3 GitHub Actions updates for Node.js 24 compatibility and 2 NuGet package updates (1 duplicate). All updates are non-breaking patch/minor versions with no security vulnerabilities identified.

## Current Status

### Open Pull Requests

| PR # | Type | Description | Status | Priority |
|------|------|-------------|--------|----------|
| #82 | NuGet | Swashbuckle.AspNetCore.SwaggerGen 10.1.0 → 10.1.1 | Pending | **CLOSE** (Duplicate) |
| #81 | NuGet | Swashbuckle.AspNetCore & SwaggerGen 10.1.0 → 10.1.1 | Pending | HIGH - Merge After CI Fix |
| #80 | Actions | upload-artifact v5 → v6 (Node.js 24) | Pending | HIGH - Merge First |
| #79 | Actions | cache v4 → v5 (Node.js 24) | Pending | HIGH - Merge Second |
| #78 | Actions | download-artifact v6 → v7 (Node.js 24) | Pending | HIGH - Merge Third |

### Workflow Analysis

**Current Versions in Use:**
- `.github/workflows/main_samplecrud.yml`: actions/cache@v4, actions/upload-artifact@v5, actions/download-artifact@v6
- `.github/workflows/docker-image.yml`: actions/cache@v4

**Target Versions (After PRs merge):**
- actions/cache@v5 (Node.js 24)
- actions/upload-artifact@v6 (Node.js 24)
- actions/download-artifact@v7 (Node.js 24)

## Resolution Strategy

### Phase 1: Workflow Updates (Update workflow files first to prevent CI failures)

**Action Required**: Update workflow files to use new action versions

```yaml
# Changes needed in main_samplecrud.yml:
- uses: actions/cache@v5  # Changed from v4
- uses: actions/upload-artifact@v6  # Changed from v5
- uses: actions/download-artifact@v7  # Changed from v6

# Changes needed in docker-image.yml:
- uses: actions/cache@v5  # Changed from v4
```

**Rationale**: 
- Prevents CI failures when merging action update PRs
- All new versions require Actions Runner 2.327.1+ for Node.js 24 support
- Self-hosted runners must be updated before merging (using GitHub-hosted: ✅)

### Phase 2: Resolve Duplicate PRs

**Action**: Close PR #82 as duplicate of PR #81

**Reason**: 
- PR #81 updates both `Swashbuckle.AspNetCore` AND `Swashbuckle.AspNetCore.SwaggerGen`
- PR #82 only updates `Swashbuckle.AspNetCore.SwaggerGen`
- PR #81 is more comprehensive and should be preferred

### Phase 3: Merge Sequence (After workflow updates)

**Recommended Merge Order:**

1. **PR #79** (actions/cache@v5)
   - Base dependency for other actions
   - Used by both workflows
   
2. **PR #80** (actions/upload-artifact@v6)  
   - Required by main_samplecrud.yml build job
   
3. **PR #78** (actions/download-artifact@v7)
   - Required by main_samplecrud.yml deploy job
   - Depends on upload-artifact being updated first
   
4. **PR #81** (Swashbuckle updates)
   - Low risk patch update (10.1.0 → 10.1.1)
   - Adds cache headers to Swagger document URLs

### Phase 4: Verification

**Post-Merge Checklist:**
- [ ] All PRs merged successfully
- [ ] CI workflows pass on main branch
- [ ] Azure deployment succeeds
- [ ] Docker image builds and passes Trivy scan
- [ ] No new Dependabot PRs immediately created
- [ ] Application health checks pass

## Security Considerations

### Current Security Posture

✅ **No Critical Issues Found**
- Trivy vulnerability scanner configured in CI
- Results uploaded to GitHub Security tab
- No open security issues in repository

### Updated Package Security Notes

**Swashbuckle.AspNetCore 10.1.1** (from 10.1.0):
- Changes: Adds cache headers to document URLs endpoint  
- Security Impact: None - performance improvement only
- Breaking Changes: None
- Compatibility: Fully backward compatible

**GitHub Actions Node.js 24 Updates**:
- Changes: Runtime upgrade from Node.js 20 to Node.js 24
- Security Impact: Positive - newer runtime with security patches
- Breaking Changes: Requires Actions Runner 2.327.1+ (GitHub-hosted runners: ✅)
- Compatibility: Actions designed for backward compatibility

## Implementation Steps

### Step 1: Update Workflow Files

```bash
# Option A: Update files manually (recommended for review)
# Edit .github/workflows/main_samplecrud.yml
# Edit .github/workflows/docker-image.yml
# Commit and push to main branch

# Option B: Use automation (if comfortable with direct commits)
# Create feature branch, update, PR, and merge
```

### Step 2: Close Duplicate PR

```bash
# Via GitHub Web UI or API:
# Navigate to PR #82
# Comment: "Closing as duplicate of #81 which provides more comprehensive update"
# Click "Close pull request"
```

### Step 3: Test CI Before Merging

**Recommended**: Create a test branch to validate workflow changes
```bash
git checkout -b test/workflow-updates
# Make workflow changes
git commit -am "ci: update GitHub Actions to Node.js 24 compatible versions"
git push origin test/workflow-updates
# Create PR and verify CI passes
```

### Step 4: Merge PRs in Sequence

**For each PR in order (#79, #80, #78, #81):**
1. Review changes one final time
2. Ensure CI passes (if running)
3. Click "Merge pull request"
4. Use "Squash and merge" for clean history
5. Delete branch after merge
6. Wait 30 seconds before next merge

### Step 5: Monitor & Verify

```bash
# After all merges, verify main branch health:
git pull origin main
dotnet restore
dotnet build
dotnet test

# Check GitHub Actions runs:
# Visit: https://github.com/markhazleton/UISampleSpark/actions
# Verify latest runs on main branch pass

# Check Azure deployment:
# Visit: https://samplecrud.azurewebsites.net
# Verify application responds
```

## Rollback Plan

If issues arise after merging:

**Immediate Rollback:**
```bash
# Revert specific commits
git revert <commit-sha>
git push origin main
```

**Full Rollback:**
```bash
# Reset to last known good commit
git reset --hard <last-good-commit-sha>
git push origin main --force
```

**Action Version Pinning** (if Node.js 24 causes issues):
- Pin actions to previous major versions in workflow files
- Close remaining Dependabot PRs with comment explaining decision

## Timeline Estimate

- **Phase 1** (Workflow Updates): 15-30 minutes
- **Phase 2** (Close Duplicate): 2 minutes
- **Phase 3** (Merge PRs): 15-20 minutes (5 minutes per PR)
- **Phase 4** (Verification): 10-15 minutes
- **Total**: ~45-70 minutes

## Future Recommendations

### Dependabot Configuration Optimization

Current config is well-structured. Consider adding:

```yaml
# Add to .github/dependabot.yml for auto-merge of low-risk updates:
auto-merge:
  - match:
      dependency-type: "all"
      update-type: "semver:patch"
```

### CI/CD Enhancements

1. **Add Status Checks**: Ensure PRs require passing CI before merge
2. **Auto-merge Low-Risk PRs**: Configure Dependabot auto-merge for patch updates
3. **Scheduled Security Scans**: Consider CodeQL for C# code analysis

### Monitoring

1. **GitHub Security Alerts**: Enable notifications for new vulnerabilities
2. **Weekly Dependency Review**: Review Dependabot PRs every Tuesday morning
3. **Quarterly Audit**: Full dependency audit every 3 months

## Contacts & Resources

- **Repository Owner**: @markhazleton
- **Dependabot Docs**: https://docs.github.com/en/code-security/dependabot
- **GitHub Actions Node.js 24**: https://github.blog/changelog/2024-12-04-github-actions-node-js-24-support/
- **Azure Web App**: SampleCRUD (Production environment)

## Approval & Sign-off

- [ ] Plan reviewed and approved
- [ ] Maintenance window scheduled (if needed): ________________
- [ ] Stakeholders notified: ________________
- [ ] Rollback plan confirmed: ________________
- [ ] Execution started: ________________
- [ ] Verification completed: ________________

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-03  
**Next Review**: After PR resolution completion
