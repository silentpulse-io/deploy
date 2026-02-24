# Notifications (Alert Delivery)

Dostarczanie alertów z SilentPulse do zewnętrznych systemów i odbiorców.

## Kanały dostarczania

### Webhook

Generyczny HTTP POST z payloadem alertu (JSON) na zdefiniowany URL.
Obsługuje custom headers (np. auth token).
Umożliwia integrację z dowolnym systemem (SOAR, ticketing, custom).

### Slack

Wiadomość na zdefiniowany kanał Slack.
Formatowanie: summary alertu, impakt MITRE, link do SilentPulse.

### Email

Wiadomość email do zdefiniowanych odbiorców.
Obsługuje listy dystrybucyjne.

### Splunk (HEC)

Wysyłka alertu jako event do Splunk przez HTTP Event Collector.
Pozwala korelować dane SilentPulse z innymi eventami w Splunk.

## Konfiguracja

Notification channel to obiekt konfiguracyjny:

- name
- type (webhook, slack, email, splunk)
- config (JSONB) — URL, token, kanał, adresy email itd.
- enabled

## Powiązanie z alertami

Użytkownik definiuje notification rules:

- Warunki: severity, region, grupa assetów, technika MITRE
- Kanały: które notification channels mają zostać użyte
- Przykład: "Alerty severity=critical z regionu EU → Slack #soc-alerts + email soc-team@company.com"
- Przykład: "Wszystkie alerty → webhook do SOAR"

## External API (odczyt alertów)

Zewnętrzne systemy (PowerBI, Grafana, custom dashboardy) mogą odpytywać
SilentPulse o dane alertów przez dedykowane API z API key auth.

Endpoint zwraca dane w formacie przyjaznym dla BI:
- Agregacje (alerty per region, per grupa, per technika MITRE)
- Trendy (alerty w czasie)
- Surowe dane alertów z filtrowaniem

Autentykacja: API key (nie JWT) — dla integracji machine-to-machine.
