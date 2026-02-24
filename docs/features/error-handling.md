# Error Handling

## Standardowe kody statusu (Exit Codes)

Wzorowane na Nagios Plugin API. Jeden standard dla wszystkich workerów i checków.
Umożliwia community pisanie własnych pluginów — wystarczy zwrócić poprawny kod
i output w zdefiniowanym formacie.

### Kody

| Code | Status   | Znaczenie                                    |
|------|----------|----------------------------------------------|
| 0    | OK       | Sukces — dane zebrane poprawnie              |
| 1    | WARNING  | Częściowy sukces — dane niekompletne         |
| 2    | CRITICAL | Błąd — brak danych, nie udało się zebrać     |
| 3+   | UNKNOWN  | Nieznany stan — niespodziewany błąd          |

### Standardowy output

Każdy worker/check zwraca JSON w ustandaryzowanym formacie:

```json
{
  "code": 0,
  "status": "OK",
  "message": "Collected 142 assets from kafka-prod topic windows-events",
  "assets": ["asset-id-1", "asset-id-2", "..."],
  "metadata": {
    "duration_ms": 1230,
    "source": "kafka-prod",
    "query": "topic: windows-events"
  },
  "timestamp": "2026-01-31T10:00:00Z"
}
```

Przykłady per kod:

**Code 0 — OK:**
```json
{
  "code": 0,
  "status": "OK",
  "message": "Collected 142 assets from kafka-prod",
  "assets": ["asset-1", "asset-2", "..."]
}
```

**Code 1 — WARNING:**
```json
{
  "code": 1,
  "status": "WARNING",
  "message": "Partial data: Splunk query timed out after 30s, returned 89 of ~150 assets",
  "assets": ["asset-1", "asset-2", "..."]
}
```

**Code 2 — CRITICAL:**
```json
{
  "code": 2,
  "status": "CRITICAL",
  "message": "Connection refused: kafka-prod:9092",
  "assets": []
}
```

**Code 3+ — UNKNOWN:**
```json
{
  "code": 3,
  "status": "UNKNOWN",
  "message": "Unexpected error: JSON parse failure on response from Splunk",
  "assets": []
}
```

### Wpływ na scheduler

Scheduler sprawdza kod statusu workera **przed** ewaluacją:

| Worker code | Scheduler zachowanie                                              |
|-------------|-------------------------------------------------------------------|
| 0 (OK)      | Normalna ewaluacja. Alerty biznesowe na brakujące assety.         |
| 1 (WARNING) | Ewaluacja z flagą `partial_data`. Alerty biznesowe oznaczone.     |
| 2 (CRITICAL)| Ewaluacja **wstrzymana**. Alert systemowy. Brak alertów biznesowych.|
| 3+ (UNKNOWN)| Ewaluacja **wstrzymana**. Alert systemowy. Wymaga ręcznej analizy.|

Zasada: scheduler nie generuje alertów biznesowych na podstawie niewiarygodnych danych.

### Wpływ na alerty

Alerty biznesowe wygenerowane przy code=1 (WARNING) zawierają dodatkową flagę:

```json
{
  "partial_data": true,
  "worker_message": "Splunk query timed out, returned 89 of ~150 assets"
}
```

To pozwala odbiorcy alertu wiedzieć, że dane mogą być niekompletne.

## Retry i Circuit Breaker

### Retry

Przy code 2 (CRITICAL) lub 3+ (UNKNOWN) worker jest ponowiany:

```
Próba 1: fail (code 2) → retry po 30s
Próba 2: fail (code 2) → retry po 60s
Próba 3: fail (code 2) → retry po 120s
Max retries: 3 (konfigurowalne per Integration Point)
```

### Circuit Breaker

Po wyczerpaniu retry:

```
CLOSED (normalny) → 3 consecutive failures → OPEN
OPEN → brak prób, alert systemowy, scheduler wstrzymany
OPEN → co N minut → HALF-OPEN (jedna próba testowa)
HALF-OPEN → sukces → CLOSED (normalny ruch)
HALF-OPEN → failure → OPEN
```

Stan circuit breakera per Integration Point, nie per flow.
Jeśli Kafka jest niedostępna, wszystkie flow korzystające z tego punktu
przechodzą w tryb OPEN jednocześnie.

#### Przechowywanie stanu circuit breakera

Stan circuit breakera przechowywany w **Redis** (nie w pamięci procesu).
Jest to wymagane przez model K8s CronJob, gdzie batch worker jest stateless
(uruchamia się, wykonuje cykl, kończy się).

Klucz Redis: `cb:{tenant_id}:{integration_point_id}`

Operacje atomiczne (Lua script):
- `INCR` failures po błędzie
- `RESET` po sukcesie
- `CHECK` threshold przed próbą połączenia
- TTL na kluczu = czas trwania stanu OPEN

Dzięki Redis circuit breaker działa poprawnie zarówno w modelu
długożyciowego kontenera (Docker dev), jak i stateless CronJob (K8s prod).

## Worker status w cache

```
tenant:{tenant_id}:pulse:{id}:worker_status → {
  "code": 0,
  "status": "OK",
  "last_success": "2026-01-31T10:00:00Z",
  "last_error": null,
  "consecutive_failures": 0,
  "circuit_breaker": "closed"
}
```

## Scenariusze per komponent

| Komponent               | Błąd                          | Zachowanie                                           |
|--------------------------|-------------------------------|------------------------------------------------------|
| Worker → zewn. system   | Connection / timeout / auth   | Retry → circuit breaker → alert systemowy            |
| Worker → Redis (zapis)  | Redis unavailable             | Retry → alert systemowy, dane utracone               |
| Scheduler → Redis       | Redis unavailable             | Retry → alert systemowy, ewaluacja odroczona         |
| Scheduler → PostgreSQL  | DB unavailable                | Retry → alert systemowy, ewaluacja odroczona         |
| CMDB Sync → zewn. CMDB  | Connection / auth             | Retry → alert systemowy, ostatni znany stan assetów  |
| CMDB Sync → CSV upload  | Invalid format                | Odrzucenie z komunikatem błędu do użytkownika        |
| Notification → kanał    | Delivery failure              | Retry → dead letter queue → alert systemowy          |

## Community Plugins

Standardowe kody i format output umożliwiają community tworzenie własnych workerów.

Wymagania dla custom workera:
1. Przyjmij konfigurację (connection, query) jako input
2. Połącz się z zewnętrznym systemem
3. Zwróć JSON z kodem statusu, listą assetów i metadanymi
4. Respektuj kody: 0=OK, 1=WARNING, 2=CRITICAL, 3+=UNKNOWN

Przykład minimalnego custom workera:
```bash
#!/bin/bash
# Custom worker: sprawdź assety w pliku logów

ASSETS=$(grep -oP 'hostname=\K[^ ]+' /var/log/security.log | sort -u)
COUNT=$(echo "$ASSETS" | wc -l)

if [ $COUNT -gt 0 ]; then
  echo "{\"code\": 0, \"status\": \"OK\", \"message\": \"Found $COUNT assets\", \"assets\": [$(echo $ASSETS | sed 's/ /\", \"/g' | sed 's/^/\"/;s/$/\"/')]}"
  exit 0
else
  echo "{\"code\": 2, \"status\": \"CRITICAL\", \"message\": \"No assets found in log\", \"assets\": []}"
  exit 2
fi
```

SilentPulse uruchamia custom workery jako kontenery — wystarczy obraz Docker
z binarką/skryptem, który zwraca poprawny output.
