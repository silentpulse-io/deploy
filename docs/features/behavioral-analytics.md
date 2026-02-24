# Behavioral Analytics

**Moduł:** `behavioral` (opcjonalny)

Funkcjonalność analizy behawioralnej obejmująca TimeTravel, Profiling,
automatyczne sugestie progów alertowania oraz wykrywanie anomalii.

## Status modułu

Ten moduł jest **opcjonalny**. System SilentPulse działa poprawnie bez niego.

Gdy moduł jest wyłączony:
- Alerty nadal informują o ciszy i brakujących assetach
- Brak historii zachowania assetów (TimeTravel)
- Brak profilowania i wykrywania anomalii
- Brak automatycznych sugestii progów

Gdy moduł jest włączony:
- Pełna funkcjonalność TimeTravel, Profiling, Anomaly Detection
- Automatyczne sugestie progów alertowania
- Eksport danych historycznych dla audytorów

## Cel

Każdy asset i feed może mieć inną charakterystykę — różne częstotliwości
wysyłania danych, sezonowość (dzień/noc, dni robocze/weekendy), zależność
od obciążenia. Sztywne progi (np. "alert po 5 minutach ciszy") nie sprawdzają
się uniwersalnie.

Behavioral Analytics pozwala na:
- Śledzenie historii zachowania feedów i assetów (TimeTravel)
- Uczenie się wzorców zachowania (Profiling)
- Automatyczne sugestie optymalnych progów alertowania
- Wykrywanie anomalii w zachowaniu
- Eksport danych historycznych dla audytorów

## Komponenty

### 1. TimeTravel

Wizualizacja historii zachowania assetu/feeda na osi czasu.

**Funkcje:**
- Oś czasu pokazująca:
  - Kiedy asset był widziany w każdym punkcie flow
  - Okresy ciszy (gaps)
  - Alerty (open/resolved)
  - Anomalie
- Zoom in/out (godziny → dni → tygodnie → miesiące)
- Możliwość porównania wielu assetów/feedów
- Nakładki:
  - Oczekiwany wzorzec (baseline z profilu)
  - Rzeczywiste obserwacje
  - Odchylenia od baseline

**Eksport dla audytora:**
- Format: PDF, CSV, JSON
- Zawartość:
  - Pełna historia obserwacji w wybranym okresie
  - Wszystkie alerty z czasem trwania
  - Wykryte anomalie z klasyfikacją
  - Statystyki: uptime, średni czas między obserwacjami, odchylenia
  - Porównanie z baseline (jeśli istnieje profil)
- Możliwość adnotacji audytora przed eksportem

### 2. Profiling

System uczący się charakterystyki zachowania feedów i assetów.

**Typy profili:**

1. **Feed Profile** (per FlowPulse + AssetGroup)
   - Profil zagregowany dla całej grupy assetów w danym punkcie flow
   - Metryki:
     - Oczekiwana liczba unikalnych assetów per interwał
     - Typowa częstotliwość obserwacji
     - Wzorce sezonowe (dzień/noc, dni tygodnia)

2. **Asset Profile** (per Asset + FlowPulse)
   - Indywidualny profil dla konkretnego assetu
   - Metryki:
     - Typowy interwał między obserwacjami
     - Wzorce aktywności (np. serwer batch = aktywny tylko w nocy)
     - Oczekiwany rozmiar/wolumen danych (opcjonalnie)

**Fazy profilingu:**

1. **Learning Phase** (domyślnie 7 dni, konfigurowalne)
   - System zbiera dane bez generowania alertów opartych na profilu
   - Buduje baseline zachowania
   - Operator widzi status: "Profiling in progress (3/7 days)"

2. **Active Phase**
   - Profil jest aktywny
   - System porównuje bieżące zachowanie z baseline
   - Generuje anomalie przy odchyleniach

3. **Continuous Learning**
   - Profil jest ciągle aktualizowany (sliding window)
   - Adaptuje się do zmian w zachowaniu
   - Nagłe zmiany flagowane jako anomalie do weryfikacji

**Konfiguracja profilingu:**

```json
{
  "learning_period_days": 7,
  "sliding_window_days": 30,
  "seasonality_detection": true,
  "weekday_weekend_split": true,
  "business_hours": {
    "start": "08:00",
    "end": "18:00",
    "timezone": "Europe/Warsaw"
  },
  "sensitivity": "medium"
}
```

### 3. Threshold Suggestions

System sugerujący optymalne progi alertowania na podstawie profilu.

**Typy sugestii:**

1. **Time Window Suggestion**
   - "Asset X wysyła dane średnio co 15 minut. Sugerowany próg: 45 minut (3x średnia)"
   - Uwzględnia odchylenie standardowe i percentyle (p95, p99)

2. **Volume Suggestion**
   - "W grupie Y zwykle widzisz 450-520 assetów. Sugerowany próg: <400"

