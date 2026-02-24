# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| latest  | Yes                |
| < latest | No                |

## Reporting a Vulnerability

If you discover a security vulnerability in SilentPulse, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

### How to Report

Email: **security@silentpulse.io**

Include:
- Description of the vulnerability
- Steps to reproduce
- Affected component(s) and version(s)
- Potential impact assessment
- Any suggested fix (optional)

### What to Expect

- **Acknowledgment**: Within 48 hours of your report
- **Initial assessment**: Within 5 business days
- **Resolution timeline**: Depends on severity (critical: ASAP, high: 14 days, medium: 30 days)
- **Credit**: We will credit reporters in our security advisories (unless you prefer anonymity)

### Scope

The following are in scope:
- SilentPulse backend API (`src/backend/`)
- SilentPulse frontend (`src/frontend/`)
- Helm charts and deployment configurations (`deploy/`)
- MCP server (`cmd/mcp/`)

The following are out of scope:
- Third-party dependencies (report to upstream maintainers)
- Social engineering attacks
- Denial of service attacks
- Issues in demo/test environments

### Safe Harbor

We consider security research conducted in good faith to be authorized.
We will not pursue legal action against researchers who:
- Act in good faith and avoid privacy violations, data destruction, and service disruption
- Only interact with accounts they own or with explicit permission
- Report vulnerabilities promptly and do not exploit them beyond what is necessary to confirm the issue

## Security Best Practices for Deployers

- Always use TLS for API communication
- Rotate `JWT_SECRET` and `ENCRYPTION_KEY` periodically
- Enable per-tenant encryption (`PER_TENANT_ENCRYPTION=true`)
- Use Kubernetes Secrets or Vault for sensitive configuration
- Enable Secret Scanning and Dependabot on your fork
- Review the [deployment guide](docs/Architecture.md) for production hardening
