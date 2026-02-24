# MITRE ATT&CK Mapping

**Moduł:** `mitre` (opcjonalny)

Każda grupa assetów może mieć przypisane techniki MITRE ATT&CK, które dana grupa
pokrywa z perspektywy detekcji.

## Status modułu

Ten moduł jest **opcjonalny**. System SilentPulse działa poprawnie bez niego.

Gdy moduł jest wyłączony:
- Alerty nadal informują o ciszy i brakujących assetach
- Brak informacji o impakcie na pokrycie MITRE ATT&CK
- Brak widoków coverage heatmap
- Brak możliwości mapowania grup na techniki

Gdy moduł jest włączony:
- Pełna funkcjonalność mapowania MITRE
- Impakt MITRE w alertach
- Coverage dashboards
- Analiza impaktu kaskadowego

## Cel

Przełożenie technicznego faktu (cisza w telemetrii) na operacyjny impakt
bezpieczeństwa zrozumiały dla zespołów SOC, managementu i audytu.

## Mechanizm

Użytkownik przypisuje do grupy assetów techniki MITRE ATT&CK, które ta grupa
umożliwia wykrywać. Gdy scheduler wykryje brak zdarzeń z danej grupy,
system automatycznie komunikuje impakt:

- **co** — które techniki ataków przestały być wykrywalne
- **jak długo** — czas trwania przestoju (np. "3h bez widoczności")
- **zakres** — ile assetów z grupy nie raportowało

## Przykład

Grupa: "Kontrolery domeny AD"

Mapowane techniki:
- T1003 — OS Credential Dumping
- T1558 — Steal or Forge Kerberos Tickets
- T1078 — Valid Accounts

### Komunikat przy przestoju (moduł włączony)

"Przestój 3h na grupie 'AD Controllers EU'.
W tym czasie organizacja była ślepa na techniki: T1003, T1558, T1078.
Brak zdolności detekcji Credential Access i Lateral Movement."

### Komunikat przy przestoju (moduł wyłączony)

"Przestój 3h na grupie 'AD Controllers EU'.
15 assetów nie raportowało w oczekiwanym oknie czasowym.
Krytyczność grupy: HIGH."

## Źródło danych MITRE

System potrzebuje lokalnej bazy technik MITRE ATT&CK (taktyki, techniki, subtechniki)
do prezentowania użytkownikowi wyboru przy mapowaniu grup.

Baza jest dostarczana jako część modułu i aktualizowana przy upgradach.

## Model danych

### MitreTechnique

Dane referencyjne — lokalna kopia bazy MITRE ATT&CK.

| Pole           | Typ      | Opis                            |
|----------------|----------|---------------------------------|
| id             | UUID     | PK                              |
| technique_id   | VARCHAR  | Np. T1003, T1003.001            |
| name           | VARCHAR  | Np. "OS Credential Dumping"     |
| tactic         | VARCHAR  | Np. "Credential Access"         |
| description    | TEXT     |                                 |

### AssetGroupMitre (M:N)

Relacja między grupą assetów a technikami MITRE.

| Pole              | Typ     | Opis                   |
|--------------------|---------|------------------------|
| asset_group_id     | UUID    | FK → AssetGroup        |
| mitre_technique_id | UUID    | FK → MitreTechnique    |

**Uwaga:** Ta tabela istnieje tylko gdy moduł `mitre` jest włączony.

### Alert.mitre_techniques (opcjonalne)

Pole `mitre_techniques` w tabeli Alert jest nullable.
Wypełniane tylko gdy moduł `mitre` jest włączony.

```json
{
  "techniques": [
    {"id": "T1003", "name": "OS Credential Dumping", "tactic": "Credential Access"},
    {"id": "T1558", "name": "Steal or Forge Kerberos Tickets", "tactic": "Credential Access"}
  ]
}
```

## API

Endpointy dostępne tylko gdy moduł `mitre` jest włączony.
Zwracają 404 gdy moduł jest wyłączony.

### MITRE Data

```
GET    /api/v1/mitre/techniques            # Baza technik (do wyboru przy mapowaniu)
GET    /api/v1/mitre/tactics               # Lista taktyk
GET    /api/v1/mitre/coverage              # Pokrycie organizacji (graf)
```

### Asset Group MITRE Mapping

```
GET    /api/v1/asset-groups/:id/mitre      # Przypisane techniki MITRE
PUT    /api/v1/asset-groups/:id/mitre      # Aktualizuj mapowanie MITRE
```

### Impact Analysis

```
GET    /api/v1/impact/asset/:id            # Impakt ciszy na assecie (kaskadowo)
GET    /api/v1/impact/integration-point/:id # Impakt awarii punktu (cross-flow)
GET    /api/v1/impact/asset-group/:id      # Impakt ciszy na grupie
```

### Alert MITRE Impact

```
GET    /api/v1/alerts/:id/mitre-impact     # Pełny impakt MITRE alertu
```

### Dashboard

```
GET    /api/v1/dashboard/mitre-coverage    # Pokrycie MITRE (aktywne vs dotknięte)
```

### External Data API

```
GET    /api/v1/external/mitre-coverage     # Pokrycie MITRE ATT&CK
```

## UI

### Asset Group - MITRE Mapping

Widoczne tylko gdy moduł włączony:
- Panel "MITRE Coverage" w szczegółach grupy
- Multi-select technik MITRE przy tworzeniu/edycji grupy
- Wizualizacja pokrytych taktyk

### Alert - MITRE Impact

Widoczne tylko gdy moduł włączony:
- Sekcja "MITRE Impact" w szczegółach alertu
- Lista dotkniętych technik i taktyk
- Link do coverage dashboard

### Dashboard - MITRE Coverage

Widoczne tylko gdy moduł włączony:
- Heatmapa MITRE ATT&CK (taktyki × techniki)
- Kolory: zielony (pokryte), czerwony (dotknięte ciszą), szary (niemonitorowane)
- Drill-down do szczegółów techniki

### Topology Graph

Gdy moduł włączony:
- Węzły grup assetów pokazują przypisane techniki MITRE
- Kliknięcie na węzeł pokazuje impakt MITRE
- Kaskadowy impakt podświetla dotknięte techniki

Gdy moduł wyłączony:
- Węzły pokazują tylko nazwę grupy i liczbę assetów
- Brak informacji o MITRE

## Graf zależności (AGE)

Krawędź `(:AssetGroup)-[:COVERS]->(:MitreTechnique)` istnieje tylko gdy moduł włączony.

Zapytania grafowe działają bez modułu MITRE, ale zwracają mniej informacji:

```cypher
-- Z modułem MITRE
MATCH (g:AssetGroup)-[:COVERS]->(t:MitreTechnique)
RETURN g.name, collect(t.technique_id)

-- Bez modułu MITRE (zapytanie zwróci pusty wynik, ale nie błąd)
```

## Powiązania

- [modules.md](../modules.md) — System modułów
- [asset-groups.md](asset-groups.md) — Grupy assetów (core)
- [alerting.md](alerting.md) — Alerting (core, rozszerzony przez MITRE)
- [dashboards.md](dashboards.md) — Dashboardy (core, rozszerzony przez MITRE)
