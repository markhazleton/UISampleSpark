---
description: Perform constitution-aware pull request review with actionable feedback for any PR in the repository
handoffs:
  - label: View Review History
    agent: devspark.pr-review
    prompt: Show me previous PR reviews in .documentation/specs/pr-review/
scripts:
  sh: .devspark/scripts/bash/get-pr-context.sh $ARGUMENTS --json
  ps: .devspark/scripts/powershell/get-pr-context.ps1 $ARGUMENTS -Json
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Overview

This command reviews GitHub Pull Requests against the project constitution. It works for **any PR in the repository** regardless of feature branch or target branch. Reviews are stored in `/.documentation/specs/pr-review/pr-{id}.md` for historical reference.

**IMPORTANT**: This command **only provides suggestions** - it does not make any code changes.

Reviews are advisory. The agent must explain constitution or lifecycle issues, recommend a disposition, and let the human decide the next action.

`/devspark.create-pr` is the preferred predecessor for spec-driven work because it collects task, checklist, and gate context before review. If the PR was created manually, continue with review but call out any missing lifecycle context.

## Prerequisites

- Project constitution at `/.documentation/memory/constitution.md` (REQUIRED)
- GitHub repository with PR context
- GitHub CLI (`gh`) installed and authenticated (required)
- **HARD RULE — Branch Sync**: The source (head) branch **MUST** be fully in sync with the target (base) branch. Do **NOT** proceed with review or approval if the source branch is behind the target. Instruct the user to rebase or merge the target branch into the source branch first.

## Outline

### 1. Initialize Review Context

Run `{SCRIPT}` to extract PR context and parse JSON output for:

- `PR_CONTEXT`: PR metadata (number, title, branches, commit SHA, files, diff)
- `CONSTITUTION_PATH`: Path to constitution file
- `REVIEW_DIR`: Directory where review will be saved

Treat script JSON as bounded context:

- `files_changed` may be sampled for large PRs.
- Use `files_changed_total` and `files_changed_truncated` to decide whether to zoom in further.
- Do not expand to all files unless user explicitly requests a full exhaustive review.

Execution limits (required):

- Max findings in report: 7 highest-signal items
- Max files to inspect deeply: 25
- Max follow-up searches/reads beyond provided context: 8
- Stop once evidence is sufficient for high-confidence conclusions
- If confidence is low for a specific area, ask one clarifying question

**PR Number Detection**:
The script will try to determine PR number in this order:

1. User explicitly provides PR number in arguments: `#123` or `123`
2. GitHub environment variables: `GITHUB_PR_NUMBER`, `PR_NUMBER`
3. Current branch PR detection via `gh pr view`
4. If unable to detect, the script will error with clear instructions

**Error Handling**:
If the script fails:

- **Constitution missing**: Guide user to run `/devspark.constitution`
- **GitHub CLI not installed**: Provide installation instructions
- **PR not found**: Ask user to verify PR number and `gh auth status`
- **No PR number**: Ask user to provide PR number explicitly
- **Branch out of sync** (`is_behind_target: true`): **STOP immediately.** Do not review or approve. Inform the user:
  > "BLOCKED: The source branch `{source_branch}` is behind target branch `{target_branch}`. Sync it first before this PR can be reviewed or approved."
  > Suggested fix: `gh pr update-branch {PR_NUMBER}` or `git fetch origin && git rebase origin/{target_branch}`

For single quotes in args like "I'm reviewing", use escape syntax: e.g 'I'\''m reviewing' (or double-quote if possible: "I'm reviewing").

### 2. Load Constitution

Read and parse `/.documentation/memory/constitution.md`:

- Extract all core principles with their names
- Identify MUST requirements (non-negotiable/mandatory)
- Identify SHOULD requirements (recommended)
- Note constitution version and amendment date
- Build a checklist of principles to evaluate

If constitution doesn't exist:

- **STOP** and inform user that constitution is required
- Provide guidance: "Run `/devspark.constitution` to create project principles first"
- Do not proceed with review

### 3. Analyze PR Changes

Using the PR_CONTEXT data from the script:

#### A. Review Changed Files

For each file in `files_changed`:

- Read the diff to understand what changed
- Identify the type of change (new file, modified, deleted)
- Note the scope of changes (lines added/removed)
- Extract code snippets for analysis

Prioritization policy:

- If `files_changed_truncated` is true, prioritize risky files first (auth, security, configuration, dependency manifests, migration scripts, CI/CD) before expanding scope.
- Expand beyond sampled files only if necessary to validate a top-severity finding.

