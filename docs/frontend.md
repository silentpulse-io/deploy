# Frontend

## Filozofia UI

Interfejs SilentPulse musi natychmiast komunikować stan widoczności bezpieczeństwa.
Użytkownik otwiera aplikację i w ciągu sekund rozumie: co działa, co milczy,
jaki jest impakt. Bez szukania, bez klikania przez menu.

Inspiracja: Darktrace — ciemny interfejs, dynamiczne wizualizacje,
poczucie monitorowania w real-time.

## Moduły

Frontend dostosowuje się do włączonych modułów. Przy inicjalizacji pobiera
informację o aktywnych modułach i renderuje tylko odpowiednie komponenty.

```typescript
// GET /api/v1/modules
interface ModulesState {
  mitre: boolean;      // Moduł MITRE ATT&CK
  behavioral: boolean; // Moduł Behavioral Analytics
  aiAssistant: boolean; // Moduł AI Assistant
}
```

Komponenty UI renderują się warunkowo:
```tsx
{modules.mitre && <MitreCoveragePanel />}
{modules.behavioral && <TimeTravelView />}
{modules.aiAssistant && <AIAssistantPanel />}
```

## Tech Stack

| Komponent          | Technologia                          |
|--------------------|--------------------------------------|
| Framework          | React + Next.js (App Router)         |
| Język              | TypeScript                           |
| Styling            | Tailwind CSS                         |
| Komponenty UI      | shadcn/ui (Radix UI)                 |
| Grafy / topologia  | Cytoscape.js lub React Flow          |
| Wykresy / metryki  | Apache ECharts                       |
| Real-time          | WebSocket                            |
| State management   | Zustand                              |
| Auth               | JWT (Bearer token)                   |

Uzasadnienie:
- Next.js — SSR, routing, API routes, enterprise-grade
- shadcn/ui — nowoczesne, customizowalne, dark theme natywnie
- Cytoscape.js — silnik do grafów sieciowych (topologia assetów, flow, MITRE impact)
- ECharts — rozbudowane wykresy dashboardowe (trendy, pokrycie, timeline)
- WebSocket — live updates alertów, statusu workerów, zmian w flow

## Design System

### Motyw

- **Dark theme** domyślnie (ciemne tło, jasne akcenty)
- Paleta kolorów security-oriented:
  - Zielony: healthy, OK, covered
  - Amber/żółty: warning, partial, degraded
  - Czerwony: critical, silent, uncovered
  - Niebieski: informacyjny, neutral
  - Szary: inactive, disabled
- Subtelne animacje glow/pulse na elementach wymagających uwagi
- Typografia: monospace dla identyfikatorów i kodów, sans-serif dla treści

### Logo

Motyw "pulsu" — linia pulsu (heartbeat line) z elementem nasłuchu.
Koncepcja: linia EKG, która w pewnym momencie przechodzi w ciszę (flat line),
symbolizując moment utraty widoczności. Puls = widoczność, cisza = zagrożenie.

```
    ╱╲      ╱╲
───╱  ╲────╱  ╲───────────── ← cisza (silent)
```

## Widoki per rola

### Admin

**Dashboard główny:**
- Status komponentów systemu (Health Service) — zielone/czerwone karty
- Status workerów i schedulerów per flow
- Circuit breaker states per Integration Point
- Metryki Prometheus (uptime, latency, error rate)
- Aktywne alerty systemowe

**Zarządzanie:**
- CRUD użytkowników
- Konfiguracja CMDB Sync
- Audit tasks management
- Data retention settings
- Notification channels i rules
- API keys

### Analyst

**Dashboard główny (core):**
- Mapa widoczności — graf pokazujący flow, punkty, status (green/amber/red)
- Strefy ciszy — lista grup assetów z aktywną ciszą, posortowana po krytyczności
- Timeline alertów — live feed nowych alertów

**Dashboard główny (moduł mitre):**
- Pokrycie MITRE ATT&CK — heatmapa technik (covered vs exposed)
- Strefy ciszy sortowane po impakcie MITRE

**Widok grafu (centralny) — core:**
- Topologia: Asset Groups → Flow → Integration Points
- Zależności assetów (HOSTS, RUNS, DEPENDS_ON)
- Kliknięcie na węzeł → drill-down do szczegółów
- Kliknięcie na czerwony węzeł → kaskadowy impakt (podświetlenie zależnych)
- Real-time: zmiana koloru węzła gdy alert się pojawi/zniknie

**Widok grafu (moduł mitre):**
- Węzły pokazują przypisane techniki MITRE
- Impakt MITRE przy drill-down

**Widok Flow — core:**
- Wizualizacja ścieżki: punkt 1 → punkt 2 → punkt 3
- Status per punkt (OK/WARNING/CRITICAL)
- Lista assetów brakujących w oknie

**Widok Flow (moduł mitre):**
- Impakt MITRE dla tego flow

