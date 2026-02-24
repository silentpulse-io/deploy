# Integration Points (Punkty połączeń)

Obiekty konfiguracyjne definiowane wewnątrz SilentPulse.
Opisują **połączenie** do zewnętrznego systemu — ale **nie** szczegóły zapytań.

## Kluczowe rozróżnienie

- **Integration Point = definicja połączenia** (adres, credentials, typ systemu).
- **Szczegóły zapytań** (topic Kafka, search query Splunk, SQL query Databricks,
  JSON path) konfigurowane są **per-flow** w ramach FlowPulse.

Dzięki temu jeden Integration Point ("Kafka Cluster SG") może być współdzielony
przez wiele flow z różnymi topikami (windows-events, linux-syslog, app-logs).

## Konfiguracja punktu

- Typ systemu zewnętrznego (Kafka, Splunk, Elasticsearch, Databricks itd.)
- Parametry połączenia (adres, credentials) — szyfrowane w `connection_config`

## Przykłady

- Kafka: cluster address, authentication (SASL/SSL credentials)
- Splunk: adres, credentials (token/user+password)
- Databricks: connection string, workspace token
- Elasticsearch: cluster URL, API key

## Szczegóły zapytań — per flow

Szczegóły takie jak topic, query, JSON path, parser konfigurowane są
w edytorze flow podczas tworzenia pulse na węźle pipeline:

- Kafka: topic, consumer group — w Query Config pulse
- Splunk: search query — w Query Config pulse
- Databricks: SQL query — w Query Config pulse
- Parser (JSONPath/Grok/Regex) — w zakładce Extract pulse
