# Contributing to SilentPulse

Thank you for your interest in contributing to SilentPulse!

## Contributor License Agreement (CLA)

Before we can accept your contributions, you must sign our CLA.
A CLA bot will automatically comment on your first pull request with instructions.

## Getting Started

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Run tests: `go test ./...` (backend) and `npm test` (frontend)
5. Submit a pull request

## Development Setup

### Backend (Go)

```bash
cd src/backend
go build ./cmd/api/
go test ./...
```

### Frontend (Next.js)

```bash
cd src/frontend
npm install
npm run dev
```

### Enterprise Build

Enterprise modules (behavioral analytics, AI assistant) require the enterprise build tag:

```bash
go build -tags enterprise ./cmd/api/
```

## Pull Request Guidelines

- Keep PRs focused on a single change
- Include tests for new functionality
- Follow existing code style and patterns
- Update documentation if needed
- Reference related issues (e.g., `Fixes #123`)
- All PRs require review from CODEOWNERS before merging

## Code Style

- **Go**: Follow standard `gofmt` formatting. Run `go vet ./...` before submitting.
- **TypeScript/React**: Follow existing patterns in `src/frontend/`.
- **SQL Migrations**: Add new files in `src/backend/migrations/` with sequential numbering.

## Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- For security vulnerabilities, see [SECURITY.md](SECURITY.md)

## License

By contributing to SilentPulse, you agree that your contributions will be licensed
under the Business Source License 1.1 (BSL 1.1) as specified in the [LICENSE](LICENSE) file.
