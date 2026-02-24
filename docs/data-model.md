# Data Model

## Encje relacyjne (PostgreSQL — SQL)

### Asset

Pojedynczy asset zaimportowany z CMDB.

| Pole        | Typ           | Opis                                      |
|-------------|---------------|-------------------------------------------|
| id          | UUID          | PK                                        |
| external_id | VARCHAR       | ID z zewnętrznego CMDB                    |
| hostname    | VARCHAR       | Nazwa hosta                               |
| ip          | VARCHAR       | Adres IP                                  |
| os          | VARCHAR       | System operacyjny                         |
| vendor      | VARCHAR       | Producent                                 |
| product     | VARCHAR       | Produkt                                   |
| region      | VARCHAR       | Region                                    |
| rating      | VARCHAR       | Klasyfikacja                              |
| metadata    | JSONB         | Elastyczne atrybuty z CMDB                |
| tenant_id   | UUID          | FK → Tenant (multi-tenancy)               |
| created_at  | TIMESTAMP     |                                           |
| updated_at  | TIMESTAMP     |                                           |

Stałe pola (hostname, vendor, region) to kolumny — indeksowanie, filtrowanie.
Zmienne atrybuty z CMDB w `metadata` (JSONB).

### AssetGroup

Filtrowana grupa assetów. Nie przechowuje listy assetów — oblicza ją dynamicznie.

| Pole        | Typ           | Opis                                      |
|-------------|---------------|-------------------------------------------|
| id          | UUID          | PK                                        |
| name        | VARCHAR       |                                           |
| description | TEXT          |                                           |
| filters     | JSONB         | Definicja filtrów (vendor, region itd.)   |
| tenant_id   | UUID          | FK → Tenant                               |
| created_at  | TIMESTAMP     |                                           |
| updated_at  | TIMESTAMP     |                                           |

Przykład filters: `{"vendor": "Microsoft", "region": "EU", "os": "Windows Server%"}`

### AssetGroupMitre (M:N) — moduł `mitre`

**Uwaga:** Ta tabela istnieje tylko gdy moduł `mitre` jest włączony.

| Pole              | Typ     | Opis                   |
|--------------------|---------|------------------------|
| asset_group_id     | UUID    | FK → AssetGroup        |
| mitre_technique_id | UUID    | FK → MitreTechnique    |

### MitreTechnique — moduł `mitre`

**Uwaga:** Ta tabela istnieje tylko gdy moduł `mitre` jest włączony.

Dane referencyjne — lokalna kopia bazy MITRE ATT&CK.

| Pole           | Typ      | Opis                            |
|----------------|----------|---------------------------------|
| id             | UUID     | PK                              |
| technique_id   | VARCHAR  | Np. T1003, T1003.001            |
| name           | VARCHAR  | Np. "OS Credential Dumping"     |
| tactic         | VARCHAR  | Np. "Credential Access"         |
| description    | TEXT     |                                 |

### IntegrationPoint

Konfiguracja połączenia do zewnętrznego systemu. Zawiera wyłącznie dane potrzebne
do nawiązania połączenia (adres, credentials). Szczegóły zapytań (topic, query,
JSON path) konfigurowane są per-flow w ramach FlowPulse.

| Pole              | Typ      | Opis                                           |
|--------------------|----------|-------------------------------------------------|
| id                 | UUID     | PK                                              |
| name               | VARCHAR  |                                                 |
| type               | VARCHAR  | kafka, splunk, elasticsearch, databricks itd.   |
| connection_config  | BYTEA    | Szyfrowane (pgcrypto) — adres, credentials      |
| tenant_id          | UUID     | FK → Tenant                                      |
| created_at         | TIMESTAMP|                                                  |
| updated_at         | TIMESTAMP|                                                  |

### Flow

Definicja ścieżki danych per grupa assetów.

| Pole           | Typ       | Opis                    |
|----------------|-----------|-------------------------|
| id             | UUID      | PK                      |
| name           | VARCHAR   |                         |
| description    | TEXT      |                         |
| asset_group_id | UUID      | FK → AssetGroup         |
| enabled        | BOOLEAN   | Czy flow jest aktywny   |
| tenant_id      | UUID      | FK → Tenant             |
| created_at     | TIMESTAMP |                         |
| updated_at     | TIMESTAMP |                         |

