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
     │  PostgreSQL 16  │  │   Redis 7  │   │ Flow Controller  │ :8081
     │  + Apache AGE   │  │   (cache)  │   │  (Docker mgmt)   │
     └────────────────┘  └────────────┘   └────────┬─────────┘
                                                   │
                                          Docker API (socket)
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
| **Flow Controller** | 8081 | Manages worker/scheduler container lifecycle via Docker API |
| **CMDB Sync** | 8082 | Synchronizes assets from external sources (PULL/PUSH/CSV) |
| **Health** | 8083 | Health monitoring service |
| **Notifications** | 8084 | Alert dispatcher — webhook, Slack, email, Splunk HEC |
| **Reporting** | 8085 | Report generation service |
| **Frontend** | 3000 | Next.js dashboard UI |
| **PostgreSQL** | 5432 | Primary datastore (Apache AGE for graph queries) |
| **Redis** | 6379 | Cache for observed assets (worker → scheduler) |

## Quick Start (Docker Compose)

```bash
# 1. Clone this repo
git clone https://github.com/silentpulse-io/deploy.git && cd deploy

# 2. Configure
cp deploy/docker-compose/.env.example deploy/docker-compose/.env
# Edit .env — set JWT_SECRET, POSTGRES_PASSWORD, etc.

# 3. Start everything
docker compose -f deploy/docker-compose/docker-compose.yml up -d

# 4. Open the app
open http://localhost:3000
```

Default login: `admin@silentpulse.local` / `admin123`

> **WARNING:** Change the default admin password immediately after first login.
> This is a development-only default and must NOT be used in production.

## Kubernetes Deployment (Helm)

### Prerequisites

- Kubernetes 1.28+
- Helm 3.x

### Install

```bash
helm install silentpulse deploy/helm/silentpulse \
  --namespace silentpulse --create-namespace \
  --set api.env.JWT_SECRET=$(openssl rand -hex 32) \
  --set postgresql.password=$(openssl rand -hex 16)
```

### Upgrade

```bash
helm upgrade silentpulse deploy/helm/silentpulse --namespace silentpulse
```

### Configuration

See `deploy/helm/silentpulse/values.yaml` for all available options. Key settings:

```bash
helm install silentpulse deploy/helm/silentpulse \
  --namespace silentpulse --create-namespace \
  --set api.env.JWT_SECRET=your-secret \
  --set api.env.ENCRYPTION_KEY=your-32-byte-hex-key \
  --set api.env.SILENTPULSE_MODULES_ENABLED=core,mitre,behavioral
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_DB` | `silentpulse` | Database name |
| `POSTGRES_USER` | `silentpulse` | Database user |
| `POSTGRES_PASSWORD` | `silentpulse` | Database password |
| `JWT_SECRET` | *(required)* | HMAC secret for JWT signing |
| `JWT_EXPIRY` | `24h` | JWT token expiry duration |
| `ENCRYPTION_KEY` | *(empty)* | 32-byte hex key for AES-256-GCM (connection secrets) |
| `SILENTPULSE_MODULES_ENABLED` | `core` | Comma-separated: `core`, `mitre`, `behavioral` |
| `NOTIFICATION_POLL_INTERVAL` | `30s` | How often notifications service checks for new alerts |
| `IMAGE_REGISTRY` | `ghcr.io/silentpulse-io` | Container image registry |
| `IMAGE_TAG` | `latest` | Container image tag |

## Modules

SilentPulse uses a module system controlled by `SILENTPULSE_MODULES_ENABLED`:

- **core** — always enabled. Assets, flows, alerts, workers, schedulers, notifications.
- **mitre** — MITRE ATT&CK technique/tactic mapping, coverage analysis, impact assessment per asset group.
- **behavioral** — TimeTravel (asset observation timeline), feed/asset profiling, anomaly detection, threshold suggestions.

Disabled modules return HTTP 404 for their endpoints. See `docs/modules.md` for details.

## Documentation

Full documentation is available in the `docs/` directory:

- [Architecture](docs/Architecture.md) — system architecture and component diagram
- [API Reference](docs/api.md) — REST API endpoints
- [Data Model](docs/data-model.md) — entities, relations, graph dependencies
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
- [Security Policy](SECURITY.md)

## License

SilentPulse is licensed under the [Business Source License 1.1](LICENSE).

The Change License is Apache License 2.0. Each version becomes available under the Change License four years after its release.
