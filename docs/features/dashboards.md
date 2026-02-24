# Dashboards

Wizualna warstwa prezentacji stanu widoczności bezpieczeństwa.

## Cel

Przedstawienie stanu widoczności organizacji w formie graficznej:
- Które flow działają prawidłowo
- Gdzie występują przestoje i jak długo trwają
- Trendy widoczności w czasie

### Moduł mitre (opcjonalny)

Gdy moduł `mitre` jest włączony:
- Jaki jest impakt na pokrycie MITRE ATT&CK
- Które techniki są aktualnie dotknięte
- Heatmapa pokrycia MITRE

## Odbiorcy

- **SOC** — operacyjny widok bieżących alertów i przestojów
- **Management** — zagregowany widok stanu widoczności
- **Audyt** — historyczne dane o przestojach i ich impakcie

## Widoki

### Overview Dashboard (Core)

Główny widok stanu widoczności.

**Komponenty:**
- Status Flow — karty z zielonym/żółtym/czerwonym statusem per flow
- Aktywne alerty — liczba i lista najważniejszych
- Topologia — uproszczony graf infrastruktury
- Trendy — wykres widoczności w ostatnich 24h/7d/30d

### Overview Dashboard (Moduł mitre)

Rozszerzenie głównego widoku o dane MITRE:
- Pokrycie MITRE — % pokrytych technik
- Dotknięte techniki — lista aktualnie niedostępnych
- Impakt score — zagregowany wskaźnik impaktu

### MITRE Coverage Dashboard (Moduł mitre)

Dedykowany widok pokrycia MITRE ATT&CK.

**Komponenty:**
- Heatmapa MITRE (tactics × techniques)
- Kolory: zielony (pokryte), czerwony (dotknięte ciszą), szary (niemonitorowane)
- Drill-down do szczegółów techniki
- Historia pokrycia (trend)

### Topology Dashboard (Core)

Widok grafu infrastruktury.

**Komponenty:**
- Graf assetów i zależności
- Kolorowanie po statusie (green/amber/red)
- Drill-down do szczegółów węzła
- Kaskadowy impakt przy wyborze węzła

### Topology Dashboard (Moduł mitre)

Rozszerzenie widoku topologii:
- Węzły pokazują przypisane techniki MITRE
- Impakt MITRE przy drill-down
- Filtrowanie po technikach MITRE

### Alerts Dashboard (Core)

Widok alertów.

**Komponenty:**
- Lista aktywnych alertów
- Filtry: severity, region, flow, grupa
- Timeline alertów
- Szczegóły alertu

### Alerts Dashboard (Moduł mitre)

Rozszerzenie widoku alertów:
- Filtr po technikach/taktykach MITRE
- Impakt MITRE w szczegółach alertu
- Agregacja po technikach MITRE

### TimeTravel Dashboard (Moduł behavioral)

Widok historii zachowania assetów i feedów.
Dostępny tylko gdy moduł `behavioral` jest włączony.

Szczegóły: [behavioral-analytics.md](behavioral-analytics.md)

### Anomalies Dashboard (Moduł behavioral)

Widok wykrytych anomalii.
Dostępny tylko gdy moduł `behavioral` jest włączony.

Szczegóły: [behavioral-analytics.md](behavioral-analytics.md)

## Powiązania

- [modules.md](../modules.md) — System modułów
- [mitre-mapping.md](mitre-mapping.md) — Mapowanie MITRE (opcjonalne)
- [behavioral-analytics.md](behavioral-analytics.md) — Behavioral Analytics (opcjonalne)
- [frontend.md](../frontend.md) — Szczegóły UI
