<!-- 
═══════════════════════════════════════════════════════════════════════════════
GitHub Copilot Runtime Instructions for UISampleSpark
═══════════════════════════════════════════════════════════════════════════════
This file provides RUNTIME guidance for AI coding agents.
For GOVERNANCE and PRINCIPLES, see: /.documentation/memory/constitution.md
═══════════════════════════════════════════════════════════════════════════════
-->

# GitHub Copilot Instructions

## 📜 Constitution Authority

**BEFORE making any significant decisions, consult the project constitution:**

**Location**: `/.documentation/memory/constitution.md`

The constitution defines:
- ✅ 11 core principles (what MUST/SHOULD be done)
- ✅ Educational project scope (no auth by design)
- ✅ Testing standards (25% coverage goal)
- ✅ CI/CD requirements (3 workflows mandatory)
- ✅ Architecture patterns (repository, DI, async/await)
- ✅ Security posture (educational-only scope)

**These instructions are COMPLEMENTARY** - they provide practical "how-to" guidance for implementing constitutional principles.

---

## 📁 AI Documentation Organization (MANDATORY)

**ALL AI/Copilot-generated artifacts MUST follow this structure:**

### Required Folders

```
/.documentation/copilot/
├── session-{YYYY-MM-DD}/    ← Today's work, planning, context
├── drafts/                   ← Work-in-progress documents
├── audit/                    ← Code quality audits, compliance reports
└── prompts/                  ← Reusable prompts, agent instructions
```

### Organization Rules

| Artifact Type | Location | When to Use |
|---------------|----------|-------------|
| **Session work** | `session-{date}/` | ALWAYS for daily work - specs, plans, tasks, analysis |
| **Draft documents** | `drafts/` | Constitution drafts, major specs, WIP design docs |
| **Audit reports** | `audit/` | Code quality audits, security scans, compliance checks |
| **Custom prompts** | `prompts/` | Reusable agent instructions, workflow templates |
| **Finalized docs** | `memory/`, `architecture/`, `features/` | When drafts are approved |

### Naming Conventions

- ✅ **Session folders**: `session-2026-02-05` (ISO date format)
- ✅ **Draft files**: `{domain}-{feature}-draft.md` (e.g., `spec-auth-feature-draft.md`)
- ✅ **Audit files**: `audit-{YYYY-MM-DD}-{topic}.md` (e.g., `audit-2026-02-security.md`)
- ❌ **NEVER**: Place AI artifacts in project root or source code directories

### When to Finalize

Move from `copilot/` to permanent locations when:
- User explicitly approves the artifact
- Document is ready for team consumption
- Spec/plan/task has been executed and verified

**Permanent Locations**:
- Constitution → `/.documentation/memory/constitution.md`
- ADRs → `/.documentation/architecture/decisions/`
- Feature specs → `/.documentation/features/{feature-name}/`
- Release notes → Root `CHANGELOG.md`

---

## 🏗️ ASP.NET Core Implementation Guidance

**Ranked by real-world impact** (security, correctness, maintainability, performance)

**Priority**: Security > Correctness > Performance > Architecture > Cosmetics

---

### ⚠️ Educational Scope Override

**THIS PROJECT IS EDUCATIONAL-ONLY** per Constitution Principle IV:
- ❌ NO authentication/authorization implemented (intentional)
- ⚠️ Rate limiting is implemented selectively for current API surfaces (do not remove unless explicitly requested)
- ⚠️ Feature-flagged API key protection is implemented for selected scenarios (keep aligned with current configuration)
- ✅ Security scanning via CodeQL + Trivy (mandatory)
- ✅ SECURITY.md must document limitations (mandatory)

**For general ASP.NET best practices**, follow tiers below. **For this project**, adjust based on educational scope.

---

### Tier 1 — Non-negotiable (Production APIs)

1. **Protect all APIs with HTTPS** ✅ *(Implemented in this project)*
   Security baseline. No HTTPS = game over.

2. **~~JWT authentication with `[Authorize]`~~** ⚠️ *(Educational scope: NOT implemented)*
   Auth comes before architecture polish.
   **THIS PROJECT**: Intentionally omitted for educational simplicity.

3. **~~Role-Based Access Control (RBAC)~~** ⚠️ *(Educational scope: NOT implemented)*
   Auth without authorization is incomplete.
   **THIS PROJECT**: Intentionally omitted for educational simplicity.

4. **Return proper HTTP status codes (`ActionResult<T>`)** ✅ *(Constitution Principle III)*
   APIs are contracts. Breaking this breaks clients.

5. **Return `ProblemDetails` for all errors** ✅ *(Constitution Principle III)*
   Standardized error handling = debuggable APIs.

