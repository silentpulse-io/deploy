# API Design

Dwie warstwy komunikacji.

## System modułów

Niektóre endpointy są dostępne tylko gdy odpowiedni moduł jest włączony.
Endpointy modułowe zwracają 404 gdy moduł jest wyłączony.

Sprawdzenie dostępnych modułów:
```
GET /api/v1/modules
→ {"data": {"available": ["core", "mitre", "behavioral"], "enabled": ["core", "mitre"]}}
```

## Frontend → Backend: REST API

Wersjonowane API (`/api/v1/`), JSON, autentykacja per request.
RBAC egzekwowany na poziomie każdego endpointa.

### CMDB / Assets

```
POST   /api/v1/cmdb/sync                  # Trigger PULL sync z zewnętrznego CMDB
POST   /api/v1/cmdb/upload                # CSV upload
POST   /api/v1/cmdb/push                  # PUSH API — zewnętrzny system wysyła assety
GET    /api/v1/assets                      # Lista assetów (filtry, paginacja)
GET    /api/v1/assets/:id                  # Szczegóły assetu
GET    /api/v1/assets/:id/dependencies     # Graf zależności assetu (AGE)
```

### Asset Groups

```
POST   /api/v1/asset-groups                # Utwórz grupę
GET    /api/v1/asset-groups                # Lista grup
GET    /api/v1/asset-groups/:id            # Szczegóły grupy
PUT    /api/v1/asset-groups/:id            # Aktualizuj grupę
DELETE /api/v1/asset-groups/:id            # Usuń grupę
GET    /api/v1/asset-groups/:id/assets     # Assety w grupie (resolved z filtrów)

# Moduł mitre (opcjonalny)
GET    /api/v1/asset-groups/:id/mitre      # Przypisane techniki MITRE
PUT    /api/v1/asset-groups/:id/mitre      # Aktualizuj mapowanie MITRE
```

### Integration Points

```
POST   /api/v1/integration-points          # Utwórz punkt
GET    /api/v1/integration-points          # Lista punktów
GET    /api/v1/integration-points/:id      # Szczegóły punktu
PUT    /api/v1/integration-points/:id      # Aktualizuj punkt
DELETE /api/v1/integration-points/:id      # Usuń punkt
POST   /api/v1/integration-points/:id/test # Test połączenia
```

### Flows

```
POST   /api/v1/flows                       # Utwórz flow
GET    /api/v1/flows                       # Lista flow
GET    /api/v1/flows/:id                   # Szczegóły flow (z punktami)
PUT    /api/v1/flows/:id                   # Aktualizuj flow
DELETE /api/v1/flows/:id                   # Usuń flow
POST   /api/v1/flows/:id/enable            # Włącz flow (start kontenerów)
POST   /api/v1/flows/:id/disable           # Wyłącz flow (stop kontenerów)
GET    /api/v1/flows/:id/status            # Stan workerów i schedulerów
```

### Alerts

```
GET    /api/v1/alerts                      # Lista alertów (filtry, paginacja)
GET    /api/v1/alerts/:id                  # Szczegóły alertu
POST   /api/v1/alerts/:id/acknowledge      # Potwierdź alert

# Moduł mitre (opcjonalny)
GET    /api/v1/alerts/:id/mitre-impact     # Pełny impakt MITRE
```

### MITRE ATT&CK — moduł `mitre` (opcjonalny)

Endpointy dostępne tylko gdy moduł `mitre` jest włączony.

```
GET    /api/v1/mitre/techniques            # Baza technik (do wyboru przy mapowaniu)
GET    /api/v1/mitre/tactics               # Lista taktyk
GET    /api/v1/mitre/coverage              # Pokrycie organizacji (graf)
```

### Impact Analysis (Apache AGE) — moduł `mitre` (opcjonalny)

Analiza impaktu MITRE. Wymaga włączonego modułu `mitre`.

