# AI Assistant

Wbudowany asystent AI, który tłumaczy zdarzenia w systemie na zrozumiały,
operacyjny język. Moduł opcjonalny (`ai-assistant`), wymaga licencji Enterprise.

## Cel

Użytkownik nie musi samodzielnie interpretować surowych danych o przestojach.
AI Assistant wyjaśnia:

- Co się stało — w kontekście konkretnego flow i grupy assetów
- Jaki jest impakt — tłumaczenie na techniki MITRE ATT&CK i taktyki
- Co robić — sugerowane działania naprawcze
- Jak długo organizacja była ślepa — podsumowanie okna przestoju

## Przykład

Użytkownik widzi alert. AI Assistant generuje wyjaśnienie:

"W ciągu ostatnich 3h nie otrzymano zdarzeń z 12 z 15 kontrolerów domeny AD
w regionie EU. Oznacza to utratę widoczności na techniki Credential Access
(T1003, T1558) i Lateral Movement (T1078). Zalecane działanie: sprawdzenie
statusu agenta na kontrolerach DC-EU-01, DC-EU-02, DC-EU-05..."

## Architektura

### Provider Abstraction

Warstwa abstrakcji LLM (`internal/ai/provider.go`) obsługuje wielu dostawców:

| Provider    | Model examples                      | Auth           |
|-------------|-------------------------------------|----------------|
| `openai`    | gpt-4o, gpt-4o-mini, gpt-4-turbo   | API key        |
| `anthropic` | claude-sonnet-4-5, claude-haiku-4-5 | API key        |
| `ollama`    | deepseek-r1:8b, qwen3-vl:8b        | Base URL       |

Ollama używa OpenAI-compatible API, więc dowolny serwer zgodny z `/v1/chat/completions`
działa jako provider (vLLM, LocalAI, etc.).

### Prompt Engineering

Prompt składa się z:

1. **System prompt** — rola AI, format odpowiedzi (JSON), zasady (nie spekuluj, dane z SilentPulse)
2. **User prompt** — struktura alertu: typ, severity, asset, flow, pulse, grupa, czas ciszy, techniki MITRE, security functions

Odpowiedź LLM to JSON z 4 polami:
```json
{
  "summary": "Co się stało (operational language)",
  "impact": "Wpływ na bezpieczeństwo i MITRE ATT&CK",
  "duration": "Jak długo organizacja była ślepa",
  "remediation": "Zalecane działania (numbered list)"
}
```

### Template Fallback

Gdy LLM jest niedostępny lub niekonfigurowany, system generuje wyjaśnienie
z szablonów Go (`internal/ai/fallback.go`). Użytkownik zawsze otrzymuje odpowiedź,
niezależnie od stanu providera.

### Caching

Wyjaśnienia cachowane w Redis (TTL 15 min, klucz: `tenant:{id}:ai:explain:{alertId}`).
Kolejne żądania dla tego samego alertu zwracają cached response z flagą `cached: true`.

## API

### Configuration (admin only)

| Method   | Endpoint           | Description                                 |
|----------|--------------------|---------------------------------------------|
| `GET`    | `/api/v1/ai/config`   | Get tenant AI config (API key masked)    |
| `PUT`    | `/api/v1/ai/config`   | Create/update AI config                  |
| `DELETE` | `/api/v1/ai/config`   | Delete AI config and stored key          |
| `POST`   | `/api/v1/ai/test`     | Test LLM provider connectivity           |

### Explain (all roles, rate limited)

| Method | Endpoint             | Description                              |
|--------|----------------------|------------------------------------------|
| `POST` | `/api/v1/ai/explain` | Generate AI explanation for an alert     |

Rate limit: 10 requests/minute per tenant.

**Request:**
```json
{ "alert_id": "uuid" }
```

**Response:**
```json
{
  "data": {
    "alert_id": "uuid",
    "summary": "...",
    "impact": "...",
    "duration": "...",
    "remediation": "...",
    "provider": "openai",
    "model": "gpt-4o",
    "cached": false
  }
}
```

## RBAC

| Endpoint       | Roles        |
|----------------|--------------|
| Config CRUD    | `admin`      |
| Test connection| `admin`      |
| Explain alert  | all roles    |

Moduł wymaga licencji `ai-assistant` — endpointy zwracają 403 bez niej.

## Security

- API klucze szyfrowane per-tenant (AES-256-GCM, derived from master key)
- Klucze nigdy nie opuszczają backendu w plaintext
- Odpowiedź `GET /config` zawiera tylko `has_api_key: true/false`
- Encryption version tracking (v0 = plaintext fallback, v2 = per-tenant AES)

## Frontend

### Settings Page (`/dashboard/settings/ai`)

- Provider dropdown (OpenAI, Anthropic, Ollama)
- Model input z placeholderami per provider
- API key / Base URL input (masked gdy key stored)
- Max tokens slider (256–4096)
- Enable/disable toggle
- Test Connection button
- Delete Config button

### AI Explanation Card (`alerts/[id]`)

Na stronie szczegółów alertu, karta "AI Explanation":

1. Przycisk "Generate AI Explanation"
2. Po kliknięciu: loading → wynik z 4 sekcjami (Summary, Impact, Duration, Remediation)
3. Footer: `provider/model` + badge "Cached" jeśli z cache
4. Jeśli moduł niedostępny (403) — karta ukrywa się automatycznie

## Kontekst

AI Assistant operuje wyłącznie na danych dostępnych w SilentPulse.
Nie spekuluje poza dostarczonymi danymi. Enrichment kontekstu:

1. Alert: typ, severity, asset, flow, pulse, grupa
2. MITRE: techniki i taktyki z enrichmentu alertu (jeśli moduł mitre włączony)
3. Security Functions: z asset group (fallback gdy brak w enrichmencie)
4. Czas ciszy: obliczany dynamicznie od `started_at`

## Implementation

### Backend

| File | Description |
|------|-------------|
| `internal/ai/provider.go` | Provider interface + factory |
| `internal/ai/openai.go` | OpenAI + OpenAI-compatible providers |
| `internal/ai/anthropic.go` | Anthropic Messages API |
| `internal/ai/prompt.go` | System/user prompt builders, AlertContext |
| `internal/ai/fallback.go` | Template-based fallback generator |
| `internal/handler/ai_assistant.go` | Handler: config CRUD, test, explain |
| `internal/handler/module_ai_assistant.go` | Module registration with routes |
| `internal/repository/postgres/ai_config_postgres.go` | AIConfig CRUD (UPSERT) |
| `internal/domain/ai.go` | AIConfig, AIExplanation domain types |

### Frontend

| File | Description |
|------|-------------|
| `app/(dashboard)/dashboard/settings/ai/page.tsx` | AI config settings page |
| `app/(dashboard)/dashboard/alerts/[id]/_components/ai-explanation-card.tsx` | Explanation card |
| `hooks/queries/use-ai.ts` | React Query hooks |
| `types/api.ts` | AIConfig, AIExplanation TypeScript types |

### Database

Table `ai_configs` (per-tenant singleton):
- `tenant_id` UUID PK + FK
- `provider` VARCHAR(20) — openai, anthropic, ollama
- `model` VARCHAR(100)
- `api_key_enc` BYTEA — encrypted API key
- `encryption_version` INT — 0 (plaintext) or 2 (per-tenant AES)
- `max_tokens` INT DEFAULT 1024
- `enabled` BOOLEAN DEFAULT false
