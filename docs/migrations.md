# Database Migrations

SilentPulse uses [golang-migrate](https://github.com/golang-migrate/migrate) for schema management.

## Source of truth

All migration files live in `src/backend/migrations/`. This is the **only** place where the database schema is defined.

```
src/backend/migrations/
├── embed.go                                # Go embed directive
├── prerequisites.sql                       # Extensions (run once as superuser)
├── baseline.sql                            # For existing databases
├── 000001_initial_schema.up.sql            # Full initial schema
├── 000001_initial_schema.down.sql          # Rollback
├── 000002_audit_log_context.up.sql         # Audit log operational context
├── 000002_audit_log_context.down.sql       # Rollback
├── 000003_alert_notify_trigger.up.sql      # LISTEN/NOTIFY trigger for alerts
└── 000003_alert_notify_trigger.down.sql    # Rollback
```

## Creating a new migration

Use the provided script:

```bash
make migration name=add_tags_table
```

This creates a numbered pair:
```
src/backend/migrations/000003_add_tags_table.up.sql
src/backend/migrations/000003_add_tags_table.down.sql
```

### Naming conventions

- Use snake_case: `add_tags_table`, `alter_alerts_add_priority`
- Prefix with verb: `add_`, `alter_`, `drop_`, `create_index_`
- Each migration must have both `.up.sql` and `.down.sql`
- The `.down.sql` must exactly reverse the `.up.sql`

### Writing migrations

**up.sql:**
```sql
ALTER TABLE alerts ADD COLUMN priority VARCHAR(10) DEFAULT 'medium';
CREATE INDEX idx_alerts_priority ON alerts(priority);
```

**down.sql:**
```sql
DROP INDEX IF EXISTS idx_alerts_priority;
ALTER TABLE alerts DROP COLUMN IF EXISTS priority;
```

### Tips

- Use `IF NOT EXISTS` / `IF EXISTS` for idempotency where possible
- Nullable columns with pgx require `COALESCE()` in SELECT queries (pgx Scan doesn't handle NULL → string)
- Test both up and down locally before pushing

## How it runs

The API service runs migrations automatically on startup (before connecting to the database pool):

```
cmd/api/main.go → database.RunMigrations() → golang-migrate (embed.FS)
```

`RunMigrations()` retries up to 30 times with 2-second intervals if the database isn't ready yet.

## Testing locally

### OrbStack (K8s)

```bash
# Check current version
kubectl exec silentpulse-postgres-0 -n silentpulse -- \
  psql -U silentpulse -d silentpulse -c "SELECT version, dirty FROM schema_migrations"

# Restart API to re-run migrations
kubectl rollout restart deployment/silentpulse-api -n silentpulse
```

### Docker Compose

```bash
make dev-restart
# or manually:
docker compose -f deploy/docker-compose/docker-compose.yml up -d --build api
```

## Operational runbook

### Setting up a new database

1. Create the database and user
2. Run `prerequisites.sql` as superuser (creates extensions: uuid-ossp, pgcrypto, age)
3. Start the API service — migrations run automatically

### Existing database (already has tables from init-db scripts)

Run `baseline.sql` once:

```bash
kubectl exec silentpulse-postgres-0 -n silentpulse -- \
  psql -U silentpulse -d silentpulse -f /path/to/baseline.sql
```

This creates `schema_migrations` with version=1, so golang-migrate skips the initial schema.

### Checking current version

```bash
kubectl exec silentpulse-postgres-0 -n silentpulse -- \
  psql -U silentpulse -d silentpulse -c "SELECT version, dirty FROM schema_migrations"
```

Expected output:
```
 version | dirty
---------+-------
       2 | f
```

### Handling dirty state

If `dirty = true`, a migration failed mid-way. Fix the issue, then force the version:

```bash
# Using migrate CLI:
migrate -path src/backend/migrations \
  -database "postgres://user:pass@host:5432/silentpulse?sslmode=disable" \
  force <VERSION>
```

Or manually:

```sql
UPDATE schema_migrations SET dirty = false WHERE version = <VERSION>;
```

Then restart the API to re-apply pending migrations.

### Manual rollback

```bash
# Roll back one version:
migrate -path src/backend/migrations \
  -database "postgres://user:pass@host:5432/silentpulse?sslmode=disable" \
  down 1

# Roll back to specific version:
migrate -path src/backend/migrations \
  -database "postgres://user:pass@host:5432/silentpulse?sslmode=disable" \
  goto <VERSION>
```

### Extension prerequisites

Extensions require superuser privileges and must be created before migrations:

| Extension | Purpose |
|-----------|---------|
| uuid-ossp | UUID generation |
| pgcrypto | Cryptographic functions |
| age | Apache AGE graph extension |

In Docker Compose: `deploy/docker-compose/init-extensions/01-extensions.sql`
In Helm: inline in `deploy/helm/silentpulse/templates/initdb-configmap.yaml`

## Encryption key rotation

SilentPulse encrypts credentials stored in three tables: `integration_points.connection_config`, `notification_channels.config`, and `ai_configs.api_key_enc`. The `migrate-credentials` CLI tool manages both v1→v2 migration and master key rotation.

### Building the tool

```bash
cd src/backend && go build -o migrate-credentials ./cmd/migrate-credentials/
```

### Mode 1: Migrate to per-tenant encryption (v1 → v2)

Re-encrypts credentials from master key (v1) to per-tenant HKDF-derived keys (v2):

```bash
ENCRYPTION_KEY=<current-64-hex-key> \
POSTGRES_DSN=postgres://user:pass@host/db \
HKDF_SALT=<optional-custom-salt> \
./migrate-credentials [--dry-run]
```

After migration, set `PER_TENANT_ENCRYPTION=true` in all services (api, worker, notifications).

### Mode 2: Rotate master key

Decrypts all credentials with the old key and re-encrypts with a new key. Handles both v1 and v2 encrypted data. Preserves encryption version.

```bash
OLD_ENCRYPTION_KEY=<old-64-hex-key> \
ENCRYPTION_KEY=<new-64-hex-key> \
POSTGRES_DSN=postgres://user:pass@host/db \
HKDF_SALT=<optional-custom-salt> \
./migrate-credentials --rotate [--dry-run]
```

### Rotation procedure

1. **Generate new key:** `openssl rand -hex 32`
2. **Dry run:** Run with `--dry-run` to verify all credentials can be decrypted
3. **Stop services:** Scale down api, worker, notifications deployments
4. **Rotate:** Run `migrate-credentials --rotate`
5. **Update secret:** Replace `ENCRYPTION_KEY` in K8s secret with the new key
6. **Restart services:** Scale deployments back up

### Safety features

- Entire operation runs in a single PostgreSQL transaction
- `pg_advisory_xact_lock` prevents concurrent runs
- Failure rolls back atomically — no partial re-encryption
- All three credential tables (integration_points, notification_channels, ai_configs) processed together
- Dry-run mode previews changes without applying

## CI validation

PRs touching `src/backend/migrations/` trigger a GitHub Actions workflow that runs a full roundtrip test: up → down → up. See `.github/workflows/migrations.yml`.