```
GET    /api/v1/impact/asset/:id            # Impakt ciszy na assecie (kaskadowo)
GET    /api/v1/impact/integration-point/:id # Impakt awarii punktu (cross-flow)
GET    /api/v1/impact/asset-group/:id      # Impakt ciszy na grupie
```

### Dashboards

```
GET    /api/v1/dashboard/overview          # Stan widoczności — podsumowanie
GET    /api/v1/dashboard/trends            # Trendy widoczności w czasie
GET    /api/v1/dashboard/topology          # Topologia infrastruktury (graf)

# Moduł mitre (opcjonalny)
GET    /api/v1/dashboard/mitre-coverage    # Pokrycie MITRE (aktywne vs dotknięte)
```

### Users (Admin)

```
POST   /api/v1/users                       # Utwórz użytkownika
GET    /api/v1/users                       # Lista użytkowników
PUT    /api/v1/users/:id                   # Aktualizuj użytkownika
DELETE /api/v1/users/:id                   # Usuń użytkownika
```

### Notification Channels

```
POST   /api/v1/notification-channels           # Utwórz kanał (webhook, slack, email, splunk)
GET    /api/v1/notification-channels           # Lista kanałów
GET    /api/v1/notification-channels/:id       # Szczegóły kanału
PUT    /api/v1/notification-channels/:id       # Aktualizuj kanał
DELETE /api/v1/notification-channels/:id       # Usuń kanał
POST   /api/v1/notification-channels/:id/test  # Wyślij test notification
```

### Notification Rules

```
POST   /api/v1/notification-rules              # Utwórz regułę
GET    /api/v1/notification-rules              # Lista reguł
GET    /api/v1/notification-rules/:id          # Szczegóły reguły
PUT    /api/v1/notification-rules/:id          # Aktualizuj regułę
DELETE /api/v1/notification-rules/:id          # Usuń regułę
```

### Reports

```
POST   /api/v1/reports                         # Utwórz definicję raportu
GET    /api/v1/reports                         # Lista definicji raportów
GET    /api/v1/reports/:id                     # Szczegóły definicji
PUT    /api/v1/reports/:id                     # Aktualizuj definicję
DELETE /api/v1/reports/:id                     # Usuń definicję
POST   /api/v1/reports/:id/generate            # Wygeneruj raport ad-hoc
GET    /api/v1/reports/:id/executions          # Historia wykonań
GET    /api/v1/reports/:id/executions/:eid/download  # Pobierz wygenerowany raport
```

### External Data API (API key auth)

Dedykowane endpointy dla zewnętrznych systemów BI (PowerBI, Grafana itd.).
Autentykacja: API key (header `X-API-Key`), nie JWT.

```
GET    /api/v1/external/alerts                 # Alerty (filtry, paginacja, zakres dat)
GET    /api/v1/external/alerts/aggregations    # Agregacje (per region, grupa)
GET    /api/v1/external/alerts/trends          # Trendy alertów w czasie
GET    /api/v1/external/coverage               # Pokrycie assetów (per criticality, region)

# Moduł mitre (opcjonalny)
GET    /api/v1/external/mitre-coverage         # Pokrycie MITRE ATT&CK
GET    /api/v1/external/alerts/aggregations?by=mitre  # Agregacje per MITRE (wymaga modułu)
```

### API Keys

```
POST   /api/v1/api-keys                        # Utwórz klucz API
GET    /api/v1/api-keys                        # Lista kluczy
DELETE /api/v1/api-keys/:id                    # Cofnij klucz
```

### Audit Tasks (Admin)

```
POST   /api/v1/audit-tasks                 # Utwórz audit task (przypisz audytora, zakres, okres)
GET    /api/v1/audit-tasks                 # Lista audit tasków
GET    /api/v1/audit-tasks/:id             # Szczegóły audit taska
PUT    /api/v1/audit-tasks/:id             # Aktualizuj audit task
POST   /api/v1/audit-tasks/:id/complete    # Oznacz jako zakończony
DELETE /api/v1/audit-tasks/:id             # Usuń audit task
```