#### B. Examine PR Diff

Parse the full diff to:

- Identify new functionality added
- Check for removed functionality
- Look for modified behavior
- Note refactoring vs. feature changes

#### C. Review Commit Messages

- Check if commits follow conventions
- Identify the intent behind changes
- Look for breaking change indicators

### 4. Perform Constitution-Based Review

Start the review with a gate result block:

```yaml
gate: pr-review
status: pass | warn | fail
blocking: true | false
severity: info | warning | error | showstopper
summary: "<concise outcome>"
```

For **each principle** in the constitution:

#### A. Compliance Check

- Review changed files against this specific principle
- Determine if the PR violates, partially complies, or fully complies
- Collect specific evidence (file names, line numbers, code snippets)

#### B. Severity Classification

Based on the principle's importance and violation type:

- **CRITICAL**: Violates mandatory (MUST) principle - blocks merge
- **HIGH**: Violates recommended (SHOULD) principle significantly
- **MEDIUM**: Partial compliance, improvement opportunity
- **LOW**: Style suggestions or minor improvements

For each finding:

- Quote the specific code that demonstrates the issue
- Reference the exact constitution section violated
- Explain clearly why this is an issue
- Provide a specific, actionable recommendation

#### C. Generate Findings

Create structured findings with:

- **ID**: Unique identifier (C1, H1, M1, L1, etc.)
- **Principle**: Name of constitution principle
- **File:Line**: Exact location in code
- **Issue**: Specific description of the problem
- **Recommendation**: Concrete action to resolve

### 5. Additional Review Dimensions

#### Security Analysis

- **Hardcoded Secrets**: Scan for API keys, passwords, tokens in code
- **Input Validation**: Check if user inputs are validated
- **Authentication**: Review auth/authz changes for correctness
- **SQL Injection**: Look for unsafe database queries
- **XSS**: Check for unescaped output in web contexts
- **Dependency Vulnerabilities**: Note if new dependencies added

Create checklist:

- [ ] No hardcoded secrets or credentials
- [ ] Input validation present where needed
- [ ] Authentication/authorization checks appropriate
- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities
- [ ] Dependencies reviewed for vulnerabilities

#### Code Quality Assessment

If constitution has code quality principles:

- **Naming Conventions**: Verify names follow standards
- **Code Organization**: Check structure matches guidelines
- **Error Handling**: Review exception handling patterns
- **Duplication**: Identify code duplication issues
- **Complexity**: Note overly complex code

Identify:

- **Strengths**: What the PR does well
- **Areas for Improvement**: Specific suggestions

#### Testing Validation

If constitution has testing principles (e.g., TDD):

- Check if tests exist for new/modified code
- Verify test quality and coverage
- Confirm tests were written appropriately
- Review test naming and organization

#### Documentation Review

If constitution requires documentation:

- Check if README updated if needed
- Verify code comments for complex logic
- Confirm API documentation updated
- Check if CHANGELOG updated

### 6. Spec Lifecycle Validation (Required for Feature Branches)

Determine if this PR maps to a feature spec and validate spec lifecycle status:

1. **Detect feature spec**: Extract feature identifier from the source branch name pattern (e.g., `001-feature-name`). Check if `/.documentation/specs/{feature}/spec.md` exists. Also check `SPEC_STATUS` from the PR context script output (if available).

2. **If spec exists**, validate lifecycle completeness:

   a. **Spec Status Check**: Read the `**Status**:` field in spec.md. Valid values are: `Draft`, `In Progress`, `Complete`.
      - If status is `Draft` or `In Progress`: **flag as CRITICAL finding** — spec must be `Complete` before merge.

   b. **Task Completion Check**: Read `/.documentation/specs/{feature}/tasks.md` (if it exists).
      - Count total tasks (lines matching `- [ ]` or `- [x]` or `- [X]`)
      - Count completed tasks (lines matching `- [x]` or `- [X]`)
      - If any tasks are incomplete (`- [ ]`): **flag as CRITICAL finding** — all tasks must be checked off before merge.
      - If tasks.md does not exist but spec.md does: **flag as HIGH finding** — tasks should be generated.

   c. **Cross-reference implementation**:
      - Does implementation match spec requirements?
      - Are acceptance criteria being addressed?
      - Is scope appropriate for the spec?

3. **If no spec exists** for a feature branch (branch name matches `\d+-.*` pattern):
   - **Flag as CRITICAL finding**: Constitution requires features to be spec-driven (Constitution §Development Workflow: "Features must be spec-driven: specify first, plan second, implement third").
   - Block APPROVE recommendation.

