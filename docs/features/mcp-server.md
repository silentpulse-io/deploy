# MCP Server

SilentPulse as a Model Context Protocol provider, allowing external LLMs and AI agents
to query alert status, MITRE coverage, telemetry health, and asset inventory.

## Transport

- **stdio** (default) — for Claude Desktop, local AI tools
- **HTTP/SSE** — set `MCP_TRANSPORT=http` and `MCP_ADDR=:8090`

## Configuration

| Variable             | Description                                   | Default                                |
|----------------------|-----------------------------------------------|----------------------------------------|
| `MCP_API_URL`        | SilentPulse REST API base URL (required)      | —                                      |
| `MCP_API_TOKEN`      | Service account JWT token for API auth (required) | —                                  |
| `MCP_TENANT_ID`      | Tenant UUID                                   | `a0000000-0000-0000-0000-000000000001` |
| `MCP_TRANSPORT`      | Transport: `stdio` or `http`                  | `stdio`                                |
| `MCP_ADDR`           | HTTP listen address                           | `127.0.0.1:8090`                       |
| `MCP_MITRE_ENABLED`  | Set `true` to enable MITRE tools/resources    | `false`                                |
| `MCP_RATE_LIMIT`     | HTTP requests per second per client IP        | `10`                                   |
| `MCP_TLS_CERT`       | Path to TLS certificate file (enables HTTPS)  | —                                      |
| `MCP_TLS_KEY`        | Path to TLS private key file                  | —                                      |
| `MCP_TLS_CLIENT_CA`  | Path to client CA certificate (enables mTLS)  | —                                      |
| `MCP_API_KEY`        | API key for HTTP transport client auth (required if http) | —                        |

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
| `get_alert_detail`             | Full detail for a single alert by ID                  |
| `get_alert_timeline`           | Recent alerts for a specific entity or asset group    |
| `list_flows`                   | List all monitoring flow pipelines                    |
| `get_flow_diagnostics`         | Detailed diagnostics for a flow: config + runtime status |
| `list_observation_types`       | List observation types with entity/group counts       |
| `search_entities`              | Search observed entities by external ID or type       |
| `get_entities_with_status`     | Entities with monitoring status (critical/active/passive) |
| `get_asset_group_details`      | Asset group details with full asset list              |
| `search_audit_logs`            | Search audit trail by user, action, entity, or date   |
| `get_mitre_coverage`           | MITRE ATT&CK coverage summary (if module enabled)    |
| `check_asset_group_mitre_impact` | MITRE impact for specific asset group             |
| `simulate_flow_impact`         | Predict MITRE coverage loss when a flow stops (if module enabled) |

## Usage with Claude Desktop

Add to `~/.claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "silentpulse": {
      "command": "/path/to/silentpulse-mcp",
      "env": {
        "MCP_API_URL": "http://silentpulse-api:8080",
        "MCP_API_TOKEN": "<service-account-jwt-token>",
        "MCP_TENANT_ID": "<your-tenant-uuid>"
      }
    }
  }
}
```

## Security

### Authentication
- **HTTP transport**: Requires `MCP_API_KEY` (min 32 chars). Clients send via `Authorization: Bearer <key>` or `X-API-Key: <key>`.
- **stdio transport**: No network exposure; inherits OS process security.

### Rate Limiting
- Per-client IP token bucket limiter (default 10 req/s, burst 20).
- Configurable via `MCP_RATE_LIMIT` env var.
- Returns HTTP 429 with `Retry-After: 1` when exceeded.

### TLS Enforcement
- Set `MCP_TLS_CERT` + `MCP_TLS_KEY` to enable HTTPS (TLS 1.2+).
- Set `MCP_TLS_CLIENT_CA` additionally to require mTLS (client certificate auth).
- Security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Content-Security-Policy`, `Cache-Control`.

### Audit Logging
- Every tool invocation is logged to stdout: `[mcp-audit] tool=<name> tenant=<id> ok=<bool> ms=<duration> time=<iso8601>`.
- Log lines can be captured by any log aggregation system (Loki, Splunk, etc.).

## Implementation

### Architecture
The MCP binary calls the SilentPulse REST API instead of connecting directly to PostgreSQL.
This isolates the MCP server from the database and enforces all authorization rules via the API.

### Binary
- `cmd/mcp/main.go` — standalone binary, calls SilentPulse REST API, starts MCP server
- Supports stdio (default) and HTTP/SSE transports
- HTTP transport supports TLS, mTLS, per-IP rate limiting, and API key authentication

### Package
- `internal/mcpserver/apiclient.go` — REST API client (bearer token auth, JSON passthrough)
- `internal/mcpserver/server.go` — creates MCP server, registers tools and resources
- `internal/mcpserver/resources.go` — static resource handlers (alerts, flows, MITRE)
- `internal/mcpserver/tools.go` — tool handlers with audit logging wrapper

### Health Check

In HTTP mode, the MCP server exposes `/healthz` which pings `GET /api/v1/alerts/stats`
to verify backend connectivity and API authentication.

### MITRE module
MITRE-related resources and tools are conditionally registered when `MCP_MITRE_ENABLED=true`.

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
  env:
    MCP_API_URL: "http://silentpulse-api:8080"
    MCP_API_TOKEN: "<service-account-jwt>"
    MCP_MITRE_ENABLED: "true"
```

Creates a Deployment + ClusterIP Service. Accessible at `silentpulse-mcp:8090` within the cluster.
Ingress rule `/mcp` is conditionally added when enabled.

### Docker Compose

```bash
docker compose --profile mcp up -d mcp
```