### FlowPulse

Punkt w flow — łączy Flow z IntegrationPoint, dodaje kolejność i scheduler.

| Pole                  | Typ       | Opis                                  |
|-----------------------|-----------|---------------------------------------|
| id                    | UUID      | PK                                    |
| flow_id               | UUID      | FK → Flow                             |
| integration_point_id  | UUID      | FK → IntegrationPoint                 |
| position              | INT       | Kolejność w flow (1, 2, 3...)         |
| scheduler_interval    | INTERVAL  | Częstotliwość sprawdzania             |
| time_window           | INTERVAL  | Okno tolerancji (brak w oknie = alert)|
| created_at            | TIMESTAMP |                                       |

### Alert

| Pole              | Typ       | Opis                                              |
|--------------------|-----------|---------------------------------------------------|
| id                 | UUID      | PK                                                |
| flow_pulse_id      | UUID      | FK → FlowPulse                                    |
| asset_id           | UUID      | FK → Asset                                        |
| status             | VARCHAR   | open, acknowledged, resolved                      |
| started_at         | TIMESTAMP | Początek przestoju                                |
| resolved_at        | TIMESTAMP | Koniec przestoju (NULL jeśli trwa)                |
| mitre_techniques   | JSONB     | Zdenormalizowane techniki (NULL gdy moduł wyłączony) |
| tenant_id          | UUID      | FK → Tenant                                       |

**Alert.mitre_techniques** — pole opcjonalne, wypełniane tylko gdy moduł `mitre` jest włączony.
Gdy moduł aktywny, pole jest zdenormalizowane — alert jest samowystarczalny,
nie wymaga joinów do wyświetlenia impaktu.

### User

| Pole          | Typ       | Opis                          |
|---------------|-----------|-------------------------------|
| id            | UUID      | PK                            |
| email         | VARCHAR   | Unique                        |
| password_hash | VARCHAR   |                               |
| role          | VARCHAR   | admin, analyst, viewer, auditor |
| tenant_id     | UUID      | FK → Tenant                   |
| created_at    | TIMESTAMP |                               |

### NotificationChannel

Kanał dostarczania alertów do zewnętrznego systemu.

| Pole       | Typ       | Opis                                              |
|------------|-----------|---------------------------------------------------|
| id         | UUID      | PK                                                |
| name       | VARCHAR   | Np. "SOC Slack", "SOAR webhook"                   |
| type       | VARCHAR   | webhook, slack, email, splunk                     |
| config     | BYTEA     | Szyfrowane — URL, token, adresy email itd.        |
| enabled    | BOOLEAN   |                                                   |
| tenant_id  | UUID      | FK → Tenant                                       |
| created_at | TIMESTAMP |                                                   |
| updated_at | TIMESTAMP |                                                   |

### NotificationRule

Reguła określająca kiedy i gdzie wysłać powiadomienie.

| Pole                    | Typ       | Opis                                        |
|-------------------------|-----------|---------------------------------------------|
| id                      | UUID      | PK                                          |
| name                    | VARCHAR   | Np. "Critical EU alerts to Slack"           |
| conditions              | JSONB     | Warunki: severity, region, group, MITRE itd.|
| notification_channel_id | UUID      | FK → NotificationChannel                    |
| enabled                 | BOOLEAN   |                                             |
| tenant_id               | UUID      | FK → Tenant                                 |
| created_at              | TIMESTAMP |                                             |

Przykład conditions:
```json
{
  "severity": "critical",
  "regions": ["EU"],
  "mitre_tactics": ["Credential Access"]  // opcjonalne, wymaga modułu mitre
}
```

**Uwaga:** Warunek `mitre_tactics` jest dostępny tylko gdy moduł `mitre` jest włączony.
Reguły z warunkami MITRE są ignorowane gdy moduł jest wyłączony.

### ReportDefinition

