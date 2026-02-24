# Modules

SilentPulse jest systemem modularnym. Funkcjonalności podzielone są na moduły,
które mogą być włączane i wyłączane niezależnie od siebie.

## Architektura modułów

### Core (wymagany)

Podstawowa funkcjonalność monitorowania widoczności bezpieczeństwa.
Zawsze włączony, stanowi fundament systemu.

**Komponenty:**
- CMDB Sync — synchronizacja assetów
- Asset Groups — filtrowane grupy assetów (bez mapowania MITRE)
- Integration Points — punkty połączenia z zewnętrznymi systemami
- Flows — definicje ścieżek przepływu danych
- Workers — pobieranie danych z zewnętrznych systemów
- Schedulers — porównywanie oczekiwanych vs obserwowanych assetów
- Alerts — generowanie alertów o ciszy/degradacji
- Notifications — wysyłanie powiadomień
- Dashboards — podstawowe widoki stanu widoczności

**Alerty w Core:**
- Które assety nie raportowały
- W którym punkcie flow nastąpiła cisza
- Jak długo trwa przestój
- Liczba dotkniętych assetów
- Krytyczność grupy assetów (rating)

### Moduły opcjonalne

| Moduł              | Opis                                         | Zależności |
|--------------------|----------------------------------------------|------------|
| mitre              | Mapowanie MITRE ATT&CK i analiza impaktu     | core       |
| behavioral         | TimeTravel, Profiling, Anomaly Detection     | core       |
| ai-assistant       | Asystent AI do analizy i rekomendacji        | core       |

## Konfiguracja modułów

Moduły są konfigurowane na poziomie deploymentu (environment variables)
oraz per tenant (ustawienia w bazie danych).

### Deployment-level

```yaml
# docker-compose.yml / k8s ConfigMap
SILENTPULSE_MODULES_ENABLED: "core,mitre,behavioral"
```

### Tenant-level

```json
// Tenant settings
{
  "modules": {
    "mitre": {
      "enabled": true
    },
    "behavioral": {
      "enabled": true,
      "config": {
        "learning_period_days": 7
      }
    }
  }
}
```

**Zasady:**
- Moduł musi być włączony na poziomie deploymentu, żeby mógł być włączony per tenant
- Tenant może wyłączyć moduł włączony globalnie, ale nie może włączyć wyłączonego globalnie
- Licencja może ograniczać dostępne moduły

## API modułów

### Sprawdzenie dostępnych modułów

```
GET /api/v1/modules
```

Response:
```json
{
  "data": {
    "available": ["core", "mitre", "behavioral"],
    "enabled": ["core", "mitre"],
    "disabled": ["behavioral"]
  }
}
```

### Feature flags w API

Endpointy modułowe zwracają 404 gdy moduł jest wyłączony:

```
GET /api/v1/mitre/coverage
→ 404 {"error": "Module 'mitre' is not enabled"}
```

### Conditional responses

Endpointy core'owe uwzględniają włączone moduły w odpowiedziach:

```
GET /api/v1/alerts/:id
```

Response gdy MITRE włączone:
```json
{
  "data": {
    "id": "...",
    "flow_pulse_id": "...",
    "asset_id": "...",
    "started_at": "...",
    "mitre_impact": {
      "techniques": ["T1003", "T1558"],
      "tactics": ["Credential Access"]
    }
  }
}
```

Response gdy MITRE wyłączone:
```json
{
  "data": {
    "id": "...",
    "flow_pulse_id": "...",
    "asset_id": "...",
    "started_at": "..."
  }
}
```

## UI modułów

### Conditional rendering

Frontend otrzymuje informację o włączonych modułach przy inicjalizacji:

```typescript
// GET /api/v1/modules
interface ModulesState {
  mitre: boolean;
  behavioral: boolean;
  aiAssistant: boolean;
}
```

Komponenty UI renderują się warunkowo:

```tsx
{modules.mitre && <MitreCoveragePanel />}
{modules.behavioral && <TimeTravelView />}
```

### Menu i nawigacja

Pozycje menu związane z modułami są ukrywane gdy moduł nieaktywny:
- MITRE Coverage (moduł mitre)
- TimeTravel (moduł behavioral)
- Anomalies (moduł behavioral)
- AI Assistant (moduł ai-assistant)

## Migracja danych

### Włączenie modułu

Gdy moduł jest włączany:
1. Migracje bazy danych są uruchamiane automatycznie (jeśli potrzebne)
2. Dane historyczne mogą wymagać backfill (np. learning phase dla behavioral)
3. UI odświeża się i pokazuje nowe funkcjonalności

### Wyłączenie modułu

Gdy moduł jest wyłączany:
1. Dane modułu pozostają w bazie (nie są usuwane)
2. Endpointy modułowe zwracają 404
3. UI ukrywa komponenty modułowe
4. Schedulery/workery modułowe są zatrzymywane

## Zależności między modułami

```
core ←── mitre
     ←── behavioral
     ←── ai-assistant ←── (może korzystać z mitre i behavioral jeśli włączone)
```

- `mitre` wymaga tylko `core`
- `behavioral` wymaga tylko `core`
- `ai-assistant` wymaga `core`, opcjonalnie korzysta z `mitre` i `behavioral`

## Licencjonowanie

Moduły mogą być objęte różnymi poziomami licencji:

| Moduł      | Community | Professional | Enterprise |
|------------|-----------|--------------|------------|
| core       | ✓         | ✓            | ✓          |
| mitre      | ✓         | ✓            | ✓          |
| behavioral | -         | ✓            | ✓          |
| ai-assistant | -       | -            | ✓          |

Szczegóły: [licensing.md](licensing.md)
