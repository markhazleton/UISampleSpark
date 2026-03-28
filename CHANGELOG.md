# Changelog

This document captures notable milestones extracted from the git history of `UISampleSpark`. For visual commit-density analytics generated with the Mark Hazleton `git-spark` npm package, open `reports/git-spark-report.html` in a browser.

## 2026
- **Mar 24-28** – Hardened API surfaces with per-IP rate limiting in both MVC/API and Minimal API hosts, added feature-flagged multi-key API protection, and reduced CodeQL findings with targeted source fixes. Also refreshed key dependencies (`Swashbuckle.AspNetCore` 10.1.7, `coverlet.collector` 8.0.1, `WebSpark.HttpClientUtility` 2.5.0) and added Speckit archive/harvest/upgrade agent workflow assets.
- **Feb 6** – Added a React 18 Employee CRUD implementation (`/EmployeeReact`) with functional components, hooks, and Fetch API. Introduced a dedicated `_LayoutReact.cshtml` layout loading React/Babel via CDN to isolate from jQuery-based pages. Features include sortable columns, search/filter, pagination, modal forms with Bootstrap 5 validation, delete confirmation dialog, and toast notifications.

## 2025
- **Nov 16** *(Tag: net10-ga)* – Migrated the solution to .NET 10.0, refactored project structure, hardened Docker and GitHub Actions workflows, and replaced `System.Drawing` with SkiaSharp for cross-platform image processing.
- **Sep 7** – Performed a dependency refresh across all projects to prepare for the upcoming .NET 10 upgrade window.
- **Jul 28** *(Tag: docker-hardening-2025)* – Tuned Docker linting with a `.hadolint.yaml`, strengthened Dockerfile scripting, refreshed breadcrumb/navigation UX, and expanded SEO and favicon assets.
- **May 24-25** *(Tag: ui-bootswatch-switcher)* – Delivered the Bootswatch-powered runtime theme switcher, extended HTTP client utilities, polished README deployment guidance, and finalized the theming experience.
- **Apr 17-22** *(Tag: azure-workflows-2025)* – Added Azure App Service deploy workflows with explicit permissions, enabled npm inside the Docker image build pipeline, and realigned UI elements for consistency.
- **Jan 20** – Updated project documentation to reflect architecture changes heading into the 2025 roadmap.

## 2024
- **Sep 20-24** *(Tag: net9-ga)* – Upgraded the application stack to .NET 9.0, refreshed Razor Pages, tuned Docker/GitHub workflows, and synchronized versioning across projects.
- **Aug 3-27** – Iterated on CI configuration while applying scheduled NuGet maintenance for solution stability.
- **May 2-29** – Removed Aspire hosting artifacts, reorganized project structure, merged Dependabot dependency bumps, and simplified deployment workflows.
- **Apr 11-12** – Accepted OpenTelemetry instrumentation updates via Dependabot to maintain observability parity.
- **Mar 12-28** – Introduced the minimal API sample project, added new endpoints, synchronized documentation for MarkHazleton.com, and reconciled long-running branches.
- **Feb 12-Mar 6** – Modernized LibMan/NuGet dependencies while experimenting with Azure App Service workflows.
- **Jan 24-Feb 13** – Added the AspireHost project and continued dependency maintenance to support future cloud scenarios.

## 2023
- **Oct 22** *(Tag: net8-ga)* – Completed the .NET 8 migration, streamlined Swagger integration, and modernized Docker automation.
- **Oct 9** – Established Azure Pipelines CI, reconciled `global.json`, addressed EF Core unit test regressions, and harmonized GitHub workflows.
- **Sep 8-25** – Improved employee data integrity (gender fixes), refreshed dependencies, and standardized Razor Page experiences.
- **Jul 26-30** – Expanded domain models with gender metadata, updated packages, and refined JavaScript clients alongside preview .NET 8 changes.
- **May-Jun** – Continued sweeping dependency updates while expanding unit tests for repository and domain layers.
- **Mar-Apr** – Introduced Swagger styling, merged iterative NuGet updates, and documented new HTTP request samples for API testing.

## 2022
- **Nov 8** *(Tag: net7-ga)* – Upgraded the solution to .NET 7, refreshed publish profiles, and tuned Docker support for Linux-based hosting.
- **Oct 1-26** – Added the `TreeNode` hierarchy helpers, hardened guard clauses, and continued documentation and README improvements.
- **Sep 17-22** – Strengthened DTO validation, resolved nullability warnings, increased unit test coverage, and refined Ajax workflows.
- **Aug 14-23** – Delivered PivotTable.js reporting demos, refined Swagger configuration, and added Azure Linux App Service deployment automation.
- **May 11-18** – Added Docker support, introduced database client logic for container scenarios, and iterated on issue templates and CI pipelines.
- **Apr 22-30** – Standardized naming conventions, fixed navigation issues, and created Docker image workflows for repeatable builds.

- **Nov 10-16** *(Tag: net6-ga)* – Migrated to .NET 6, restructured solutions, introduced Azure Key Vault integration, and activated CI/CD across GitHub Actions and Azure Pipelines.
- **Jun 2-27** – Upgraded to Bootstrap 5 with dynamic versioning, streamlined pipelines, and updated telemetry configuration.
- **May 27-29** – Consolidated the .NET 5 modernization work, strengthened Azure Pipeline automation, and expanded automated test coverage.
- **Mar 23-24** – Established multi-solution CI pipelines, added Code Analysis tooling, and increased controller-level tests.
- **Jan 9-26** – Refined publishing to Azure, standardized versioning, and continued NuGet maintenance as the solution stabilized on .NET 5.

- **Oct 1-20** – Enhanced code analysis, added employee API unit tests, and synchronized Azure pipeline definitions across solutions.
- **Jul 28-30** – Upgraded legacy projects to .NET 4.8, introduced CodeQL analysis, and strengthened REST client abstractions and documentation.
- **May 1-3** – Added the React sample application, kicked off a modernized employee CRUD flow, and refreshed dependencies.
- **Apr 4-13** – Expanded repository/service layers, added Blazor demos, standardized SOAP/REST implementations, and addressed cross-project linting.
- **Apr 5-7** – Established Azure App Service deployment automation, unified API usage across solutions, and refactored shared components.
- **Mar 23-Apr 3** – Added MVC automation tests, increased code coverage, and refactored pipeline scripts following early CI/CD experiments.

- **Nov 10-13** *(Tag: swagger-ci-foundation)* – Enabled Swagger-driven APIs, wired Azure Pipelines CI, and broadened automated testing baselines.
- **Jul 11** – Introduced the React front-end, added security documentation, and harmonized `develop` and `master` branches.
- **Apr 25-27** – Implemented the initial MVC CRUD experience with AJAX-powered forms, navigation scaffolding, and early README guidance.
- **Apr 25** – Seeded the repository with the original ASP.NET MVC CRUD sample, contributor docs, and solution metadata.