3. **Seasonality-Aware Suggestion**
   - "W nocy (22:00-06:00) asset Z jest nieaktywny. Sugeruj wyłączenie alertów w tym oknie"
   - "W weekendy ruch spada o 70%. Sugerowany próg dla weekendu: 2h (vs 30min w tygodniu)"

**Workflow sugestii:**

1. System generuje sugestię automatycznie po zakończeniu learning phase
2. Operator widzi sugestię w UI z uzasadnieniem
3. Operator może:
   - Zaakceptować sugestię (threshold zostaje ustawiony)
   - Odrzucić sugestię (pozostaje stary threshold)
   - Zmodyfikować sugestię (operator wie lepiej)
4. System uczy się z decyzji operatora

**Priorytet sugestii:**
- `high` - duże odchylenie od aktualnego thresholdu, potencjalnie dużo false positives/negatives
- `medium` - umiarkowana optymalizacja
- `low` - drobna korekta

### 4. Anomaly Detection

Automatyczne wykrywanie nietypowych zachowań.

**Typy anomalii:**

1. **Silence Anomaly**
   - Asset/feed przestaje wysyłać dane w nietypowym momencie
   - Np. "Asset X zwykle aktywny o 14:00 — brak danych od 2h"

2. **Volume Anomaly**
   - Nietypowa liczba assetów w grupie
   - Np. "Grupa Y: oczekiwane 500 assetów, widzimy 150 — spadek 70%"

3. **Pattern Anomaly**
   - Zmiana wzorca zachowania
   - Np. "Asset Z zmienił częstotliwość z 5min na 30min"

4. **Burst Anomaly**
   - Nagły wzrost aktywności (może wskazywać na atak lub błąd)
   - Np. "Serwer wysyła 10x więcej logów niż zwykle"

5. **Drift Anomaly**
   - Stopniowa zmiana charakterystyki (nie nagła)
   - Np. "Przez ostatnie 2 tygodnie średni interwał wzrósł z 5min do 15min"

**Severity anomalii:**
- `critical` - natychmiastowa uwaga (np. całkowita cisza krytycznego assetu)
- `warning` - znaczące odchylenie, wymaga zbadania
- `info` - zauważone odchylenie, prawdopodobnie normalne

**Reakcja na anomalie:**
- Anomalie są osobnym typem zdarzeń (nie są alertami)
- Mogą być powiązane z alertem (anomalia → alert)
- Operator może:
  - Oznaczyć jako "expected" (np. planowany maintenance)
  - Oznaczyć jako "investigated" z notatką
  - Zignorować (wpływa na przyszłe uczenie)

### 5. Observation History Storage

Przechowywanie historii obserwacji dla TimeTravel i Profiling.

**Strategia przechowywania:**

1. **Hot Storage** (Redis) - ostatnie 7 dni
   - Pełna rozdzielczość (każda obserwacja)
   - Szybki dostęp dla real-time dashboardów

2. **Warm Storage** (PostgreSQL + TimescaleDB extension) - ostatnie 90 dni
   - Pełna rozdzielczość
   - Używane przez TimeTravel i Profiling

3. **Cold Storage** (PostgreSQL) - powyżej 90 dni
   - Agregacje (hourly, daily)
   - Dla długoterminowych trendów i audytu

**Retencja:**
- Raw observations: 90 dni (konfigurowalne)
- Hourly aggregations: 1 rok
- Daily aggregations: 3 lata (lub zgodnie z polityką retention)

## Model danych

### Nowe encje

Zobacz [data-model.md](../data-model.md) dla pełnej specyfikacji.

Kluczowe encje:
- `AssetObservation` - pojedyncza obserwacja assetu w punkcie flow
- `FeedProfile` - profil zachowania feeda (per FlowPulse)
- `AssetProfile` - profil zachowania assetu (per Asset + FlowPulse)
- `ThresholdSuggestion` - sugestia progu od systemu
- `AnomalyEvent` - wykryta anomalia

## API

### TimeTravel

```
GET /api/v1/timetravel/asset/:id
    ?flow_pulse_id=...      # opcjonalnie, konkretny punkt
    &from=2024-01-01T00:00Z
    &to=2024-01-31T23:59Z
    &resolution=auto        # auto, minute, hour, day

GET /api/v1/timetravel/asset/:id/export
    ?format=pdf|csv|json
    &from=...
    &to=...
    &include_alerts=true
    &include_anomalies=true
    &include_baseline=true

GET /api/v1/timetravel/flow-pulse/:id
    ?from=...
    &to=...
    &resolution=auto
```

### Profiling

