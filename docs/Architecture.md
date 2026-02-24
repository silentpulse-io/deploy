SilentPulse — modularna, skalowana aplikacja.

**Repozytoria:** Closed-core model — prywatny kod, publiczne artefakty deployment. Szczegóły: [repo-layout.md](repo-layout.md)

## System modułów

SilentPulse używa systemu modułów. Szczegóły: [modules.md](modules.md)

**Core (wymagany):**
- CMDB Sync, Asset Groups, Integration Points, Flows
- Workers, Schedulers, Alerts, Notifications
- Podstawowe dashboardy

**Moduły opcjonalne:**
- `mitre` — mapowanie MITRE ATT&CK i analiza impaktu
- `behavioral` — TimeTravel, Profiling, Anomaly Detection
- `ai-assistant` — asystent AI

**Baza danych:** Schemat zarządzany przez golang-migrate. Szczegóły: [migrations.md](migrations.md)

## Wytyczne technologiczne

- Aplikacja bazuje na kontenerach
- Srodowisko developerskie: Docker Compose, produkcyjne: Kubernetes
- Serwisy komunikuja sie po bezpiecznym API
- Technologia musi byc nowoczesna, bezpieczna, szybka
- Kod powstaje w jezyku angielskim

## Komponenty systemu

```
                              ┌─────────────────────────────────────────────┐
                              │                   CORE                       │
                              │                                              │
Zewnętrzny CMDB ──► CMDB Sync ──► Baza assetów                              │
                                       │                                     │
                                       ▼                                     │
                               Grupy assetów (filtry)                        │
                                       │                                     │
                                       ▼                                     │
                                Flow (per grupa)                             │
                                       │                                     │
                         ┌─────────────┼─────────────┐                       │
                         ▼                           ▼                       │
                   Punkt 1 (np. Kafka)         Punkt 2 (np. Splunk)          │
                   ┌──────────────┐            ┌──────────────┐              │
                   │ Worker       │            │ Worker       │              │
                   │  → realtime  │            │  → batch     │              │
                   │    lub batch │            │  → odpytuje  │              │
                   │  → cache     │            │  → cache     │              │
                   │              │            │              │              │
                   │ Scheduler    │            │ Scheduler    │              │
                   │  → porównuje │            │  → porównuje │              │
                   │  → alerty    │            │  → alerty    │              │
                   └──────────────┘            └──────────────┘              │
                              └──────────────────────────────────────────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    ▼                          ▼                          ▼
        ┌───────────────────┐      ┌───────────────────┐      ┌───────────────────┐
        │ MODUŁ: mitre      │      │ MODUŁ: behavioral │      │ MODUŁ: ai-assist  │
        │ (opcjonalny)      │      │ (opcjonalny)      │      │ (opcjonalny)      │
        ├───────────────────┤      ├───────────────────┤      ├───────────────────┤
        │ Mapowanie MITRE   │      │ TimeTravel        │      │ Analiza AI        │
        │ Impakt ATT&CK     │      │ Profiling         │      │ Rekomendacje      │
        │ Coverage heatmap  │      │ Anomaly Detection │      │ Playbooki         │
        └───────────────────┘      │ Threshold Suggest │      └───────────────────┘
                                   └───────────────────┘
```

### CMDB Sync

Osobny komponent odpowiedzialny za synchronizację danych o assetach.
Dane pochodzą z zewnętrznych systemów — SilentPulse ich nie generuje, tylko importuje.

Szczegóły: [features/cmdb-sync.md](features/cmdb-sync.md)

### Grupy assetów

Filtrowane podzbiory assetów z pełnej puli CMDB.
Każda grupa posiada mapowanie na techniki MITRE ATT&CK.

Szczegóły: [features/asset-groups.md](features/asset-groups.md)

### Integration Points

Obiekty konfiguracyjne wewnątrz SilentPulse opisujące dostęp do zewnętrznych systemów.
Systemy zewnętrzne (Kafka, Splunk, Elasticsearch itd.) znajdują się poza ekosystemem SilentPulse.

Szczegóły: [features/integration-points.md](features/integration-points.md)

### Flow

Ścieżka przepływu danych per grupa assetów przez kolejne punkty połączeń.
Każdy punkt w flow posiada własny worker i scheduler.

Szczegóły: [features/flows.md](features/flows.md)

### Worker — tryby pracy (Batch vs Realtime)

Worker obsługuje dwa tryby zbierania danych:

- **Batch** (domyślny): periodyczne odpytywanie zewnętrznego systemu w interwałach
  (np. Splunk query co 5 minut, Elasticsearch search co 10 minut).
- **Realtime**: ciągła konsumpcja strumienia danych (np. Kafka consumer, Syslog listener).
  Worker zapisuje assety do Redis na bieżąco, bez przerw.

Tryb jest konfigurowany per pulse (`collector_mode` na `FlowPulse`).
Scheduler działa identycznie w obu trybach — czyta Redis w oknie czasowym.

Konektory deklarują wspierane tryby:

| Konektor        | Batch | Realtime |
|-----------------|-------|----------|
| Kafka           | ✓     | ✓        |
| Elasticsearch   | ✓     | -        |
| Splunk          | ✓     | -        |
| Syslog          | -     | ✓        |
| REST API        | ✓     | -        |

Plugin batch implementuje `Plugin.Collect()`.
Plugin realtime implementuje dodatkowy interfejs `StreamingPlugin.Stream()`.
Pluginy mogą wspierać oba tryby (np. Kafka).

### Orkiestracja workerów — model K8s

Lifecycle workerów zależy od środowiska uruchomieniowego.
Interfejs `ContainerOrchestrator` abstrahuje różnice:

```
type ContainerOrchestrator interface {
    StartWorker(ctx, flow, pulse, ipType) (string, error)
    StartScheduler(ctx, flow, pulse, ipType) (string, error)
    StopAll(ctx, flowID) error
    Status(ctx, flowID) ([]ContainerStatus, error)
}
```

| Środowisko | Implementacja | Batch worker | Realtime worker |
|------------|---------------|--------------|-----------------|
| Dev        | `DockerOrchestrator` | Kontener z tickerem | Kontener z streamem |
| Prod       | `K8sOrchestrator`   | **K8s CronJob** | **K8s Deployment** |

Wybór: `ORCHESTRATOR_TYPE=docker|k8s`

#### Batch → K8s CronJob

Worker uruchamia się w trybie `--single-run`: wykonuje jeden cykl
(connect → collect → parse → write Redis) i kończy się (exit 0/1/2).
K8s CronJob zarządza harmonogramem i restartami.

```
┌─────────────────────────────────────┐
│ CronJob: pulse-splunk-eu            │
│ schedule: */5 * * * *               │
│ concurrencyPolicy: Forbid           │
│ activeDeadlineSeconds: 240          │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ Job (Pod)                     │  │
│  │ worker --single-run           │  │
│  │                               │  │
│  │ 1. Connect to Splunk          │  │
│  │ 2. Execute query              │  │
│  │ 3. Parse results              │  │
│  │ 4. Write observed → Redis     │  │
│  │ 5. Exit 0 (OK) / 1 (WARN)    │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

Zalety:
- Zero idle memory — worker nie żyje między cyklami
- Scheduling delegowany do K8s (zamiast self-managed ticker)
- Restart/backoff natywny (backoffLimit, CrashLoopBackOff)

Ograniczenie: CronJob ma granulację 1 minuty.
Interwały < 1 min → Deployment zamiast CronJob.

#### Realtime → K8s Deployment

Worker utrzymuje ciągłe połączenie (Kafka consumer, Syslog listener).
Deployment zapewnia auto-restart i skalowanie.

```
┌─────────────────────────────────────┐
│ Deployment: pulse-kafka-stream      │
│ replicas: 2 (HPA)                   │
│ restartPolicy: Always               │
│                                     │
│  ┌──────────┐  ┌──────────┐        │
│  │ Pod 1    │  │ Pod 2    │        │
│  │ consumer │  │ consumer │        │
│  │ group    │  │ group    │        │
│  │ /healthz │  │ /healthz │        │
│  │ /readyz  │  │ /readyz  │        │
│  └──────────┘  └──────────┘        │
└─────────────────────────────────────┘
```

Zalety:
- HPA — skalowanie Kafka consumerów na wiele podów
- Liveness/readiness probes zamiast heartbeat z opóźnieniem
- Rolling updates bez downtime

Syslog: wymaga K8s Service (LoadBalancer/NodePort) dla portu UDP/TCP 514.

#### Evaluator → K8s CronJob

Scheduler/Evaluator (porównanie CMDB vs Redis) działa jako CronJob
analogicznie do batch workera.

#### Pełny diagram K8s

```
┌─────────────────────────────────────────────────────────────────────┐
│                        KUBERNETES CLUSTER                           │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Operator (Deployment)          CRD: SilentPulseFlow          │  │
│  │  - Watch CRDs                   spec:                         │  │
│  │  - Reconcile state                pulses:                     │  │
│  │  - Leader election                  - splunk (batch, 5m)      │  │
│  │  - RBAC scoped                      - kafka (realtime)        │  │
│  │                                     - syslog (realtime)       │  │
│  │         │ creates/manages         status:                     │  │
│  │         │                           phase: Running            │  │
│  └─────────┼─────────────────────────────────────────────────────┘  │
│            │                                                        │
│            ▼                                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  BATCH (CronJob)                REALTIME (Deployment)        │   │
│  │                                                              │   │
│  │  ┌────────────────┐            ┌────────────────────┐        │   │
│  │  │ CronJob:       │            │ Deployment:        │        │   │
│  │  │  splunk        │            │  kafka-stream      │        │   │
│  │  │  */5 * * * *   │            │  replicas: 2       │        │   │
│  │  │  --single-run  │            │  /healthz /readyz  │        │   │
│  │  └────────────────┘            └────────────────────┘        │   │
│  │                                                              │   │
│  │  ┌────────────────┐            ┌────────────────────┐        │   │
│  │  │ CronJob:       │            │ Deployment:        │        │   │
│  │  │  eval-splunk   │            │  syslog            │        │   │
│  │  │  */5 * * * *   │            │  replicas: 1       │        │   │
│  │  │  --single-run  │            │  Service: LB:514   │        │   │
│  │  └────────────────┘            └────────────────────┘        │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│            │ write                  │ read                          │
│            ▼                        ▼                               │
│     ┌─────────────┐         ┌──────────────┐                       │
│     │    Redis     │         │  PostgreSQL   │                      │
│     │ - observed   │         │ - alerts      │                      │
│     │ - circuit br.│         │ - config      │                      │
│     │ - status     │         │ - CMDB        │                      │
│     └─────────────┘         └──────────────┘                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Cache

Przechowuje stan faktyczny — które assety zostały zaobserwowane, gdzie i kiedy.
Dane zapisywane przez workery, odczytywane przez schedulery.
Technologia: Redis.

### Zasady architektoniczne

- Brak monolitów
- Brak współdzielonych baz danych pomiędzy serwisami
- Brak synchronicznego fan-out dla przetwarzania per asset
- Interfejs użytkownika nie może blokować ingestu ani ścieżek wykonawczych
- Architektura modułowa
- Preferowane użycie kontenerów dla każdego komponentu