4. **If branch is NOT a feature branch** (e.g., hotfix, chore, docs-only): Spec validation is not required. Note this in the review.

5. **Include Spec Lifecycle Summary** in the Executive Summary section:
   - **Spec Status**: [Complete | In Progress | Draft | Missing]
   - **Task Completion**: [X/Y tasks complete | No tasks file | N/A]
   - If spec is not `Complete` or tasks are incomplete, the **Approval Recommendation MUST be ⚠️ REQUEST CHANGES or ❌ REJECT** — never ✅ APPROVE.

### 6b. PR Scope Validation (Multi-App Mode)

If the repository operates in multi-app mode (`.documentation/devspark.json` exists with `mode: "multi-app"`), perform scope validation on the PR:

#### A. Check for Scope Declaration

Look for a PR scope declaration in the PR description or in `.documentation/specs/` artifacts. A scope declaration specifies:

- **mode**: `single-app`, `cross-app`, or `repo-scope`
- **primary_app**: The primary application being changed
- **affected_apps**: All applications intentionally touched by this PR

If no scope declaration is present, infer scope from the changed files:

- If all changed files belong to a single app (plus approved shared paths), infer `single-app` mode.
- If changed files span multiple apps, infer `cross-app` mode.
- If changes are purely in shared/repo-level paths, infer `repo-scope`.

#### B. Validate Scope Against Changed Paths

Using the PR's changed file list and the registry from `.documentation/devspark.json`:

1. Map each changed file to its owning application (by matching `app.path` prefixes).
2. Identify shared paths (`.documentation/`, `.github/`, `.devspark/`, root-level config files).
3. Validate that the changed paths are consistent with the declared (or inferred) scope:
   - **single-app**: Only the declared app's path and approved shared paths should be touched. Flag files in other apps as scope mismatches.
   - **cross-app**: All touched app paths must be listed in `affected_apps`. Flag undeclared app paths.
   - **repo-scope**: All paths are allowed.

#### C. Report Scope Findings

Include scope validation results in the review output:

- If scope is valid, note it in the Executive Summary as a passing check.
- If scope mismatches are detected, report them as **HIGH** severity findings:
  - List which files violate the declared scope.
  - Recommend updating the scope declaration or splitting the PR.
- Add a row to the Constitution Alignment Details table for scope compliance.

### 7. Generate Review Report

Create comprehensive report at `/.documentation/specs/pr-review/pr-{PR_NUMBER}.md`:

#### Handle Existing Reviews

If file already exists:

1. Read the existing file
2. Extract the previous commit SHA from metadata
3. Compare with current commit SHA from PR_CONTEXT
4. **If commit SHA is the same**:
   - Replace the entire file with updated review
   - Keep the original review date, update "Last Updated" date
5. **If commit SHA is different (PR was updated)**:
   - Keep existing content
   - Insert new review at the top
   - Move previous review to "Previous Review History" section at bottom
   - Add clear separators between reviews

#### Report Structure

Use this exact format:

