# GoSmart AI Recommend — Design Spec

**Date:** 2026-03-14
**Status:** Approved
**Scope:** Incremental improvements to the existing `ai-chat` Edge Function and Flutter AI layer — endpoint contract, conversation continuity, offline fallback, latency SLA measurement.

---

## 1. Context

The existing `ai-chat` Supabase Edge Function calls Gemini 2.0 Flash with a single-turn payload (no history). The Flutter side stores messages in local widget state that resets on screen pop. Route results are hardcoded mocks (`buildMockRoutes()`), disconnected from the chat UI. There is no latency telemetry.

This spec formalises the function into a typed `/ai/recommend` contract, adds conversation continuity via client-sent history, a two-layer offline fallback, and a dev-phase SLA measurement pipeline.

---

## 2. Approach

**Single enriched endpoint** — the existing `ai-chat` function becomes the canonical `/ai/recommend` contract. No new Edge Functions. Backend stays stateless (client sends conversation history). Flutter gains a `AiConversationNotifier` Riverpod provider that owns conversation state and a recent-routes cache.

---

## 3. Endpoint Contract

### `POST /functions/v1/ai-chat`

Auth: `Authorization: Bearer <supabase-jwt>` (required — unchanged).

#### Request Body

```typescript
{
  query: string;                    // required — user's current message
  history?: ConversationTurn[];     // last ≤10 turns, client-managed
  user_location?: {
    lat: number;
    lng: number;
  };
  context?: string;                 // ambient context (neighbourhood, preferences)
}

type ConversationTurn = {
  role: "user" | "assistant";
  content: string;
};
```

#### Response Body

```typescript
{
  reply: string;                    // always present — fallback text if AI unavailable
  intent: "route_query" | "balance_query" | "general";
  routes: RouteOption[] | null;     // null when intent ≠ route_query
  latency_ms: number;               // wall-clock ms measured inside the function
  source: "gemini" | "heuristic" | "cache";
}

type RouteOption = {
  id: string;
  type: "fastest" | "cheapest" | "eco";
  total_duration_min: number;
  total_cost_cop: number;
  total_co2_kg: number;
  legs: Leg[];
};

type Leg = {
  mode: "bus" | "metro" | "cable" | "bike" | "walk" | "taxi";
  line?: string;
  duration_min: number;
  cost_cop: number;
};
```

The `source` field tells the Flutter client which path fired. Flutter renders a subtle `"estimado"` badge on route cards when `source === "heuristic"` or `"cache"`.

#### OpenAPI 3.1 Snippet

