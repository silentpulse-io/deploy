# Connector Permissions — Recommended Minimums

SilentPulse holds credentials to every monitored security system. Apply the
principle of least privilege: grant only what SilentPulse needs, nothing more.

## Per Connector Type

### Kafka

- **Consumer group** membership only (no produce, no admin)
- Read-only access on the specific topic(s) configured in the flow
- No `ALTER`, `CREATE`, or `DELETE` ACLs
- Recommended: dedicated consumer group `silentpulse-<flow-name>`

### Splunk

- `search` capability only — no `admin`, `edit_*`, or `restart` capabilities
- Restrict to the specific indexes configured in the flow
- Read-only search access via service account (not personal)
- Recommended: create a dedicated Splunk role `silentpulse_reader`

### Elasticsearch

- `read` role on the specific indices configured in the flow
- No `write`, `manage`, or `cluster:admin` privileges
- Use API keys with index-level restrictions rather than user credentials
- Recommended: create a role `silentpulse_read` with `indices: [{ names: [...], privileges: ["read"] }]`

### Syslog

- Receive-only listener — no management access
- SilentPulse only needs to read incoming syslog events
- No access to syslog daemon configuration

### REST API

- Read-only API tokens where available
- Avoid admin/management tokens
- Use API keys with explicit scope restrictions
- Rotate keys on a regular schedule (90 days recommended)

## General Guidelines

1. **Dedicated service accounts** — never share credentials with human users
2. **Scope to specific resources** — limit to the exact indices/topics/searches needed
3. **Read-only by default** — SilentPulse only reads telemetry, never writes
4. **Rotate regularly** — enable per-tenant encryption and rotate the master key periodically
5. **Audit access** — enable `credential_access_log` to track when credentials are decrypted
6. **Network isolation** — restrict SilentPulse's network access to only the monitored endpoints
