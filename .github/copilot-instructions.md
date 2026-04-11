<!--
GitHub Copilot Runtime Instructions for UISampleSpark
For GOVERNANCE and PRINCIPLES, see: /.documentation/memory/constitution.md
For FEATURE WORKFLOW, use DevSpark: @devspark.specify → @devspark.plan → @devspark.tasks → @devspark.implement
-->

# GitHub Copilot Instructions

**Constitution**: `/.documentation/memory/constitution.md` (11 core principles — authoritative)
**Priority**: Security > Correctness > Performance > Architecture > Cosmetics

---

## DevSpark Workflow

This repo uses **DevSpark v1.5.0** for spec-driven development. Use the `@devspark.*` agents:

| Step | Agent | Purpose |
|------|-------|---------|
| 1 | `@devspark.specify` | Create feature spec from natural language |
| 2 | `@devspark.plan` | Generate technical implementation plan |
| 3 | `@devspark.tasks` | Break plan into actionable task list |
| 4 | `@devspark.implement` | Execute tasks against the plan |
| — | `@devspark.pr-review` | Constitution-based PR review |
| — | `@devspark.site-audit` | Full codebase audit |
| — | `@devspark.harvest` | Clean stale docs and archive artifacts |
| — | `@devspark.quickfix` | Lightweight bug fix (skip full spec cycle) |

Feature specs live in `/.documentation/features/{feature-name}/`.
Audit reports live in `/.documentation/copilot/audit/`.

---

## Educational Scope Override

This is an **educational project** — no authentication by design (Constitution Principle IV).
- Preserve existing per-IP rate limiting and feature-flagged API key protection
- Do NOT add auth/RBAC unless explicitly requested

---

## ASP.NET Core Coding Rules

### Architecture
- **Repository pattern**: All data access through interfaces (`IEmployeeService`, `IEmployeeClient`)
- **No raw SQL**: EF Core LINQ only — `FromSqlRaw`/`ExecuteSqlRaw` prohibited
- **DTO/Entity separation**: DTOs (`EmployeeDto`) separate from EF entities (`Employee`)
- **DI**: All services in DI container, constructor injection
- **Async/await**: All I/O must be async
- **ConfigureAwait(false)**: Required in Domain and Repository layers

### Error Handling
- Global `IExceptionHandler` for unhandled exceptions
- RFC 7807 `ProblemDetails` for all API errors
- Proper HTTP status codes via `ActionResult<T>`

### Code Quality (all .csproj files)
```xml
<Nullable>enable</Nullable>
<ImplicitUsings>enable</ImplicitUsings>
<LangVersion>latest</LangVersion>
<AnalysisLevel>latest-all</AnalysisLevel>
<EnableNETAnalyzers>true</EnableNETAnalyzers>
<EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
```

### Allowed Suppressions
- CA1707 (underscores in test names), CA2007 (ConfigureAwait), CA1303 (localization)
- Never suppress CA5xxx or CA3xxx security warnings

---

## Testing

- **Framework**: MSTest | **Naming**: `*Test.cs` / `*Tests.cs` | **Pattern**: Arrange-Act-Assert
- **Coverage goal**: 25% baseline
- **Test projects**: `UISampleSpark.Core.Tests/`, `UISampleSpark.Data.Tests/`
- **Priority**: Domain logic → Repository layer → API contracts → Integration

---

## Docker

- Multi-stage builds, Alpine base images, non-root user (`appuser`)
- Port 8080 (not 80), `apk upgrade --available`, pass hadolint

---

## Quick Decision Guide

| Question | Answer |
|----------|--------|
| Authentication needed? | NO — educational scope |
| Test framework? | MSTest |
| Raw SQL allowed? | NO — EF Core LINQ only |
| `ConfigureAwait(false)`? | YES in library code |
| Code analysis level? | `latest-all` |
| .NET version? | Latest (.NET 10) |
| Feature specs location? | `/.documentation/features/{name}/` |
| AI session artifacts? | `/.documentation/copilot/session-{date}/` |

---

**Last Updated**: 2026-04-11 (DevSpark v1.5.0 optimization)