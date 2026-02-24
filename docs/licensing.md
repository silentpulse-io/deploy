# Model licencyjny

Definicja modelu licencyjnego i tierów SilentPulse.

## Moduły i licencje

SilentPulse używa systemu modułów. Dostępność modułów zależy od tieru licencji.

| Moduł        | Community | Professional | Enterprise |
|--------------|-----------|--------------|------------|
| core         | ✓         | ✓            | ✓          |
| mitre        | ✓         | ✓            | ✓          |
| behavioral   | -         | ✓            | ✓          |
| ai-assistant | -         | -            | ✓          |

Szczegóły systemu modułów: [modules.md](modules.md)

## Tiers

### Community (Open Source)

**Moduły:** core, mitre

**Funkcjonalności:**
- Podstawowe flow i Integration Points
- Ograniczona liczba assetów (do 500)
- Ograniczona liczba flow (do 5)
- Podstawowe dashboardy
- Mapowanie MITRE ATT&CK
- Podstawowe alerty i powiadomienia
- Community support

**Ograniczenia:**
- Brak TimeTravel i Behavioral Analytics
- Brak AI Assistant
- Brak multi-tenancy
- Brak zaawansowanych raportów

### Professional

**Moduły:** core, mitre, behavioral

**Funkcjonalności:**
- Nieograniczona liczba assetów
- Nieograniczona liczba flow
- TimeTravel i historia zachowania
- Behavioral profiling i anomaly detection
- Automatyczne sugestie progów
- Zaawansowane dashboardy i raporty
- RBAC z pełnym podziałem ról
- Standard support (email, 48h SLA)

**Ograniczenia:**
- Brak AI Assistant
- Brak multi-tenancy
- Brak dedykowanego support

### Enterprise

**Moduły:** core, mitre, behavioral, ai-assistant

**Funkcjonalności:**
- Wszystko z Professional
- AI Assistant do analizy i rekomendacji
- Multi-tenancy
- Zaawansowane raporty audytowe
- Integracja z SOAR / ticketing
- Dedykowany support (24/7, 4h SLA)
- Custom integrations
- On-premise deployment option

## Metryki licencyjne

Model licencyjny oparty na:

| Metryka                    | Community | Professional | Enterprise |
|----------------------------|-----------|--------------|------------|
| Liczba assetów             | ≤500      | Unlimited    | Unlimited  |
| Liczba flow                | ≤5        | Unlimited    | Unlimited  |
| Liczba Integration Points  | ≤10       | Unlimited    | Unlimited  |
| Liczba użytkowników        | ≤5        | Per-seat     | Unlimited  |
| Retention (dni)            | 30        | 90           | Custom     |
| Tenants                    | 1         | 1            | Unlimited  |

## Egzekwowanie licencji

Licencja jest egzekwowana na poziomie:

1. **Deployment** — moduły niedostępne w tierze są wyłączone
2. **API** — limity per endpoint (liczba assetów, flow itd.)
3. **Tenant** — sprawdzenie limitu przy tworzeniu nowych zasobów

Przekroczenie limitów:
- Soft limit: warning w UI i logach
- Hard limit: operacja zablokowana z komunikatem o upgrade

## Aktywacja licencji

```
POST /api/v1/license/activate
Body: { "license_key": "..." }
```

Response:
```json
{
  "tier": "professional",
  "modules": ["core", "mitre", "behavioral"],
  "limits": {
    "assets": -1,
    "flows": -1,
    "users": 50
  },
  "expires_at": "2027-01-31T00:00:00Z"
}
```