### Auditor (scoped — filtrowane przez audit task)

Endpointy dostępne dla audytora. Każde zapytanie jest automatycznie
filtrowane przez scope_filters i period z przypisanego audit taska.

```
GET    /api/v1/auditor/task                # Mój aktywny audit task (zakres, okres)
GET    /api/v1/auditor/assets              # Assety w zakresie audytu
GET    /api/v1/auditor/asset-groups        # Grupy w zakresie audytu
GET    /api/v1/auditor/flows               # Flow w zakresie audytu
GET    /api/v1/auditor/alerts              # Alerty w zakresie i okresie audytu
GET    /api/v1/auditor/alerts/timeline     # Timeline przestojów
GET    /api/v1/auditor/report              # Wygeneruj raport (eksport)

# Moduł mitre (opcjonalny)
GET    /api/v1/auditor/mitre-impact        # Impakt MITRE w zakresie audytu
```

### Audit Log

```
GET    /api/v1/audit-log                   # Logi audytowe (filtry, paginacja)
```

### TimeTravel — moduł `behavioral` (opcjonalny)

Historyczna oś czasu obserwacji assetów i feedów.
Endpointy dostępne tylko gdy moduł `behavioral` jest włączony.

```
GET    /api/v1/timetravel/asset/:id                # Historia assetu
       ?flow_pulse_id=...                          # Opcjonalnie: konkretny punkt flow
       &from=2024-01-01T00:00:00Z                  # Początek okresu
       &to=2024-01-31T23:59:59Z                    # Koniec okresu
       &resolution=auto                            # auto, minute, hour, day

GET    /api/v1/timetravel/asset/:id/export         # Eksport historii
       ?format=pdf|csv|json
       &from=...
       &to=...
       &include_alerts=true
       &include_anomalies=true
       &include_baseline=true

GET    /api/v1/timetravel/flow-pulse/:id           # Historia całego feedu
       ?from=...
       &to=...
       &resolution=auto

GET    /api/v1/timetravel/flow-pulse/:id/export    # Eksport historii feedu
       ?format=pdf|csv|json
       &from=...
       &to=...

GET    /api/v1/timetravel/compare                  # Porównanie wielu assetów/feedów
       ?asset_ids=id1,id2,id3
       &flow_pulse_id=...
       &from=...
       &to=...
```

### Profiles — moduł `behavioral` (opcjonalny)

Profile zachowania feedów i assetów.
Endpointy dostępne tylko gdy moduł `behavioral` jest włączony.

```
GET    /api/v1/profiles/feed/:flow_pulse_id        # Profil feeda
GET    /api/v1/profiles/feed/:flow_pulse_id/stats  # Statystyki profilu

GET    /api/v1/profiles/asset/:asset_id            # Profile assetu (wszystkie flow pulses)
GET    /api/v1/profiles/asset/:asset_id/:flow_pulse_id  # Profil assetu w konkretnym punkcie

POST   /api/v1/profiles/feed/:flow_pulse_id/reset  # Reset profilu (restart learning phase)
POST   /api/v1/profiles/asset/:asset_id/:flow_pulse_id/reset

PUT    /api/v1/profiles/feed/:flow_pulse_id/config # Konfiguracja profilingu
PUT    /api/v1/profiles/asset/:asset_id/config

POST   /api/v1/profiles/feed/:flow_pulse_id/pause  # Wstrzymaj profilowanie
POST   /api/v1/profiles/feed/:flow_pulse_id/resume # Wznów profilowanie
```

### Threshold Suggestions — moduł `behavioral` (opcjonalny)

Sugestie optymalnych progów alertowania.
Endpointy dostępne tylko gdy moduł `behavioral` jest włączony.

