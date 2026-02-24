---
title: Quick Start
description: Get SilentPulse running in 5 minutes with Docker Compose.
---

# Quick Start

Get SilentPulse up and running locally in minutes using Docker Compose.

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM available

## 1. Clone the Deploy Repository

```bash
git clone https://github.com/silentpulse-io/deploy.git
cd deploy
```

## 2. Configure

```bash
cp deploy/docker-compose/.env.example deploy/docker-compose/.env
```

Edit `.env` to set at minimum:
- `JWT_SECRET` — generate with `openssl rand -hex 32`
- `POSTGRES_PASSWORD` — change from default

## 3. Start the Stack

```bash
docker compose -f deploy/docker-compose/docker-compose.yml up -d
```

This starts:
- **PostgreSQL** with Apache AGE (graph database)
- **Redis** (observation cache)
- **API Server** (REST API)
- **CMDB Sync** (asset synchronization)
- **Health** (health monitoring)
- **Notifications** (alert dispatcher)
- **Reporting** (report generation)
- **Frontend** (React dashboard)

## 4. Access the Dashboard

Open [http://localhost:3000](http://localhost:3000) in your browser.

Default credentials:
- Email: `admin@silentpulse.local`
- Password: `admin123`

> **WARNING:** Change the default admin password immediately after first login.

## 5. Create Your First Flow

1. Navigate to **Flows** → **New Flow**
2. Add an **Asset Group** node (e.g., "Windows Servers")
3. Add an **Observation Type** node (e.g., "EDR Telemetry")
4. Connect them and configure the integration
5. Save and activate the flow

## Optional: Enable MCP Server

```bash
docker compose -f deploy/docker-compose/docker-compose.yml --profile mcp up -d
```

The MCP server will be available at `http://localhost:8090`.

## Next Steps

- [Installation Guide](/getting-started/installation/) — Production deployment with Helm
- [Architecture](/concepts/architecture/) — Understand how SilentPulse works
- [Integrations](/integrations/overview/) — Connect to your security stack
