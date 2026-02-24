# KPI Compliance Tracking

Śledzenie zgodności z celami dostępności (KPI) per grupa assetów.

## Cel

Umożliwia definiowanie celów dostępności (np. 99.5% SLA) dla grup assetów
i automatyczne śledzenie, czy cele są spełnione. Generuje naruszenia (breaches)
gdy dostępność spada poniżej progu.

## Kluczowe pytania

- Czy grupa assetów spełnia zdefiniowany cel dostępności?
- Jak zmieniała się dostępność w czasie?
- Kiedy i jak długo trwały naruszenia KPI?
- Jakie działania podjęto w odpowiedzi na naruszenia?

## Model danych

### Rozszerzenie asset_groups

| Pole               | Typ     | Opis                                    |
|--------------------|---------|------------------------------------------|
| kpi_target_percent | numeric | Cel dostępności (np. 99.5)              |
| kpi_period         | text    | Okres pomiaru: daily / weekly / monthly |

### availability_snapshots (PostgreSQL)

Okresowe migawki dostępności grupy.

| Pole                | Typ         | Opis                                    |
|---------------------|-------------|------------------------------------------|
| id                  | UUID        | PK                                       |
| asset_group_id      | UUID (FK)   | Grupa assetów                            |
| period_start        | timestamptz | Początek okresu                          |
| period_end          | timestamptz | Koniec okresu                            |
| total_assets        | int         | Łączna liczba assetów w grupie           |
| available_assets    | int         | Liczba dostępnych assetów                |
| availability_percent| numeric     | Procent dostępności                      |
| kpi_target_percent  | numeric     | Cel KPI w momencie migawki               |
| compliant           | boolean     | Czy spełniony                            |
| tenant_id           | UUID        | Multi-tenancy                            |
| created_at          | timestamptz |                                          |

### compliance_breaches (PostgreSQL)

Naruszenia KPI.

| Pole                | Typ         | Opis                                    |
|---------------------|-------------|------------------------------------------|
| id                  | UUID        | PK                                       |
| asset_group_id      | UUID (FK)   | Grupa assetów                            |
| snapshot_id         | UUID (FK)   | Migawka, która wykryła naruszenie        |
| status              | text        | open / acknowledged / resolved           |
| availability_percent| numeric     | Rzeczywista dostępność                   |
| kpi_target_percent  | numeric     | Cel KPI                                  |
| started_at          | timestamptz | Początek naruszenia                      |
| acknowledged_at     | timestamptz | Kiedy potwierdzone                       |
| acknowledged_by     | UUID        | Kto potwierdził                          |
| resolved_at         | timestamptz | Kiedy rozwiązane                         |
| resolved_by         | UUID        | Kto rozwiązał                            |
| tenant_id           | UUID        | Multi-tenancy                            |
| created_at          | timestamptz |                                          |

## API

| Metoda | Endpoint                                          | Opis                              |
|--------|---------------------------------------------------|-----------------------------------|
| GET    | /api/v1/availability                              | Bieżąca dostępność wszystkich grup|
| GET    | /api/v1/availability-snapshots                    | Migawki (paginated, filterable)   |
| GET    | /api/v1/compliance-breaches                       | Naruszenia (paginated, filterable)|
| POST   | /api/v1/compliance-breaches/{id}/acknowledge      | Potwierdzenie naruszenia          |
| POST   | /api/v1/compliance-breaches/{id}/resolve          | Rozwiązanie naruszenia            |
| GET    | /api/v1/asset-groups/{id}/compliance-report       | Raport compliance per grupa       |
| GET    | /api/v1/asset-groups/{id}/kpi                     | Odczyt KPI grupy                  |
| PUT    | /api/v1/asset-groups/{id}/kpi                     | Ustawienie KPI grupy              |

## Frontend

### Nawigacja

Sidebar: Operations → Compliance

### Strony

- **Przegląd** (`/dashboard/compliance`) — siatka kart per grupa z KPI: nazwa, dostępność %, cel, badge compliant/non-compliant, kolor-kodowanie. Poniżej: tabela otwartych naruszeń.
- **Szczegóły grupy** (`/dashboard/compliance/{id}`) — nagłówek z dostępnością i statusem, wykres trendu (Recharts AreaChart z linią referencyjną KPI), tabela migawek, tabela naruszeń z akcjami Acknowledge/Resolve.

### Integracja z istniejącymi stronami

- **Observability Groups list** (`/dashboard/asset-groups`) — dodatkowa kolumna "Availability" z kolorowym % i celem
- **Observability Group edit** (`/dashboard/asset-groups/{id}/edit`) — pola KPI Target % i KPI Period
- **Dashboard** (`/dashboard`) — metryka "KPI Compliant X/Y" w GlobalSummaryBar

## Scheduler

Okresowy job (zgodny z `kpi_period`) tworzy availability_snapshots.
Jeśli snapshot.availability_percent < kpi_target_percent → tworzony compliance_breach.

## Powiązania

- [asset-groups.md](asset-groups.md) — KPI jest właściwością grupy assetów
- [dashboards.md](dashboards.md) — Metryka compliance na dashboardzie
- [exclusion-windows.md](exclusion-windows.md) — Wyciszone alerty nie wpływają na dostępność
