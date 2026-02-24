# Exclusion Windows

Mechanizm wyciszania alertów podczas planowanych przerw serwisowych (maintenance windows).

## Cel

Pozwala zdefiniować okna czasowe, w których alerty dla wybranej grupy assetów
są wstrzymywane. Zapobiega fałszywym alertom podczas planowanych prac
konserwacyjnych, migracji, aktualizacji systemów itp.

## Model danych

### exclusion_windows (PostgreSQL)

| Pole             | Typ            | Opis                                       |
|------------------|----------------|---------------------------------------------|
| id               | UUID           | PK                                          |
| name             | text           | Nazwa okna (wymagana)                       |
| description      | text           | Opis/cel okna                               |
| asset_group_id   | UUID (FK)      | Grupa assetów (nullable = globalne)         |
| start_time       | timestamptz    | Początek okna                               |
| end_time         | timestamptz    | Koniec okna                                 |
| recurrence_type  | text           | none / daily / weekly / monthly             |
| recurrence_end   | timestamptz    | Koniec rekurencji (nullable = bez końca)    |
| enabled          | boolean        | Czy okno jest aktywne                       |
| created_by       | UUID (FK)      | Użytkownik, który utworzył                   |
| tenant_id        | UUID           | Multi-tenancy                               |
| created_at       | timestamptz    |                                             |
| updated_at       | timestamptz    |                                             |

### exclusion_logs (PostgreSQL)

Rejestr faktycznie wyciszonych alertów.

| Pole                 | Typ         | Opis                                    |
|----------------------|-------------|------------------------------------------|
| id                   | UUID        | PK                                       |
| exclusion_window_id  | UUID (FK)   | Które okno wyciszyło                     |
| asset_id             | UUID        | Wyciszony asset                          |
| flow_pulse_id        | UUID        | Punkt w flow                             |
| suppressed_at        | timestamptz | Kiedy alert został wyciszony             |
| reason               | text        | Powód wyciszenia                         |
| tenant_id            | UUID        | Multi-tenancy                            |

## API

| Metoda | Endpoint                                  | Opis                          |
|--------|-------------------------------------------|-------------------------------|
| GET    | /api/v1/exclusion-windows                 | Lista (paginated)             |
| POST   | /api/v1/exclusion-windows                 | Tworzenie                     |
| GET    | /api/v1/exclusion-windows/{id}            | Szczegóły                     |
| PUT    | /api/v1/exclusion-windows/{id}            | Edycja                        |
| DELETE | /api/v1/exclusion-windows/{id}            | Usunięcie                     |
| GET    | /api/v1/exclusion-windows/{id}/logs       | Logi wyciszenia (paginated)   |

## Logika schedulera

Scheduler przed wygenerowaniem alertu sprawdza:

1. Czy istnieje aktywne okno dla danej grupy assetów (lub globalne)
2. Czy bieżący czas mieści się w oknie (z uwzględnieniem rekurencji)
3. Jeśli tak — alert nie jest tworzony, a wpis trafia do exclusion_logs

## Frontend

### Nawigacja

Sidebar: Operations → Exclusion Windows

### Strony

- **Lista** (`/dashboard/exclusion-windows`) — DataTable z kolumnami: Name, Period, Recurrence, Enabled, Actions (Edit/Delete)
- **Tworzenie** (`/dashboard/exclusion-windows/new`) — formularz: Name, Description, Asset Group (select), Start/End Time (datetime-local), Recurrence Type (select), Recurrence End (warunkowe), Enabled (checkbox)
- **Edycja** (`/dashboard/exclusion-windows/{id}/edit`) — ten sam formularz, pre-wypełniony
- **Szczegóły** (`/dashboard/exclusion-windows/{id}`) — karta informacyjna + tabela logów wyciszenia

## Powiązania

- [alerting.md](alerting.md) — Exclusion windows wpływają na generowanie alertów
- [asset-groups.md](asset-groups.md) — Okno może być przypisane do grupy
