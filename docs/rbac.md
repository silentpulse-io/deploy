# RBAC — Role-Based Access Control

Definicja ról użytkowników i uprawnień w systemie SilentPulse.

## Role

### Admin

Pełny dostęp do systemu. Zarządzanie użytkownikami, konfiguracją systemu,
tworzenie audit tasków.

### Analyst

Operacyjna praca z systemem — definiowanie flow, grup assetów,
Integration Points, przeglądanie alertów, analiza impaktu.

### Viewer

Read-only dostęp do dashboardów i alertów. Nie może zmieniać konfiguracji.

### Auditor

Rola zadaniowa — tworzona per audyt z ograniczonym zakresem i czasem.

Auditor **nie jest** stałym użytkownikiem systemu. Admin tworzy audit task,
który definiuje:
- Kto: przypisany audytor (użytkownik)
- Zakres: filtry (region, grupy assetów, flow itd.)
- Okres: przedział czasowy danych objętych audytem
- Wygaśnięcie: data, po której dostęp audytora jest automatycznie cofany

Audytor widzi **wyłącznie** dane objęte scope audit taska:
- Assety spełniające filtry zakresu
- Grupy assetów zawierające te assety
- Flow powiązane z tymi grupami
- Alerty z zdefiniowanego okresu
- Impakt MITRE dla dotkniętych grup
- Timeline przestojów

Audytor **nie może** modyfikować żadnych danych.
Audytor **może** eksportować raporty w zakresie swojego taska.

Przykład:
```
Audit Task: "Q1 2026 Asia Security Visibility Audit"
  Audytor:     jan.kowalski@audit.com
  Zakres:      region IN (Singapore, Tokyo, Sydney)
  Okres:       2026-01-01 → 2026-03-31
  Wygaśnięcie: 2026-04-15
```

## Zakres uprawnień

| Operacja                      | Admin | Analyst | Viewer | Auditor       |
|-------------------------------|-------|---------|--------|---------------|
| Zarządzanie użytkownikami     | +     | -       | -      | -             |
| Konfiguracja CMDB Sync       | +     | -       | -      | -             |
| Tworzenie audit tasków        | +     | -       | -      | -             |
| Integration Points (CRUD)    | +     | +       | -      | -             |
| Asset Groups (CRUD)          | +     | +       | -      | -             |
| MITRE mapping                | +     | +       | -      | -             |
| Flow (CRUD)                  | +     | +       | -      | -             |
| Przeglądanie alertów         | +     | +       | +      | scoped        |
| Dashboardy                   | +     | +       | +      | scoped        |
| Impact analysis              | +     | +       | +      | scoped        |
| Eksport raportów             | +     | +       | -      | scoped        |
| Dane historyczne             | +     | +       | +      | scoped (okres)|

`scoped` = tylko w zakresie przypisanego audit taska (filtry + okres).

## Multi-tenancy

Do ustalenia — czy system obsługuje wielu tenantów (organizacje) na jednej instancji.
Jeśli tak, Row-Level Security (PostgreSQL RLS) egzekwuje izolację na poziomie bazy.
