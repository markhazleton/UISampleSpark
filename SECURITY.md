# Security Policy

## ⚠️ Educational Project Warning

**This project is for educational and demonstration purposes only.**

### Not Production-Ready

This codebase intentionally omits critical production security features to maintain simplicity for learning purposes:

| Security Feature | Status | Rationale |
|------------------|--------|-----------|
| Authentication | ❌ Not Implemented | Educational scope - demonstrates CRUD patterns without auth complexity |
| Authorization | ❌ Not Implemented | No `[Authorize]` attributes or role-based access control |
| Rate Limiting | ✅ Implemented | Per-IP fixed window limit: 100 requests/minute |
| Input Validation Middleware | ⚠️ Basic Only | Model validation present, but no WAF or advanced input filtering |
| CORS Policies | ❌ Not Configured | Educational scope - assumes trusted clients |
| API Key Management | ⚠️ Lightweight | Header/cookie API key validation with up to 10 configured keys |

**⚠️ DO NOT deploy this application to production without implementing these features.**

### What IS Secured

While authentication is intentionally omitted, we maintain security best practices in other areas:

- ✅ **HTTPS Enforcement**: Required in non-development environments
- ✅ **Secrets Management**: User Secrets (dev) and environment variables (prod) - no hardcoded credentials
- ✅ **SQL Injection Prevention**: Entity Framework Core with parameterized queries (no raw SQL)
- ✅ **Dependency Scanning**: Automated security scans via CodeQL and Trivy
- ✅ **Container Security**: Non-root user, Alpine Linux, aggressive security updates
- ✅ **Code Analysis**: Latest .NET analyzers with security rules enabled
- ✅ **API Key Access Guard**: API endpoints validate `X-API-Key` against configured keys
- ✅ **Abuse Protection**: Per-IP rate limiting for API endpoints

### API Key Access

- API access keys are controlled by repository maintainers.
- Contact Mark Hazleton if you would like an API key to use the API.
- Configure multiple keys using `ApiSecurity:ApiKeys` (`ApiKeys[0]`..`ApiKeys[9]`).

### Security Scanning

We actively scan for vulnerabilities despite the educational scope:

| Tool | Frequency | Purpose |
|------|-----------|---------|
| **CodeQL** | Weekly + PRs | Static analysis for C# security vulnerabilities |
| **Trivy** | Weekly + PRs | Container image vulnerability scanning |
| **Dependabot** | Daily | Automated dependency update PRs |
| **.NET Analyzers** | Every build | Built-in security rule violations (CA5xxx, CA3xxx) |

View security scan results: [GitHub Security Tab](https://github.com/MarkHazleton/UISampleSpark/security)

---

## Supported Versions

This is an educational reference project with no official support or versioning.

| Version | Supported          |
| ------- | ------------------ |
| main    | ✅ Active development |
| < 1.0   | ❌ No support |

---

## Reporting a Vulnerability

We use GitHub issues to track vulnerabilities in this educational project.

**To report a security issue**:

1. **Public Issues**: For educational/demonstration vulnerabilities, [open a public issue](https://github.com/MarkHazleton/UISampleSpark/issues/new?template=bug_report.md)
2. **Private Disclosure**: For serious vulnerabilities in dependencies, use [GitHub Security Advisories](https://github.com/MarkHazleton/UISampleSpark/security/advisories/new)

**Response Time**: Best effort (this is not a production application)

---

## Production Deployment Checklist

If you intend to adapt this code for production use, you MUST implement:

### Critical Security Features

- [ ] JWT or OAuth authentication with identity provider (Auth0, Azure AD, etc.)
- [ ] Role-based authorization with `[Authorize]` attributes
- [ ] API rate limiting (e.g., `AspNetCoreRateLimit` package)
- [ ] CORS policy configuration for known client origins
- [ ] Input validation middleware (e.g., FluentValidation with sanitization)
- [ ] API key management for external integrations
- [ ] Web Application Firewall (WAF) or equivalent
- [ ] Security headers (CSP, X-Frame-Options, HSTS, etc.)
- [ ] Data encryption at rest and in transit
- [ ] Audit logging for sensitive operations
- [ ] Penetration testing and security review

### Infrastructure Security

- [ ] Move from InMemory database to production-grade persistence (SQL Server, PostgreSQL)
- [ ] Database connection string encryption
- [ ] Secrets management (Azure Key Vault, AWS Secrets Manager, etc.)
- [ ] Network isolation and firewall rules
- [ ] DDoS protection
- [ ] Monitoring and alerting for security events
- [ ] Incident response plan

### Compliance

- [ ] GDPR compliance (if handling EU user data)
- [ ] CCPA compliance (if handling California resident data)
- [ ] Data retention and deletion policies
- [ ] Terms of Service and Privacy Policy
- [ ] Security audit and compliance certifications

---

## Educational Purpose Statement

This project demonstrates:
- ✅ ASP.NET Core MVC and Web API patterns
- ✅ Repository pattern and dependency injection
- ✅ Entity Framework Core usage
- ✅ Docker containerization
- ✅ CI/CD with GitHub Actions
- ✅ Test-driven development practices

It deliberately does NOT demonstrate:
- ❌ Production authentication/authorization
- ❌ Multi-tenant architecture
- ❌ Horizontal scaling patterns
- ❌ High-availability deployment

Use this project as a learning reference, not a production template.

---

**Last Updated**: 2026-02-05  
**Constitution Version**: v1.0.0  
**Security Contact**: Repository maintainers via GitHub Issues

