---
description: Archive development artifacts at release, distill key decisions into permanent documentation, and prepare for next development cycle
handoffs:
  - label: View Release History
    agent: speckit.release
    prompt: Show me previous releases in .documentation/releases/
  - label: Run Final Audit
    agent: speckit.site-audit
    prompt: Run a final site audit before release
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Overview

This command performs release documentation by:

1. Archiving completed development artifacts (specs, plans, tasks)
2. Distilling key architectural decisions into ADRs (Architecture Decision Records)
3. Generating CHANGELOG entries
4. Creating release notes
5. Preparing a clean slate for the next development cycle

**IMPORTANT**: This command modifies documentation files. Use `--dry-run` to preview changes before committing.

## Prerequisites

- Git repository with version tags (recommended)
- Completed feature specs in `/.documentation/specs/`
- Quickfixes in `/.documentation/quickfixes/` (optional)

## Options

Parse `$ARGUMENTS` for options:

| Option | Description |
|--------|-------------|
| `{version}` | Explicit version (e.g., `2.0.0` or `v2.0.0`) |
| `--dry-run` | Preview changes without writing files |

## Outline

### 1. Initialize Release Context

Run `.documentation/scripts/powershell/release-context.ps1 $ARGUMENTS -Json` to gather context and parse JSON output for:

- `REPO_ROOT`: Repository root path
- `SPECS_DIR`: Path to specs directory
- `RELEASES_DIR`: Path to releases archive
- `QUICKFIX_DIR`: Path to quickfixes directory
- `DECISIONS_DIR`: Path to ADR directory
- `CURRENT_VERSION`: Current version from package file
- `VERSION_SOURCE`: Where version was read from
- `NEXT_VERSION`: Proposed next version
- `VERSION_BUMP`: Type of bump (major/minor/patch)
- `COMPLETED_SPECS`: List of specs ready for archival
- `PENDING_SPECS`: List of incomplete specs
- `QUICKFIXES`: List of quickfixes since last release
- `LAST_TAG`: Most recent git tag
- `LAST_RELEASE_DATE`: Date of last release
- `COMMITS_SINCE_RELEASE`: Commit count since last release
- `CONTRIBUTORS`: List of contributors
- `DRY_RUN`: Whether this is a preview run
- `SPECKIT_VERSION_PATH`: Path to `.documentation/SPECKIT_VERSION`
- `INSTALLED_VERSION`: Version recorded in the stamp file (blank if absent)

### 2. Version Confirmation

Display proposed version:

```markdown
## Release Version

- **Current Version**: {CURRENT_VERSION} (from {VERSION_SOURCE})
- **Proposed Version**: {NEXT_VERSION} ({VERSION_BUMP} bump)
- **Reason**: {N} completed specs, {M} quickfixes

Confirm this version or provide explicit version:
- To accept: continue
- To change: `/speckit.release {version}`
```

**Version Bump Logic:**

| Content | Bump Type | Example |
|---------|-----------|---------|
| Completed feature specs | Minor | 1.2.4 → 1.3.0 |
| Quickfixes only | Patch | 1.2.4 → 1.2.5 |
| Breaking changes in specs | Major | 1.2.4 → 2.0.0 |

### 3. Classify Artifacts

#### A. Completed Specs (Ready for Archive)

For each spec in COMPLETED_SPECS:

- Verify all tasks are checked in `tasks.md`
- Confirm associated PR merged (if trackable)
- Mark for archival

#### B. Pending Specs (Keep Active)

For each spec in PENDING_SPECS:

- Keep in `/.documentation/specs/`
- Note as "Deferred to next release"
- Include in release notes as "Coming Soon"

#### C. Quickfixes

All quickfixes in QUICKFIXES:

- Archive to release directory
- Include in CHANGELOG under "Fixed"

### 4. Extract Architectural Decisions

For each completed spec, analyze `research.md` and `plan.md` for ADR-worthy decisions:

**ADR Criteria:**

- Technology stack choices (frameworks, databases, libraries)
- Architecture pattern decisions (microservices, event-driven, etc.)
- Security or compliance decisions
- Performance trade-offs
- Integration approaches

**Skip:**

- Implementation details
- Bug fixes
- Minor configuration choices

For each identified decision, create ADR at `/.documentation/decisions/ADR-{NNN}.md`:

```markdown
# ADR-{NNN}: {Decision Title}

## Status

Accepted

## Context

{Why this decision was needed - extracted from spec/research}

## Decision

{What was decided - extracted from plan}

## Consequences

### Positive

- {Benefit 1}
- {Benefit 2}

### Negative

- {Trade-off 1}

## Source

- **Spec**: {spec-name}
- **Release**: v{NEXT_VERSION}
- **Date**: {RELEASE_DATE}
```