```yaml
openapi: "3.1.0"
info:
  title: GoSmart AI Recommend
  version: "1.0.0"
paths:
  /functions/v1/ai-chat:
    post:
      summary: AI route recommendation and conversational assistant
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/AiRecommendRequest"
            examples:
              route_query:
                summary: Route query with history
                value:
                  query: "¿Y si quiero ir más barato?"
                  history:
                    - role: user
                      content: "¿Cómo llego de Chapinero a La Candelaria?"
                    - role: assistant
                      content: "Puedes tomar el TransMilenio B74 (32 min, $2.900 COP)..."
                  user_location:
                    lat: 4.6486
                    lng: -74.0669
              balance_query:
                summary: Balance query, no history
                value:
                  query: "¿Cuánto saldo tengo?"
              offline_fallback:
                summary: Request that will hit heuristic
                value:
                  query: "Ruta de Medellín centro al aeropuerto"
      responses:
        "200":
          description: Successful response
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/AiRecommendResponse"
              examples:
                gemini_route:
                  value:
                    reply: "La opción más barata es el bus zonal (55 min, $2.400 COP)."
                    intent: route_query
                    source: gemini
                    latency_ms: 1840
                    routes:
                      - id: route_cheapest
                        type: cheapest
                        total_duration_min: 55
                        total_cost_cop: 2400
                        total_co2_kg: 0.3
                        legs:
                          - mode: walk
                            duration_min: 10
                            cost_cop: 0
                          - mode: bus
                            line: "Bus Zonal"
                            duration_min: 45
                            cost_cop: 2400
                heuristic_fallback:
                  value:
                    reply: "Estimado basado en datos locales — los tiempos reales pueden variar."
                    intent: route_query
                    source: heuristic
                    latency_ms: 42
                    routes:
                      - id: route_fastest
                        type: fastest
                        total_duration_min: 38
                        total_cost_cop: 2900
                        total_co2_kg: 0.4
                        legs:
                          - mode: bus
                            line: "Bus Expreso"
                            duration_min: 38
                            cost_cop: 2900
        "400":
          description: Missing or invalid query
        "401":
          description: Missing or invalid JWT
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
  schemas:
    AiRecommendRequest:
      type: object
      required: [query]
      properties:
        query:
          type: string
        history:
          type: array
          maxItems: 10
          items:
            $ref: "#/components/schemas/ConversationTurn"
        user_location:
          type: object
          properties:
            lat: { type: number }
            lng: { type: number }
        context:
          type: string
    ConversationTurn:
      type: object
      required: [role, content]
      properties:
        role:
          type: string
          enum: [user, assistant]
        content:
          type: string
    AiRecommendResponse:
      type: object
      required: [reply, intent, latency_ms, source]
      properties:
        reply:
          type: string
        intent:
          type: string
          enum: [route_query, balance_query, general]
        routes:
          type: array
          nullable: true
          items:
            $ref: "#/components/schemas/RouteOption"
        latency_ms:
          type: integer
        source:
          type: string
          enum: [gemini, heuristic, cache]
    RouteOption:
      type: object
      required: [id, type, total_duration_min, total_cost_cop, total_co2_kg, legs]
      properties:
        id: { type: string }
        type:
          type: string
          enum: [fastest, cheapest, eco]
        total_duration_min: { type: integer }
        total_cost_cop: { type: integer }
        total_co2_kg: { type: number }
        legs:
          type: array
          items:
            $ref: "#/components/schemas/Leg"
    Leg:
      type: object
      required: [mode, duration_min, cost_cop]
      properties:
        mode:
          type: string
          enum: [bus, metro, cable, bike, walk, taxi]
        line: { type: string }
        duration_min: { type: integer }
        cost_cop: { type: integer }
```

---

## 4. Conversation Continuity

### Backend (Edge Function)

`history` is injected into Gemini's `contents` array immediately before the current `query`. If `history.length > 10`, the function slices to the last 10 turns before building `contents`.

```typescript
const contents = [
  ...(context ? [{ role: "user", parts: [{ text: context }] }] : []),
  ...(history ?? []).slice(-10).map(t => ({
    role: t.role,
    parts: [{ text: t.content }],
  })),
  { role: "user", parts: [{ text: query }] },
];
```

Token budget estimate: 10 turns × ~80 tokens avg = ~800 tokens history + ~50 tokens query = ~850 tokens input. Well within Gemini Flash's 1 M token context.

### Flutter (`AiConversationNotifier`)

Replace `List<_Message>` in widget state with a `StateNotifierProvider<AiConversationNotifier, AiConversationState>`.

```dart
class AiConversationState {
  final List<AiMessage> messages;      // display list
  final List<ConversationTurn> history; // last 10 turns sent to backend
  final List<RouteOption> recentRoutes; // Riverpod cache for offline fallback
  final bool isTyping;
}
```

On each successful assistant reply:
1. Append `{ role: "user", content: query }` + `{ role: "assistant", content: reply }` to `history`.
2. Trim `history` to last 10 entries.
3. If `routes != null`, replace `recentRoutes`.

History resets only on explicit "New conversation" action — not on screen pop.

---

## 5. Offline / Fallback Strategy

### Fallback chain

```
request
  → Gemini (timeout: 3.5 s)
  → retry once after 1 s
  → Layer 1: heuristic resolver (bundled stops.json)
  → Layer 2: Riverpod recentRoutes cache
  → static fallback message
```

Worst-case user-visible latency before Layer 1 content: 3.5 s (within SLA). Total worst case (both retries fail): 7 s, but Layer 1 fires at 3.5 s so the user sees content before that.

### Layer 1 — Bundled heuristic (`assets/data/stops.json`)

