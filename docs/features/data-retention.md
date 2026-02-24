# Data Retention

Polityka przechowywania danych w SilentPulse.
Konfigurowalny per tenant (multi-tenancy) lub globalnie (single-tenant).

## Kategorie danych i domyślne retencje

### Dane konfiguracyjne (PostgreSQL)

Assety, grupy, flow, Integration Points, użytkownicy, RBAC, MITRE mapping.

| Retencja | Uwagi |
|----------|-------|
| Bezterminowa | Aktywna konfiguracja systemu. Usuwane tylko jawnie przez użytkownika. |

Usunięte obiekty (soft delete) przechowywane przez 90 dni — możliwość odzyskania.
Po 90 dniach hard delete (nieodwracalne).

### Cache — worker results (Redis)

Dane o assetach zebranych przez workery. Dane tymczasowe.

| Retencja | Uwagi |
|----------|-------|
| 2x time_window flow pulse'u | TTL ustawiane automatycznie. Jeśli time_window = 1h, dane żyją 2h. |

Redis TTL per klucz. Po wygaśnięciu dane znikają automatycznie.
Nie ma potrzeby przechowywać dłużej — scheduler porównuje w oknie,
dane historyczne trafiają do alertów.

### Worker status (Redis)

Stan workera (code, last_success, circuit_breaker).

| Retencja | Uwagi |
|----------|-------|
| 24h | Nadpisywane przy każdym wykonaniu. TTL jako zabezpieczenie. |

### Alerty (PostgreSQL)

Historia alertów biznesowych i systemowych.

| Tier          | Retencja      | Uwagi                                      |
|---------------|---------------|---------------------------------------------|
| Hot (active)  | Bezterminowa  | Otwarte alerty — zawsze dostępne            |
| Warm (recent) | 90 dni        | Zamknięte alerty — szybki dostęp, dashboardy|
| Cold (archive)| 1 rok         | Archiwum — audyt, compliance, trendy        |
| Expired       | Usunięte      | Po roku — hard delete lub eksport           |

Implementacja: partycjonowanie PostgreSQL po `started_at` (monthly partitions).
Warm → cold → drop realizowane przez scheduled job.

Opcja: przed usunięciem cold data eksport do storage (S3-compatible / NFS)
jako CSV/Parquet — tańsze przechowywanie dla compliance.

### Audit log (PostgreSQL)

Historia zmian konfiguracji (kto, co, kiedy).

| Retencja | Uwagi |
|----------|-------|
| 2 lata   | Wymogi compliance. Konfigurowalne per tenant. |

Partycjonowanie po `created_at`. Stare partycje read-only, potem drop.
Opcja eksportu do cold storage przed usunięciem.

### Audit task data (PostgreSQL)

Dane audit tasków (zakres, okres, audytor).

| Retencja | Uwagi |
|----------|-------|
| 2 lata   | Zgodne z audit log. Dowód na przeprowadzony audyt. |

### Raporty — wygenerowane pliki (filesystem / object storage)

Pliki PDF/CSV generowane przez reporting engine.

| Retencja | Uwagi |
|----------|-------|
| 90 dni   | Po 90 dniach usunięte. Użytkownik może pobrać i archiwizować wcześniej. |

Tabela `report_executions` (metadata) przechowywana dłużej (1 rok) —
widać, że raport był wygenerowany i wysłany, nawet gdy plik już nie istnieje.

### Metryki Prometheus (zewnętrzne)

Przechowywane przez zewnętrzną instancję Prometheus/Thanos.
SilentPulse nie zarządza retencją metryk — to odpowiedzialność zespołu infrastruktury.

Rekomendacja: 30 dni raw metrics, 1 rok downsampled (Thanos/Cortex).

### Graf zależności (Apache AGE)

Węzły i krawędzie grafu (HOSTS, RUNS, DEPENDS_ON).

| Retencja | Uwagi |
|----------|-------|
| Podąża za assetami | Krawędź usuwana gdy asset jest usunięty (soft/hard delete). |

## Cold Storage Export (S3 / Blob Storage)

Dane przed usunięciem mogą być eksportowane do zewnętrznego storage.
Tańsze przechowywanie na potrzeby compliance, audytu i analizy historycznej.

### Obsługiwane backendy

- AWS S3
- Azure Blob Storage
- S3-compatible (MinIO, GCS z S3 API)

### Co jest eksportowane

| Dane | Format | Struktura klucza |
|------|--------|------------------|
| Alerty (cold → expired) | Parquet / CSV | `{bucket}/alerts/{tenant}/{year}/{month}/alerts-{date}.parquet` |
| Audit log | Parquet / CSV | `{bucket}/audit/{tenant}/{year}/{month}/audit-{date}.parquet` |
| Pliki raportów | PDF / CSV | `{bucket}/reports/{tenant}/{year}/{month}/{report-id}.pdf` |

Parquet preferowany — kolumnowy, kompresja, łatwy do konsumpcji
przez narzędzia analityczne (Databricks, Athena, BigQuery).

### Konfiguracja

```json
{
  "cold_storage": {
    "enabled": true,
    "backend": "s3",
    "bucket": "silentpulse-archive",
    "prefix": "prod",
    "credentials_secret": "cold-storage-creds",
    "format": "parquet",
    "export_before_delete": true
  }
}
```

`export_before_delete: true` — cleanup job nie usunie danych dopóki eksport
nie zakończy się sukcesem. Zabezpieczenie przed utratą danych.

### Lifecycle

```
Active (PostgreSQL) → Warm → Cold → Export to S3/Blob → Delete from PostgreSQL
```

Dane w cold storage są read-only. SilentPulse nie odpytuje ich w normalnym
trybie pracy. Służą wyłącznie do:
- Compliance i audytu (ręczny dostęp / zewnętrzne narzędzia)
- Analizy historycznej (Databricks, Athena)
- Odtworzenia danych w razie potrzeby

## Konfiguracja retencji

Retencje konfigurowane przez admina:

```json
{
  "retention": {
    "alerts_warm_days": 90,
    "alerts_cold_days": 365,
    "audit_log_days": 730,
    "report_files_days": 90,
    "report_metadata_days": 365,
    "soft_delete_days": 90
  }
}
```

## Scheduled Cleanup Job

Dedykowany job (cron) realizujący politykę retencji:

1. Przeniesienie alertów warm → cold (partycjonowanie)
2. Usunięcie expired alertów (drop old partitions)
3. Usunięcie starych audit logów
4. Usunięcie wygasłych plików raportów
5. Hard delete soft-deleted obiektów po 90 dniach
6. Opcjonalny eksport do cold storage przed usunięciem

Job loguje każdą operację do audit log.
Konfigurowalny harmonogram (domyślnie: daily 03:00 UTC).

## Sizing — szacowanie storage

Pomocnicze wzory do planowania pojemności:

```
Alerty:      ~1 KB/alert × alerts/day × retention_days
Audit log:   ~0.5 KB/entry × changes/day × retention_days
Cache:       ~100 bytes/asset × total_assets × flow_pulses (Redis RAM)
Raporty:     ~1 MB/PDF × reports/week × retention_days / 7
```

Przykład:
- 1000 alertów/dzień × 365 dni × 1 KB = ~365 MB (alerts cold)
- 500 zmian/dzień × 730 dni × 0.5 KB = ~183 MB (audit log)
- 10000 assetów × 50 flow pulses × 100 B = ~50 MB (Redis)
