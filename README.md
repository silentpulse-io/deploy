# SilentPulse

**See when security goes silent.**

SilentPulse is a security visibility monitoring system that detects when security telemetry stops flowing or degrades, leading to loss of detection capabilities and blind spots.

## What SilentPulse Answers

- When was security visibility lost or degraded?
- Which detection capabilities were affected?
- How long was the organization blind to threats?
- What actions should be taken to restore visibility?

## Architecture

```
                          ┌──────────────┐
                          │   Frontend   │ :3000
                          │  (Next.js)   │
                          └──────┬───────┘
                                 │
                          ┌──────▼───────┐
                          │     API      │ :8080
                          │   (Go HTTP)  │
                          └──┬───┬───┬───┘
                             │   │   │
              ┌──────────────┘   │   └──────────────┐
              ▼                  ▼                   ▼
     ┌────────────────┐  ┌────────────┐   ┌──────────────────┐
     │  PostgreSQL 16  │  │   Redis 7  │   │ Flow Controller  │
     │  + Apache AGE   │  │   (cache)  │   │  / Operator      │
     └────────────────┘  └────────────┘   └────────┬─────────┘
                                                   │
                                          Container runtime
                                                   │
                                    ┌──────────────┼──────────────┐
                                    ▼                              ▼
                           ┌──────────────┐              ┌──────────────┐
                           │   Workers    │              │  Schedulers  │
                           │ (Kafka/ES/   │──── Redis ──▶│ (CMDB vs     │
                           │  Splunk)     │              │  observed)   │
                           └──────────────┘              └──────┬───────┘
                                                                │
              ┌─────────────────────────────────────────────────┘
              ▼
     ┌──────────────────┐     ┌──────────────┐     ┌──────────────┐
     │     Alerts        │────▶│ Notifications│────▶│  Webhook /   │
     │  (PostgreSQL)     │     │  :8084       │     │ Slack/Email/ │
     └──────────────────┘     └──────────────┘     │ Splunk HEC   │
                                                   └──────────────┘
```

## Services

| Service | Port | Description |
|---|---|---|
| **API** | 8080 | REST API — auth, CRUD, dashboard, modules |
| **Frontend** | 3000 | Next.js dashboard UI |
| **CMDB Sync** | 8082 | Synchronizes assets from external sources (PULL/PUSH/CSV) |
| **Health** | 8083 | Health monitoring service |
| **Notifications** | 8084 | Alert dispatcher — webhook, Slack, email, Splunk HEC |
| **Reporting** | 8085 | Report generation service |
| **Flow Controller** | 8081 | Manages worker/scheduler containers via Docker API *(Docker Compose)* |
| **Operator** | — | Manages worker/scheduler pods via `SilentPulseFlow` CRD *(Kubernetes)* |
| **MCP Server** | 8090 | Exposes data to AI agents via Model Context Protocol *(optional)* |
| **PostgreSQL** | 5432 | Primary datastore (Apache AGE for graph queries) |
| **Redis** | 6379 | Cache for observed assets (worker → scheduler) |

> **Flow Controller vs Operator:** In Docker Compose, the Flow Controller manages worker and scheduler containers via Docker socket. In Kubernetes, the Operator replaces it — watching `SilentPulseFlow` custom resources and managing pods through the K8s API.

## Quick Start (Docker Compose)

```bash
# 1. Clone this repo
git clone https://github.com/silentpulse-io/deploy.git && cd deploy

# 2. Configure
cp deploy/docker-compose/.env.example deploy/docker-compose/.env
# Edit .env — set JWT_SECRET, POSTGRES_PASSWORD

# 3. Start everything
docker compose -f deploy/docker-compose/docker-compose.yml up -d

# 4. Open the dashboard
open http://localhost:3000
```

Default login: `admin@silentpulse.local` / `admin123`

> **WARNING:** Change the default admin password immediately after first login.

See [docs/quick-start.md](docs/quick-start.md) for the full guide.

## Kubernetes (Helm)

```bash
helm install silentpulse deploy/helm/silentpulse \
  -n silentpulse --create-namespace \
  -f values-override.yaml
```

See [docs/installation.md](docs/installation.md) for prerequisites, configuration reference, upgrading, and all available `values.yaml` options.

## Modules

SilentPulse uses a module system controlled by `SILENTPULSE_MODULES_ENABLED`:

| Module | Description | License |
|--------|-------------|---------|
| **core** | Assets, flows, alerts, workers, schedulers, notifications | Community |
| **mitre** | MITRE ATT&CK mapping, coverage analysis, impact assessment | Community |
| **ai-assistant** | BYO LLM alert explanations (Ollama, OpenAI, Anthropic) | Enterprise |
| **behavioral** | TimeTravel, feed/asset profiling, anomaly detection | Enterprise |

Disabled modules return HTTP 404 for their endpoints. See [docs/modules.md](docs/modules.md) for details.

## Documentation

- [Quick Start](docs/quick-start.md) — get running in 5 minutes with Docker Compose
- [Installation](docs/installation.md) — production deployment with Helm
- [Architecture](docs/Architecture.md) — system architecture and component diagram
- [Data Model](docs/data-model.md) — entities, relations, graph dependencies
- [API Reference](docs/api.md) — REST API endpoints
- [Modules](docs/modules.md) — module system (core + optional)
- [RBAC](docs/rbac.md) — user roles and permissions
- [Features](docs/features.md) — feature manifest with implementation status
- [Licensing](docs/licensing.md) — licensing model

## Tech Stack

- **Backend**: Go, `net/http`, pgx/v5, go-redis/v9
- **Frontend**: Next.js, React, TypeScript, shadcn/ui, Zustand
- **Database**: PostgreSQL 16 + Apache AGE (graph), Redis 7
- **Infrastructure**: Docker, Kubernetes, Helm
- **Auth**: JWT HS256, bcrypt, role-based access control

## Links

- [Website](https://silentpulse.io)
- [Documentation](https://docs.silentpulse.io)
- [Blog](https://blog.silentpulse.io)
- [Live Demo](https://demo.silentpulse.io)
- [Security Policy](SECURITY.md)

## License

SilentPulse is licensed under the [Business Source License 1.1](LICENSE).

The Change License is Apache License 2.0. Each version becomes available under the Change License four years after its release.