```json
{
  "cities": ["Bogotá", "Medellín", "Cali", "Barranquilla", "Cartagena"],
  "modes": ["bus", "metro", "cable", "bike", "walk"],
  "cost_cop": {
    "bus": 2900, "metro": 3100, "cable": 2100, "bike": 0, "walk": 0
  },
  "avg_speed_kmh": {
    "bus": 18, "metro": 40, "cable": 12, "bike": 15, "walk": 5
  }
}
```

`buildMockRoutes()` is replaced by a resolver that uses these constants to produce plausible `RouteOption[]`. Routes are city-level (not stop-level — no A* required for prototype). Response sets `source: "heuristic"` and `reply: "Estimado basado en datos locales — los tiempos reales pueden variar."`.

### Layer 2 — Riverpod cache (Flutter-side only)

If the device is fully offline (Edge Function unreachable), `AiService.sendMessage()` catches the exception and the notifier returns `recentRoutes` with a synthetic response:

```
source: "cache"
reply: "Sin conexión. Mostrando tu última ruta guardada."
```

If `recentRoutes` is empty: static fallback message (already present in codebase).

### UI signal

Route cards render a subtle amber chip `"Estimado"` when `source` is `"heuristic"` or `"cache"`. No chip when `source === "gemini"`.

---

## 6. Latency Measurement Plan (SLA dev)

### SLA target: ≤ 4 s P95 (total perceived latency, `source: "gemini"`)

### Instrumentation points

| label | location | what |
|---|---|---|
| `t0` | Flutter `AiService.sendMessage()` entry | user taps Send |
| `t1` | Edge Function — after Gemini returns | `latency_ms` in response body |
| `t2` | Flutter notifier — reply received, setState | render complete |

- `t2 − t0` = **total perceived latency** (SLA metric)
- `t1` = **backend latency** (diagnose Gemini vs network)
- `t2 − t1` = **Flutter overhead** (target < 50 ms)

### Storage

```sql
create table ai_latency_log (
  id          bigserial primary key,
  user_id     uuid references auth.users not null default auth.uid(),
  created_at  timestamptz default now(),
  total_ms    int not null,
  backend_ms  int,
  source      text check (source in ('gemini','heuristic','cache')),
  intent      text check (intent in ('route_query','balance_query','general'))
);

-- RLS: users can only insert their own rows
alter table ai_latency_log enable row level security;
create policy "insert own" on ai_latency_log
  for insert with check (user_id = auth.uid());
```

Flutter insert is `unawaited` — never blocks UI. Gated by `kDebugMode || kProfileMode` so release builds skip it entirely.

### SLA dashboard query

```sql
select
  source,
  percentile_cont(0.50) within group (order by total_ms) as p50_ms,
  percentile_cont(0.95) within group (order by total_ms) as p95_ms,
  count(*) as n
from ai_latency_log
where created_at > now() - interval '7 days'
group by source;
```

### Alert threshold

If `p95_ms > 4000` for `source = 'gemini'` across ≥ 20 samples → investigate Gemini cold starts. Mitigation: switch to `gemini-1.5-flash-8b` (lower latency, same free tier) or add a Supabase Edge Function keep-warm cron.

---

## 7. Files Changed

| file | change |
|---|---|
| `backend/functions/ai-chat/index.ts` | Add `history[]` to request, `latency_ms` + `source` to response, replace `buildMockRoutes()` with heuristic resolver, add history injection into Gemini `contents` |
| `lib/services/ai_service.dart` | Add `history`, `latency_ms`, `source` to `AiMessage`; add `ConversationTurn` model; fire-and-forget latency log insert |
| `lib/providers/ai_conversation_provider.dart` | New `AiConversationNotifier` with history + recentRoutes state |
| `lib/features/ai_chat/ai_chat_screen.dart` | Consume `AiConversationNotifier` via Riverpod instead of local widget state |
| `assets/data/stops.json` | New bundled heuristic dataset |
| `pubspec.yaml` | Register `assets/data/stops.json` |
| `backend/migrations/004_ai_latency_log.sql` | New table + RLS policy |

---

## 8. Out of Scope

- Real stop-graph routing (A* or GTFS) — post-MVP
- Server-side conversation persistence (DB table for history) — post-MVP
- Streaming responses — post-MVP
- Large model deployment (GPT-4, Gemini Pro) — explicitly excluded from prototype