**Widok MITRE ATT&CK — moduł mitre (opcjonalny):**
- Matryca MITRE (tactics × techniques)
- Kolory: zielony (pokryte), czerwony (dotknięte ciszą), szary (niemonitorowane)
- Kliknięcie na technikę → które grupy assetów ją pokrywają, czy jest aktywna cisza

### Viewer

Okrojona wersja widoku Analyst:
- Dashboard z grafem i strefami ciszy (read-only)
- Pokrycie MITRE
- Lista alertów
- Brak CRUD, brak konfiguracji

### Auditor

**Widok "Time Machine":**
- Timeline na dole ekranu (slider) — audytor przesuwa suwak i widzi stan
  widoczności w dowolnym momencie okresu audytu
- Play/pause — animacja zmian w czasie (timelapse)
- Stan grafu zmienia się z czasem — widać kiedy węzły gasną i zapalają się
- Kliknięcie na moment ciszy → szczegóły: które assety, jak długo, impakt MITRE

**Dashboard audytowy:**
- Podsumowanie: łączny czas ciszy, % czasu z pełną widocznością
- Top 10 najdłuższych przestojów w okresie
- Pokrycie MITRE w czasie (trend)
- Eksport raportu PDF/CSV

**Zakres:** Wszystko filtrowane przez scope audit taska — audytor widzi
tylko dane z przypisanych regionów/grup w zdefiniowanym okresie.

---

## Behavioral Analytics Views — moduł `behavioral` (opcjonalny)

Widoki wspierające TimeTravel, Profiling i Anomaly Detection.
Dostępne dla ról: Analyst, Viewer (read-only), Auditor (scoped).

**Uwaga:** Te widoki są dostępne tylko gdy moduł `behavioral` jest włączony.
Menu i nawigacja ukrywają te pozycje gdy moduł jest wyłączony.

### TimeTravel (rozszerzony)

**Widok pojedynczego assetu:**
```
┌─────────────────────────────────────────────────────────────────┐
│  Asset: srv-prod-01                     [Flow: EDR Pipeline ▼]  │
├─────────────────────────────────────────────────────────────────┤
│  Period: [2024-01-01] ─ [2024-01-31]     Resolution: [Auto ▼]   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ──── Expected (baseline)                                        │
│  ████ Observed                                                   │
│  ░░░░ Gap (silence)                                             │
│  ⚠    Alert                                                      │
│  ◆    Anomaly                                                    │
│                                                                  │
│  Jan 1        5        10       15       20       25       30   │
│  ├────────────┼─────────┼────────┼────────┼────────┼────────┤   │
│  │████████████│█████░░░░│████████│████████│███⚠░░░░│████████│   │
│  │            │     ◆   │        │    ◆   │        │        │   │
│  └────────────┴─────────┴────────┴────────┴────────┴────────┘   │
│                     │               │                            │
│                Pattern anomaly   Volume anomaly                  │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  Summary                                                         │
│  ────────────────────────────────────────────────────────────   │
│  Uptime: 94.3%  │  Avg interval: 12m 34s  │  Alerts: 2          │
│  Anomalies: 3 (1 warning, 2 info)  │  Total silence: 4h 12m     │
├─────────────────────────────────────────────────────────────────┤
│  [📥 Export PDF]  [📊 Export CSV]  [🔍 Compare with...]          │
└─────────────────────────────────────────────────────────────────┘
```

**Funkcje:**
- Zoom in/out: godziny → dni → tygodnie → miesiące
- Hover na segmencie → szczegółowy tooltip (dokładne czasy, statystyki)
- Klik na anomalię/alert → panel szczegółów z prawej strony
- Porównanie wielu assetów na jednym wykresie (overlay lub multi-lane)

### Profile Dashboard

