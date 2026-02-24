# Alerting

System generowania alertów na podstawie wyników porównania schedulera.

## Wyzwalacz

Alert powstaje, gdy scheduler wykryje, że asset z grupy nie pojawił się
w danym punkcie połączenia w zdefiniowanym oknie czasowym.

## Zawartość alertu

### Core (zawsze dostępne)

- Które assety nie raportowały
- W którym punkcie flow nastąpiła cisza
- Jak długo trwa przestój
- Liczba dotkniętych assetów
- Krytyczność grupy assetów (rating)

### Moduł mitre (opcjonalny)

Gdy moduł `mitre` jest włączony, alert zawiera dodatkowo:

- Impakt MITRE ATT&CK — które techniki detekcji zostały utracone
  (na podstawie mapowania grupy assetów)
- Dotknięte taktyki MITRE
- Łączny impakt na pokrycie organizacji

## Przykłady komunikatów

### Core (bez modułu mitre)

```
Przestój 3h na grupie 'AD Controllers EU'.
15 assetów nie raportowało w oczekiwanym oknie czasowym.
Krytyczność grupy: HIGH.
Flow: EDR Pipeline, Punkt: Splunk Ingest.
```

### Z modułem mitre

```
Przestój 3h na grupie 'AD Controllers EU'.
15 assetów nie raportowało w oczekiwanym oknie czasowym.
Krytyczność grupy: HIGH.
Flow: EDR Pipeline, Punkt: Splunk Ingest.

Impakt MITRE ATT&CK:
W tym czasie organizacja była ślepa na techniki: T1003, T1558, T1078.
Brak zdolności detekcji: Credential Access, Lateral Movement.
```

## Granularność

Alert jest generowany per punkt w flow, nie globalnie.
Dzięki temu precyzyjnie lokalizuje miejsce awarii w potoku danych.

## Severity

Severity alertu jest obliczany na podstawie:

### Core

- Krytyczność grupy assetów (rating)
- Liczba dotkniętych assetów
- Czas trwania przestoju

### Moduł mitre

- Liczba dotkniętych technik MITRE
- Krytyczność technik (Credential Access > Reconnaissance)
- Pokrycie taktyk

## Model danych

Alert przechowuje pole `mitre_techniques` jako nullable JSONB.
Pole jest wypełniane tylko gdy moduł `mitre` jest włączony.

```json
// Gdy moduł mitre włączony
{
  "techniques": [
    {"id": "T1003", "name": "OS Credential Dumping", "tactic": "Credential Access"},
    {"id": "T1558", "name": "Steal or Forge Kerberos Tickets", "tactic": "Credential Access"}
  ]
}

// Gdy moduł mitre wyłączony
null
```

## Powiązania

- [modules.md](../modules.md) — System modułów
- [mitre-mapping.md](mitre-mapping.md) — Mapowanie MITRE (opcjonalne)
- [notifications.md](notifications.md) — Wysyłanie powiadomień
- [flows.md](flows.md) — Flow i punkty
