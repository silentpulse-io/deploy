# Flows

Flow opisuje ścieżkę przepływu danych dla konkretnej grupy assetów
przez kolejne punkty połączeń (Integration Points).

## Struktura flow

Flow składa się z:
1. **Pipeline** — wizualny diagram węzłów połączonych strzałkami
   (np. Windows Server → Kafka → Splunk → Databricks)
2. **Pulse** (opcjonalny, per węzeł) — konfiguracja monitorowania
   przypiętego do węzła pipeline

## Pipeline

Pipeline definiuje topologię przepływu danych. Węzły reprezentują
etapy w potoku (source, transport, compute, sink). Krawędzie
(reference_edges) definiują kolejność przepływu.

Węzły pipeline nie mają własnej konfiguracji — są jedynie
wizualną reprezentacją etapów potoku danych.

## Pulse (sonda monitorująca)

Pulse to konfiguracja monitorowania przypiętego do konkretnego
węzła pipeline. Pulse odpowiada encji FlowPulse w bazie danych.

Pulse konfiguruje:

### Source (zakładka Source)
- **Integration Point** — wybór połączenia do systemu zewnętrznego
- **Collector Mode** — batch lub realtime
- **Scheduler Interval** — częstotliwość odpytywania (np. 5m)
- **Query Config** — szczegóły zapytania per-flow (topic Kafka,
  search query Splunk, SQL query Databricks)

### Extract (zakładka Extract)
- **Parser Type** — None / JSONPath / Grok / Regex
- **Parser Config** — wyrażenie parsera (np. `$.hostname`)
- **Hostname Field** — pole identyfikujące asset

### Alert (zakładka Alert)
- **Asset Group** — grupa assetów do porównania
- **Validation Type** — freshness / count / query / exists
- **Time Window** — okno czasowe walidacji (np. 15m)
- **Notification Channel** — kanał powiadomień

## Przykład

Flow: "Windows EU telemetry"
- Pipeline: `[Windows Servers] → [Kafka] → [Splunk]`
- Pulse na "Kafka":
  - IP: Kafka Cluster SG
  - Query: `{"topic": "windows-events"}`
  - Parser: JSONPath `$.source.hostname`
  - Asset Group: "Stacje Windows EU"
  - Validation: freshness, window=15m
- Pulse na "Splunk":
  - IP: Splunk HEC
  - Query: `{"search": "index=windows | stats count by host"}`
  - Parser: None (strukturalne dane)
  - Asset Group: "Stacje Windows EU"
  - Validation: freshness, window=1h

## Worker

Worker nie podejmuje żadnych decyzji.
Jego jedyna rola to:
1. Połączenie z zewnętrznym systemem (wg connection_config z Integration Point)
2. Wykonanie zapytania (wg query_config z FlowPulse)
3. Parsowanie wyników (wg parser_config z pulse)
4. Zapisanie listy zaobserwowanych assetów do cache (Redis)

### Tryby uruchomienia

| Tryb | Flaga | Zastosowanie | Zasób K8s |
|------|-------|--------------|-----------|
| Long-lived | (domyślny) | Dev (Docker Compose), realtime (prod) | Deployment |
| Single-run | `--single-run` | Batch (prod) | CronJob |

W trybie `--single-run` worker wykonuje jeden cykl i kończy się:
- Exit 0 → OK (dane zebrane)
- Exit 1 → WARNING (dane częściowe)
- Exit 2 → CRITICAL (brak danych)

### Health endpoints (tryb K8s)

- `/healthz` — liveness probe (proces żyje)
- `/readyz` — readiness probe (Redis connectivity)

## Scheduler (per pulse)

Każdy pulse ma własny scheduler z własnym oknem czasowym.

Scheduler okresowo:
1. Pobiera listę assetów z grupy (oczekiwane — z CMDB)
2. Pobiera listę assetów z cache dla danego pulse (faktycznie widziane)
3. Porównuje: które assety nie pojawiły się w zdefiniowanym oknie czasowym
4. Generuje alert dla brakujących assetów

W produkcji (K8s) scheduler działa jako CronJob analogicznie do batch workera.

## Lokalizacja problemu

System precyzyjnie wskazuje, **gdzie** w potoku nastąpiła cisza:
- Asset nie pojawił się na Kafce → alert na pulse "Kafka"
- Asset pojawił się na Kafce, ale nie dotarł do Splunka → alert na pulse "Splunk"
