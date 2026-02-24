# CMDB Sync

Osobny komponent odpowiedzialny za synchronizację danych o assetach.
Dane o assetach pochodzą z zewnętrznych systemów — SilentPulse ich nie generuje, tylko importuje.

## Tryby pozyskiwania danych

### PULL

Job pobierający dane z zewnętrznego systemu (np. ServiceNow).
Uruchamiany cyklicznie wg harmonogramu lub na żądanie.

### PUSH

API wystawione po stronie SilentPulse, gotowe przyjąć dane w każdej chwili.
Zewnętrzny system wysyła dane do SilentPulse.

### CSV upload

Ręczny import pliku przez użytkownika za pośrednictwem UI.

## Zachowanie

- Po synchronizacji wszystkie assety trafiają do wewnętrznej bazy assetów SilentPulse
- Synchronizacja jest idempotentna — ponowny import tych samych danych nie tworzy duplikatów
- CMDB Sync to osobny komponent architektoniczny, niezależny od workerów i schedulerów

## Planned Improvements

### Input Validation Layer

CMDB Sync should validate ingested data at the boundary before persisting assets.

**Data Format Validation**
- Detect changes in data format between sync runs (schema drift)
- Reject or flag records with missing required fields or incorrect data types
- Handle multi-encoding sources (including Cyrillic and other non-Latin character sets)

**Data Integrity Validation**
- Cross-reference ingested records for internal consistency
- Automatic detection and flagging of discrepancies (e.g., duplicate hostnames with different IPs, orphaned references)
- Reconciliation report per sync run

**Metric & Timestamp Validation**
- Validate that timestamp fields are correctly formatted and within reasonable bounds
- Verify encoding consistency across all text fields
- Ensure presence of expected fields per observation type schema