Definicja schedulowanego raportu.

| Pole          | Typ       | Opis                                           |
|---------------|-----------|------------------------------------------------|
| id            | UUID      | PK                                             |
| name          | VARCHAR   | Np. "Weekly Asia Critical Coverage"            |
| type          | VARCHAR   | asset_coverage, outage_history, visibility_trend, mitre_coverage (wymaga modułu mitre) |
| filters       | JSONB     | region, criticality, asset_group itd.          |
| period        | VARCHAR   | last_7d, last_30d, last_quarter, custom        |
| schedule_cron | VARCHAR   | Harmonogram (cron expression)                  |
| format        | VARCHAR   | pdf, csv                                       |
| recipients    | JSONB     | Lista adresów email                            |
| enabled       | BOOLEAN   |                                                |
| tenant_id     | UUID      | FK → Tenant                                    |
| created_at    | TIMESTAMP |                                                |
| updated_at    | TIMESTAMP |                                                |

### ReportExecution

Pojedyncze wykonanie raportu (historia).

| Pole                 | Typ       | Opis                              |
|----------------------|-----------|-----------------------------------|
| id                   | UUID      | PK                                |
| report_definition_id | UUID      | FK → ReportDefinition             |
| status               | VARCHAR   | pending, generating, sent, failed |
| generated_at         | TIMESTAMP |                                   |
| file_path            | VARCHAR   | Ścieżka do wygenerowanego pliku   |
| error                | TEXT      | Komunikat błędu (jeśli failed)    |

### ApiKey

Klucz API dla integracji machine-to-machine (PowerBI, Grafana itd.).

| Pole       | Typ       | Opis                                    |
|------------|-----------|------------------------------------------|
| id         | UUID      | PK                                       |
| name       | VARCHAR   | Np. "PowerBI production"                 |
| key_hash   | VARCHAR   | Hash klucza (nigdy plaintext)            |
| scopes     | JSONB     | Dozwolone zakresy (alerts:read itd.)     |
| user_id    | UUID      | FK → User (właściciel)                   |
| expires_at | TIMESTAMP | Data wygaśnięcia                         |
| tenant_id  | UUID      | FK → Tenant                              |
| created_at | TIMESTAMP |                                          |

### AuditTask

Zadanie audytowe — definiuje scoped, czasowy dostęp dla audytora.

| Pole              | Typ       | Opis                                          |
|-------------------|-----------|-----------------------------------------------|
| id                | UUID      | PK                                            |
| name              | VARCHAR   | Np. "Q1 2026 Asia Visibility Audit"           |
| description       | TEXT      |                                               |
| auditor_user_id   | UUID      | FK → User (rola auditor)                      |
| scope_filters     | JSONB     | Filtry zakresu (region, asset_group itd.)      |
| period_start      | TIMESTAMP | Początek okresu objętego audytem              |
| period_end        | TIMESTAMP | Koniec okresu objętego audytem                |
| access_expires_at | TIMESTAMP | Data wygaśnięcia dostępu audytora             |
| status            | VARCHAR   | active, completed, expired                    |
| created_by        | UUID      | FK → User (admin, który stworzył task)        |
| tenant_id         | UUID      | FK → Tenant                                   |
| created_at        | TIMESTAMP |                                               |

Przykład scope_filters:
```json
{
  "regions": ["Singapore", "Tokyo", "Sydney"],
  "asset_group_ids": null,
  "flow_ids": null
}
```

Null oznacza "wszystkie w ramach regionów". Filtry są kumulatywne (AND).

Wszystkie zapytania audytora są automatycznie filtrowane przez scope_filters + period.
Egzekwowane na poziomie API middleware — audytor nie może wyjść poza zakres.

### AuditLog

| Pole        | Typ       | Opis                                |
|-------------|-----------|-------------------------------------|
| id          | UUID      | PK                                  |
| user_id     | UUID      | FK → User                           |
| action      | VARCHAR   | create, update, delete              |
| entity_type | VARCHAR   | asset_group, flow, integration_point|
| entity_id   | UUID      |                                     |
| changes     | JSONB     | Diff zmian                          |
| tenant_id   | UUID      | FK → Tenant                         |
| created_at  | TIMESTAMP |                                     |