```markdown
# Pull Request Review: [PR_TITLE]

## Review Metadata

- **PR Number**: #[NUMBER]
- **Source Branch**: [HEAD_BRANCH]
- **Target Branch**: [BASE_BRANCH]
- **Review Date**: [YYYY-MM-DD HH:MM:SS UTC]
- **Last Updated**: [YYYY-MM-DD HH:MM:SS UTC]
- **Reviewed Commit**: [COMMIT_SHA]
- **Reviewer**: devspark.pr-review
- **Constitution Version**: [VERSION from constitution]

## PR Summary

- **Author**: [@AUTHOR]
- **Created**: [CREATED_DATE]
- **Status**: [OPEN/CLOSED/MERGED]
- **Files Changed**: [COUNT]
- **Commits**: [COUNT]
- **Lines**: +[ADDITIONS] -[DELETIONS]

## Executive Summary

- ✅ **Constitution Compliance**: [PASS/FAIL] ([X]/[Y] principles checked)
- 📋 **Spec Lifecycle**: [Complete | In Progress | Draft | Missing | N/A (not a feature branch)]
- 📝 **Task Completion**: [X/Y tasks complete | No tasks file | N/A]
- 🔒 **Security**: [X] issues found
- 📊 **Code Quality**: [X] recommendations
- 🧪 **Testing**: [PASS/FAIL/N/A]
- 📝 **Documentation**: [PASS/FAIL/N/A]

**Overall Assessment**: [1-2 sentence summary]

**Approval Recommendation**: [✅ APPROVE | ⚠️ REQUEST CHANGES | ❌ REJECT]
*Note: APPROVE is blocked if Spec Lifecycle is not Complete or tasks are incomplete for feature branches.*

## Critical Issues (Blocking)

[If none, write "None found."]

| ID | Principle | File:Line | Issue | Recommendation |
|----|-----------|-----------|-------|----------------|
| C1 | [Name] | path/file.ext:45 | [Specific violation with code quote] | [Specific action to fix] |

## High Priority Issues

[If none, write "None found."]

| ID | Principle | File:Line | Issue | Recommendation |
|----|-----------|-----------|-------|----------------|
| H1 | [Name] | path/file.ext:67 | [Issue description] | [Action to fix] |

## Medium Priority Suggestions

[If none, write "None found."]

| ID | Principle | File:Line | Issue | Recommendation |
|----|-----------|-----------|-------|----------------|
| M1 | [Name] | path/file.ext:89 | [Suggestion] | [Improvement] |

## Low Priority Improvements

[If none, write "None found."]

| ID | Principle | File:Line | Issue | Recommendation |
|----|-----------|-----------|-------|----------------|
| L1 | [Name] | path/file.ext:123 | [Minor suggestion] | [Optional improvement] |

## Constitution Alignment Details

| Principle | Status | Evidence | Notes |
|-----------|--------|----------|-------|
| [Principle 1] | ✅ Pass | Files comply | [Brief explanation] |
| [Principle 2] | ❌ Fail | src/api.ts:45 | [Why it fails] |
| [Principle 3] | ⚠️ Partial | Multiple files | [Partial compliance details] |
| [Principle 4] | ⏭️ N/A | - | Not applicable to this PR |

## Security Checklist

- [ ] No hardcoded secrets or credentials
- [ ] Input validation present where needed
- [ ] Authentication/authorization checks appropriate
- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities
- [ ] Dependencies reviewed for vulnerabilities

[Add notes for any checked/unchecked items]

## Code Quality Assessment

### Strengths
- [Positive aspect 1]
- [Positive aspect 2]

### Areas for Improvement
- [Specific improvement 1]
- [Specific improvement 2]

## Testing Coverage

**Status**: [ADEQUATE | INADEQUATE | N/A]

[Details about test coverage, or "N/A - No testing principle in constitution"]

## Documentation Status

**Status**: [ADEQUATE | INADEQUATE | N/A]

[Details about documentation, or "N/A - No documentation principle in constitution"]

## Changed Files Summary

| File | Changes | Type | Constitution Issues |
|------|---------|------|---------------------|
| src/api.ts | +45 -12 | Modified | 2 issues (C1, H1) |
| tests/api.test.ts | +120 -0 | Added | None |
| README.md | +8 -2 | Modified | None |

## Detailed Findings by File

[For each file with issues, provide detailed explanation]

### src/api.ts

**Lines 45-67**: [Issue description]
```javascript
// Quote the problematic code here
const apiKey = "hardcoded-secret-key";
```

- **Principle Violated**: Security - No hardcoded credentials
- **Severity**: CRITICAL
- **Recommendation**: Move API key to environment variable: `process.env.API_KEY`

[Continue for each significant finding]

## Next Steps

### Immediate Actions (Required)

[If critical issues exist]

- [ ] [Action 1 - reference issue ID]
- [ ] [Action 2 - reference issue ID]

[If no critical issues]
No immediate blocking actions required.

### Recommended Improvements

- [ ] [Improvement 1 - reference issue ID]
- [ ] [Improvement 2 - reference issue ID]

### Future Considerations (Optional)

- [ ] [Enhancement 1]
- [ ] [Enhancement 2]

## Approval Decision

**Recommendation**: [✅ APPROVE | ⚠️ REQUEST CHANGES | ❌ REJECT]

**Reasoning**:
[Provide clear reasoning based on findings. Examples:

- "PR violates mandatory Test-First principle (C1). Must add tests before merge."
- "No critical issues found. Minor suggestions provided but not blocking."
- "Excellent PR - follows all constitution principles and includes comprehensive tests."]

**Estimated Rework Time**: [X hours | X days | N/A]

---

*Review generated by devspark.pr-review v1.0*
*Constitution-driven code review for [PROJECT_NAME]*
*To update this review after changes: `/devspark.pr-review #[PR_NUMBER]`*