```
GET  /api/v1/profiles/feed/:flow_pulse_id       # Profil feeda
GET  /api/v1/profiles/asset/:asset_id           # Profile assetu (wszystkie flow pulses)
GET  /api/v1/profiles/asset/:asset_id/:flow_pulse_id  # Profil assetu w konkretnym punkcie

POST /api/v1/profiles/feed/:flow_pulse_id/reset    # Reset profilu (restart learning)
POST /api/v1/profiles/asset/:asset_id/reset

PUT  /api/v1/profiles/feed/:flow_pulse_id/config   # Konfiguracja profilingu
PUT  /api/v1/profiles/asset/:asset_id/config
```

### Threshold Suggestions

```
GET  /api/v1/suggestions                        # Lista aktywnych sugestii
GET  /api/v1/suggestions/:id                    # Szczegóły sugestii

POST /api/v1/suggestions/:id/accept             # Zaakceptuj sugestię
POST /api/v1/suggestions/:id/reject             # Odrzuć sugestię
POST /api/v1/suggestions/:id/modify             # Modyfikuj i zastosuj
     Body: { "modified_value": "45m" }
```

### Anomalies

```
GET  /api/v1/anomalies                          # Lista anomalii (filtry, paginacja)
     ?severity=critical,warning
     &type=silence,volume,pattern
     &from=...
     &to=...

GET  /api/v1/anomalies/:id                      # Szczegóły anomalii

POST /api/v1/anomalies/:id/acknowledge          # Potwierdź anomalię
     Body: { "status": "expected|investigated|ignored", "note": "..." }
```

### Auditor extensions

```
GET  /api/v1/auditor/timetravel/asset/:id       # TimeTravel w zakresie audytu
GET  /api/v1/auditor/timetravel/export          # Eksport dla audytora
GET  /api/v1/auditor/anomalies                  # Anomalie w zakresie audytu
GET  /api/v1/auditor/profiles                   # Profile w zakresie audytu
```

## UI/UX

### TimeTravel View

```
+------------------------------------------------------------------+
|  Asset: srv-prod-01                    [Flow: EDR Pipeline v]    |
+------------------------------------------------------------------+
|  Period: [2024-01-01] to [2024-01-31]    Resolution: [Auto v]    |
+------------------------------------------------------------------+
|                                                                   |
|  Timeline:                                                        |
|  |----|----|----|----|----|----|----|----|----|----|             |
|  Jan 1    5    10   15   20   25   30                            |
|                                                                   |
|  [===][===][===][ GAP ][===][===][=!!!=][===][===]               |
|                    ^              ^                               |
|                    |              |                               |
|               3h silence     Anomaly: pattern change              |
|                                                                   |
|  Legend: [===] Observed  [ GAP ] Silence  [!!!] Alert/Anomaly    |
|                                                                   |
|  -------- Baseline (expected)                                     |
|  ======== Actual observations                                     |
|                                                                   |
+------------------------------------------------------------------+
|  Stats:                                                           |
|  - Uptime: 94.3%                                                 |
|  - Avg interval: 12m 34s                                         |
|  - Alerts: 2 (total 4h 12m downtime)                             |
|  - Anomalies: 3 (1 critical, 2 warning)                          |
+------------------------------------------------------------------+
|  [Export PDF]  [Export CSV]  [Compare with...]                   |
+------------------------------------------------------------------+
```

### Profile Dashboard

```
+------------------------------------------------------------------+
|  Flow Point: Splunk Ingest                                        |
+------------------------------------------------------------------+
|  Status: [ACTIVE] Learning complete (7/7 days)                   |
+------------------------------------------------------------------+
|                                                                   |
|  Feed Profile:                                                    |
|  - Expected assets: 487 (± 23)                                   |
|  - Observation frequency: every 5m                                |
|  - Seasonality: Weekday/Weekend split detected                   |
|                                                                   |
|  Weekly Pattern:                                                  |
|  Mon |████████████████████| 520                                  |
|  Tue |███████████████████ | 498                                  |
|  Wed |████████████████████| 515                                  |
|  Thu |███████████████████ | 503                                  |
|  Fri |██████████████████  | 478                                  |
|  Sat |██████████          | 234                                  |
|  Sun |█████████           | 201                                  |
|                                                                   |
+------------------------------------------------------------------+
|  Threshold Suggestions:                                           |
|  ⚠ [HIGH] Current threshold (5m) may cause false positives       |
|     Suggested: 15m (based on p95 interval)                       |
|     [Accept] [Modify] [Dismiss]                                  |
|                                                                   |
|  ℹ [LOW] Weekend threshold could be relaxed                       |
|     Suggested: 30m for Sat-Sun                                   |
|     [Accept] [Modify] [Dismiss]                                  |
+------------------------------------------------------------------+
```

## Powiązania

- [modules.md](../modules.md) — System modułów
- [flows.md](flows.md) — Flow i FlowPulse, do których odnosi się profiling
- [alerting.md](alerting.md) — Alerty generowane na podstawie thresholdów
- [data-retention.md](data-retention.md) — Polityka retencji observation history
- [reporting.md](reporting.md) — Raporty behawioralne dla audytorów