---

## Behavioral Analytics — moduł `behavioral` (opcjonalny)

Encje wspierające TimeTravel, Profiling i Anomaly Detection.

**Uwaga:** Te tabele istnieją tylko gdy moduł `behavioral` jest włączony.

### AssetObservation

Historia obserwacji assetu w punkcie flow (time series).

| Pole           | Typ       | Opis                                       |
|----------------|-----------|---------------------------------------------|
| id             | UUID      | PK                                          |
| asset_id       | UUID      | FK → Asset                                  |
| flow_pulse_id  | UUID      | FK → FlowPulse                              |
| observed_at    | TIMESTAMP | Kiedy asset został zaobserwowany            |
| metadata       | JSONB     | Dodatkowe dane (rozmiar, wolumen itd.)      |
| tenant_id      | UUID      | FK → Tenant                                 |

Index: `(flow_pulse_id, observed_at)` dla TimeTravel queries.
Partycjonowanie: po `observed_at` (monthly partitions) dla wydajności.

### AssetObservationHourly

Agregacja godzinowa obserwacji (warm/cold storage).

| Pole              | Typ       | Opis                                     |
|-------------------|-----------|-------------------------------------------|
| id                | UUID      | PK                                        |
| asset_id          | UUID      | FK → Asset                                |
| flow_pulse_id     | UUID      | FK → FlowPulse                            |
| hour              | TIMESTAMP | Początek godziny (truncated)              |
| observation_count | INT       | Liczba obserwacji w godzinie              |
| first_seen        | TIMESTAMP | Pierwsza obserwacja w godzinie            |
| last_seen         | TIMESTAMP | Ostatnia obserwacja w godzinie            |
| avg_interval_ms   | BIGINT    | Średni interwał między obserwacjami (ms)  |
| tenant_id         | UUID      | FK → Tenant                               |

### AssetObservationDaily

Agregacja dzienna (cold storage, długoterminowe trendy).

| Pole              | Typ       | Opis                                     |
|-------------------|-----------|-------------------------------------------|
| id                | UUID      | PK                                        |
| asset_id          | UUID      | FK → Asset                                |
| flow_pulse_id     | UUID      | FK → FlowPulse                            |
| date              | DATE      | Data                                      |
| observation_count | INT       | Liczba obserwacji w dniu                  |
| uptime_pct        | DECIMAL   | Procent czasu, gdy asset był widoczny     |
| gaps_count        | INT       | Liczba przerw (silence gaps)              |
| longest_gap_ms    | BIGINT    | Najdłuższa przerwa w ms                   |
| avg_interval_ms   | BIGINT    | Średni interwał (ms)                      |
| tenant_id         | UUID      | FK → Tenant                               |

### FeedProfile

Profil zachowania feeda (agregacja per FlowPulse).

| Pole                     | Typ       | Opis                                          |
|--------------------------|-----------|------------------------------------------------|
| id                       | UUID      | PK                                             |
| flow_pulse_id            | UUID      | FK → FlowPulse (unique)                        |
| status                   | VARCHAR   | learning, active, paused                       |
| learning_started_at      | TIMESTAMP | Początek fazy uczenia                          |
| learning_completed_at    | TIMESTAMP | Koniec fazy uczenia (NULL jeśli trwa)          |
| config                   | JSONB     | Konfiguracja profilingu                        |
| baseline                 | JSONB     | Nauczony baseline (zobacz struktura poniżej)   |
| tenant_id                | UUID      | FK → Tenant                                    |
| created_at               | TIMESTAMP |                                                |
| updated_at               | TIMESTAMP |                                                |

Struktura `baseline`:
```json
{
  "expected_assets": {
    "mean": 487,
    "stddev": 23,
    "p50": 490,
    "p95": 520,
    "p99": 535
  },
  "observation_interval_ms": {
    "mean": 300000,
    "stddev": 45000,
    "p95": 450000
  },
  "seasonality": {
    "hourly": { "0": 0.3, "1": 0.2, ..., "23": 0.9 },
    "daily": { "mon": 1.0, "tue": 0.98, ..., "sun": 0.45 }
  },
  "business_hours_factor": 1.3
}
```

