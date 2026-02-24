# Licensing System & Connector Hub — Architecture

Dokument architektoniczny opisujący nowe systemy zewnętrzne:
1. **License Server** (`license.silentpulse.io`) — API serwera licencji (validate, refresh, report)
2. **Admin Panel** (`admin.silentpulse.io`) — panel administracyjny (klienci, licencje, billing, usage)
3. **Connector Hub** (`hub.silentpulse.io`) — dystrybucja definicji connectorów bez aktualizacji aplikacji

## 1. License Server (`license.silentpulse.io`) + Admin Panel (`admin.silentpulse.io`)

### 1.1. Cel

Dwa osobne serwisy na osobnych subdomenach:

- **`license.silentpulse.io`** — publiczne API licencji (validate, refresh, report). Dostępne dla instancji SilentPulse klientów.
- **`admin.silentpulse.io`** — panel administracyjny (UI + admin API). Dostępny wyłącznie dla właściciela. Zabezpieczony Cloudflare Access.

Rozdzielenie pozwala na:
- Osobne reguły dostępu (Cloudflare Access tylko na admin, license publiczny)
- Niezależne rate limiting (license: liberalny, admin: restrykcyjny)
- Czytelne nazewnictwo domen

### 1.2. Technologia

| Komponent | Technologia | Uzasadnienie |
|-----------|-------------|--------------|
| Komponent | Subdomena | Technologia | Uzasadnienie |
|-----------|-----------|-------------|--------------|
| License API | `license.silentpulse.io` | **Node.js + Fastify** | Publiczne API, lekki, szybki |
| Admin Panel | `admin.silentpulse.io` | **Node.js + Fastify + htmx + Tailwind CSS** | SSR HTML, brak build stepu, single-admin |
| Baza (wspólna) | — | **SQLite** (lub **MySQL/PG**) | Oba serwisy współdzielą bazę |
| Kryptografia | — | **Ed25519** | Szybkie podpisy, krótkie klucze (32B), bezpieczne |
| Format klucza | — | **JWT (JWS)** | Samoopisujący się token, weryfikowalny offline |

> Jeśli SQLite okaże się niewystarczający (np. concurrent writes, backup, replikacja),
> można przemigrować na MySQL/PG bez zmiany architektury.

### 1.3. Architektura klucza licencyjnego

Klucz licencyjny to **podpisany JWT (JWS)** z algorytmem Ed25519:

```
Header:  { "alg": "EdDSA", "typ": "JWT", "kid": "key-2026-02" }
Payload: {
  "ver": 1,                          // wersja formatu — zamrożona, kontrakt API
  "iss": "license.silentpulse.io",
  "sub": "customer-uuid",
  "iat": 1738000000,
  "exp": 1769536000,               // data wygaśnięcia
  "jti": "license-key-uuid",
  "org": "ACME Corp",              // nazwa organizacji
  "contact": "admin@acme.com",     // contact point
  "tier": "professional",          // community | professional | enterprise
  "modules": ["core", "mitre", "behavioral"],
  "limits": {
    "assets": -1,                   // -1 = unlimited
    "flows": -1,
    "integration_points": -1,
    "users": 50,
    "observations_per_day": 100000, // quota obserwacji
    "retention_days": 90
  },
  "pricing": {
    // Pricing details are internal — see private enterprise docs
  }
}
Signature: Ed25519(private_key, header + "." + payload)
```

**Bezpieczeństwo:**
- Klucz prywatny Ed25519 **nigdy nie opuszcza serwera licencji**
- Klucz publiczny Ed25519 jest **wbudowany w binarke Go** (hardcoded)
- Aplikacja weryfikuje podpis offline — nie wymaga łączności z serwerem licencji do działania
- Ed25519 jest odporny na ataki timing, nie ma znanych podatności praktycznych
- Modyfikacja payload unieważnia podpis → klucz jest tamper-proof

**Wersjonowanie i rotacja kluczy:**
- Pole `"ver": 1` w payload — kontrakt API. Zmiana formatu = nowa wersja, verifier Go obsługuje obie.
- Pole `"kid"` w JWT header — identyfikuje klucz publiczny do weryfikacji (np. `"key-2026-02"`).
- Go embedduje **tablicę kluczy publicznych** (stare + nowe), co umożliwia rotację bez reissue istniejących licencji.
- Opcjonalnie: pole `"instance_id"` w payload — fingerprint instancji (hash hostname + MAC), weryfikowany przy aktywacji. Zapobiega kopiowaniu licencji na inne serwery.

### 1.4. Dwa modele wyceny

#### Pricing Models

Two pricing models are supported (per-observation and package).
Pricing details, rates, and billing logic are documented in the private enterprise repository.

The license JWT contains **technical limits only** (quotas), not financial terms.
Pricing is stored separately in a `pricing_agreements` table.

### 1.5. Walidacja licencji w aplikacji Go

