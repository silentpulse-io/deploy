# Flow Editor v2 — Design Document

Multi-role design: Architect, Graphic Designer, Developer.
Reviewed and updated after architect review (2026-02-02).

---

## 1. Problem Statement

The current Flow Editor models a flat graph: **Asset Group → Integration Point** edges.
All configuration (query, hostname field, scheduler, time window) lives on the edge — a single
opaque JSON blob. This has several shortcomings:

1. **No concept of "processors"** — the user can't compose a chain like Kafka → Parser → Databricks.
2. **No distinction between the customer's real data flow and SilentPulse monitoring pulses.**
3. **No test/preview mode** — you save config blindly with no feedback loop.
4. **No per-processor start/stop** — the entire flow starts or stops as a unit.
5. **Edge properties panel is a flat form** — query_config is raw JSON, unstructured.

---

## 2. Core Concept: Two-Layer Model

### Layer 1 — Real Data Flow (readonly, reference)
The customer's actual data pipeline. Example:

```
Windows hosts  ──→  Kafka (topic: win-events)  ──→  Databricks (table: security_events)
```

This layer is **informational only**. It tells the user: "This is how your data normally travels."
SilentPulse does not control or manage this pipeline.

### Layer 2 — SilentPulse Monitoring Flow (editable)
SilentPulse pulses placed at specific points in the real pipeline. Example:

```
[Kafka pulse]               [Databricks pulse]
  ├─ Connection: broker:9092  ├─ Connection: jdbc:databricks://...
  ├─ Topic: win-events        ├─ Query: SELECT hostname FROM security_events
  ├─ Parser: JSONPath          │         WHERE ts > now() - interval '15m'
  │   └─ $.source.hostname    └─ Hostname field: hostname (direct)
  └─ Scheduler: every 5m
```

Each pulse is a **processor chain**: Integration → (optional Parser) → Validation.

