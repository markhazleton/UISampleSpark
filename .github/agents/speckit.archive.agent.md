---
description: Archive outdated documentation to .archive/, update Guide.md and CHANGELOG.md so .documentation stays current and clean
handoffs:
  - label: Run a site audit after archiving
    agent: speckit.site-audit
    prompt: Run a site audit to confirm the project is in good health after archiving
  - label: Evolve the constitution
    agent: speckit.evolve-constitution
    prompt: Review the constitution in light of the cleaned-up documentation
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). If the user names specific files or directories, prioritize those as archive candidates.

## Purpose

Keep `.documentation/` current and authoritative. Move outdated, completed, or contradicting material to `.archive/` with a date-stamped folder. Before moving anything, extract important information into `CHANGELOG.md` and `.documentation/Guide.md` so no knowledge is lost.

**CRITICAL: Never read from `.archive/` during this command or any other command.** The archive folder is write-only from an operational perspective. Past decisions are preserved for audit; they do not drive current work.

## Prerequisites

- Git repository (recommended but not required)
- `.documentation/` directory exists

## Execution Steps

### 1. Gather Context

Run `.documentation/scripts/powershell/archive-context.ps1 -Json` from the repo root. Parse the JSON output:

- `REPO_ROOT` — absolute path to the repository root
- `ARCHIVE_DIR` — target folder for today's archive (e.g., `.archive/2026-03-07`)
- `GUIDE_PATH` / `GUIDE_EXISTS` — location of the living guide
- `CHANGELOG_PATH` / `CHANGELOG_EXISTS` — location of the changelog
- `CANDIDATES` — categorised lists of potential archive candidates:
  - `drafts` — files under `.documentation/drafts/`
  - `session_docs` — files under `.documentation/copilot/`
  - `implementation_plans` — historical `*-implementation-plan.md` and `*-plan.md` files
  - `release_docs` — files under `.documentation/releases/`
  - `quickfix_records` — files under `.documentation/quickfixes/`
  - `pr_reviews` — files under `.documentation/specs/pr-review/`
- `CURRENT_DOCS` — top-level `.documentation/*.md` files (review for staleness)

Treat script JSON as summary context:

- Candidate arrays may be sampled; use `CANDIDATE_COUNTS` and `CURRENT_DOCS_COUNT` for totals.
- Do not force exhaustive review of every candidate when counts are large.
- Only request full inventory when explicitly needed.

Execution limits (required):

- Default max files to read in one pass: 40
- Prioritize by category in this order: drafts, stale session docs, superseded plans/releases, then remaining categories
- Stop once enough evidence exists to archive clearly stale content safely
- If ambiguous, keep file and note why instead of broadening scope

### 2. Review and Decide

Read each candidate file. For each, make one of three decisions:

| Decision | Criteria |
|----------|----------|
| **Archive** | Completed, superseded, contradicts current docs, or is working-notes noise (sausage-making) |
| **Keep** | Still actively referenced, contains unique current guidance, or is the canonical version of something |
| **Merge** | Has important content that should be folded into a current doc before the file is archived |

If candidate counts exceed the one-pass limit, process the highest-signal subset first and report deferred items.

**Always archive:**

- Everything under `.documentation/drafts/`
- Session artifacts under `.documentation/copilot/session=*/` older than the current session
- Completed `*-implementation-plan.md` files whose features are already shipped
- Superseded release notes when a newer release exists

**Be conservative with:**

- Top-level `.documentation/*.md` files — only archive if clearly outdated or contradicted
- `.documentation/specs/` active feature directories — do not archive specs in progress

### 3. Extract Knowledge Before Archiving

For every file you decide to archive, scan it for:

- **Decisions made** → add to `CHANGELOG.md` as historical record
- **How-to guidance still valid** → merge into `.documentation/Guide.md`
- **Architectural rationale** → add to `CHANGELOG.md` with context

Do not copy content verbatim — summarise concisely. The goal is to preserve the signal, discard the noise.

### 4. Update CHANGELOG.md

The changelog lives at `CHANGELOG.md` (repo root). If it does not exist, create it.

Format:

```markdown
# Changelog

## [Unreleased]

## [YYYY-MM-DD] Archive run

### Archived
- `path/to/file.md` — one-sentence reason
- ...

### Key decisions preserved
- Decision or rationale extracted from archived docs
- ...
```

Prepend the new archive-run section above any existing entries. Do not remove existing changelog content.

### 5. Update .documentation/Guide.md

The guide lives at `.documentation/Guide.md`. It is the **living orientation document** for `.documentation/`. If it does not exist, create it.

The guide must always reflect the **current** state. Update it to:

1. **Directory map** — what each folder in `.documentation/` contains right now
2. **Key files** — brief description of each top-level `.documentation/*.md` file
3. **How to use** — which commands use which scripts and templates
4. **Constitution location** — `/.documentation/memory/constitution.md`
5. **What is in `.archive/`** — one-line summary: "Completed and historical docs. Do not read from here during normal operations."

Do not add historical content to Guide.md — it describes the present, not the past.

### 6. Create the Archive Folder and Move Files

1. Create `ARCHIVE_DIR` if it does not exist (e.g., `.archive/2026-03-07/`).
2. Mirror the source directory structure inside the archive folder:
   - `.documentation/drafts/foo.md` → `.archive/2026-03-07/.documentation/drafts/foo.md`
3. Move (do not copy) each file decided for archiving.
4. If moving a directory would leave an empty parent, remove the empty parent only if it has no remaining files.
5. **Do not move** `.documentation/memory/constitution.md` — it is never an archive candidate.
6. **Do not move** `.documentation/scripts/` or `.documentation/templates/` — these are operational.

### 7. Update .archive/README.md

Create or update `.archive/README.md`:

```markdown
# Archive

This folder contains completed and historical documentation that is no longer
part of the active `.documentation/` surface.

**Do not reference files in this folder from prompts, scripts, or active docs.**
Files here are preserved for audit and traceability only.

## Contents

| Folder | Date | Description |
|--------|------|-------------|
| YYYY-MM-DD/ | YYYY-MM-DD | Brief description of this archive batch |
```

### 8. Report

Output a summary to the user:

```markdown
## Archive Complete

**Archived**: N files → `.archive/YYYY-MM-DD/`
**CHANGELOG.md**: updated with N entries
**Guide.md**: updated

### Files Archived
- `path/file.md` — reason

### Files Kept
- `path/file.md` — reason

### .documentation/ Current State
Brief description of what remains and why it is all current.
```

## Rules

- **Never read `.archive/` in this or any other command.**
- **Never archive `.documentation/memory/constitution.md`.**
- **Never archive active specs in `.documentation/specs/` unless they are explicitly completed and superseded.**
- Preserve directory structure inside `.archive/YYYY-MM-DD/` to maintain traceability.
- One archive folder per run, named by today's date.
- If `$ARGUMENTS` names specific files, archive those directly without requiring full review of all candidates.