#### Offline validation (primary)

```go
// internal/license/verifier.go

// Wbudowany klucz publiczny Ed25519
var publicKey ed25519.PublicKey = []byte{...} // hardcoded w kompilacji

type License struct {
    Tier        string            `json:"tier"`
    Modules     []string          `json:"modules"`
    Limits      LicenseLimits     `json:"limits"`
    ExpiresAt   time.Time         `json:"exp"`
    Org         string            `json:"org"`
    Contact     string            `json:"contact"`
}

func Verify(token string) (*License, error) {
    // 1. Parse JWT
    // 2. Verify Ed25519 signature using embedded public key
    // 3. Check expiry
    // 4. Return parsed license
}
```

#### Online refresh (secondary, optional)

Aplikacja **opcjonalnie** kontaktuje `license.silentpulse.io` co 24h:
- Pobiera najnowszy klucz (np. po upgrade planu)
- Weryfikuje odwołanie (revocation check)
- Raportuje statystyki zużycia (opt-in)

Jeśli serwer licencji jest nieosiągalny → aplikacja kontynuuje pracę z ostatnim zapisanym kluczem. **Nigdy nie blokuje przez brak łączności.**

### 1.6. Enforcement middleware (Go backend)

```go
// internal/middleware/license.go

func LicenseEnforcement(verifier *license.Verifier) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            lic := verifier.Current()
            if lic == nil {
                // Brak licencji → Community mode
                enforceCommunityLimits(w, r, next)
                return
            }
            if lic.Expired() {
                // Wygasła → fallback do Community
                enforceExpiredBehavior(w, r, next)
                return
            }
            // Aktywna licencja → sprawdź moduły i quoty
            ctx := license.WithContext(r.Context(), lic)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

**Sprawdzenia per request:**

| Endpoint pattern | Sprawdzenie |
|-----------------|-------------|
| `/api/v1/mitre/*` | `lic.HasModule("mitre")` |
| `/api/v1/behavioral/*` | `lic.HasModule("behavioral")` |
| `/api/v1/ai-assistant/*` | `lic.HasModule("ai-assistant")` |
| `POST /api/v1/assets` | `lic.Limits.Assets != -1 && currentCount >= lic.Limits.Assets` |
| `POST /api/v1/flows` | `lic.Limits.Flows != -1 && currentCount >= lic.Limits.Flows` |
| Worker collect | `lic.Limits.ObservationsPerDay != -1 && dailyCount >= lic.Limits.ObservationsPerDay` |

### 1.7. Graceful degradation

#### Ostrzeżenia przed wygaśnięciem

| Dni do wygaśnięcia | Zachowanie |
|---------------------|------------|
| > 90 | Normalnie |
| 90 | Dyskretny banner w Settings: "License expires in 90 days" |
| 30 | Żółty banner na dashboardzie |
| 7 | Czerwony banner na każdej stronie |
| 0 | Licencja wygasła — degradacja |

#### Po wygaśnięciu

1. **Moduły licencjonowane** (behavioral, ai-assistant) → **wyłączone** (404 na endpointach)
2. **Quoty** → spadają do limitów Community (500 assetów, 5 flow, 10 IP)
3. **Dane historyczne** → **zachowane** (read-only), brak nowych kolekcji ponad limit
4. **UI** → widoczny banner: "License expired — contact {contact_email} to renew"
5. **Grace period** → 14 dni po wygaśnięciu, zanim hard limity się włączą (soft warnings only)

### 1.8. API

#### license.silentpulse.io — publiczne API (dostępne dla instancji klientów)

```
POST   /api/v1/license/validate     — weryfikuje klucz, zwraca aktualny status
POST   /api/v1/license/refresh      — pobiera najnowszy klucz (po upgrade)
POST   /api/v1/license/report       — raportuje zużycie (opt-in)
GET    /api/v1/version               — wersja serwera licencji
```

#### admin.silentpulse.io — panel administracyjny (zabezpieczony Cloudflare Access + auth)

```
# HTML pages (SSR + htmx)
GET    /admin/                        — dashboard
GET    /admin/customers               — lista klientów
GET    /admin/customers/:id           — szczegóły klienta
GET    /admin/licenses/issue          — formularz wydawania licencji
GET    /admin/billing                 — raport przychodów
GET    /admin/usage                   — dashboard zużycia

# Admin API (JSON, używane przez htmx)
GET    /api/v1/customers              — lista klientów
POST   /api/v1/customers              — tworzenie klienta
GET    /api/v1/customers/:id          — szczegóły + historia kluczy
PUT    /api/v1/customers/:id          — edycja klienta
POST   /api/v1/licenses/issue         — wydanie nowego klucza (podpisanie JWT)
POST   /api/v1/licenses/revoke        — odwołanie klucza
GET    /api/v1/usage                  — dane zużycia per klient
GET    /api/v1/billing                — dane billingowe
GET    /api/v1/billing/export.csv     — eksport CSV
```

### 1.9. Database (SQLite)

```sql
CREATE TABLE customers (
    id         TEXT PRIMARY KEY,  -- UUID
    name       TEXT NOT NULL,
    contact    TEXT NOT NULL,     -- email
    notes      TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE licenses (
    id           TEXT PRIMARY KEY,  -- UUID = JWT jti
    customer_id  TEXT NOT NULL REFERENCES customers(id),
    tier         TEXT NOT NULL,     -- community/professional/enterprise
    modules      TEXT NOT NULL,     -- JSON array
    limits       TEXT NOT NULL,     -- JSON object
    pricing      TEXT,              -- JSON object (negotiated terms)
    issued_at    DATETIME NOT NULL,
    expires_at   DATETIME NOT NULL,
    revoked_at   DATETIME,          -- NULL = active
    revoke_reason TEXT,
    jwt_token    TEXT NOT NULL       -- pełny podpisany JWT
);

CREATE TABLE usage_reports (
    id           TEXT PRIMARY KEY,
    license_id   TEXT NOT NULL REFERENCES licenses(id),
    reported_at  DATETIME NOT NULL,
    period_start DATETIME NOT NULL,
    period_end   DATETIME NOT NULL,
    observations INTEGER NOT NULL,
    assets       INTEGER NOT NULL,
    flows        INTEGER NOT NULL
);

CREATE TABLE pricing_agreements (
    id           TEXT PRIMARY KEY,
    customer_id  TEXT NOT NULL REFERENCES customers(id),
    model        TEXT NOT NULL,      -- per_observation | package
    rate         REAL,               -- per observation (if per_observation)
    package_fee  REAL,               -- monthly fee (if package)
    valid_from   DATETIME NOT NULL,
    valid_to     DATETIME,
    notes        TEXT
);
```

### 1.10. UI w aplikacji SilentPulse

**Settings → License:**

```
┌─────────────────────────────────────────────────┐
│ License                                          │
├──────────────────────────────────────────────────┤
│                                                  │
│ Status: ● Active                                 │
│ Tier:   Professional                             │
│ Org:    ACME Corp                                │
│ Valid:  2025-01-15 → 2026-01-15 (340 days left)  │
│                                                  │
│ Modules:                                         │
│   ✓ core  ✓ mitre  ✓ behavioral  ✗ ai-assistant  │
│                                                  │
│ Limits:                                          │
│   Assets: 5,000 / unlimited                      │
│   Flows: 12 / unlimited                          │
│   Observations/day: 45,231 / 100,000             │
│                                                  │
│ ┌───────────────────────────────────────┐        │
│ │ License Key                           │        │
│ │ [eyJhbGciOiJFZERTQSI...         ]    │        │
│ │               [Activate]              │        │
│ └───────────────────────────────────────┘        │
│                                                  │
│ Contact: admin@acme.com                          │
│ Last refresh: 2025-12-08 14:30 UTC               │
│ [Refresh Now]                                    │
└──────────────────────────────────────────────────┘
```

### 1.11. Admin Panel (`admin.silentpulse.io`)

Osobna subdomena z panelem administracyjnym. Dostępny **wyłącznie dla właściciela**.

**Technologia:** Node.js + Fastify SSR + htmx + Tailwind CSS (CDN)

Uzasadnienie:
- Panel dla **1 użytkownika** — SPA (React) to overkill
- Brak build stepu frontendu — HTML renderowany server-side
- htmx zapewnia interaktywność (sortowanie, filtrowanie, modals) bez pisania JS
- Tailwind CSS z CDN — profesjonalny wygląd, zero konfiguracji
- Osobna subdomena = osobne reguły Cloudflare Access

#### Autentykacja

```
POST /admin/login
  → weryfikacja: ADMIN_API_KEY (z env)
  → signed cookie session (@fastify/cookie + @fastify/session)
  → timeout: 24h

Cloudflare Access (Zero Trust) na admin.silentpulse.io
  → darmowy plan (50 users), konfigurowalne w Cloudflare Dashboard
  → blokuje dostęp zanim request trafi do Node.js
```

#### Wspólna baza z License Server

Admin panel i License Server współdzielą tę samą bazę danych
(ten sam plik SQLite lub ta sama instancja MySQL/PG). Dwa osobne procesy Node.js
czytają/piszą do tej samej bazy.

#### Widoki

**1. Dashboard (`/admin/`)**

```
┌─────────────────────────────────────────────────────────────┐
│  SilentPulse License Server                    [Logout]     │
├──────────┬──────────────────────────────────────────────────┤
│          │                                                   │
│ Dashboard│  ┌──────┐ ┌──────┐ ┌──────────┐ ┌────────────┐  │
│ Customers│  │  12  │ │  10  │ │    3     │ │  monthly   │  │
│ Licenses │  │active│ │active│ │expiring  │ │  revenue   │  │
│ Billing  │  │custs.│ │lic.  │ │< 30 days │ │  summary   │  │
│ Usage    │  └──────┘ └──────┘ └──────────┘ └────────────┘  │
│          │                                                   │
│          │  [Chart: New licenses / month — last 12 months]   │
│          │  [Chart: Total observations/day — trend 90 days]  │
│          │                                                   │
└──────────┴──────────────────────────────────────────────────┘
```

**2. Lista klientów (`/admin/customers`)**

```
┌──────────────────────────────────────────────────────────────┐
│ Customers                              [+ New Customer]      │
├──────────────────────────────────────────────────────────────┤
│ Filter: [All tiers ▾] [All statuses ▾]     🔍 Search...     │
│                                                              │
│ Name         │ Contact          │ Tier   │ Valid until│ Obs/d│
│──────────────┼──────────────────┼────────┼───────────┼──────│
│ ACME Corp    │ admin@acme.com   │ Pro    │ 2027-01   │ 45K  │
│ GlobalSec    │ sec@global.io    │ Ent    │ 2026-06   │ 120K │
│ StartupX     │ cto@startupx.co  │ Com    │ —         │ 2K   │
└──────────────────────────────────────────────────────────────┘
```

**3. Szczegóły klienta (`/admin/customers/:id`)**

```
┌──────────────────────────────────────────────────────────────┐
│ ← Customers    ACME Corp                    [Edit] [Delete]  │
├──────────────────────────────────────────────────────────────┤
│ Contact: admin@acme.com                                      │
│ Notes: Enterprise client, 3-year contract                    │
│                                                              │
│ ── Active License ──────────────────────────────────────     │
│ Tier: Professional  │  Modules: core, mitre, behavioral     │
│ Valid: 2026-01-15 → 2027-01-15 (340 days)                    │
│ Assets: unlimited  │  Obs/day: 100,000                       │
│ [Revoke] [Issue New License]                                 │
│                                                              │
│ ── Pricing Agreement ───────────────────────────────────     │
│ Model: Package  │  Monthly fee: [configured]                 │
│ Package: 5,000 assets  │  Valid: 2026-01 → 2027-01           │
│ [Edit Agreement]                                             │
│                                                              │
│ ── Usage (last 30 days) ────────────────────────────────     │
│ [Chart: observations/day]                                    │
│ [Chart: active assets]                                       │
│ Avg obs/day: 45,231  │  Peak: 67,892  │  Assets: 3,412      │
│                                                              │
│ ── License History ─────────────────────────────────────     │
│ Issued     │ Expired    │ Tier │ Status                      │
│ 2026-01-15 │ 2027-01-15 │ Pro  │ ● Active                   │
│ 2025-01-15 │ 2026-01-15 │ Com  │ ○ Expired                  │
└──────────────────────────────────────────────────────────────┘
```

**4. Wydawanie licencji (`/admin/licenses/issue`)**

```
┌──────────────────────────────────────────────────────────────┐
│ Issue New License                                            │
├──────────────────────────────────────────────────────────────┤
│ Customer:  [ACME Corp              ▾]                        │
│ Tier:      [○ Community  ● Professional  ○ Enterprise]       │
│ Modules:   [✓ core] [✓ mitre] [✓ behavioral] [□ ai-assist]  │
│                                                              │
│ Limits:                                                      │
│   Assets:          [-1         ] (-1 = unlimited)            │
│   Flows:           [-1         ]                             │
│   Integration Pts: [-1         ]                             │
│   Users:           [50         ]                             │
│   Obs/day:         [100000     ]                             │
│   Retention (days):[90         ]                             │
│                                                              │
│ Expires:   [2027-01-15    📅]                                │
│                                                              │
│                    [Generate License Key]                     │
│                                                              │
│ ┌────────────────────────────────────────────────────────┐   │
│ │ eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCIsImtpZCI6Imtle...  │   │
│ │                                              [📋 Copy] │   │
│ └────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**5. Billing (`/admin/billing`)**

```
┌──────────────────────────────────────────────────────────────┐
│ Billing                                    [Export CSV]       │
├──────────────────────────────────────────────────────────────┤
│ Expected Monthly Revenue: [calculated]                       │
│                                                              │
│ Customer    │ Model      │ This Month │ Est. Cost │ Status   │
│─────────────┼────────────┼────────────┼───────────┼──────────│
│ ACME Corp   │ Package    │ 45K obs    │ [rate]    │ ● OK     │
│ GlobalSec   │ Per-obs    │ 120K obs   │ [rate]    │ ● OK     │
│ MegaCorp    │ Package    │ 95K obs    │ [rate]    │ ⚠ 95%   │
│─────────────┴────────────┴────────────┴───────────┴──────────│
│ Totals:                    260K obs     [total]              │
└──────────────────────────────────────────────────────────────┘
```

**6. Usage (`/admin/usage`)**

```
┌──────────────────────────────────────────────────────────────┐
│ Usage Overview                           [30d] [90d] [1y]    │
├──────────────────────────────────────────────────────────────┤
│ [Line chart: total observations/day — all customers]         │
│                                                              │
│ Top Customers by Usage:                                      │
│  1. GlobalSec — 120K obs/day (48%)                           │
│  2. ACME Corp — 45K obs/day (18%)                            │
│  3. MegaCorp — 38K obs/day (15%)                             │
│                                                              │
│ ⚠ Quota Alerts:                                              │
│  MegaCorp — 95% of daily quota (95K / 100K)                  │
└──────────────────────────────────────────────────────────────┘
```

### 1.12. Klucz publiczny w Go

Klucz publiczny Ed25519 jest wbudowany w kompilację:

```go
// internal/license/keys.go
package license

import "crypto/ed25519"

//go:embed license_pub.pem
var publicKeyPEM []byte

var PublicKey ed25519.PublicKey  // initialized in init()
```

Plik `license_pub.pem` jest commitowany do repo. Klucz prywatny **nigdy** nie jest w repo — istnieje tylko na `license.silentpulse.io`.

---

## 2. Connector Hub (`hub.silentpulse.io`)

### 2.1. Cel

Zewnętrzny hub dystrybucji definicji connectorów:
- Nowe connectory bez aktualizacji aplikacji
- Wersjonowanie definicji connectorów
- Community connectors (w przyszłości)
- Rozdzielenie katalogu connectorów od kodu aplikacji

### 2.2. Stan obecny

Connectors są hardcoded w Go:
- `connector.go` — `connectorCatalog []ConnectorInfo` (5 typów: kafka, splunk, elasticsearch, syslog, api)
- `plugins/registry.go` — `DefaultRegistry()` z `KafkaPlugin`, `SplunkPlugin`, `ElasticsearchPlugin`, `SyslogPlugin`
- Każdy plugin implementuje `Plugin.Collect()` i opcjonalnie `StreamingPlugin.Stream()`

**Problem:** Dodanie nowego connectora wymaga:
1. Nowy plik Go w `plugins/`
2. Rejestracja w `DefaultRegistry()`
3. Nowy wpis w `connectorCatalog`
4. Rebuild + redeploy

### 2.3. Podział: Definicja vs Implementacja

Kluczowe rozróżnienie:

| Warstwa | Opis | Gdzie żyje |
|---------|------|------------|
| **Definicja** (ConnectorInfo) | Metadane: nazwa, ikona, pola konfiguracji, wspierane tryby | Hub → pobierane dynamicznie |
| **Implementacja** (Plugin) | Kod Go: jak się połączyć, jak zebrać dane | W repo SilentPulse (builtin) lub jako Go plugin (.so) |

Hub obsługuje **definicje**. Implementacje muszą istnieć jako kod.

### 2.4. Connector Manifest Format

Każdy connector na hubie to **manifest JSON**:

```json
{
  "version": "1.0.0",
  "type": "databricks",
  "name": "Databricks",
  "description": "Query Databricks SQL Warehouse for asset telemetry",
  "category": "Data Platform",
  "icon": "database",
  "supported_modes": ["batch"],
  "min_app_version": "1.2.0",
  "fields": [
    {
      "key": "host",
      "label": "Workspace URL",
      "type": "url",
      "required": true,
      "group": "connection",
      "placeholder": "https://dbc-xxx.cloud.databricks.com",
      "description": "Databricks workspace URL"
    },
    {
      "key": "token",
      "label": "Access Token",
      "type": "password",
      "required": true,
      "group": "connection"
    },
    {
      "key": "warehouse_id",
      "label": "SQL Warehouse ID",
      "type": "text",
      "required": true,
      "group": "connection"
    },
    {
      "key": "query",
      "label": "SQL Query",
      "type": "textarea",
      "required": true,
      "group": "query",
      "placeholder": "SELECT DISTINCT hostname FROM events WHERE ts > :time_window",
      "description": "SQL query returning hostnames"
    },
    {
      "key": "hostname_field",
      "label": "Hostname Field",
      "type": "text",
      "required": true,
      "group": "query",
      "default": "hostname"
    }
  ],
  "implementation": {
    "builtin": false,
    "plugin_type": "generic_sql",
    "driver": "databricks"
  }
}
```

### 2.5. Architektura Hub

```
                    ┌──────────────────────────────────┐
                    │  hub.silentpulse.io               │
                    │  (Node.js + Fastify)              │
                    │                                   │
                    │  /api/v1/connectors               │
                    │  /api/v1/connectors/:type          │
                    │  /api/v1/connectors/sync           │
                    │                                   │
                    │  ┌─────────────────────────────┐  │
                    │  │ SQLite DB                    │  │
                    │  │  - connectors (manifests)    │  │
                    │  │  - versions (changelog)      │  │
                    │  │  - downloads (stats)         │  │
                    │  └─────────────────────────────┘  │
                    └──────────────┬───────────────────┘
                                   │
                    HTTPS GET /api/v1/connectors/sync
                    ?since=2025-12-01T00:00:00Z
                                   │
                    ┌──────────────▼───────────────────┐
                    │  SilentPulse App (Go backend)     │
                    │                                   │
                    │  ConnectorSyncer (goroutine)      │
                    │   - pulls every 6h                │
                    │   - merges with builtin catalog   │
                    │   - stores in DB (connector_defs) │
                    │                                   │
                    │  GET /api/v1/connectors            │
                    │   - returns merged catalog         │
                    │     (builtin + hub)                │
                    └───────────────────────────────────┘
```

### 2.6. Sync Protocol

Aplikacja synchronizuje definicje connectorów z hubem:

```
GET https://hub.silentpulse.io/api/v1/connectors/sync?since=2025-12-01T00:00:00Z
Accept: application/json
X-License-ID: license-uuid       # opcjonalnie, dla trackingu
X-App-Version: 1.2.0             # filtrowanie po min_app_version
```

Response:

```json
{
  "connectors": [
    { "type": "databricks", "version": "1.0.0", "manifest": {...} },
    { "type": "s3", "version": "1.1.0", "manifest": {...} }
  ],
  "deleted": ["old_connector_type"],
  "server_time": "2025-12-08T15:00:00Z"
}
```

**Logika sync w Go:**

```go
// internal/connector/syncer.go

type ConnectorSyncer struct {
    hubURL     string
    store      ConnectorStore      // PostgreSQL table: connector_defs
    builtin    []ConnectorInfo     // hardcoded catalog (fallback)
    interval   time.Duration       // 6h
    lastSync   time.Time
}

func (s *ConnectorSyncer) Run(ctx context.Context) {
    ticker := time.NewTicker(s.interval)
    defer ticker.Stop()
    s.sync(ctx) // initial sync
    for {
        select {
        case <-ticker.C:
            s.sync(ctx)
        case <-ctx.Done():
            return
        }
    }
}
```

### 2.7. Merged Catalog

Endpoint `/api/v1/connectors` zwraca scalony katalog:

1. **Builtin connectors** (kafka, splunk, elasticsearch, syslog, api) — zawsze dostępne
2. **Hub connectors** — pobrane z huba, nadpisują builtin jeśli nowsza wersja
3. **Custom connectors** — dodane lokalnie przez admina (przyszłość)

Priorytet: custom > hub > builtin

### 2.8. Generic Plugin Pattern

Nowe connectory z huba nie mają dedykowanego kodu Go. Zamiast tego używają **generic plugins**:

```go
// internal/worker/plugins/generic_http.go
type GenericHTTPPlugin struct{}

func (p *GenericHTTPPlugin) Type() string { return "generic_http" }

func (p *GenericHTTPPlugin) Collect(ctx context.Context,
    connCfg json.RawMessage, queryCfg json.RawMessage) ([]worker.CollectedAsset, int, error) {
    // Generic HTTP client:
    // 1. Read URL, method, headers, body from connCfg
    // 2. Execute HTTP request
    // 3. Extract hostnames using JSONPath from queryCfg
    // 4. Return collected assets
}

// internal/worker/plugins/generic_sql.go
type GenericSQLPlugin struct{}
// Similar: connects via database/sql, executes query, extracts hostnames
```

Manifest definiuje `implementation.plugin_type`:
- `"generic_http"` → `GenericHTTPPlugin` (REST APIs, webhooks)
- `"generic_sql"` → `GenericSQLPlugin` (Databricks, Snowflake, BigQuery via SQL drivers)
- `"builtin"` → dedykowany plugin (kafka, splunk, etc.)

To pozwala na dodawanie nowych connectorów **bez nowego kodu Go**, o ile pasują do jednego z generic patterns.

### 2.9. Hub API

```
# Publiczne (dla aplikacji SilentPulse)
GET    /api/v1/connectors              — pełny katalog
GET    /api/v1/connectors/:type         — pojedynczy connector manifest
GET    /api/v1/connectors/sync          — delta sync (z parametrem since)

# Admin panel
POST   /api/v1/admin/connectors         — dodaj/aktualizuj connector
DELETE /api/v1/admin/connectors/:type    — usuń connector
GET    /api/v1/admin/stats               — statystyki pobierań
```

### 2.10. Hub Database (SQLite)

```sql
CREATE TABLE connectors (
    type        TEXT PRIMARY KEY,
    version     TEXT NOT NULL,
    name        TEXT NOT NULL,
    manifest    TEXT NOT NULL,      -- pełny JSON manifest
    published   BOOLEAN DEFAULT TRUE,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE connector_versions (
    id          TEXT PRIMARY KEY,
    type        TEXT NOT NULL,
    version     TEXT NOT NULL,
    manifest    TEXT NOT NULL,
    released_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    changelog   TEXT
);

CREATE TABLE download_stats (
    id           TEXT PRIMARY KEY,
    connector    TEXT NOT NULL,
    license_id   TEXT,
    app_version  TEXT,
    downloaded_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### 2.11. SilentPulse DB — nowa tabela

```sql
-- Migracja: 19-connector-hub.sql
CREATE TABLE IF NOT EXISTS connector_defs (
    type        VARCHAR(64) PRIMARY KEY,
    version     VARCHAR(32) NOT NULL,
    source      VARCHAR(16) NOT NULL DEFAULT 'builtin',  -- builtin | hub | custom
    manifest    JSONB NOT NULL,
    synced_at   TIMESTAMPTZ,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Seed builtin connectors
INSERT INTO connector_defs (type, version, source, manifest) VALUES
  ('kafka', '1.0.0', 'builtin', '...'::jsonb),
  ('splunk', '1.0.0', 'builtin', '...'::jsonb),
  ('elasticsearch', '1.0.0', 'builtin', '...'::jsonb),
  ('syslog', '1.0.0', 'builtin', '...'::jsonb),
  ('api', '1.0.0', 'builtin', '...'::jsonb)
ON CONFLICT (type) DO NOTHING;
```

### 2.12. Zmiany w istniejącym kodzie

| Plik | Zmiana |
|------|--------|
| `handler/connector.go` | `ListConnectors` czyta z DB (`connector_defs`) zamiast hardcoded `connectorCatalog` |
| `plugins/registry.go` | Dodaj `GenericHTTPPlugin`, `GenericSQLPlugin` |
| `plugins/registry.go` | `Get()` sprawdza czy typ jest builtin, jeśli nie → generic plugin wg manifestu |
| Frontend `connector-icons.ts` | Dynamiczna mapa ikon (fallback na `Box` icon jeśli nieznany) |
| Frontend palette | Renderuje connectors z API (już tak działa po Flow Simplification) |

---

## 3. Infrastructure

Deployment details for the license server, admin panel, and connector hub
are documented in the private enterprise repository.

---

## 4. Milestones i kolejność prac

### Rekomendowana kolejność

```
Faza 1:  #13 License Server MVP (license + admin + wersjonowanie)
              │
Faza 2:  #14 License Enforcement in Go
              │
Faza 3:  #15 License UI  ──────  #17 Connector Hub MVP  (równolegle)
              │                        │
Faza 4:       │                   #18 Hub Integration in Go
              │                        │
Faza 5:  #16 Quotas & Usage      (po #14+#15, może równolegle z #18)
                                       │
Faza 6:                           #19 Connector Marketplace
```

**Dwie niezależne ścieżki** (licencja i hub) mogą iść równolegle.

**Zależności twarde (blokujące):**
- #14 ← #13 (klucz publiczny Ed25519 + działające API)
- #15 ← #14 (API endpoint zwracający status licencji)
- #16 ← #14 (enforcement middleware)
- #18 ← #17 (działające API huba)
- #19 ← #17 + #18

**Zależności miękkie:**
- #16 korzysta z admin panelu #13 do wyświetlania raportów zużycia
- #18 opcjonalnie wysyła `X-License-ID` do huba (z #14)

### Milestone 1: License Server MVP (#13)
- **`license.silentpulse.io`** — Node.js + Fastify, publiczne API (validate/refresh/report)
- **`admin.silentpulse.io`** — Node.js + Fastify SSR + htmx + Tailwind CSS, panel admina:
  - Auth (API key + cookie session + Cloudflare Access)
  - Dashboard: aktywni klienci, licencje, spodziewany przychód
  - Customer management: lista, szczegóły, wydawanie licencji
  - Billing: model per-obs/package, szacunkowe kwoty, eksport CSV
  - Usage: wykresy zużycia, alerty przekroczeń quot
- Ed25519 key pair generation + JWT signing
- SQLite DB (lub MySQL/PG) — wspólna dla obu serwisów
- **Wersjonowanie aplikacji** — `internal/version` w Go, endpoint `/api/v1/version`
- Deploy to hosting

### Milestone 2: License Enforcement w Go (#14)
- `internal/license/` — verifier z wbudowanym kluczem publicznym (tablica kluczy, `kid` w JWT header)
- Middleware enforcement na routerze
- Graceful degradation (Community fallback)
- Przechowywanie klucza w DB (`settings` lub osobna tabela `license_keys`)

### Milestone 3: License UI w aplikacji (#15)
- Settings → License page (aktywacja, status, refresh)
- Expiry warning banners (90/30/7/0 dni)
- Module availability indicators w sidebar
- Usage stats (observations/day, assets count)

### Milestone 4: Quotas & Usage Reporting (#16)
- Daily usage counter w Go (observations, assets)
- Opt-in reporting do License Server
- Admin dashboard zużycia na admin.silentpulse.io (rozszerzenie Admin UI z #13)
- Per-observation i package model enforcement

### Milestone 5: Connector Hub MVP (#17)
- Serwer Node.js + Fastify z SQLite (lub MySQL/PG)
- Admin API: CRUD connectors
- Public API: list, sync (delta)
- Deploy to hosting (hub.silentpulse.io)
- Seed z istniejących 5 builtin connectors

### Milestone 6: Hub Integration w Go (#18)
- `internal/connector/syncer.go` — goroutine sync co 6h
- Tabela `connector_defs` w PostgreSQL
- `ListConnectors` handler czyta z DB
- Generic HTTP/SQL plugins
- Frontend bez zmian (już dynamiczny po Flow Simplification)

### Milestone 7: Connector Marketplace (#19) — przyszłość
- Community submissions
- Weryfikacja i review process
- Wersjonowanie i changelog
- Frontend: connector browser z filtrowaniem

---

## 5. Wersjonowanie aplikacji

Aplikacja SilentPulse nie ma jeszcze mechanizmu wersjonowania. Wprowadzamy go równolegle z licencjami,
ponieważ JWT klucza licencyjnego zawiera `min_app_version` dla connectorów z huba,
a serwer licencji potrzebuje znać wersję aplikacji klienta.

### 5.1. Wersja w Go backend

```go
// internal/version/version.go
package version

// Set via ldflags at build time:
//   go build -ldflags "-X github.com/silentpulse/silentpulse/internal/version.Version=1.0.0
//                       -X github.com/silentpulse/silentpulse/internal/version.GitCommit=$(git rev-parse --short HEAD)
//                       -X github.com/silentpulse/silentpulse/internal/version.BuildDate=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

var (
    Version   = "dev"
    GitCommit = "unknown"
    BuildDate = "unknown"
)
```

Endpoint:

```
GET /api/v1/version
→ { "version": "1.0.0", "commit": "c69bfc0", "build_date": "2026-02-09T12:00:00Z" }
```

### 5.2. Wersja w frontend (Next.js)

```ts
// next.config.ts — inject at build time
env: {
  NEXT_PUBLIC_APP_VERSION: process.env.APP_VERSION || require('./package.json').version,
  NEXT_PUBLIC_GIT_COMMIT: process.env.GIT_COMMIT || 'dev',
}
```

Wyświetlanie w UI:
- **Sidebar footer:** `v1.0.0` (mały tekst, kliknięcie → tooltip z commit hash)
- **Settings → About:** pełne info (wersja, commit, data buildu, tier licencji)

### 5.3. Wersja w admin panelu (`admin.silentpulse.io`)

Footer admin panelu wyświetla:
- Wersję serwera licencji (np. `License Server v1.0.0`)
- Ilość aktywnych klientów i licencji (quick stats)

### 5.4. Wersja w Connector Hub sync

Header `X-App-Version` wysyłany do huba przy sync:

```
GET https://hub.silentpulse.io/api/v1/connectors/sync
X-App-Version: 1.0.0
```

Hub filtruje connectors po `min_app_version` — stara wersja nie dostanie manifestów wymagających nowszych features.

### 5.5. Konwencja wersjonowania

**Semantic Versioning (SemVer):** `MAJOR.MINOR.PATCH`

- `MAJOR` — breaking changes (zmiana formatu API, migracja wymagająca ręcznej interwencji)
- `MINOR` — nowe features (nowy moduł, nowy connector, nowe endpointy)
- `PATCH` — bug fixes, security patches

Wersja źródłowa: **tag Git** (np. `v1.0.0`). CI/CD builduje z tagiem → ldflags wstrzykuje wersję.

### 5.6. Dockerfile

```dockerfile
ARG APP_VERSION=dev
ARG GIT_COMMIT=unknown
RUN go build -ldflags "-X .../version.Version=${APP_VERSION} -X .../version.GitCommit=${GIT_COMMIT}" ...
```

---

## 6. Security Considerations

### License
- Ed25519 private key — **only on license server**, nigdy w repo
- Public key — embedded w Go binary, tamper-proof
- JWT expiry — nie da się przedłużyć bez nowego podpisu
- Revocation — online check (optional), local cache
- No phone-home requirement — offline verification always works

### Connector Hub
- Hub connector manifests are **data only** (JSON) — no executable code
- Generic plugins execute predefined patterns, not arbitrary code
- Connector configs (credentials) are stored encrypted in SilentPulse DB, not sent to hub
- Hub sync uses HTTPS, optional API key for authentication

### Rate Limiting
- `license.silentpulse.io`: 10 req/min per IP (publiczny)
- `hub.silentpulse.io`: 60 req/min per IP (publiczny)
- `admin.silentpulse.io`: Cloudflare Access (whitelist) + API key auth (nie wymaga rate limit per IP)
