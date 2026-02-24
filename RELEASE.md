# SilentPulse — Release Notes

## [Unreleased]

### Dodano
- **Demo Mode** — tryb demonstracyjny uruchamiany jednym kliknięciem (admin)
  - `POST /api/v1/demo/enable` — tworzy 15 assetów, grupę, 2 integration pointy (Log Source + SIEM), flow i uruchamia monitoring
  - `DELETE /api/v1/demo/disable` — zatrzymuje flow i usuwa wszystkie dane demo
  - `GET /api/v1/demo/status` — status demo z aktualnymi scenariuszami
  - `POST /api/v1/demo/scenarios/{scenario}` — symulacja awarii (healthy, asset-silent, node-down, gradual-degradation, recovery)
  - Frontend: strona `/dashboard/demo` z kontrolkami enable/disable, wyborem scenariuszy i selektorem target (source/siem/both)
  - Worker plugin `demo` czytający scenariusze z Redis
- **CORS middleware** — obsługa preflight requests (OPTIONS) dla frontend-backend cross-origin
- **Makefile** — 22 targety do zarządzania środowiskiem dev (make dev, make dev-restart, make backend-test, itp.)
- Rozszerzony **README.md** — architektura, API endpoints, pakiety backend, instrukcje dev

### Naprawiono
- **RLS tenant isolation** — `SET app.current_tenant = $1` nie działał z parametryzowanymi zapytaniami w pgx v5 (extended query protocol). Zamieniono na `SELECT set_config(...)` który poprawnie obsługuje parametry.

### Zmieniono
- `internal/config/config.go` — dodano pole `FlowControllerURL`
- `deploy/docker-compose/docker-compose.yml` — dodano `FLOW_CONTROLLER_URL` do serwisu api

---

## [0.1.0] — 2026-01-31

### Faza 1-3: Core Backend, Frontend, Workers
- Auth (JWT login/refresh), CRUD API (assets, asset groups, integration points, flows, alerts)
- Frontend (Next.js 14, dark theme, dashboard, wszystkie widoki CRUD)
- Flow Controller, Worker, Scheduler — orkiestracja kontenerów Docker

### Faza 4: Notyfikacje
- Serwis notifications (webhook, Slack, email, Splunk)
- Notification channels + rules CRUD

### Faza 5: Moduły opcjonalne
- Moduł `mitre` — mapowanie MITRE ATT&CK, coverage, impact analysis
- Moduł `behavioral` — TimeTravel, profiling, anomaly detection, suggestions
