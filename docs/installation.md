---
title: Installation
description: Production deployment of SilentPulse with Helm on Kubernetes.
---

# Installation

This guide covers production deployment of SilentPulse on Kubernetes using Helm.

For a quick local evaluation with Docker Compose, see [Quick Start](/getting-started/quick-start/).

## Prerequisites

- Kubernetes 1.25+
- Helm 3.10+
- `kubectl` configured for your cluster
- 2 CPU cores and 2 GB RAM available (minimum)

## 1. Add the Helm Repository

```bash
helm repo add silentpulse https://charts.silentpulse.io
helm repo update
```

Or install directly from the deploy repository:

```bash
git clone https://github.com/silentpulse-io/deploy.git
cd deploy
```

## 2. Configure Values

Create a `values-override.yaml` with your settings:

```yaml
postgresql:
  password: ""      # REQUIRED — openssl rand -hex 16

redis:
  password: ""      # Recommended — openssl rand -hex 16

auth:
  jwtSecret: ""     # REQUIRED (min 32 chars) — openssl rand -hex 32
  encryptionKey: "" # REQUIRED — openssl rand -hex 32
  healthAPIKey: ""  # Recommended — openssl rand -hex 32

ingress:
  host: silentpulse.example.com
```

:::caution
Never commit secrets to version control. Use `--set` flags, sealed secrets, or a secrets manager in production.
:::

## 3. Install

```bash
# From Helm repo
helm install silentpulse silentpulse/silentpulse \
  -n silentpulse --create-namespace \
  -f values-override.yaml

# Or from local chart
helm install silentpulse deploy/helm/silentpulse \
  -n silentpulse --create-namespace \
  -f values-override.yaml
```

## 4. Verify

```bash
kubectl -n silentpulse get pods
```

All pods should reach `Running` within 2–3 minutes:

```
NAME                          READY   STATUS    RESTARTS
silentpulse-api-xxx           1/1     Running   0
silentpulse-frontend-xxx      1/1     Running   0
silentpulse-cmdb-sync-xxx     1/1     Running   0
silentpulse-health-xxx        1/1     Running   0
silentpulse-notifications-xxx 1/1     Running   0
silentpulse-reporting-xxx     1/1     Running   0
silentpulse-operator-xxx      1/1     Running   0
silentpulse-postgres-0        1/1     Running   0
silentpulse-redis-0           1/1     Running   0
```

## 5. Access the Dashboard

If ingress is enabled, open `https://silentpulse.example.com` in your browser.

For port-forwarding without ingress:

```bash
kubectl -n silentpulse port-forward svc/silentpulse-frontend 3000:3000
```

Default credentials:
- **Email:** `admin@silentpulse.local`
- **Password:** `admin123`

:::danger
Change the default admin password immediately after first login.
:::

---

## Configuration Reference

### Infrastructure

| Value | Description | Default |
|-------|-------------|---------|
| `postgresql.enabled` | Deploy PostgreSQL StatefulSet | `true` |
| `postgresql.image` | PostgreSQL + AGE image | `apache/age:release_PG16_1.6.0` |
| `postgresql.storage` | PVC size | `5Gi` |
| `postgresql.password` | Database password | (required) |
| `redis.enabled` | Deploy Redis StatefulSet | `true` |
| `redis.image` | Redis image | `redis:7-alpine` |
| `redis.storage` | PVC size | `1Gi` |
| `redis.password` | Redis password | (recommended) |

If you use an external PostgreSQL or Redis, set `enabled: false` and configure the connection in service environment variables.

### Services

| Value | Description | Default |
|-------|-------------|---------|
| `api.replicas` | API server replicas | `1` |
| `api.port` | API port | `8080` |
| `frontend.replicas` | Frontend replicas | `1` |
| `frontend.port` | Frontend port | `3000` |
| `cmdbSync.replicas` | CMDB Sync replicas | `1` |
| `health.replicas` | Health monitor replicas | `1` |
| `notifications.replicas` | Notification dispatcher replicas | `1` |
| `notifications.pollInterval` | Alert poll interval | `30s` |
| `reporting.replicas` | Reporting service replicas | `1` |
| `operator.replicas` | Operator replicas | `1` |

### Authentication

| Value | Description | Default |
|-------|-------------|---------|
| `auth.jwtSecret` | JWT signing secret (min 32 chars) | (required) |
| `auth.jwtExpiry` | Token expiry duration | `24h` |
| `auth.encryptionKey` | Per-tenant encryption key | (required) |
| `auth.healthAPIKey` | External health metrics API key | (optional) |

### Ingress

| Value | Description | Default |
|-------|-------------|---------|
| `ingress.enabled` | Enable Ingress resource | `true` |
| `ingress.className` | Ingress class | `nginx` |
| `ingress.host` | Hostname | `silentpulse.local` |

For TLS, add annotations for your cert-manager or load balancer:

```yaml
ingress:
  host: silentpulse.example.com
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
```

### Optional Components

#### MCP Server

Exposes SilentPulse data to AI agents and LLMs via the Model Context Protocol.

```yaml
mcp:
  enabled: true
```

Accessible at port `8090`. See [MCP documentation](https://modelcontextprotocol.io/) for client configuration.

#### Data Retention Job

Automated cleanup of old alerts and observation data.

```yaml
retentionJob:
  enabled: true
  schedule: "0 3 * * *"  # Daily at 03:00 UTC
  coldStorage:
    enabled: true
    endpoint: "https://s3.amazonaws.com"
    bucket: "silentpulse-archive"
    region: "eu-central-1"
```

### Licensing

```yaml
license:
  key: "sp_lic_xxxxxxxx"
```

Without a license key, SilentPulse runs in community mode with core features. Enterprise features (AI Assistant, Behavioral Analytics) require a valid license.

### Connector Hub

```yaml
connectorHub:
  url: "https://hub.silentpulse.io"
```

For air-gapped environments, point to your internal Hub instance. See [Connector Hub](/integrations/connectors/) for self-hosting instructions.

---

## Upgrading

```bash
helm repo update
helm upgrade silentpulse silentpulse/silentpulse \
  -n silentpulse -f values-override.yaml
```

Database migrations run automatically on API startup — no manual steps needed.

:::tip
Always back up your database before upgrading: `kubectl -n silentpulse exec silentpulse-postgres-0 -- pg_dump -U silentpulse silentpulse > backup.sql`
:::

## Uninstalling

```bash
helm uninstall silentpulse -n silentpulse
```

This removes all Kubernetes resources but preserves PersistentVolumeClaims (database data). To delete data permanently:

```bash
kubectl -n silentpulse delete pvc --all
```

## Next Steps

- [Architecture](/concepts/architecture/) — Understand the system components
- [Flows](/concepts/flows/) — Create your first monitoring flow
- [Integrations](/integrations/overview/) — Connect to your security stack
- [API Reference](/api/overview/) — Integrate with your tools
