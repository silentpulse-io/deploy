# Self-Monitoring

SilentPulse monitoruje widoczność bezpieczeństwa — ale sam musi być monitorowany.
Jeśli system monitorujący padnie po cichu, cały jego sens zostaje podważony.

## Warstwy monitorowania

### Warstwa 1: Wewnętrzny Health Service

Centralny komponent, który odbiera heartbeaty od wszystkich komponentów systemu.
Brak heartbeatu w zdefiniowanym oknie → wewnętrzny alert systemowy
(osobna ścieżka niż alerty biznesowe o ciszy telemetrii).

Monitorowane komponenty:

| Komponent       | Heartbeat                                         | Alert gdy                              |
|-----------------|----------------------------------------------------|----------------------------------------|
| Worker          | Potwierdzenie życia + status ostatniej kolekcji   | Brak heartbeatu / collection failure   |
| Scheduler       | Potwierdzenie życia + timestamp ostatniej ewaluacji| Brak heartbeatu / evaluation opóźniona |
| Flow Controller | Status zarządzanych kontenerów                    | Kontener nie startuje / crashuje       |
| Redis           | Ping + write/read test                            | Brak odpowiedzi / błędy zapisu         |
| PostgreSQL      | Connection check                                  | Brak odpowiedzi                        |
| CMDB Sync       | Timestamp ostatniej udanej synchronizacji         | Sync nie wykonany w oknie              |
| Notifications   | Status ostatnich dostarczeń                       | Failed deliveries                      |

Alerty systemowe mogą być dostarczane przez te same kanały co alerty biznesowe
(Slack, email, webhook), ale powinny być wyraźnie oznaczone jako systemowe.

### Warstwa 2: Kubernetes Probes

Standardowe mechanizmy K8s per kontener:

- **Liveness probe** — czy proces żyje (restart jeśli nie)
- **Readiness probe** — czy jest gotowy obsługiwać ruch (wyjęcie z load balancera)
- **Startup probe** — czy kontener wystartował poprawnie (dla wolniejszych serwisów)

Kubernetes automatycznie restartuje kontenery, które failują liveness probe.
Nie wymaga dodatkowej logiki w aplikacji — wystarczy endpoint `/healthz` per serwis.

### Warstwa 3: Metryki Prometheus

Każdy komponent eksponuje endpoint `/metrics` w formacie Prometheus.
Metryki są scrape'owane przez zewnętrzną instancję Prometheus,
wizualizowane w Grafanie i monitorowane niezależnie od SilentPulse
przez team odpowiedzialny za infrastrukturę aplikacji.

Kluczowe metryki:

```
# Worker
silentpulse_worker_collections_total{flow_id, point_id, status}
silentpulse_worker_collection_duration_seconds{flow_id, point_id}
silentpulse_worker_last_collection_timestamp{flow_id, point_id}
silentpulse_worker_assets_collected{flow_id, point_id}
silentpulse_worker_errors_total{flow_id, point_id, error_type}

# Scheduler
silentpulse_scheduler_evaluations_total{flow_id, point_id, status}
silentpulse_scheduler_evaluation_duration_seconds{flow_id, point_id}
silentpulse_scheduler_last_evaluation_timestamp{flow_id, point_id}
silentpulse_scheduler_missing_assets{flow_id, point_id}

# Alerts
silentpulse_alerts_active{severity, region}
silentpulse_alerts_created_total{severity, region}
silentpulse_alerts_resolved_total{severity, region}
silentpulse_alert_duration_seconds{flow_id, point_id}

# Notifications
silentpulse_notifications_sent_total{channel_type, status}
silentpulse_notification_delivery_failures_total{channel_type}

# Cache (Redis)
silentpulse_cache_operations_total{operation, status}
silentpulse_cache_latency_seconds{operation}

# CMDB Sync
silentpulse_cmdb_sync_last_success_timestamp
silentpulse_cmdb_sync_assets_total
silentpulse_cmdb_sync_errors_total{source_type}

# Flow Controller
silentpulse_flows_active_total
silentpulse_flow_containers_running{flow_id}
silentpulse_flow_container_restarts_total{flow_id}

# System
silentpulse_health_status{component}  # 1 = healthy, 0 = unhealthy
```

### Warstwa 4: Dead Man's Switch

Zabezpieczenie na wypadek awarii całego SilentPulse.
Wewnętrzny monitoring nie pomoże, jeśli sam nie działa.

SilentPulse periodycznie wysyła sygnał "żyję" do zewnętrznego endpointu.
Jeśli sygnał przestaje przychodzić — alert generowany poza SilentPulse.

Implementacja:
- Lekki cron job (w osobnym kontenerze lub K8s CronJob)
- Wysyła HTTP request co N minut do zewnętrznego URL
- Zewnętrzny odbiornik: prosty serwis (self-hosted) lub darmowy tier
  usługi typu Healthchecks.io / UptimeRobot
- Nie bazujemy na płatnych rozwiązaniach (Datadog, PagerDuty)

```
SilentPulse ──heartbeat co 5min──► Dead Man's Switch (zewnętrzny)
                                         │
                                    brak sygnału > 10min?
                                         │
                                         ▼
                                   Alert email/webhook
                                   niezależny od SilentPulse
```

## Rozdzielenie alertów

System rozróżnia dwa typy alertów:

1. **Alerty biznesowe** — cisza telemetrii, brak assetów w oknie, impakt MITRE
2. **Alerty systemowe** — awaria komponentu SilentPulse, degradacja wydajności

Oba typy mogą korzystać z tych samych kanałów dostarczania (notifications),
ale są wyraźnie oznaczone typem i mogą mieć osobne reguły routingu.
