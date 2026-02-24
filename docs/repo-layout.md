# Repository Layout

SilentPulse uses a closed-core model: private source code, public deployment artifacts.

## Repositories

| Repo | Visibility | Contents |
|------|-----------|----------|
| `silentpulse-io/silentpulse` | **private** | Full codebase — backend (Go), frontend (Next.js), migrations, Dockerfiles, CI workflows, internal tooling |
| `silentpulse-io/deploy` | **public** | Helm chart, Docker Compose, K8s manifests, public docs, governance files |
| `silentpulse-io/silentpulse-enterprise` | **private** | Enterprise modules |
| `silentpulse-io/license-server` | **private** | License Server + Admin Panel |
| `silentpulse-io/connector-hub` | **private** | Connector Hub |
| `silentpulse-io/silentpulse-websites` | **private** | 4x Astro sites (www, docs, blog, demo) |
| `silentpulse-io/.github` | **public** | Organization profile README |

## Deploy repo (`silentpulse-io/deploy`)

Public-facing repo for users deploying SilentPulse. Contains only deployment artifacts — no source code.

### Structure

```
deploy/
├── helm/silentpulse/        # Full Helm chart (self-contained)
├── docker-compose/          # Docker Compose for evaluation/demo
│   ├── docker-compose.yml   # Uses image: refs (not build:)
│   ├── .env.example
│   └── init-extensions/
└── k8s/
    ├── base/                # CRD, RBAC, manager
    └── dev/                 # Sample configs

docs/                        # Public documentation subset
.github/
├── CLA.md
├── profile/README.md
└── workflows/cla.yml

LICENSE                      # BSL 1.1
README.md                    # Product overview (deployment-focused)
CONTRIBUTING.md
CODE_OF_CONDUCT.md
SECURITY.md
RELEASE.md
```

### What is NOT in the deploy repo

These stay only in the private `silentpulse` repo:

- `src/` — all backend and frontend source code
- `deploy/docker/Dockerfile.*` — build instructions (images come from registry)
- `Makefile` — depends on src/
- `CLAUDE.md`, `CLAUDE_RULES.md` — AI assistant instructions
- `.github/workflows/ci.yml`, `migrations.yml`, `integration-tests.yml` — CI requiring source
- `scripts/` — internal tooling (new-migration, github-org-setup, etc.)
- `CODEOWNERS` — team-specific, relevant only for private repo
- `docs/roles/` — AI role guidelines
- `docs/assets/` — internal diagrams
- 5 internal feature specs: `pulse-check`, `tagging`, `workingmode`, `enhanced-audit-logs`, `audit-log-export`

### Docker Compose differences

The deploy repo's `docker-compose.yml` uses pre-built images instead of `build:` directives:

```yaml
# Private repo (for development):
api:
  build:
    context: ../../
    dockerfile: deploy/docker/Dockerfile.api

# Deploy repo (for users):
api:
  image: ${IMAGE_REGISTRY:-ghcr.io/silentpulse-io}/silentpulse-api:${IMAGE_TAG:-latest}
```

### Branch protection

The deploy repo has a `main-protection` ruleset:
- 1 required approval
- Stale reviews dismissed on push
- Thread resolution required
- Linear history enforced
- No branch deletion or force-push

## Keeping deploy repo in sync

When changing Helm chart, Docker Compose, K8s manifests, or public docs in the main repo, the corresponding files must be updated in the deploy repo as well. This is a manual process — treat the main repo as the source of truth and copy changes to deploy.

## Organization profile

The org profile (`silentpulse-io/.github/profile/README.md`) links to the deploy repo as the public entry point. The main `silentpulse` repo returns 404 for unauthenticated users.