### How they relate
The two layers are visually overlaid. The real-flow layer provides context ("where does data
go in your environment"), and the monitoring-flow layer shows where SilentPulse taps in.

---

## 3. Architect's Perspective

### 3.1 Processor Model

Replace the current flat edge model with a **processor chain** per monitoring point.

```
FlowPulse
├── source: IntegrationProcessor    (Kafka, Syslog, HTTP, S3, ...)
├── parser: ParserProcessor?        (JSONPath, Grok, Regex, Jolt — optional)
└── target: ValidationProcessor     (Query, Freshness check, Count check)
```

**Key decisions:**

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Processor granularity | 3 types (Integration, Parser, Validation) | Covers all use cases without over-abstraction |
| Parser optionality | Skip when source returns structured values directly | JDBC/SQL queries already return hostname — no parsing needed |
| Pulse independence | Each pulse has its own start/stop/status | Allows debugging one point without disrupting others |
| Execution model | Each pulse → 2 containers (worker + scheduler) | Worker collects & parses; Scheduler evaluates & alerts. Separation of concerns. |

### 3.2 Data Model Changes

#### Renaming: `flow_edges` → `flow_pulses`

This is a **rename + extend**, not a parallel table. All existing FK references
(`flow_edge_id`) are renamed to `flow_pulse_id` across the entire schema.

```sql
CREATE TABLE flow_pulses (
    id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    flow_id               UUID         NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
    tenant_id             UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    asset_group_id        UUID         NOT NULL REFERENCES asset_groups(id),
    label                 VARCHAR(255) NOT NULL DEFAULT '',
    position_x            FLOAT        NOT NULL DEFAULT 0,
    position_y            FLOAT        NOT NULL DEFAULT 0,
    -- Integration processor
    integration_point_id  UUID         NOT NULL REFERENCES integration_points(id) ON DELETE RESTRICT,
    integration_config    JSONB        NOT NULL DEFAULT '{}',
    -- Parser processor (nullable = no parser needed)
    parser_type           VARCHAR(20),   -- 'jsonpath', 'grok', 'regex', 'jolt', NULL
    parser_config         JSONB,         -- e.g. {"expression": "$.source.hostname"}
    -- Validation processor
    validation_type       VARCHAR(20)  NOT NULL DEFAULT 'freshness',
    validation_config     JSONB        NOT NULL DEFAULT '{}',
    hostname_field        VARCHAR(255) NOT NULL DEFAULT 'hostname',
    -- Scheduler
    scheduler_interval    INTERVAL     NOT NULL DEFAULT '5 minutes',
    time_window           INTERVAL     NOT NULL DEFAULT '15 minutes',
    collector_mode        VARCHAR(10)  NOT NULL DEFAULT 'batch'
                          CHECK (collector_mode IN ('batch', 'realtime')),
    -- Notification
    notification_channel_id UUID REFERENCES notification_channels(id),
    -- Metadata
    enabled               BOOLEAN      NOT NULL DEFAULT true,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at            TIMESTAMPTZ,

    -- Constraints
    CHECK (parser_type IS NULL OR parser_type IN ('jsonpath', 'grok', 'regex', 'jolt')),
    CHECK (validation_type IN ('freshness', 'count', 'query', 'exists'))
);

-- Indexes
CREATE INDEX idx_flow_pulses_flow    ON flow_pulses(flow_id);
CREATE INDEX idx_flow_pulses_tenant  ON flow_pulses(tenant_id);
CREATE INDEX idx_flow_pulses_ip      ON flow_pulses(integration_point_id);
CREATE INDEX idx_flow_pulses_active  ON flow_pulses(flow_id, enabled) WHERE deleted_at IS NULL;

-- RLS
ALTER TABLE flow_pulses ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_flow_pulses ON flow_pulses
    USING (tenant_id = current_setting('app.current_tenant')::uuid);
```

**Design decisions applied from architect review:**
- `tenant_id` added — enables direct RLS without joining through `flows`
- `asset_group_id` added — each pulse explicitly declares which asset group it monitors
  (different pulses in the same flow can monitor different asset groups)
- `updated_at` added — needed for optimistic concurrency and audit
- `deleted_at` added — consistent with soft-delete pattern across all entities
- `integration_point_id` uses `ON DELETE RESTRICT` — cannot delete IP while pulse references it
- CHECK constraints on `parser_type`, `validation_type`, `collector_mode`
- `string` → `VARCHAR(255)` (SQL type fix)

#### New: `flow_reference_edges` (Layer 1 — informational)

```sql
CREATE TABLE flow_reference_edges (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    flow_id      UUID         NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
    tenant_id    UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    source_label VARCHAR(100) NOT NULL,
    target_label VARCHAR(100) NOT NULL,
    order_index  INT          NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_flow_ref_edges_flow ON flow_reference_edges(flow_id);
```

#### Removed: `flow_nodes` and `flow_edges`

Old tables are dropped entirely (no parallel existence). This is a clean cut — the dev
database is recreated from scratch.

#### FK Migration Map

All tables referencing `flow_edge_id` are renamed to `flow_pulse_id`:

| Table | Old column | New column | Notes |
|-------|-----------|-----------|-------|
| `alerts` | `flow_edge_id` | `flow_pulse_id` | Core alerts |
| `asset_observations` | `flow_edge_id` | `flow_pulse_id` | Behavioral module |
| `asset_observations_hourly` | `flow_edge_id` | `flow_pulse_id` | Unique constraint updated |
| `asset_observations_daily` | `flow_edge_id` | `flow_pulse_id` | Unique constraint updated |
| `feed_profiles` | `flow_edge_id` | `flow_pulse_id` | One-to-one with pulse |
| `asset_profiles` | `flow_edge_id` | `flow_pulse_id` | Unique constraint updated |
| `threshold_suggestions` | `flow_edge_id` | `flow_pulse_id` | Behavioral module |
| `anomaly_events` | `flow_edge_id` | `flow_pulse_id` | Behavioral module |

All indexes on these columns are renamed accordingly.

#### AGE Graph Schema Update

```cypher
-- Old
(:Flow)-[:HAS_EDGE]->(:FlowEdge)-[:USES]->(:IntegrationPoint)

-- New
(:Flow)-[:HAS_PULSE]->(:FlowPulse)-[:USES]->(:IntegrationPoint)
(:FlowPulse)-[:MONITORS]->(:AssetGroup)
```

### 3.3 Execution Architecture

```
              ┌───────────────────────────────────────────┐
              │  Worker Container (per pulse)         │
              │                                           │
              │  ┌──────────┐  ┌────────┐                │
              │  │Integrate │→ │ Parse  │→ Write Redis   │
              │  │(plugin)  │  │(opt.)  │                │
              │  └──────────┘  └────────┘                │
              └───────────────────────────────────────────┘
                                    │
                                    │ Redis cache
                                    ↓
              ┌───────────────────────────────────────────┐
              │  Scheduler Container (per pulse)      │
              │                                           │
              │  Read CMDB (expected assets)              │
              │  Read Redis (observed assets)             │
              │  Compare → Generate/Resolve alerts        │
              └───────────────────────────────────────────┘
```

**Worker container** — collects data from the integration point, runs the optional parser
to extract hostnames, writes results to Redis cache. This is the existing worker pattern
extended with the parser step.

**Scheduler container** — unchanged from v1. Reads expected assets from CMDB (via
`asset_group_id`), reads observed assets from Redis, compares, generates/resolves alerts.
Runs on its own interval.

**Container count: 2 per pulse** (worker + scheduler), same as v1.
Parser runs in-process inside the worker — JSONPath, Grok, Regex are lightweight Go libs.

**Per-pulse start/stop** — Flow Controller manages containers per pulse ID.
API endpoints:

```
POST /api/v1/flows/{flowId}/pulses/{pulseId}/start
POST /api/v1/flows/{flowId}/pulses/{pulseId}/stop
GET  /api/v1/flows/{flowId}/pulses/{pulseId}/status
POST /api/v1/flows/{flowId}/start    (starts all enabled pulses)
POST /api/v1/flows/{flowId}/stop     (stops all pulses)
```

### 3.4 Test Mode Architecture

Test mode uses `fetch()` with `ReadableStream` (not `EventSource`) to support
JWT Bearer token authentication in headers.

```
POST /api/v1/flows/{flowId}/pulses/{pulseId}/test
Headers: Authorization: Bearer <JWT>
Request body: { "max_events": 10, "timeout_seconds": 30 }
Response: text/event-stream (SSE format via fetch + ReadableStream)
```

Events streamed:
```
event: integration_sample
data: {"raw": "{\"source\":{\"hostname\":\"WS-001\"}}", "timestamp": "..."}

event: parser_result
data: {"input": "...", "output": "WS-001", "matched": true}

event: validation_result
data: {"hostname": "WS-001", "status": "found", "last_seen": "..."}

event: test_complete
data: {"events_processed": 10, "parse_success": 9, "parse_fail": 1}
```

**Security & resource limits:**
- Auth via standard JWT Bearer header (works with fetch, not EventSource)
- Max 3 concurrent test sessions per tenant
- Hard server-side timeout: 60 seconds max
- Memory limit: buffer max 100 events per test session
- Context cancellation on client disconnect
- Test runs as **short-lived container** with dry-run flag (preserves security boundary —
  API server does NOT need encryption key for connection_config)

### 3.5 Versioning — Deferred to v3

Per architect review: versioning (draft/published) is deferred. The v2 migration scope is
already large. Current model: editing a flow requires stopping it first. Save replaces
the flow atomically.

Versioning will be revisited as a separate feature when the pulse model is stable.

### 3.6 Error Handling & Resilience

Carried forward from v1:
- **Circuit breaker** on worker collection (3 failures → 5min open)
- **Retry with exponential backoff** on transient errors
- **Parser errors**: events that fail parsing are skipped and counted. If >50% of events
  in a batch fail parsing, the worker logs a warning. This does NOT trigger an alert
  (that's the scheduler's job based on missing assets).
- **Auto-restart** with exponential backoff via Flow Controller health checks (unchanged)

---

## 4. Graphic Designer's Perspective

### 4.1 Overall Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  Flow Header (name, description, save button, start/stop)            │
├────────────┬─────────────────────────────────────────────────────────┤
│            │                                                         │
│  Processor │              Canvas (two-layer)                         │
│  Palette   │                                                         │
│            │   ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐        │
│  ┌───────┐ │   │ Layer 1: Real Data Flow (muted, dashed)   │        │
│  │Source │ │   │ [Windows] ···→ [Kafka] ···→ [Databricks]  │        │
│  ├───────┤ │   └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘        │
│  │Parser │ │                                                         │
│  ├───────┤ │   ┌─────────────────────────────────────────────┐       │
│  │Target │ │   │ Layer 2: SilentPulse Pulses (solid)    │       │
│  └───────┘ │   │                                             │       │
│            │   │  ┌──────────┐    ┌────────┐    ┌─────────┐ │       │
│  Asset     │   │  │  Kafka   │───→│JSONPath│───→│Freshness│ │       │
│  Groups    │   │  │ :9092    │    │$.host  │    │ check   │ │       │
│            │   │  └──────────┘    └────────┘    └─────────┘ │       │
│            │   │       ● running       ● ok         ● ok    │       │
│            │   │                                             │       │
│            │   │  ┌──────────┐                  ┌─────────┐ │       │
│            │   │  │Databricks│─────────────────→│  Query  │ │       │
│            │   │  │ JDBC     │   (no parser)    │freshness│ │       │
│            │   │  └──────────┘                  └─────────┘ │       │
│            │   │       ● running                    ● ok    │       │
│            │   └─────────────────────────────────────────────┘       │
│            │                                                         │
├────────────┴─────────────────────────────────────────────────────────┤
│  Properties / Test Panel (slide-up, tabbed)                          │
│  [Properties] [Test] [Logs]                                          │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │ Selected: Kafka pulse                                    │   │
│  │ Connection: broker-1:9092  Topic: win-events  Group: sp-...   │   │
│  │ Parser: JSONPath  Expression: $.source.hostname               │   │
│  │ Scheduler: every 5m  Window: 15m  Mode: realtime             │   │
│  └───────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

### 4.2 Two-Layer Visual Distinction

| Aspect | Layer 1: Real Data Flow | Layer 2: SilentPulse Pulses |
|--------|------------------------|----------------------------------|
| **Edges** | Dashed, `border-muted/40`, thin (1px) | Solid, `brand-500`, medium (2px) |
| **Nodes** | Rounded pill shape, `bg-muted/20`, `text-muted-foreground` | Card shape with shadow, `bg-card`, `border-border` |
| **Icons** | Muted gray (`text-muted-foreground`) | Colored per type (see below) |
| **Interactivity** | Hover tooltip only, not clickable for editing | Full click → select → properties panel |
| **Label** | Caption: "Your Data Pipeline" `text-xs uppercase tracking-wider text-muted-foreground` | Caption: "SilentPulse Monitoring" `text-xs uppercase tracking-wider text-brand-500` |

### 4.3 Processor Node Design

Each processor type has a distinct visual identity:

#### Integration Processor (Source)
```
┌─────────────────────────┐
│  ⚡ Kafka               │  ← icon + type label
│  broker-1:9092          │  ← connection summary (truncated)
│  topic: win-events      │  ← key config
│  ● running              │  ← status indicator
└────────────────────[▶]──┘  ← output handle
```
- Border-left: `4px solid` color per integration type
  - Kafka: `#F59E0B` (amber)
  - Splunk: `#22C55E` (green)
  - Elasticsearch: `#3B82F6` (blue)
  - Databricks: `#EF4444` (red)
  - JDBC: `#8B5CF6` (purple)
  - Syslog: `#6B7280` (gray)
- Size: ~200px wide, auto-height
- Background: `bg-card`

#### Parser Processor (Transform)
```
    ┌─────────────────────┐
[▶]─│  { } JSONPath       │  ← icon + parser type
    │  $.source.hostname  │  ← expression (monospace)
    │  ● matched 9/10     │  ← last test result
    └─────────────────[▶]─┘
```
- Border-left: `4px solid #A855F7` (purple, brand-adjacent)
- Icon: `{ }` for JSONPath, `.*` for Grok/Regex, `⇄` for Jolt
- Narrower: ~180px wide
- Expression shown in `font-mono text-xs`

#### Validation Processor (Target)
```
    ┌─────────────────────┐
[▶]─│  ✓ Freshness Check  │  ← icon + validation type
    │  field: hostname     │  ← hostname field
    │  window: 15m         │  ← time window
    │  ● 142/150 ok        │  ← last check result
    └─────────────────────┘
```
- Border-left: `4px solid #22C55E` (green)
- No output handle (terminal node)

#### Asset Group Node (Context)
```
┌─────────────────────────┐
│  📁 Windows EU hosts    │
│  150 assets             │
│  Filters: os=windows,   │
│  region=eu              │
└─────────────────────────┘
```
- Border-left: `4px solid brand-500`
- Connected to pulses via dashed line

### 4.4 Status Indicators

Small dot + label, inline within each processor node:

| Status | Dot color | Label |
|--------|-----------|-------|
| Running | `bg-green-500` + pulse animation | `running` |
| Stopped | `bg-gray-400` | `stopped` |
| Error | `bg-red-500` + pulse animation | `error: <message>` |
| Testing | `bg-amber-500` + pulse animation | `testing...` |
| Never run | `bg-gray-300` (outline only) | `not started` |

### 4.5 Properties Panel

Slides up from the bottom, height ~40% of canvas. Three tabs:

**Tab 1: Properties**
- Form fields specific to the selected processor type.
- Integration: connection fields, auth, topic/index/query.
- Parser: type selector (JSONPath / Grok / Regex / Jolt), expression input.
- Validation: type selector (freshness / count / query / exists), config fields.
- Scheduler: interval, time window, collector mode.
- Asset Group: selector for which asset group this pulse monitors.

**Tab 2: Test**
- "Start Test" button (with stop/cancel).
- Three-column live preview:
  - **Raw Input** — events from integration (scrollable, monospace).
  - **Parsed Output** — extracted values (highlighted matches).
  - **Validation Result** — hostname, status, last_seen.
- Event counter: "Processed 10/10 events".

**Tab 3: Logs**
- Streaming log output from the processor container.
- Filterable by level (INFO, WARN, ERROR).
- Monospace, dark background even in light theme (terminal feel).

### 4.6 Pulse Chain Layout

Within the monitoring layer, processors of a pulse are arranged horizontally:

```
[Integration] ──→ [Parser] ──→ [Validation]
     or
[Integration] ────────────────→ [Validation]   (when no parser)
```

- Edges within pulse: solid, `brand-500/60`, animated dash flow when running
- Edge between Asset Group and pulse: dashed, `text-muted-foreground/40`

### 4.7 Palette Redesign

Left sidebar, grouped into sections:

```
SOURCES
  ├─ Kafka
  ├─ Syslog / SC4S
  ├─ HTTP
  ├─ S3
  ├─ JDBC
  ├─ Databricks
  └─ (integration points list)

PARSERS
  ├─ JSONPath
  ├─ Grok / Regex
  └─ Jolt

VALIDATION
  ├─ Freshness Check
  ├─ Count Check
  ├─ Query Validation
  └─ Exists Check

ASSET GROUPS
  ├─ Windows EU hosts (150)
  └─ Linux servers (82)

REFERENCE FLOW
  └─ + Add pipeline step
```

### 4.8 Color System for Flow Editor

```
--flow-edge-real:       hsl(var(--muted-foreground) / 0.3)
--flow-edge-monitor:    hsl(var(--primary))
--flow-edge-animated:   hsl(var(--primary) / 0.6)
--flow-node-source:     #F59E0B    /* integration amber */
--flow-node-parser:     #A855F7    /* parser purple */
--flow-node-validation: #22C55E    /* validation green */
--flow-node-asset:      hsl(var(--primary))
--flow-bg-layer1:       hsl(var(--muted) / 0.3)
--flow-bg-layer2:       transparent
```

### 4.9 Typography in Flow Editor

- **Node title**: `text-sm font-semibold`
- **Node details**: `text-xs text-muted-foreground`
- **Node status**: `text-xs` + colored dot
- **Expression/code**: `font-mono text-xs`
- **Layer labels**: `text-xs uppercase tracking-wider font-semibold`
- **Panel headings**: `text-base font-semibold`
- **Panel form labels**: `text-sm font-medium`
- **Panel help text**: `text-xs text-muted-foreground`

### 4.10 Animations in Flow Editor

| Animation | Usage | Spec |
|-----------|-------|------|
| Edge data flow | Running pulse edges | `stroke-dasharray: 8 4; animation: dash-flow 1s linear infinite` |
| Status pulse | Running/error dot | `animate-pulse` (Tailwind built-in) |
| Node appear | Dragged onto canvas | `animate-fade-in` (0.2s) |
| Panel slide | Properties panel open/close | `transition: transform 0.2s ease-out` |
| Test event | New event in test panel | `animate-slide-in` per row (0.15s) |

---

## 5. Developer's Perspective

### 5.1 Frontend Architecture

#### Component Hierarchy

```
FlowEditorPage
├── FlowHeader (name, desc, save, start/stop)
├── FlowEditorLayout (horizontal split)
│   ├── ProcessorPalette (left sidebar, grouped, draggable items)
│   └── FlowCanvas (ReactFlow instance)
│       ├── ReferenceFlowLayer (Layer 1 — readonly pipeline nodes/edges)
│       ├── PulseNode (custom ReactFlow node — composite)
│       │   ├── IntegrationProcessor (sub-component)
│       │   ├── ParserProcessor (optional sub-component)
│       │   └── ValidationProcessor (sub-component)
│       ├── AssetGroupNode (existing, adapted)
│       └── PulseEdge (animated custom edge)
└── BottomPanel (slide-up, tabbed)
    ├── PropertiesTab
    │   ├── IntegrationPropertiesForm
    │   ├── ParserPropertiesForm
    │   └── ValidationPropertiesForm
    ├── TestTab
    │   ├── TestControls (start/stop, event count)
    │   ├── RawInputPreview (scrollable monospace)
    │   ├── ParsedOutputPreview (highlighted)
    │   └── ValidationResultPreview (table)
    └── LogsTab (streaming terminal-style log view)
```

#### Composite pulse node

Each pulse is a **single ReactFlow node** rendering its processor chain internally:

```tsx
<PulseNode>
  <IntegrationBlock type="kafka" config={...} status="running" />
  <Arrow />
  <ParserBlock type="jsonpath" config={...} />  {/* or null */}
  <Arrow />
  <ValidationBlock type="freshness" config={...} status="ok" />
</PulseNode>
```

**Rationale**: Keeps ReactFlow graph simple (AssetGroup → Pulse edges),
avoids complex multi-node management. Internal layout via flexbox.

#### State management

```tsx
interface FlowEditorState {
  flow: Flow;
  pulses: FlowPulse[];
  referenceEdges: ReferenceEdge[];
  assetGroupLinks: AssetGroupLink[];
  selectedPulseId: string | null;
  selectedProcessor: 'integration' | 'parser' | 'validation' | null;
  panelOpen: boolean;
  panelTab: 'properties' | 'test' | 'logs';
  testState: TestState;
  dirty: boolean;
}
```

#### Test mode (fetch + ReadableStream)

```tsx
function usePulseTest(flowId: string, pulseId: string) {
  const [events, setEvents] = useState<TestEvent[]>([]);
  const [status, setStatus] = useState<'idle' | 'running' | 'done'>('idle');
  const abortRef = useRef<AbortController | null>(null);

  const start = async (maxEvents = 10) => {
    const abort = new AbortController();
    abortRef.current = abort;
    setStatus('running');
    setEvents([]);

    const res = await fetch(
      `/api/v1/flows/${flowId}/pulses/${pulseId}/test`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${getToken()}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ max_events: maxEvents, timeout_seconds: 30 }),
        signal: abort.signal,
      }
    );

    const reader = res.body!.getReader();
    const decoder = new TextDecoder();
    // Parse SSE events from the stream...
  };

  const stop = () => { abortRef.current?.abort(); setStatus('idle'); };

  return { events, status, start, stop };
}
```

### 5.2 Backend Changes

#### Go domain types

```go
type FlowPulse struct {
    ID                    uuid.UUID
    FlowID                uuid.UUID
    TenantID              uuid.UUID
    AssetGroupID          uuid.UUID
    Label                 string
    PositionX, PositionY  float64
    // Integration
    IntegrationPointID    uuid.UUID
    IntegrationConfig     json.RawMessage
    // Parser (nullable)
    ParserType            *string
    ParserConfig          json.RawMessage
    // Validation
    ValidationType        string
    ValidationConfig      json.RawMessage
    HostnameField         string
    // Scheduler
    SchedulerInterval     string
    TimeWindow            string
    CollectorMode         string
    // Notification
    NotificationChannelID *uuid.UUID
    // Runtime
    Enabled               bool
    CreatedAt             time.Time
    UpdatedAt             time.Time
    DeletedAt             *time.Time
}
```

#### Parser interface

```go
type Parser interface {
    Parse(raw []byte) ([]string, error)
}

var parsers = map[string]func(config json.RawMessage) (Parser, error){
    "jsonpath": NewJSONPathParser,
    "grok":     NewGrokParser,
    "regex":    NewRegexParser,
}
```

Jolt deferred to a later phase (advanced feature).

#### Worker pipeline extension

```go
func (c *Collector) runPipeline(ctx context.Context) error {
    // Step 1: Collect from integration (existing plugin.Collect)
    raw, count, err := c.plugin.Collect(ctx, connConfig, c.cfg.IntegrationConfig)

    // Step 2: Parse (optional — new)
    var hostnames []string
    if c.cfg.ParserType != nil {
        parser, err := parsers[*c.cfg.ParserType](c.cfg.ParserConfig)
        if err != nil { return fmt.Errorf("init parser: %w", err) }
        for _, event := range raw {
            names, err := parser.Parse(event.Raw)
            if err != nil {
                c.parseErrors++
                continue // skip unparseable events
            }
            hostnames = append(hostnames, names...)
        }
    } else {
        for _, asset := range raw {
            hostnames = append(hostnames, asset.Hostname)
        }
    }

    // Step 3: Write to Redis cache (existing)
    c.writeToRedis(ctx, hostnames)
    return nil
}
```

Circuit breaker, retry, and exponential backoff are preserved from v1.

#### Redis key schema update

```
Old: tenant:{tenant_id}:flow_edge:{flow_edge_id}:assets
New: tenant:{tenant_id}:pulse:{pulse_id}:assets
```

#### Flow Controller updates

- Container labels: `silentpulse.flow-edge-id` → `silentpulse.pulse-id`
- Container ref struct: `FlowEdgeID` → `PulseID`
- Restart key: uses `PulseID` + Role
- `loadFlow` loads pulses instead of edges
- Environment variable: `FLOW_EDGE_ID` → `PULSE_ID`

### 5.3 Go Rename Map (FlowEdgeID → FlowPulseID)

Complete list of Go files requiring `FlowEdge` → `FlowPulse` rename:

**Domain:**
- `domain/flow.go` — FlowEdge struct → FlowPulse
- `domain/alert.go` — FlowEdgeID field → FlowPulseID
- `domain/behavioral.go` — FlowEdgeID in 8 structs → FlowPulseID

**Repository:**
- `repository/alert.go` — interface methods, AlertFilter
- `repository/behavioral.go` — AnomalyFilter
- `repository/postgres/alert_postgres.go` — all SQL queries (~15 locations)
- `repository/postgres/behavioral_postgres.go` — all SQL queries (~30 locations)
- `repository/postgres/flow_postgres.go` — complete rewrite for pulses

**Handler:**
- `handler/alert.go` — query parameter
- `handler/behavioral.go` — query parameters (4 locations)
- `handler/demo.go` — FlowEdgeIDs field, queries, container count
- `handler/worker_status.go` — query parameter
- `handler/flow.go` — complete rewrite for pulses

**Worker/Scheduler:**
- `worker/collector.go` — CollectorConfig, all logging, Redis key
- `worker/status.go` — CollectorStatus field
- `scheduler/evaluator.go` — EvaluatorConfig, all logging, Redis key, alert creation

**Flow Controller:**
- `flowcontroller/manager.go` — labels, containerRef, restartKey, env vars

**Other:**
- `health/heartbeat.go` — Heartbeat struct
- `notifier/channels/channel.go` — AlertPayload
- `notifier/dispatcher.go` — payload, rule matching
- `reporting/alert_summary.go` — SQL joins
- `reporting/compliance.go` — SQL joins
- `reporting/executive.go` — SQL subqueries
- `reporting/visibility_gaps.go` — SQL joins
- `cmd/worker/main.go` — config
- `cmd/scheduler/main.go` — config

**Frontend:**
- `types/api.ts` — FlowEdge interface → FlowPulse, Alert.flow_edge_id
- `components/flow/` — all flow components
- `app/(dashboard)/dashboard/alerts/` — display fields

### 5.4 Libraries

| Need | Library | Status |
|------|---------|--------|
| Graph editor | `@xyflow/react` (ReactFlow) | Already installed |
| JSONPath (Go) | `github.com/PaesslerAG/jsonpath` | New dependency |
| Grok parser (Go) | `github.com/vjeantet/grok` | New dependency |
| SSE server (Go) | stdlib `net/http` + Flusher | No dependency |
| SSE client (JS) | `fetch()` + `ReadableStream` | Built-in browser API |

---

## 6. Interaction Flows

### 6.1 Building a new pulse

1. User drags "Kafka" from Sources palette onto canvas.
2. Node appears as Integration block with empty config.
3. Properties panel opens automatically.
4. User fills connection details (broker, topic, auth).
5. User selects asset group from dropdown.
6. User drags "JSONPath" from Parsers → attaches to the pulse.
7. User types `$.source.hostname` in expression field.
8. User clicks "Test" tab → "Start Test".
9. Stream shows raw Kafka events, parsed hostnames, validation results.
10. User adjusts parser expression if needed, re-tests.
11. When satisfied: configure scheduler interval and time window.
12. Save flow.

### 6.2 Testing a processor

1. Select a pulse node on canvas.
2. Click "Test" tab in bottom panel.
3. Click "Start Test" — POST request with JWT auth.
4. System spawns ephemeral container, connects to integration point.
5. Events stream: Raw → Parsed → Validated.
6. User can "Stop" at any time.
7. User can modify parser expression and re-test without saving.
8. "Apply Changes" persists test-time edits.

### 6.3 Modeling the reference flow

1. Click "+ Add Pipeline Step" in Reference Flow palette.
2. Enter label (e.g., "Windows hosts", "Kafka", "Databricks").
3. Steps appear as horizontal chain in Layer 1 (dashed, muted).
4. Purely informational — context for understanding.

---

## 7. Resolved Questions

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | Composite vs separate nodes? | Composite | Simpler graph, better UX |
| 2 | Reference flow on same canvas? | Same canvas | Constant visual context |
| 3 | Jolt transforms? | Deferred | Start with JSONPath + Grok; Jolt later |
| 4 | Validation separate or built-in? | Built-in | Every pulse needs validation |
| 5 | Versioning? | Deferred to v3 | Current migration scope is sufficient |
| 6 | Scheduler placement? | Separate container | Separation of concerns with worker |
| 7 | SSE auth? | fetch + ReadableStream | EventSource cannot send JWT headers |
| 8 | Test execution? | Ephemeral container | Preserves security boundary |
| 9 | Pulse ↔ asset group? | `asset_group_id` on pulse | Explicit, allows different groups per pulse |

---

## 8. Implementation Order

1. **Database schema** — drop old tables, create `flow_pulses` + `flow_reference_edges`,
   update all FK references in dependent tables.
2. **Go domain types** — rename FlowEdge → FlowPulse across all structs.
3. **Go repositories** — update all SQL queries.
4. **Go handlers, worker, scheduler, flow controller** — update all business logic.
5. **Frontend types** — update TypeScript interfaces.
6. **Frontend flow editor** — new composite node component, palette, properties panel.
7. **Test mode** — parser implementations, test endpoint, frontend test panel.
8. **Build & verify** — compile Go + Next.js, run tests.