---

## Previous Review History

[If this is an updated review, previous reviews go here]

### Review 2: 2026-01-24 10:30:00 UTC

**Commit**: abc123def

[Summary of previous review or full previous review content]

### Review 1: 2026-01-23 14:15:00 UTC

**Commit**: 789xyz012

[Summary of first review]

```text
End of report template
```

### 8. Create Review Directory

Ensure `/.documentation/specs/pr-review/` directory exists:

- Check if directory exists
- Create it if it doesn't (including parent `/.documentation/specs/` if needed)
- Set appropriate permissions

### 9. Write Review File

Write the generated report to `/.documentation/specs/pr-review/pr-{PR_NUMBER}.md`:

- Use UTF-8 encoding
- Ensure proper line endings
- Make file readable

### 10. Output Summary to User

Display concise summary to the user:

```text
✅ PR Review Complete!

📄 Review saved: /.documentation/specs/pr-review/pr-{NUMBER}.md
🔍 Reviewed commit: {COMMIT_SHA}
📅 Review date: {DATETIME}

Executive Summary:
- [Status emoji] {COUNT} Critical issues
- [Status emoji] {COUNT} High priority
- [Status emoji] {COUNT} Medium priority
- [Status emoji] {COUNT} Low priority

Recommendation: {APPROVE/REQUEST CHANGES/REJECT}

{If critical issues:}
Critical issues must be resolved before merge:
- C1: {Brief description}
- C2: {Brief description}

View full review: /.documentation/specs/pr-review/pr-{NUMBER}.md
```

## Guidelines

### Constitution Authority

The constitution is **non-negotiable** and the **authoritative source** for all review criteria.

All findings must:

- Reference the specific constitution section (by principle name)
- Quote the exact constitution language (MUST/SHOULD/etc.)
- Explain how the code violates or complies with the principle
- Use the constitution's own terminology and standards

### Evidence-Based Feedback

Every issue must include:

- **Specific location**: File path and line number (not "multiple files" or "various places")
- **Code quote**: Actual code snippet showing the issue (2-5 lines of context)
- **Constitution reference**: Which principle is violated and why
- **Actionable recommendation**: Specific fix with example if possible

**Bad example**: "Code has issues with naming"
**Good example**: "src/api.ts:45 - Variable `x` violates naming principle 'Use descriptive names'. Rename to `userApiKey`."

### Review Objectivity

- Focus on facts, not opinions or style preferences
- Base all feedback on constitution principles
- Avoid subjective language ("ugly code", "bad design")
- If not in constitution, don't flag it (or mark as LOW priority observation)

### Severity Guidelines

Use these criteria for classification:

- **CRITICAL**: Violates MUST principle, blocks functionality, security risk, breaks production
- **HIGH**: Violates SHOULD principle significantly, quality concerns, technical debt
- **MEDIUM**: Partial compliance, improvement opportunity, maintainability concern
- **LOW**: Style preference, minor optimization, optional enhancement

### Graceful Error Handling

**If constitution missing**:

```text
❌ Cannot perform PR review - Constitution required

The project constitution defines the review criteria. Create one first:

1. Run: /devspark.constitution
2. Define your project's core principles
3. Then retry: /devspark.pr-review #{PR_NUMBER}

Learn more: <https://github.com/MarkHazleton/devspark>
```

**If PR not found**:

```text
❌ PR #{NUMBER} not found

Troubleshooting:
1. Check the PR number is correct
2. Verify GitHub CLI authentication: gh auth status
3. Confirm you have repository access

If issue persists, provide PR number explicitly:
/devspark.pr-review #123
```

**If GitHub CLI not installed**:

```text
❌ GitHub CLI (gh) required but not installed

Install GitHub CLI:
- macOS: brew install gh
- Windows: winget install --id GitHub.cli
- Linux: <https://github.com/cli/cli#installation>

After installation, authenticate:
gh auth login

Then retry: /devspark.pr-review
```

### Positive Feedback

If PR is excellent:

- Acknowledge good practices
- Call out strengths specifically
- Provide enthusiastic approval
- Example: "Excellent PR! Comprehensive tests, clear documentation, follows all constitution principles. Strong work! ✅"

### Review Updates

When re-reviewing an updated PR:

- Explicitly note what changed since last review
- Acknowledge fixed issues: "✅ Fixed: C1 (tests added)"
- Note new issues introduced: "⚠️ New: H3 (missing validation)"
- Compare commit SHAs and summarize delta

## Context

$ARGUMENTS
