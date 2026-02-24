# MCP Server

SilentPulse as a Model Context Protocol provider, allowing external LLMs and AI agents
to query alert status, MITRE coverage, telemetry health, and asset inventory.

## Transport

- **stdio** (default) — for Claude Desktop, local AI tools
- **HTTP/SSE** — set `MCP_TRANSPORT=http` and `MCP_ADDR=:8090`

## Configuration

| Variable        | Description                | Default                                |
|-----------------|----------------------------|----------------------------------------|
| `POSTGRES_DSN`  | PostgreSQL connection URL  | (required)                             |
| `MCP_TENANT_ID` | Tenant UUID                | `a0000000-0000-0000-0000-000000000001` |
| `MCP_TRANSPORT` | Transport: `stdio` or `http` | `stdio`                              |
| `MCP_ADDR`      | HTTP listen address        | `:8090`                                |

## Resources

| URI                           | Description                                           |
|-------------------------------|-------------------------------------------------------|
| `silentpulse://alerts/stats`  | Aggregated alert statistics (by status, severity, type) |
| `silentpulse://alerts/active` | Currently open alerts with severity and asset details  |
| `silentpulse://flows/status`  | All flow pipelines with enabled/disabled status        |
| `silentpulse://mitre/coverage`| MITRE ATT&CK coverage summary (if module enabled)     |

## Tools

| Tool                           | Description                                           |
|--------------------------------|-------------------------------------------------------|
| `search_alerts`                | Search alerts by status, severity, type, asset group  |
| `get_alert_stats`              | Get aggregated alert statistics                       |
| `list_flows`                   | List all monitoring flow pipelines                    |
| `list_observation_types`       | List observation types with entity/group counts       |
| `search_entities`              | Search observed entities by external ID or type       |
| `get_entities_with_status`     | Entities with monitoring status (critical/active/passive) |
| `get_mitre_coverage`           | MITRE ATT&CK coverage summary (if module enabled)    |
| `check_asset_group_mitre_impact` | MITRE impact for specific asset group               |

## Usage with Claude Desktop

Add to `~/.claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "silentpulse": {
      "command": "/path/to/silentpulse-mcp",
      "env": {
        "POSTGRES_DSN": "postgres://user:pass@localhost:5432/silentpulse?sslmode=disable"
      }
    }
  }
}
```

## Implementation

### Binary
- `cmd/mcp/main.go` — standalone binary, connects to PostgreSQL, starts MCP server
- Supports stdio (default) and HTTP/SSE transports

### Package
- `internal/mcpserver/server.go` — creates MCP server, registers tools and resources
- `internal/mcpserver/resources.go` — static resource handlers (alerts, flows, MITRE)
- `internal/mcpserver/tools.go` — tool handlers with parameter validation

### Dependencies
- `github.com/mark3labs/mcp-go` v0.44.0 — Go MCP SDK
- Reuses existing repository layer (no new DB tables needed)

### Health Check

In HTTP mode, the MCP server exposes `/healthz` (checks PostgreSQL connectivity).

### MITRE module
MITRE-related resources and tools are conditionally registered only when `deps.Mitre != nil`.

## Deployment

### Docker

```bash
docker build -f deploy/docker/Dockerfile.mcp -t silentpulse-mcp:latest .
```

### Kubernetes (Helm)

Enable in `values.yaml`:
```yaml
mcp:
  enabled: true
  image: silentpulse-mcp:latest
  port: 8090
```

Creates a Deployment + ClusterIP Service. Accessible at `silentpulse-mcp:8090` within the cluster.
Ingress rule `/mcp` is conditionally added when enabled.

### Docker Compose

```bash
docker compose --profile mcp up -d mcp
```
