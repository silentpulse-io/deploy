# SilentPulse — Features Manifest

Źródło prawdy o statusie implementacji funkcjonalności.
Specyfikacje w katalogu `features/`.

## System modułów

SilentPulse używa systemu modułów. Szczegóły: [modules.md](modules.md)

- **Core** — zawsze włączony, podstawowa funkcjonalność
- **Moduły opcjonalne** — można włączać/wyłączać niezależnie

## Features

### Core (wymagany)

| Feature              | Status      | Priorytet | Specyfikacja                              |
|----------------------|-------------|-----------|-------------------------------------------|
| CMDB Sync            | done        | high      | [features/cmdb-sync.md](features/cmdb-sync.md)                 |
| Asset Groups         | done        | high      | [features/asset-groups.md](features/asset-groups.md)            |
| Integration Points   | done        | high      | [features/integration-points.md](features/integration-points.md)|
| Flows                | done        | high      | [features/flows.md](features/flows.md)                         |
| Alerting             | done        | high      | [features/alerting.md](features/alerting.md)                   |
| Notifications        | done        | high      | [features/notifications.md](features/notifications.md)         |
| Self-Monitoring      | done        | high      | [features/self-monitoring.md](features/self-monitoring.md)     |
| Error Handling       | done        | high      | [features/error-handling.md](features/error-handling.md)       |
| Data Retention       | done        | high      | [features/data-retention.md](features/data-retention.md)       |
| Reporting            | done        | medium    | [features/reporting.md](features/reporting.md)                 |
| Dashboards           | done        | medium    | [features/dashboards.md](features/dashboards.md)               |
| Exclusion Windows    | done        | high      | [features/exclusion-windows.md](features/exclusion-windows.md) |
| KPI Compliance       | done        | high      | [features/kpi-compliance.md](features/kpi-compliance.md)       |
| Graph Explorer       | done        | medium    | [features/graph-explorer.md](features/graph-explorer.md)       |
| Asset Tagging        | done        | medium    | [features/tagging.md](features/tagging.md)                     |
| PulseCheck           | done        | high      | [features/pulse-check.md](features/pulse-check.md)             |
| Working Modes        | done        | medium    | [features/workingmode.md](features/workingmode.md)             |
| Enhanced Audit Logs  | done        | high      | [features/enhanced-audit-logs.md](features/enhanced-audit-logs.md) |
| Audit Log Export     | done        | medium    | [features/audit-log-export.md](features/audit-log-export.md)  |

### Infrastruktura

| Feature              | Status      | Priorytet | Specyfikacja / Milestone                  |
|----------------------|-------------|-----------|-------------------------------------------|
| Database Migrations  | done        | high      | Milestone [#24](https://github.com/silentpulse-io/silentpulse/milestone/24) |

**Database Migrations** — golang-migrate jako single source of truth dla schematu DB:
- ✅ Konsolidacja schematu (39 plików init-db → 000001_initial_schema) — #147
- ✅ Migration runner z retry logic w API startup — #147
- ✅ Baseline script dla istniejących baz — #147
- ✅ CI walidacja migracji (up/down roundtrip) — #161
- ✅ Dokumentacja i runbook operacyjny — #162
- ✅ Tooling do tworzenia nowych migracji — #163

### Moduł: mitre (opcjonalny)

| Feature              | Status      | Priorytet | Specyfikacja                              |
|----------------------|-------------|-----------|-------------------------------------------|
| MITRE ATT&CK Mapping | done        | high      | [features/mitre-mapping.md](features/mitre-mapping.md)          |

### Moduł: behavioral (opcjonalny)

| Feature              | Status      | Priorytet | Specyfikacja                              |
|----------------------|-------------|-----------|-------------------------------------------|
| Behavioral Analytics | done        | high      | [features/behavioral-analytics.md](features/behavioral-analytics.md) |

### Moduł: ai-assistant (opcjonalny)

| Feature              | Status      | Priorytet | Specyfikacja                              |
|----------------------|-------------|-----------|-------------------------------------------|
| AI Assistant         | done        | medium    | [features/ai-assistant.md](features/ai-assistant.md)            |
| MCP Server           | done        | medium    | [features/mcp-server.md](features/mcp-server.md)               |

Statusy: `planned` → `in-progress` → `done`