**Widok profilu feedu (FlowPoint):**
```
┌─────────────────────────────────────────────────────────────────┐
│  Flow Point: Splunk Ingest (EDR Pipeline)                       │
├─────────────────────────────────────────────────────────────────┤
│  Status: [● ACTIVE]  Learning complete (7/7 days)               │
│                                                                  │
│  ┌─────────────────────────────────┬────────────────────────┐   │
│  │  Feed Profile                   │  Configuration         │   │
│  ├─────────────────────────────────┼────────────────────────┤   │
│  │  Expected assets: 487 (±23)     │  Learning: 7 days      │   │
│  │  Observation freq: every 5m     │  Window: 30 days       │   │
│  │  Seasonality: YES               │  Sensitivity: Medium   │   │
│  │  Business hours factor: 1.3x    │  [Edit Config]         │   │
│  └─────────────────────────────────┴────────────────────────┘   │
│                                                                  │
│  Weekly Pattern                                                  │
│  ───────────────────────────────────────────────────────────    │
│  Mon │████████████████████████████████████████│ 520 assets      │
│  Tue │███████████████████████████████████████ │ 498              │
│  Wed │████████████████████████████████████████│ 515              │
│  Thu │███████████████████████████████████████ │ 503              │
│  Fri │██████████████████████████████████████  │ 478              │
│  Sat │████████████████████                    │ 234  ← weekend  │
│  Sun │███████████████████                     │ 201              │
│                                                                  │
│  Hourly Pattern (Today)                                         │
│  ───────────────────────────────────────────────────────────    │
│       ▁▂▃▅▇██████████████████▇▅▃▂▁▁▁▁                           │
│      0  4  8  12  16  20  24                                    │
│           └── business hours ──┘                                │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  ⚠ Threshold Suggestions                                   (2)  │
│  ───────────────────────────────────────────────────────────    │
│  [HIGH] Time window 5m → 15m (p95-based, reduce FP 73%)         │
│         [✓ Accept] [✎ Modify] [✗ Dismiss]                       │
│                                                                  │
│  [LOW]  Weekend threshold: 5m → 30m (activity drop 55%)         │
│         [✓ Accept] [✎ Modify] [✗ Dismiss]                       │
└─────────────────────────────────────────────────────────────────┘
```

### Anomalies View

**Lista anomalii z filtrowaniem:**
```
┌─────────────────────────────────────────────────────────────────┐
│  Anomalies                                          [Filters ▼] │
├─────────────────────────────────────────────────────────────────┤
│  Severity: [All ▼]  Type: [All ▼]  Status: [Open ▼]  Period: 7d │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ● CRITICAL  Volume Anomaly              Today 14:32            │
│    Flow: EDR Pipeline → Splunk Ingest                           │
│    Expected: ~500 assets, Actual: 152 (-70%)                    │
│    [Investigate]                                                │
│                                                                  │
│  ◐ WARNING   Pattern Anomaly             Yesterday 03:15        │
│    Asset: srv-batch-01                                          │
│    Interval changed: 5m → 45m (sustained 6h)                    │
│    [Mark Expected]  [Investigate]                               │
│                                                                  │
│  ○ INFO      Drift Anomaly               3 days ago             │
│    Flow: Firewall Logs → Kafka                                  │
│    Gradual volume decline: 1200 → 890 events/h over 2 weeks     │
│    [Acknowledge]                                                │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  Stats: 12 total  │  3 critical  │  5 warning  │  4 info        │
└─────────────────────────────────────────────────────────────────┘
```

### Suggestions Manager

**Panel zarządzania sugestiami progów:**
```
┌─────────────────────────────────────────────────────────────────┐
│  Threshold Suggestions                              Pending: 8  │
├─────────────────────────────────────────────────────────────────┤
│  Priority: [High first ▼]                                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ████ HIGH PRIORITY (3)                                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  EDR Pipeline → Splunk Ingest                           │    │
│  │  Current: 5m  →  Suggested: 15m                         │    │
│  │  Reason: Current threshold below p50 interval (12m)     │    │
│  │  Impact: Est. 73% FP reduction                          │    │
│  │  Confidence: 92%                                        │    │
│  │                                                         │    │
│  │  [✓ Accept]  [✎ Modify: ___]  [✗ Reject]               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ▒▒▒▒ MEDIUM PRIORITY (3)                                       │
│  ░░░░ LOW PRIORITY (2)                                          │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  History: [View past decisions]                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Real-time

WebSocket connection per sesję użytkownika:

```
Server → Client events (Core):
  alert:created      — nowy alert (aktualizacja grafu, badge, feed)
  alert:resolved     — alert zamknięty (zmiana koloru węzła)
  worker:status      — zmiana statusu workera (OK → CRITICAL)
  flow:status        — zmiana statusu flow
  system:health      — zmiana stanu komponentu (admin)

# Moduł behavioral (opcjonalny)
  anomaly:detected   — nowa anomalia (aktualizacja listy, badge)
  anomaly:resolved   — anomalia zamknięta/acknowledged
  profile:updated    — profil zakończył learning lub zaktualizował baseline
  suggestion:new     — nowa sugestia progu (badge w menu)
  suggestion:applied — sugestia została zaakceptowana/zmodyfikowana
```

Events modułowe są wysyłane tylko gdy odpowiedni moduł jest włączony.
Frontend ignoruje eventy dla wyłączonych modułów.

Fallback: polling co 30s jeśli WebSocket niedostępny.

## Responsywność

- Desktop-first (monitoring tool, używany na dużych ekranach)
- Responsywny do tabletu (SOC na tablecie)
- Mobile: widok alertów i statusu (uproszczony), bez pełnych grafów

## Accessibility

- WCAG 2.1 AA
- Kolory dobrze rozróżnialne przy color blindness (nie tylko red/green — dodatkowe ikony)
- Keyboard navigation
- Screen reader support dla kluczowych danych