### AssetProfile

Profil zachowania pojedynczego assetu w punkcie flow.

| Pole                 | Typ       | Opis                                          |
|----------------------|-----------|------------------------------------------------|
| id                   | UUID      | PK                                             |
| asset_id             | UUID      | FK → Asset                                     |
| flow_pulse_id        | UUID      | FK → FlowPulse                                 |
| status               | VARCHAR   | learning, active, paused                       |
| learning_started_at  | TIMESTAMP |                                                |
| learning_completed_at| TIMESTAMP |                                                |
| config               | JSONB     | Konfiguracja profilingu                        |
| baseline             | JSONB     | Nauczony baseline                              |
| tenant_id            | UUID      | FK → Tenant                                    |
| created_at           | TIMESTAMP |                                                |
| updated_at           | TIMESTAMP |                                                |

Unique constraint: `(asset_id, flow_pulse_id)`

Struktura `baseline`:
```json
{
  "typical_interval_ms": {
    "mean": 300000,
    "stddev": 30000,
    "p95": 420000
  },
  "activity_pattern": {
    "type": "continuous|scheduled|burst",
    "active_hours": [8, 9, 10, ..., 17],
    "active_days": ["mon", "tue", "wed", "thu", "fri"]
  },
  "last_updated": "2024-01-15T12:00:00Z"
}
```

### ThresholdSuggestion

Sugestia progu alertowania od systemu.

| Pole              | Typ       | Opis                                          |
|-------------------|-----------|------------------------------------------------|
| id                | UUID      | PK                                             |
| flow_pulse_id     | UUID      | FK → FlowPulse                                 |
| asset_id          | UUID      | FK → Asset (NULL = sugestia dla całego feedu)  |
| suggestion_type   | VARCHAR   | time_window, volume, seasonality               |
| priority          | VARCHAR   | high, medium, low                              |
| current_value     | VARCHAR   | Obecny próg (np. "5m")                         |
| suggested_value   | VARCHAR   | Sugerowany próg (np. "15m")                    |
| reasoning         | JSONB     | Uzasadnienie sugestii                          |
| status            | VARCHAR   | pending, accepted, rejected, modified          |
| operator_response | JSONB     | Odpowiedź operatora (modified value, note)     |
| responded_by      | UUID      | FK → User                                      |
| responded_at      | TIMESTAMP |                                                |
| tenant_id         | UUID      | FK → Tenant                                    |
| created_at        | TIMESTAMP |                                                |

Struktura `reasoning`:
```json
{
  "analysis": "Current threshold of 5m is below p50 interval (12m)",
  "data_points": 2847,
  "confidence": 0.92,
  "estimated_false_positive_reduction": "73%",
  "supporting_stats": {
    "current_fp_rate": 0.34,
    "projected_fp_rate": 0.09
  }
}
```

### AnomalyEvent

Wykryta anomalia w zachowaniu feeda lub assetu.

| Pole           | Typ       | Opis                                          |
|----------------|-----------|------------------------------------------------|
| id             | UUID      | PK                                             |
| flow_pulse_id  | UUID      | FK → FlowPulse                                 |
| asset_id       | UUID      | FK → Asset (NULL = anomalia na poziomie feedu) |
| anomaly_type   | VARCHAR   | silence, volume, pattern, burst, drift         |
| severity       | VARCHAR   | critical, warning, info                        |
| detected_at    | TIMESTAMP | Kiedy wykryto anomalię                         |
| description    | TEXT      | Opis anomalii                                  |
| details        | JSONB     | Szczegóły techniczne                           |
| related_alert_id | UUID    | FK → Alert (jeśli anomalia spowodowała alert)  |
| status         | VARCHAR   | open, expected, investigated, ignored          |
| acknowledged_by| UUID      | FK → User                                      |
| acknowledged_at| TIMESTAMP |                                                |
| operator_note  | TEXT      | Notatka operatora                              |
| tenant_id      | UUID      | FK → Tenant                                    |
| created_at     | TIMESTAMP |                                                |

