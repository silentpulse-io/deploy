# Asset Groups (Grupy assetów)

Użytkownik tworzy grupy assetów z pełnej puli CMDB za pomocą filtrów.

## Filtry

Dostępne kryteria filtrowania:
- vendor
- product
- rating
- region
- inne atrybuty z CMDB

## Przykłady grup

- "Serwery Linux z regionu Singapur"
- "Stacje Windows z Europy"
- "Kontrolery domeny AD"

## Rola w systemie

### Core (zawsze dostępne)

Grupa assetów jest podstawą do:
1. Definiowania flow — każdy flow operuje na konkretnej grupie
2. Określania krytyczności (rating) — wpływa na severity alertów

### Moduł mitre (opcjonalny)

Gdy moduł `mitre` jest włączony:
- Każda grupa może mieć przypisane techniki detekcji MITRE ATT&CK
- Alerty zawierają informację o impakcie MITRE

Szczegóły mapowania MITRE: [mitre-mapping.md](mitre-mapping.md)