6. **Global exception handling (`IExceptionHandler`)** 🔴 *(ACTION REQUIRED per Constitution)*
   Prevents crashes, leaks, and inconsistent responses.
   **THIS PROJECT**: Needs implementation - see constitution action items.

---

### Tier 2 — High impact, professional-grade APIs

7. **Avoid exposing EF entities, map to DTOs** ✅ *(Constitution Principle II)*
   Prevents tight coupling and accidental data leaks.
   **THIS PROJECT**: DTO/Entity separation is MANDATORY (100% compliant).

8. **Async/await + `AsNoTracking()` + `ConfigureAwait(false)`** ✅ *(Constitution Principle II)*
   Huge performance wins at scale.
   **THIS PROJECT**: ConfigureAwait(false) MANDATORY in library code (100% compliant).

9. **Thin controllers, business logic in services** ✅ *(Constitution Principle II)*
   Testability and sanity saver.
   **THIS PROJECT**: Repository pattern with interfaces MANDATORY (100% compliant).

10. **Dependency Injection with scoped services & interfaces** ✅ *(Constitution Principle II)*
    Core to ASP.NET Core's design philosophy.
    **THIS PROJECT**: All services in DI container MANDATORY (100% compliant).

11. **API versioning (`/api/v1/...`)** ⚠️ *(Future consideration)*
    You *will* need this eventually.
    **THIS PROJECT**: Not required for educational scope; consider for future.
`ILogger<T>`)** 🟢 *(Constitution Principle VII - SHOULD)*
    Essential once things go wrong in production.
    **THIS PROJECT**: Encouraged but not mandatory; currently missing in Repository/Services.

13. **Avoid logging sensitive data** ✅ *(General security practice)*
    Security + compliance best practice.

14. **Health checks** ✅ **& ~~rate limiting~~** *(Partial - Constitution Principles VII & IV)*
    Important for production & abuse protection.
    **THIS PROJECT**: Health checks at `/health` are implemented and per-IP rate limiting is now active on selected endpoints.

### Recent Security Baseline (2026-03)

- Preserve per-IP rate limiting in both UI and Minimal API hosts unless a user explicitly asks to change it.
- Preserve feature-flagged multi-key API protection behavior when modifying API middleware or endpoint wiring.

15. **Store config in appsettings + Options pattern** ✅ *(Best practice)*
    Clean, testable, and future-proof.
    **THIS PROJECT**: User Secrets for development, environment variables for production
14. **Health checks & rate limiting**
    Important for production & abuse protection.

15. **Store config in appsettings + Options pattern**
    Clean, testable, and future-proof.

---
 ✅ *(Implemented)*
    Helpful defaults, but not transformative alone.

17. **FluentValidation** ⚠️ *(Not currently used)*
    Great, but not mandatory for small APIs.
    **THIS PROJECT**: Data annotations used; FluentValidation is future consideration.

18. **Clean Architecture + feature folders** ✅ *(Constitution Principle II)*
    Powerful for large teams, overkill for small apps.
    **THIS PROJECT**: Clear layering (Web → Repository → Domain → EF) is MANDATORY.

19. **Grouping services with extension methods** ✅ *(Good practice)*
    Mostly cosmetic—helps readability, not behavior.

---

## 🧪 Testing Guidance (Constitution Principle V)

**Coverage Goal**: 25% baseline (currently ~1%)

### Test Structure
```
UISampleSpark.Core.Tests/       ← Unit tests for domain logic
UISampleSpark.Data.Tests/   ← Unit tests for repository layer
```

### Testing Standards
- ✅ **Framework**: MSTest (MANDATORY)
- ✅ **Naming**: `*Test.cs` or `*Tests.cs` suffix (MANDATORY)
- ✅ **Pattern**: Arrange-Act-Assert (RECOMMENDED)
- ✅ **Coverage tool**: coverlet.collector (configured)

### What to Test (Priority Order)
1. **Domain logic** - Extensions, business rules, DTOs
2. **Repository layer** - Data access patterns, CRUD operations
3. **API contracts** - Controller return types, status codes
4. **Integration tests** - Full request/response cycles (future)

---

## 🔧 Code Quality Standards (Constitution Principle I)

### Mandatory Settings (All Projects)
```xml
<PropertyGroup>
  <Nullable>enable</Nullable>
  <ImplicitUsings>enable</ImplicitUsings>
  <LangVersion>latest</LangVersion>
  <AnalysisLevel>latest-all</AnalysisLevel>
  <EnableNETAnalyzers>true</EnableNETAnalyzers>
  <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
</PropertyGroup>
```

### Security Analyzer Rules (MUST be warnings)
- CA5xxx - Security warnings (cryptography, injection, etc.)
- CA3xxx - Security warnings (file paths, XML, etc.)
- ASP0000 - ASP.NET Core warnings