Struktura `details`:
```json
{
  "expected_value": 487,
  "actual_value": 152,
  "deviation_pct": -68.7,
  "baseline_reference": "2024-01-08/2024-01-14",
  "comparison_window": "last_1h"
}
```

---

## Graf zależności (PostgreSQL + Apache AGE — Cypher)

Warstwa grafowa operuje na tych samych danych co warstwa relacyjna,
ale modeluje relacje między encjami jako krawędzie grafu.

### Węzły (Nodes)

```
# Core
(:Asset)              — asset z tabeli assets
(:AssetGroup)         — grupa assetów
(:IntegrationPoint)   — punkt połączenia
(:Flow)               — flow

# Moduł mitre (opcjonalny)
(:MitreTechnique)     — technika MITRE
```

### Krawędzie (Edges)

```
# Core
(:Asset)-[:HOSTS]->(:Asset)              — ESXi hostuje VM
(:Asset)-[:RUNS]->(:Asset)               — VM uruchamia bazę danych
(:Asset)-[:DEPENDS_ON]->(:Asset)         — zależność generyczna
(:Asset)-[:MEMBER_OF]->(:AssetGroup)     — asset należy do grupy
(:Flow)-[:USES]->(:IntegrationPoint)     — flow korzysta z punktu
(:AssetGroup)-[:HAS_FLOW]->(:Flow)       — grupa ma flow

# Moduł mitre (opcjonalny)
(:AssetGroup)-[:COVERS]->(:MitreTechnique) — grupa pokrywa technikę
```

### Przykładowe zapytania

**Core (zawsze dostępne):**

```cypher
-- Znajdź wszystkie zależne assety przy awarii ESXi
MATCH (esxi:Asset {hostname: "esxi-01"})-[:HOSTS|RUNS|DEPENDS_ON*]->(dep:Asset)
RETURN dep.hostname

-- Cross-flow impact: Kafka X padła — które flow dotknięte
MATCH (ip:IntegrationPoint {name: "kafka-prod"})<-[:USES]-(f:Flow)
MATCH (f)<-[:HAS_FLOW]-(g:AssetGroup)
RETURN f.name, g.name

-- Pełna ścieżka zależności assetu
MATCH path = (a:Asset {hostname: "db-prod-01"})<-[:HOSTS|RUNS*]-(root:Asset)
RETURN path
```

**Moduł mitre (wymaga włączonego modułu):**

```cypher
-- Impakt awarii ESXi: znajdź dotknięte techniki MITRE
MATCH (esxi:Asset {hostname: "esxi-01"})-[:HOSTS|RUNS|DEPENDS_ON*]->(dep:Asset)
MATCH (dep)-[:MEMBER_OF]->(g:AssetGroup)-[:COVERS]->(t:MitreTechnique)
RETURN dep.hostname, g.name, t.technique_id, t.name

-- Cross-flow impact z impaktem MITRE
MATCH (ip:IntegrationPoint {name: "kafka-prod"})<-[:USES]-(f:Flow)
MATCH (f)<-[:HAS_FLOW]-(g:AssetGroup)-[:COVERS]->(t:MitreTechnique)
RETURN f.name, g.name, collect(t.technique_id)

-- Pełna ścieżka z impaktem MITRE
MATCH path = (a:Asset {hostname: "db-prod-01"})<-[:HOSTS|RUNS*]-(root:Asset)
MATCH (a)-[:MEMBER_OF]->(g:AssetGroup)-[:COVERS]->(t:MitreTechnique)
RETURN path, collect(t.technique_id)
```

## Cache (Redis)

Nie w PostgreSQL — dane tymczasowe, szybki dostęp.

```
tenant:{tenant_id}:pulse:{pulse_id}:assets → Hash { asset_id: last_seen_timestamp }
```

Worker zapisuje, scheduler odczytuje i porównuje z grupą assetów z CMDB.
