---
description: Harvest knowledge from completed specs and stale docs into living documentation, rewrite stale spec-linked comments, then archive obsolete artifacts
handoffs:
  - label: Review Release Artifacts
    agent: devspark.release
    prompt: Review completed specs and release documentation before archival
  - label: Run Documentation Audit
    agent: devspark.site-audit
    prompt: Audit documentation quality and stale references before harvest
scripts:
  sh: .devspark/scripts/bash/harvest.sh $ARGUMENTS --json
  ps: .devspark/scripts/powershell/harvest.ps1 $ARGUMENTS -Json
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Harvest valuable knowledge from completed specs, stale documentation, and in-process drafts into living project documentation, then archive obsolete source material.

This command is a **knowledge-preserving cleanup** workflow:

1. Preserve durable knowledge in living documents such as `CHANGELOG.md`, `/.documentation/Guide.md`, and `/.github/copilot-instructions.md`
2. Rewrite source code comments that reference completed specs, plans, or tasks into self-contained explanations
3. Move stale artifacts into `/.archive/` while preserving directory structure
4. Produce a harvest report at `/.documentation/copilot/harvest-YYYY-MM-DD.md`

## Scope Options

By default, with no arguments, perform a full harvest.

| Scope Argument | Description |
|----------------|-------------|
| *(none)* | Full harvest with plan, confirmation, updates, comment cleanup, and archival |
| `--scope=specs` | Harvest completed specs and related release knowledge |
| `--scope=docs` | Review stale or duplicate documentation and archive candidates |
| `--scope=comments` | Rewrite code comments only; no file moves |
| `--scope=changelog` | Update CHANGELOG entries only; no archival |
| `--scope=scan` | Scan only and write a report; do not modify files |

Multiple scopes may be combined: `--scope=specs,comments`

## Operating Constraints

- Constitution authority comes from `/.documentation/memory/constitution.md`
- Knowledge must be harvested into living docs **before** archival
- No direct deletion: move files to `/.archive/`
- CHANGELOG is append-only: add new entries without rewriting older entries
- Living docs take precedence over standalone stale documents
- **Explicit user confirmation is required before any edits or moves**

## Outline

**Multi-app support**: If this repository uses multi-app mode (`.documentation/devspark.json` exists with `mode: "multi-app"`), check for `--app <id>` in the user input to scope this workflow to a specific application. When app context is provided, resolve artifacts from `{app.path}/.documentation/` instead of the repository root `.documentation/`. Print the resolved scope (app name, doc root) at the start of output.

### 1. Initialize Harvest Context

Run `{SCRIPT}` and parse its JSON output.

Expected fields include:

- `harvest_date`
- `harvest_timestamp`
- `repo_root`
- `scope`
- `report_path`
- `specs`
- `docs`
- `code_comments`
- `changelog_gaps`
- `bak_files`
- `archive_existing`
- `summary`

If the script indicates legacy root-level docs or specs paths, prefer `/.documentation/` as canonical and treat root-level paths as migration or cleanup targets unless the repository is clearly legacy-only.

### 2. Load Governance And Living Docs

Read these sources as needed:

- `/.documentation/memory/constitution.md`
- `CHANGELOG.md`
- `/.github/copilot-instructions.md` if present
- Relevant guides under `/.documentation/`

Use them to determine:

- what knowledge already exists
- which docs are living references versus stale context
- whether completed specs have already been captured in CHANGELOG or guides

### 3. Classify Artifacts

#### Specs

Treat spec folders under `/.documentation/specs/` as:

| Status | Criteria | Action |
|--------|----------|--------|
| `completed` | `**Status**: Complete` in spec.md AND tasks complete AND reflected in CHANGELOG or review evidence | Harvest then archive |
| `completed-needs-changelog` | `**Status**: Complete` AND tasks complete but no CHANGELOG entry found | Harvest then add CHANGELOG entry |
| `in-progress` | `**Status**: In Progress` OR some tasks incomplete | Keep active |
| `draft` | `**Status**: Draft` OR planning exists but implementation is incomplete or absent | Keep active |

**Lifecycle consistency check**: If the `**Status**:` field in spec.md disagrees with the task completion state (e.g., all tasks checked but status is `Draft`), flag the inconsistency and recommend running `/devspark.implement` to reconcile the status before harvesting.

#### Documentation

Classify files under `/.documentation/` using category, taxonomy, usefulness score, and disposition.

Use the following disposition semantics:

- `keep`
- `keep_refresh`
- `keep_move`
- `consolidate`
- `rewrite`
- `archive`

Bias toward preserving:

- constitution
- active guides
- accepted ADRs
- test/reference data that is still in use

Bias toward archiving:

- completed reviews
- completed audits
- stale drafts
- session notes
- backup files
- orphaned generated artifacts

#### Code Comments

Scan source files for spec-linked comments such as:

```text
# spec 026
# FR-013
# T006
# Phase 3
# TODO(spec-018)
```

Rewrite them as self-contained descriptions of behavior and intent. Remove comments that are pure tracking markers with no lasting explanatory value.

### 4. Present Harvest Plan

Before making any changes, present a plan that includes:

- specs to archive
- docs to archive
- docs to rewrite or consolidate
- CHANGELOG updates needed
- code comments to rewrite
- files to clean
- items intentionally left unchanged

Then ask:

`Proceed with harvest? (yes/no/modify)`

If the user does not explicitly approve, stop after the plan.

### 5. Harvest Knowledge Into Living Docs

After approval only:

1. Update `CHANGELOG.md` for completed work not already captured
2. Update living guides under `/.documentation/` when completed specs introduced durable system knowledge
3. Update `/.github/copilot-instructions.md` when the harvested work affects ongoing coding guidance

### 6. Clean Code Comments

For each spec-linked comment selected for cleanup:

1. Read surrounding code
2. Infer the actual behavior and rationale
3. Rewrite the comment without spec/task references
4. If the comment has no enduring value, remove it

### 7. Archive Files

After harvesting knowledge and only with user approval:

1. Mirror source paths under `/.archive/`
2. Move completed specs and stale docs there
3. Preserve structure for traceability
4. Avoid re-archiving paths already present in `archive_existing`

### 8. Write Harvest Report

Write a report to the script-provided `report_path` containing:

- summary counts
- archived specs and docs
- rewritten comments
- harvested knowledge destinations
- active items intentionally left in place

## Anti-Patterns

Do not:

1. Archive without first preserving useful knowledge
2. Delete files outright instead of moving to `/.archive/`
3. Rewrite historical CHANGELOG entries
4. Archive in-progress or draft specs
5. Leave stale spec references in code comments when they can be safely rewritten
6. Skip the user confirmation checkpoint
7. Treat stale or deprecated references as living documentation