### 5. Generate CHANGELOG Entry

Create or update `CHANGELOG.md` at repository root:

```markdown
## [v{NEXT_VERSION}] - {RELEASE_DATE}

### Added

{For each completed spec with new features:}
- **{Feature Name}**: {Brief description from spec}

### Changed

{For each completed spec with modifications:}
- **{Change Name}**: {Brief description}

### Fixed

{For each quickfix:}
- **{QF-ID}**: {Problem fixed}

### Architectural Decisions

{For each ADR created:}
- **ADR-{NNN}**: {Decision title}

### Contributors

{List each contributor from CONTRIBUTORS}
```

**If CHANGELOG.md exists:**

- Insert new entry at the top (after header)
- Preserve existing entries

**If CHANGELOG.md doesn't exist:**

- Create with header and first entry

### 6. Create Release Archive

Create directory structure at `/.documentation/releases/v{NEXT_VERSION}/`:

```text
releases/v{NEXT_VERSION}/
├── release-notes.md      # Human-readable release summary
├── specs/                # Archived specs
│   ├── {spec-001}/
│   │   ├── spec.md
│   │   ├── plan.md
│   │   ├── tasks.md
│   │   └── research.md
│   └── {spec-002}/
├── quickfixes/           # Archived quickfixes
│   ├── QF-{YYYY}-{NNN}.md
│   └── ...
└── metrics.json          # Release statistics
```

### 7. Generate Release Notes

Create `/.documentation/releases/v{NEXT_VERSION}/release-notes.md`:

```markdown
# Release Notes: v{NEXT_VERSION}

## Release Metadata

- **Version**: v{NEXT_VERSION}
- **Release Date**: {RELEASE_DATE}
- **Previous Version**: {LAST_TAG}
- **Commits**: {COMMITS_SINCE_RELEASE}
- **Contributors**: {CONTRIBUTORS count}

## Highlights

{Executive summary - 2-3 paragraphs summarizing major changes}

## New Features

{For each completed spec:}

### {Feature Name}

{Description from spec summary}

**Spec**: [View archived spec](specs/{spec-name}/spec.md)

## Bug Fixes

{For each quickfix:}

- **{QF-ID}**: {Description}

## Breaking Changes

{If any specs marked as breaking:}

- {Breaking change description with migration guide}

## Deprecations

{If any features deprecated:}

- {Deprecated feature with replacement guidance}

## Architectural Decisions

{For each ADR:}

- **ADR-{NNN}**: {Title} - [View](../../decisions/ADR-{NNN}.md)

## Deferred Features

{For each pending spec:}

- **{Feature Name}**: Planned for future release

## Upgrade Guide

{Steps to upgrade from previous version - auto-generate based on breaking changes}

## Metrics

| Metric | Value |
|--------|-------|
| Features Delivered | {completed specs count} |
| Bugs Fixed | {quickfixes count} |
| ADRs Created | {ADR count} |
| Contributors | {contributors count} |
| Commits | {commits count} |

---

*Release documentation generated by /speckit.release v1.0*
```

### 8. Generate Metrics JSON

Create `/.documentation/releases/v{NEXT_VERSION}/metrics.json`:

```json
{
  "version": "{NEXT_VERSION}",
  "releaseDate": "{RELEASE_DATE}",
  "previousVersion": "{LAST_TAG}",
  "features": {
    "completed": {count},
    "deferred": {count}
  },
  "quickfixes": {count},
  "adrs": {count},
  "commits": {count},
  "contributors": {count},
  "specs": [{list of spec names}],
  "timestamp": "{TIMESTAMP}"
}
```

### 9. Bump Version in Source Files

After generating the CHANGELOG entry and release archive, and **before** committing,
update the canonical version number so the next `specify upgrade` stamps the new
version into consumer projects.

**Skip if DRY_RUN.**

#### A. Bump `pyproject.toml` (Spec Kit Spark source repo)

Edit `pyproject.toml` at the repository root:

```toml
[project]
version = "{NEXT_VERSION}"   # was {CURRENT_VERSION}
```

Make this edit now if {NEXT_VERSION} differs from {CURRENT_VERSION}.

#### B. Confirm `.documentation/SPECKIT_VERSION` (consumer repos)

`.documentation/SPECKIT_VERSION` is **written automatically** by `specify init` and
`specify upgrade` from the CLI version. Maintainers do not need to update it manually
in the source repo — it is a per-consumer-project stamp.

After bumping `pyproject.toml` and publishing the new release, consumer projects
will receive the correct version stamp the next time they run `specify upgrade`.

#### C. Verify version consistency

Confirm these three sources agree on {NEXT_VERSION}:

| Source | Expected Value |
|--------|----------------|
| `pyproject.toml` → `version` | {NEXT_VERSION} |
| `CHANGELOG.md` top entry | `## [{NEXT_VERSION}]` |
| Git tag (to be created) | `v{NEXT_VERSION}` |

If any are out of sync, fix before tagging.

#### D. Manual workflow dispatch version (recommended)

When running **Create Release** via `workflow_dispatch`, set `release_version` to
`{NEXT_VERSION}` (or `v{NEXT_VERSION}`) so the workflow publishes the intended tag
instead of auto-incrementing from the latest existing tag.

### 10. Clean Slate Preparation

After archival (skip if DRY_RUN):

#### A. Archive Specs

For each spec in COMPLETED_SPECS:

1. Copy entire spec directory to `releases/v{NEXT_VERSION}/specs/`
2. Remove from `/.documentation/specs/`

#### B. Archive Quickfixes

For each quickfix in QUICKFIXES:

1. Copy to `releases/v{NEXT_VERSION}/quickfixes/`
2. Remove from `/.documentation/quickfixes/`

#### C. Reset State

1. Create `/.documentation/specs/.gitkeep` if directory is empty
2. Create `/.documentation/quickfixes/.gitkeep` if directory is empty

### 11. Output Summary

#### Dry Run Output

If DRY_RUN is true:

```markdown
## Release Preview: v{NEXT_VERSION}

**This is a dry run - no changes will be made**

### Proposed Changes

#### Archive to releases/v{NEXT_VERSION}/

- **Specs**: {list of completed specs}
- **Quickfixes**: {list of quickfixes}

#### Files to Create

- `/.documentation/releases/v{NEXT_VERSION}/release-notes.md`
- `/.documentation/releases/v{NEXT_VERSION}/metrics.json`
- `CHANGELOG.md` entry

#### ADRs to Generate

{List of ADRs with titles}

#### Specs to Keep (Deferred)

{List of pending specs}

---

To execute this release:
`/speckit.release {NEXT_VERSION}`
```

#### Actual Release Output

```markdown
## Release Complete: v{NEXT_VERSION}

### Archive Created

`/.documentation/releases/v{NEXT_VERSION}/`

- Specs archived: {N}
- Quickfixes archived: {M}
- ADRs created: {P}

### Documentation Updated

- CHANGELOG.md: New entry added
- Release notes: Created
- Metrics: Recorded

### Clean Slate

- Specs directory: {Cleared / {N} deferred specs remain}
- Quickfixes directory: Cleared

### Next Steps

1. Confirm `pyproject.toml` has been bumped to `{NEXT_VERSION}` (Step 9A above).

2. Review generated documentation:
   - `/.documentation/releases/v{NEXT_VERSION}/release-notes.md`
   - `CHANGELOG.md`

3. Commit changes:

   ```bash
   git add -A
   git commit -m "docs: release v{NEXT_VERSION}"
   ```

1. Tag release:

   ```bash
   git tag -a v{NEXT_VERSION} -m "Release v{NEXT_VERSION}"
   ```

2. Push to remote:

   ```bash
   git push origin main --tags
   ```

3. Create GitHub Release (optional):

   ```bash
   gh release create v{NEXT_VERSION} --notes-file .documentation/releases/v{NEXT_VERSION}/release-notes.md
   ```

4. Consumer projects will receive the new version stamp the next time they run:

   ```bash
   specify upgrade
   ```

## Guidelines

### Spec Completion Validation

A spec is considered complete when:

- All tasks in `tasks.md` are checked (`[x]`)
- At least one task exists (not an empty file)
- `spec.md` exists in the directory

### ADR Quality

ADRs should be:

- **Concise**: 1-2 paragraphs per section
- **Factual**: Based on documented decisions in specs
- **Actionable**: Help future developers understand context
- **Numbered**: Sequential ADR-001, ADR-002, etc.

### Version Numbering

Follow semantic versioning:

- **MAJOR**: Breaking changes, removed features
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes, documentation updates

### Handling Edge Cases

**No completed specs:**

- Generate release with quickfixes only
- Note: "Maintenance release - bug fixes only"

**No quickfixes:**

- Generate release with features only
- Standard release notes

**No artifacts to archive:**

```markdown
No Release Artifacts

No completed specs or quickfixes found since last release.

To create a release:
1. Complete pending features or
2. Add quickfixes for bug fixes

Run `/speckit.release` again when ready.
```

**Pending specs warning:**

```markdown
Pending Specs Detected

The following specs are incomplete and will NOT be archived:

{List of pending specs with status}

These will remain active for the next development cycle.
Continue with release? The above specs will be noted as "Deferred".
```

## Context

$ARGUMENTS