```
GET    /api/v1/suggestions                         # Lista aktywnych sugestii
       ?priority=high,medium
       &status=pending
       &flow_pulse_id=...

GET    /api/v1/suggestions/:id                     # Szczegóły sugestii

POST   /api/v1/suggestions/:id/accept              # Zaakceptuj sugestię
POST   /api/v1/suggestions/:id/reject              # Odrzuć sugestię
       Body: { "reason": "..." }

POST   /api/v1/suggestions/:id/modify              # Modyfikuj i zastosuj
       Body: { "modified_value": "45m", "note": "..." }

GET    /api/v1/suggestions/history                 # Historia decyzji o sugestiach
```

### Anomalies — moduł `behavioral` (opcjonalny)

Wykryte anomalie w zachowaniu.
Endpointy dostępne tylko gdy moduł `behavioral` jest włączony.

```
GET    /api/v1/anomalies                           # Lista anomalii
       ?severity=critical,warning
       &type=silence,volume,pattern,burst,drift
       &status=open
       &from=...
       &to=...
       &asset_id=...
       &flow_pulse_id=...

GET    /api/v1/anomalies/:id                       # Szczegóły anomalii

POST   /api/v1/anomalies/:id/acknowledge           # Potwierdź/sklasyfikuj anomalię
       Body: {
         "status": "expected|investigated|ignored",
         "note": "Planned maintenance window"
       }

GET    /api/v1/anomalies/stats                     # Statystyki anomalii
       ?from=...
       &to=...
       &group_by=type|severity|flow_pulse
```

### Auditor - Behavioral Analytics (scoped) — moduł `behavioral` (opcjonalny)

Rozszerzenia endpointów audytora o dane behawioralne.
Endpointy dostępne tylko gdy moduł `behavioral` jest włączony.

```
GET    /api/v1/auditor/timetravel/asset/:id        # TimeTravel w zakresie audytu
GET    /api/v1/auditor/timetravel/flow-pulse/:id   # TimeTravel feedu w zakresie audytu

GET    /api/v1/auditor/timetravel/export           # Eksport TimeTravel dla audytora
       ?format=pdf|csv|json
       &asset_ids=...
       &flow_pulse_ids=...

GET    /api/v1/auditor/anomalies                   # Anomalie w zakresie audytu
GET    /api/v1/auditor/profiles                    # Profile w zakresie audytu
GET    /api/v1/auditor/behavioral-report           # Raport behawioralny
       ?format=pdf
```

## Service → Service: gRPC

Wewnętrzna komunikacja między mikroserwisami. Nie eksponowana na zewnątrz.

```protobuf
service FlowController {
  rpc StartFlow(FlowConfig) returns (FlowStatus);
  rpc StopFlow(FlowId) returns (FlowStatus);
  rpc GetFlowStatus(FlowId) returns (FlowStatus);
}

service WorkerService {
  rpc StartCollection(CollectionConfig) returns (CollectionStatus);
  rpc StopCollection(CollectionId) returns (CollectionStatus);
  rpc HealthCheck(Empty) returns (HealthStatus);
}

service SchedulerService {
  rpc EvaluateFlowPulse(FlowPulseConfig) returns (EvaluationResult);
}

service AlertService {
  rpc CreateAlert(AlertRequest) returns (Alert);
  rpc ResolveAlert(AlertId) returns (Alert);
  rpc GetActiveAlerts(FlowPulseId) returns (AlertList);
}
```

## Konwencje

- Wszystkie ID to UUID v4
- Paginacja: `?page=1&per_page=50`
- Filtry: query params (`?vendor=Microsoft&region=EU`)
- Sortowanie: `?sort=created_at&order=desc`
- Odpowiedzi: JSON z envelope `{"data": ..., "meta": {"page": 1, "total": 100}}`
- Błędy: RFC 7807 Problem Details (`{"type": "...", "title": "...", "status": 400, "detail": "..."}`)
- Autentykacja: Bearer token (JWT)
- Rate limiting: per user/tenant