### Common Suppressions (Allowed)
- CA1707 - Underscores in test method names
- CA2007 - ConfigureAwait (we enforce false explicitly)
- CA1303 - Localization (educational scope doesn't require i18n)

---

## 🐳 Docker Best Practices (Constitution Principle X)

When modifying `Dockerfile`:

✅ **DO**:
- Use multi-stage builds
- Use Alpine base images
- Run aggressive security updates (`apk upgrade --available`)
- Create and use non-root user (`appuser`)
- Pass hadolint with documented exceptions
- Set `ASPNETCORE_URLS=http://+:8080` (not 80)

❌ **DON'T**:
- Run as root user
- Skip security updates
- Use `latest` tags without pinning
- Expose port 80 (use 8080 for non-root)

---

## 🔄 CI/CD Workflow Guidance (Constitution Principle VI)

**3 Required Workflows**:

1. **Test & Build** (`.github/workflows/test-build.yml`) - 🔴 NEEDS CREATION
   - Run on PRs + main branch
   - Execute `dotnet test`
   - Fail PR if tests fail

2. **Security Scanning** (`.github/workflows/codeql-analysis.yml`) - ✅ EXISTS
   - CodeQL for .NET vulnerabilities
   - Weekly schedule + PR triggers

3. **Docker Build** (`.github/workflows/docker-image.yml`) - ✅ EXISTS
   - Trivy container scanning
   - Push to Docker Hub on main
   - Weekly security rebuilds

---

## 📚 Documentation Standards (Constitution Principle VIII)

### Required Documentation
- ✅ **README.md** - Keep current with features (MANDATORY)
- ✅ **CHANGELOG.md** - Document milestones (RECOMMENDED)
- ✅ **SECURITY.md** - Document educational scope & limitations (MANDATORY)
- 🟢 **XML docs** - Public APIs, interfaces, DTOs (RECOMMENDED, currently ~40%)

### XML Documentation Template
```csharp
/// <summary>
/// Brief description of what this does
/// </summary>
/// <param name="paramName">Parameter description</param>
/// <returns>Return value description</returns>
/// <exception cref="ExceptionType">When this exception is thrown</exception>
public async Task<ActionResult<EmployeeDto>> GetEmployee(int id)
{
    // implementation
}
```

---

## 🎯 Quick Decision Guide

| Question | Answer | Reference |
|----------|--------|-----------|
| Where do I save AI-generated specs? | `/.documentation/copilot/session-{date}/` | Principle XI |
| Do I need authentication? | NO - educational scope | Principle IV |
| What test framework? | MSTest | Principle V |
| Can I use raw SQL? | NO - use EF Core LINQ | Principle II |
| Do I need `ConfigureAwait(false)`? | YES in library code (Domain/Repository) | Principle II |
| What code analysis level? | `latest-all` | Principle I |
| What .NET version? | Latest (.NET 10 currently) | Principle IX |
| Where do finalized docs go? | `/.documentation/memory/` or `/architecture/` | Principle XI |

---

## 🚨 Common Pitfalls to Avoid

1. ❌ **Placing AI drafts in project root** → Use `/.documentation/copilot/drafts/`
2. ❌ **Forgetting `ConfigureAwait(false)` in libraries** → MANDATORY per constitution
3. ❌ **Exposing EF entities in API** → Use DTOs (EmployeeDto, not Employee)
4. ❌ **Adding authentication** → This is educational scope, no auth needed
5. ❌ **Not using async/await** → All I/O must be async
6. ❌ **Raw SQL queries** → Prohibited; use EF Core LINQ
7. ❌ **Test files without `Test` suffix** → Naming convention required

---

## 📖 Additional Resources

- **Constitution (authoritative)**: `/.documentation/memory/constitution.md`
- **Session archives**: `/.documentation/copilot/session-{date}/`
- **Project templates**: `/.documentation/templates/`
- **Audit history**: `/.documentation/copilot/audit/`

---

## 🔄 When This File Gets Updated

**Update this file when**:
- Constitution principles change
- New .NET version adopted
- Workflow requirements change
- Documentation structure evolves

**DO NOT update this file for**:
- Principle governance (that belongs in constitution)
- Project-specific features (that belongs in README)
- Session-specific decisions (that belongs in `session-{date}/`)

---

**Last Updated**: 2026-02-05 (Constitution v1.0.0 ratification)

---

## 🤖 Azure-Specific Guidance

- @azure Rule - Use Azure Best Practices: When generating code for Azure, running terminal commands for Azure, or performing operations related to Azure, invoke your `azure_development-get_best_practices` tool if availableps.

19. **Grouping services with extension methods**
    Mostly cosmetic—helps readability, not behavior.