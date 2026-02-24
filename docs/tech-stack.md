# Tech Stack

Decyzje technologiczne dla SilentPulse.

## Backend: Go

Język ekosystemu cloud-native — Docker, Kubernetes, Prometheus napisane w Go.

Uzasadnienie:
- Małe statyczne binarne — lekkie kontenery (kilka MB)
- Goroutines — natywna współbieżność dla workerów i schedulerów
- Memory-safe, strong typing — bezpieczeństwo na poziomie języka
- Szybki cold start — istotne przy dynamicznym startowaniu kontenerów per flow
- Naturalny wybór do budowania Kubernetes operatorów

Wyjątek: AI Assistant jako osobny mikroserwis w Pythonie (integracja z LLM).

## Baza danych: PostgreSQL + Apache AGE

Jedna baza, dwa modele zapytań — relacyjny (SQL) i grafowy (Cypher).

### PostgreSQL (SQL) — dane konfiguracyjne i CRUD

Uzasadnienie:
- Naturalne relacje między encjami (FK, joiny)
- `JSONB` — elastyczne atrybuty assetów z CMDB (różne CMDB mają różne pola)
- Row-Level Security (RLS) — gotowe pod multi-tenancy na poziomie bazy
- `pgcrypto` — szyfrowanie credentials do Integration Points at rest
- Audit przez triggery — śledzenie zmian konfiguracji
- Dojrzały, stabilny, dobrze udokumentowany, darmowy

### Apache AGE (Cypher) — graf zależności i impact analysis

Rozszerzenie PostgreSQL dodające graf (Cypher) do tej samej bazy.
Brak synchronizacji między bazami, brak dodatkowej infrastruktury.

Zastosowania grafowe:
- Zależności między assetami (ESXi → VM → Database → App)
- Cross-flow impact analysis ("Kafka X padła — co jest dotknięte?")
- Kaskadowy impakt MITRE ("cisza na ESXi → wpływ na wszystkie zależne assety i ich techniki")
- Wizualizacja topologii infrastruktury na dashboardach

Przykład zapytania:
```cypher
-- Znajdź wszystkie assety zależne od esxi-01 i ich techniki MITRE
MATCH (esxi:Asset {hostname: "esxi-01"})-[:HOSTS|RUNS*]->(dependent)
MATCH (dependent)-[:BELONGS_TO]->(g:AssetGroup)-[:COVERS]->(t:MitreTechnique)
RETURN dependent, t
```

### Odrzucone alternatywy

- MongoDB — schema-less jest wadą, dane są relacyjne
- CockroachDB — distributed PostgreSQL, overkill na start
- MySQL — mniej features (brak RLS, słabszy JSONB)
- Neo4j (osobna baza grafowa) — dodatkowa infrastruktura i synchronizacja danych

## Cache: Redis

Przechowuje informacje o assetach zaobserwowanych przez workery.
Dane tymczasowe, odczytywane przez schedulery do porównania z CMDB.

## Kontenery i orkiestracja

Interfejs `ContainerOrchestrator` abstrahuje różnice między środowiskami.
Wybór implementacji: `ORCHESTRATOR_TYPE=docker|k8s`.

### Dev: Docker Compose + Docker API (`DockerOrchestrator`)

Flow Controller zarządza kontenerami workerów przez Docker API.
Workery batch i realtime działają jako długożyciowe kontenery z wewnętrznym tickerem.

### Prod: Kubernetes (`K8sOrchestrator`)

Operator pattern — kontroler Go obserwuje CRD `SilentPulseFlow`
i tworzy odpowiednie zasoby K8s w zależności od typu workera:

| Typ workera | Zasób K8s | Zachowanie |
|-------------|-----------|------------|
| Batch (Splunk, ES, Kafka poll) | **CronJob** | `--single-run`: start → collect → exit. Schedule z CRD |
| Realtime (Kafka stream, Syslog) | **Deployment** | Ciągły proces, liveness/readiness probes, HPA |
| Evaluator/Scheduler | **CronJob** | Periodyczne porównanie CMDB vs Redis, generacja alertów |

Zalety modelu K8s:
- Brak Docker socket mount (eliminacja ryzyka bezpieczeństwa)
- Batch: zero idle memory, scheduling delegowany do K8s
- Realtime: HPA, rolling updates, auto-restart
- Observability: pod events/status natychmiast (vs heartbeat TTL)
- Multi-tenancy: namespace-per-tenant, NetworkPolicies, ResourceQuotas

CRD: `SilentPulseFlow`
- spec: definicja pipeline + pulses (tryb, interwał, konfiguracja)
- status: phase (Running/Stopped/Error), per-pulse status

## Dynamiczne kontenery per flow

Kluczowy wzorzec architektoniczny — zdefiniowanie flow powoduje
uruchomienie dedykowanych kontenerów/zasobów K8s:

```
Użytkownik definiuje flow
        │
        ▼
ContainerOrchestrator
        │
        ├─ Docker (dev):
        │   ├─► Spawns: Worker container (pulse 1)
        │   ├─► Spawns: Worker container (pulse 2)
        │   └─► Spawns: Scheduler container per pulse
        │
        └─ K8s (prod):
            ├─► Creates: CronJob (batch pulse)
            ├─► Creates: Deployment (realtime pulse)
            └─► Creates: CronJob (evaluator per pulse)
```

Orkiestrator odpowiada za lifecycle — tworzenie, monitoring, restart, usuwanie.

## Frontend

React + Next.js (App Router), TypeScript, Tailwind CSS, shadcn/ui (Radix UI).

Wizualizacje:
- Cytoscape.js — grafy topologii (flow, zależności assetów, impakt MITRE)
- Apache ECharts — wykresy dashboardowe (trendy, pokrycie, timeline)
- WebSocket — real-time updates (alerty, status workerów)
- Zustand — state management

Dark theme domyślnie. Desktop-first, responsywny do tabletu.

Szczegóły: [frontend.md](frontend.md)

## Podsumowanie

| Komponent          | Technologia                    |
|--------------------|--------------------------------|
| Backend (core)     | Go                             |
| AI Assistant       | Python (osobny mikroserwis)    |
| Baza danych        | PostgreSQL + Apache AGE        |
| Cache              | Redis                          |
| Kontenery (dev)    | Docker Compose + Docker API    |
| Kontenery (prod)   | Kubernetes + Operator          |
| Frontend           | React + Next.js + TypeScript   |
| UI Components      | shadcn/ui + Tailwind CSS       |
| Grafy              | Cytoscape.js                   |
| Wykresy            | Apache ECharts                 |
| Real-time          | WebSocket                      |
