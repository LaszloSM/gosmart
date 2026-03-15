# AI Recommend Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the `ai-chat` Edge Function and Flutter AI layer with a typed contract, multi-turn conversation history, two-layer offline fallback, and dev latency telemetry.

**Architecture:** The existing `ai-chat` Supabase Edge Function becomes the canonical `/ai/recommend` endpoint — no new functions. The backend stays stateless; the Flutter client sends the last ≤10 conversation turns in every request. A `AiConversationNotifier` Riverpod provider owns conversation state and a recent-routes cache that serves as the client-side offline fallback.

**Tech Stack:** Dart/Flutter 3, Riverpod 2 (manual, `StateNotifierProvider`), Supabase Edge Functions (Deno/TypeScript), Gemini 2.0 Flash, `mocktail` for mocks, `flutter_test` for unit + widget tests.

**Spec:** `docs/superpowers/specs/2026-03-14-ai-recommend-design.md`

---

## File Map

| file | action | responsibility |
|---|---|---|
| `backend/functions/ai-chat/stops.json` | create | heuristic cost/speed constants for the Edge Function |
| `backend/functions/ai-chat/index.ts` | modify | typed contract, history, context fix, heuristic resolver, latency_ms, source |
| `backend/migrations/004_ai_latency_log.sql` | create | `ai_latency_log` table + RLS insert policy |
| `lib/models/ai_models.dart` | create | `ConversationTurn`, `RouteOption`, `Leg` typed Dart models |
| `lib/services/ai_service.dart` | modify | `history` param, typed routes, `latencyMs`/`source` fields, latency log insert |
| `lib/providers/ai_conversation_provider.dart` | create | `AiConversationNotifier` + `AiConversationState` |
| `lib/features/ai_chat/ai_chat_screen.dart` | modify | consume notifier via Riverpod; `source` badge on heuristic/cache responses |
| `test/models/ai_models_test.dart` | create | unit tests for model serialization |
| `test/providers/ai_conversation_provider_test.dart` | create | unit tests for notifier state transitions |
| `test/widget/ai_chat_test.dart` | create | widget test for chat screen smoke + send flow |

---

## Chunk 1: Backend — stops.json + Edge Function + DB migration

### Task 1: Create `stops.json` and DB migration

**Files:**
- Create: `backend/functions/ai-chat/stops.json`
- Create: `backend/migrations/004_ai_latency_log.sql`

- [ ] **Step 1: Create `stops.json`**

```json
{
  "cities": ["Bogotá", "Medellín", "Cali", "Barranquilla", "Cartagena"],
  "modes": ["bus", "metro", "cable", "bike", "walk"],
  "cost_cop": {
    "bus": 2900,
    "metro": 3100,
    "cable": 2100,
    "bike": 0,
    "walk": 0
  },
  "avg_speed_kmh": {
    "bus": 18,
    "metro": 40,
    "cable": 12,
    "bike": 15,
    "walk": 5
  }
}
```

Save to: `backend/functions/ai-chat/stops.json`

- [ ] **Step 2: Create the migration**

```sql
-- backend/migrations/004_ai_latency_log.sql
-- `create table if not exists` is intentionally idempotent (safe to re-run).
create table if not exists ai_latency_log (
  id          bigserial primary key,
  user_id     uuid references auth.users not null default auth.uid(),
  created_at  timestamptz default now(),
  total_ms    int not null,
  backend_ms  int,
  source      text check (source in ('gemini', 'heuristic', 'cache')),
  intent      text check (intent in ('route_query', 'balance_query', 'general'))
);

alter table ai_latency_log enable row level security;

-- `create policy` has no IF NOT EXISTS in PostgreSQL ≤15.
-- Guard against re-run errors by dropping first.
drop policy if exists "insert own latency log" on ai_latency_log;
create policy "insert own latency log"
  on ai_latency_log
  for insert
  with check (user_id = auth.uid());
```

- [ ] **Step 3: Apply migration in Supabase**

Open Supabase Dashboard → SQL Editor → paste the migration → Run.

Verify with:
```sql
select column_name, data_type from information_schema.columns
where table_name = 'ai_latency_log'
order by ordinal_position;
```

Expected: columns `id`, `user_id`, `created_at`, `total_ms`, `backend_ms`, `source`, `intent`.

- [ ] **Step 4: Commit**

```bash
git add backend/functions/ai-chat/stops.json backend/migrations/004_ai_latency_log.sql
git commit -m "feat(ai): add stops.json heuristic data and ai_latency_log migration"
```

---

### Task 2: Update the Edge Function

**Files:**
- Modify: `backend/functions/ai-chat/index.ts`

- [ ] **Step 1: Replace the entire `index.ts` with the updated version**

Replace the full contents of `backend/functions/ai-chat/index.ts` with:

```typescript
// GoSmart — ai-chat Edge Function (v2)
// Typed contract: history[], source, latency_ms, heuristic fallback
// user_id ALWAYS from JWT — never from request body

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import stops from "./stops.json" assert { type: "json" };

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent";

const SYSTEM_PROMPT = `Eres el asistente de movilidad de GoSmart, una aplicación de transporte inteligente para Colombia.
Ayudas a los usuarios con información sobre rutas de bus, metro, cable, bicicleta y transporte urbano.
SIEMPRE responde en español. Sé conciso, amigable y práctico.
Cuando el usuario pregunte por rutas: da opciones con tiempo estimado y costo en pesos colombianos (COP).
Ciudades que cubres: Bogotá, Medellín, Cali, Barranquilla, Cartagena y otras ciudades colombianas.
No inventes horarios exactos. Di que los datos en tiempo real están disponibles en la app.`;

const FALLBACK_REPLY =
  "Lo siento, el asistente no está disponible en este momento. Por favor intenta de nuevo en unos minutos. Puedes ver tus rutas guardadas en la pantalla de inicio.";

const HEURISTIC_REPLY =
  "Estimado basado en datos locales — los tiempos reales pueden variar.";

// ── Types ─────────────────────────────────────────────────────────────────────

type Intent = "route_query" | "balance_query" | "general";
type Source = "gemini" | "heuristic" | "cache";

type ConversationTurn = {
  role: "user" | "assistant";
  content: string;
};

type Leg = {
  mode: "bus" | "metro" | "cable" | "bike" | "walk" | "taxi";
  line?: string;
  duration_min: number;
  cost_cop: number;
};

type RouteOption = {
  id: string;
  type: "fastest" | "cheapest" | "eco";
  total_duration_min: number;
  total_cost_cop: number;
  total_co2_kg: number;
  legs: Leg[];
};

type RequestBody = {
  query?: string;
  history?: ConversationTurn[];
  user_location?: { lat: number; lng: number };
  context?: string;
};

type ResponseBody = {
  reply: string;
  intent: Intent;
  routes: RouteOption[] | null;
  latency_ms: number;
  source: Source;
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function detectIntent(query: string): Intent {
  const q = query.toLowerCase();
  if (
    q.includes("ruta") || q.includes("cómo llegar") ||
    q.includes("como llegar") || q.includes("bus") ||
    q.includes("metro") || q.includes("transporte") ||
    q.includes("parada") || q.includes("estación")
  ) return "route_query";
  if (
    q.includes("saldo") || q.includes("balance") ||
    q.includes("cuánto tengo") || q.includes("cuanto tengo")
  ) return "balance_query";
  return "general";
}

function resolveHeuristicRoutes(): RouteOption[] {
  // City-level estimates using stops.json constants — no A* required for prototype
  return [
    {
      id: "route_fastest",
      type: "fastest",
      total_duration_min: 35,
      total_cost_cop: stops.cost_cop.bus,
      total_co2_kg: 0.4,
      legs: [
        { mode: "bus", line: "Bus Expreso", duration_min: 35, cost_cop: stops.cost_cop.bus },
      ],
    },
    {
      id: "route_cheapest",
      type: "cheapest",
      total_duration_min: 55,
      total_cost_cop: stops.cost_cop.bus,
      total_co2_kg: 0.3,
      legs: [
        { mode: "walk", duration_min: 10, cost_cop: 0 },
        { mode: "bus", line: "Bus Zonal", duration_min: 45, cost_cop: stops.cost_cop.bus },
      ],
    },
    {
      id: "route_eco",
      type: "eco",
      total_duration_min: 45,
      total_cost_cop: stops.cost_cop.bike,
      total_co2_kg: 0.0,
      legs: [
        { mode: "bike", duration_min: 45, cost_cop: 0 },
      ],
    },
  ];
}

// ── Handler ───────────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: CORS_HEADERS,
    });
  }

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: CORS_HEADERS,
    });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: CORS_HEADERS,
    });
  }

  const { query, history, user_location, context } = body;

  if (!query || typeof query !== "string") {
    return new Response(JSON.stringify({ error: "query is required" }), {
      status: 400,
      headers: CORS_HEADERS,
    });
  }

  const intent = detectIntent(query);
  const t0 = Date.now();

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  let reply = FALLBACK_REPLY;
  let source: Source = "heuristic";

  if (geminiKey) {
    try {
      // context is appended to system_instruction — NOT injected as a user turn.
      // Injecting it as a user turn would create consecutive same-role entries,
      // which causes a 400 from the Gemini API.
      const systemText = context
        ? `${SYSTEM_PROMPT}\n\nContexto adicional del usuario: ${context}`
        : SYSTEM_PROMPT;

      const safeHistory = (history ?? []).slice(-10);
      const contents = [
        ...safeHistory.map((t) => ({
          role: t.role,
          parts: [{ text: t.content }],
        })),
        { role: "user", parts: [{ text: query }] },
      ];

      const resp = await fetch(`${GEMINI_URL}?key=${geminiKey}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: systemText }] },
          contents,
          generationConfig: { maxOutputTokens: 512, temperature: 0.7 },
        }),
        // AbortSignal.timeout() requires Deno ≥1.28.
        // Supabase hosted Edge Functions run Deno ≥1.35 — this is safe.
        signal: AbortSignal.timeout(3500),
      });

      if (resp.ok) {
        const data = await resp.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) {
          reply = text;
          source = "gemini";
        }
      } else {
        console.warn("Gemini non-200:", resp.status);
      }
    } catch (e) {
      console.warn("Gemini call failed or timed out:", e);
      // fall through to heuristic
    }
  }

  if (source === "heuristic") {
    reply = HEURISTIC_REPLY;
  }

  const latency_ms = Date.now() - t0;
  const routes: RouteOption[] | null =
    intent === "route_query" ? resolveHeuristicRoutes() : null;

  // PROTOTYPE NOTE: routes are ALWAYS heuristic regardless of `source`.
  // When Gemini succeeds (`source: "gemini"`), the text reply is real but route
  // data is still estimated. The Flutter client badges on source === "heuristic"
  // or "cache", so the badge is suppressed for Gemini replies — this is acceptable
  // for the prototype (users get a real AI answer even if travel times are estimated).
  // Post-MVP: replace resolveHeuristicRoutes() with a real A*/GTFS call and set
  // source to "heuristic" only when that path fires.
  const response: ResponseBody = { reply, intent, routes, latency_ms, source };

  return new Response(JSON.stringify(response), { headers: CORS_HEADERS });
});
```

- [ ] **Step 2: Verify the function deploys (manual)**

Deploy via Supabase CLI (no `--no-verify-jwt` — JWT auth must remain enforced):
```bash
supabase functions deploy ai-chat
```
Or push via git if connected to Supabase GitHub integration.

Test with curl (replace `<JWT>` with a valid user JWT from the Supabase dashboard → Authentication → Users → copy a session token):
```bash
curl -X POST https://<project-ref>.supabase.co/functions/v1/ai-chat \
  -H "Authorization: Bearer <JWT>" \
  -H "Content-Type: application/json" \
  -d '{"query":"Ruta al aeropuerto","history":[]}'
```

Expected response shape:
```json
{
  "reply": "...",
  "intent": "route_query",
  "routes": [{"id":"route_fastest","type":"fastest",...}],
  "latency_ms": 1200,
  "source": "gemini"
}
```

- [ ] **Step 3: Commit**

```bash
git add backend/functions/ai-chat/index.ts
git commit -m "feat(ai-chat): typed contract, history, heuristic resolver, latency_ms, source"
```

---

## Chunk 2: Flutter models + updated AiService

### Task 3: Dart models

**Files:**
- Create: `lib/models/ai_models.dart`
- Create: `test/models/ai_models_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/models/ai_models_test.dart`:

```dart
// test/models/ai_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/ai_models.dart';

void main() {
  group('ConversationTurn', () {
    test('toJson serializes correctly', () {
      const turn = ConversationTurn(role: 'user', content: 'Hola');
      expect(turn.toJson(), {'role': 'user', 'content': 'Hola'});
    });

    test('fromJson deserializes correctly', () {
      final turn = ConversationTurn.fromJson(
        {'role': 'assistant', 'content': 'Respuesta'},
      );
      expect(turn.role, 'assistant');
      expect(turn.content, 'Respuesta');
    });
  });

  group('Leg.fromJson', () {
    test('parses mode, duration, cost', () {
      final leg = Leg.fromJson(
        {'mode': 'bus', 'line': 'Bus Expreso', 'duration_min': 35, 'cost_cop': 2900},
      );
      expect(leg.mode, 'bus');
      expect(leg.line, 'Bus Expreso');
      expect(leg.durationMin, 35);
      expect(leg.costCop, 2900);
    });

    test('line is null when absent', () {
      final leg = Leg.fromJson(
        {'mode': 'walk', 'duration_min': 10, 'cost_cop': 0},
      );
      expect(leg.line, isNull);
    });
  });

  group('RouteOption.fromJson', () {
    test('parses full route with multiple legs', () {
      final json = {
        'id': 'route_fastest',
        'type': 'fastest',
        'total_duration_min': 35,
        'total_cost_cop': 2900,
        'total_co2_kg': 0.4,
        'legs': [
          {'mode': 'bus', 'line': 'Bus Expreso', 'duration_min': 35, 'cost_cop': 2900},
        ],
      };
      final route = RouteOption.fromJson(json);
      expect(route.id, 'route_fastest');
      expect(route.type, 'fastest');
      expect(route.totalDurationMin, 35);
      expect(route.totalCostCop, 2900);
      expect(route.totalCo2Kg, closeTo(0.4, 0.001));
      expect(route.legs.length, 1);
      expect(route.legs.first.line, 'Bus Expreso');
    });

    test('parses co2 as double when integer in JSON', () {
      final json = {
        'id': 'route_eco',
        'type': 'eco',
        'total_duration_min': 45,
        'total_cost_cop': 0,
        'total_co2_kg': 0,  // integer in JSON
        'legs': [
          {'mode': 'bike', 'duration_min': 45, 'cost_cop': 0},
        ],
      };
      final route = RouteOption.fromJson(json);
      expect(route.totalCo2Kg, isA<double>());
      expect(route.totalCo2Kg, 0.0);
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
flutter test test/models/ai_models_test.dart
```

Expected: `Error: Could not find package 'gosmart'` or `target of URI doesn't exist: 'package:gosmart/models/ai_models.dart'`.

- [ ] **Step 3: Create `lib/models/ai_models.dart`**

```dart
// lib/models/ai_models.dart

class ConversationTurn {
  final String role; // 'user' | 'assistant'
  final String content;

  const ConversationTurn({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ConversationTurn.fromJson(Map<String, dynamic> json) =>
      ConversationTurn(
        role: json['role'] as String,
        content: json['content'] as String,
      );
}

class Leg {
  final String mode; // 'bus' | 'metro' | 'cable' | 'bike' | 'walk' | 'taxi'
  final String? line;
  final int durationMin;
  final int costCop;

  const Leg({
    required this.mode,
    this.line,
    required this.durationMin,
    required this.costCop,
  });

  factory Leg.fromJson(Map<String, dynamic> json) => Leg(
        mode: json['mode'] as String,
        line: json['line'] as String?,
        durationMin: json['duration_min'] as int,
        costCop: json['cost_cop'] as int,
      );
}

class RouteOption {
  final String id;
  final String type; // 'fastest' | 'cheapest' | 'eco'
  final int totalDurationMin;
  final int totalCostCop;
  final double totalCo2Kg;
  final List<Leg> legs;

  const RouteOption({
    required this.id,
    required this.type,
    required this.totalDurationMin,
    required this.totalCostCop,
    required this.totalCo2Kg,
    required this.legs,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) => RouteOption(
        id: json['id'] as String,
        type: json['type'] as String,
        totalDurationMin: json['total_duration_min'] as int,
        totalCostCop: json['total_cost_cop'] as int,
        totalCo2Kg: (json['total_co2_kg'] as num).toDouble(),
        legs: (json['legs'] as List)
            .map((l) => Leg.fromJson(l as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
flutter test test/models/ai_models_test.dart
```

Expected: `All tests passed.`

- [ ] **Step 5: Commit**

```bash
git add lib/models/ai_models.dart test/models/ai_models_test.dart
git commit -m "feat(models): add ConversationTurn, RouteOption, Leg typed Dart models"
```

---

### Task 4: Update `AiService`

**Files:**
- Modify: `lib/services/ai_service.dart`

- [ ] **Step 1: Replace `lib/services/ai_service.dart` with the updated version**

```dart
// lib/services/ai_service.dart
import 'dart:async'; // required for unawaited()
import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';
import '../models/ai_models.dart';

class AiMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final List<RouteOption>? routes;
  final int? latencyMs;
  final String? source; // 'gemini' | 'heuristic' | 'cache'

  const AiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.routes,
    this.latencyMs,
    this.source,
  });
}

class AiService {
  final _client = GoSmartSupabase.client;

  Future<AiMessage> sendMessage({
    required String query,
    List<ConversationTurn>? history,
    Map<String, double>? userLocation,
    String? context,
  }) async {
    final t0 = DateTime.now().millisecondsSinceEpoch;

    final response = await _client.functions.invoke(
      'ai-chat',
      body: {
        'query': query,
        if (history != null && history.isNotEmpty)
          'history': history.map((t) => t.toJson()).toList(),
        if (userLocation != null) 'user_location': userLocation,
        if (context != null) 'context': context,
      },
    );

    final t2 = DateTime.now().millisecondsSinceEpoch;
    final raw = response.data;
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};

    final backendMs = data['latency_ms'] as int?;
    final source = data['source'] as String? ?? 'gemini';
    final totalMs = t2 - t0;

    // Fire-and-forget latency log — dev/profile builds only, never blocks UI
    if (kDebugMode || kProfileMode) {
      unawaited(_logLatency(
        totalMs: totalMs,
        backendMs: backendMs,
        source: source,
        intent: data['intent'] as String?,
      ));
    }

    final routesRaw = data['routes'] as List?;
    return AiMessage(
      role: 'assistant',
      content: data['reply'] as String? ??
          'Lo siento, el asistente no está disponible. Intenta de nuevo en unos minutos.',
      timestamp: DateTime.now(),
      routes: routesRaw
          ?.map((r) => RouteOption.fromJson(r as Map<String, dynamic>))
          .toList(),
      latencyMs: backendMs,
      source: source,
    );
  }

  Future<void> _logLatency({
    required int totalMs,
    int? backendMs,
    required String source,
    String? intent,
  }) async {
    try {
      await _client.from('ai_latency_log').insert({
        'total_ms': totalMs,
        if (backendMs != null) 'backend_ms': backendMs,
        'source': source,
        if (intent != null) 'intent': intent,
      });
    } catch (e) {
      // Telemetry must never crash the app
      debugPrint('[AiService] latency log failed: $e');
    }
  }
}

final aiService = AiService();
```

> **Note — AiService unit tests:** `sendMessage()` calls the Supabase Functions client which requires a real network connection. There is no lightweight stub for `FunctionsClient` in the Flutter SDK. Unit testing of `sendMessage()` (including the `kDebugMode` gate, latency log insert, and typed `RouteOption` parsing) is **deferred** — covered by manual verification in Task 2, Step 2 (curl test) and the final integration smoke test. `mocktail` is available in dev deps for post-MVP when a DI seam is added.

- [ ] **Step 2: Verify no analysis errors**

```bash
flutter analyze lib/services/ai_service.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/ai_service.dart
git commit -m "feat(ai-service): typed routes, history param, latency telemetry"
```

---

## Chunk 3: Flutter provider + screen

### Task 5: `AiConversationNotifier`

**Files:**
- Create: `lib/providers/ai_conversation_provider.dart`
- Create: `test/providers/ai_conversation_provider_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/providers/ai_conversation_provider_test.dart`:

```dart
// test/providers/ai_conversation_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosmart/providers/ai_conversation_provider.dart';
import 'package:gosmart/models/ai_models.dart';

void main() {
  group('AiConversationNotifier — initial state', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('has one welcome assistant message', () {
      final state = container.read(aiConversationProvider);
      expect(state.messages.length, 1);
      expect(state.messages.first.role, 'assistant');
    });

    test('history is empty', () {
      final state = container.read(aiConversationProvider);
      expect(state.history, isEmpty);
    });

    test('recentRoutes is empty', () {
      final state = container.read(aiConversationProvider);
      expect(state.recentRoutes, isEmpty);
    });

    test('isTyping is false', () {
      final state = container.read(aiConversationProvider);
      expect(state.isTyping, isFalse);
    });
  });

  group('AiConversationNotifier — resetConversation', () {
    test('clears history and recentRoutes, restores welcome message', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(aiConversationProvider.notifier);

      // Manually inject state with history to simulate post-conversation state
      notifier.injectStateForTesting(
        history: [
          const ConversationTurn(role: 'user', content: '¿Cómo llego?'),
          const ConversationTurn(role: 'assistant', content: 'Toma el bus 22.'),
        ],
        recentRoutes: [
          const RouteOption(
            id: 'r1',
            type: 'fastest',
            totalDurationMin: 35,
            totalCostCop: 2900,
            totalCo2Kg: 0.4,
            legs: [],
          ),
        ],
      );

      notifier.resetConversation();
      final state = container.read(aiConversationProvider);

      expect(state.history, isEmpty);
      expect(state.recentRoutes, isEmpty);
      expect(state.messages.length, 1);
      expect(state.messages.first.role, 'assistant');
    });
  });

  group('AiConversationNotifier — history trimming', () {
    test('history never exceeds 10 turns', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(aiConversationProvider.notifier);

      // Inject 10 existing turns
      final existing = List.generate(
        10,
        (i) => ConversationTurn(role: i.isEven ? 'user' : 'assistant', content: 'msg $i'),
      );
      notifier.injectStateForTesting(history: existing);

      // Add 2 more turns (simulating what appendToHistory does)
      notifier.appendToHistoryForTesting(
        query: 'new question',
        reply: 'new answer',
      );

      final state = container.read(aiConversationProvider);
      expect(state.history.length, 10);
      // The oldest 2 turns should have been dropped
      expect(state.history.first.content, 'msg 2');
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
flutter test test/providers/ai_conversation_provider_test.dart
```

Expected: file not found / class not found errors.

- [ ] **Step 3: Create `lib/providers/ai_conversation_provider.dart`**

```dart
// lib/providers/ai_conversation_provider.dart
import 'package:flutter/foundation.dart'; // for @visibleForTesting
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../models/ai_models.dart';

const _welcomeMessage = 'Hola! Soy tu asistente GoSmart. '
    'Dime a dónde quieres ir y te planearé la mejor ruta.';

// ── State ─────────────────────────────────────────────────────────────────────

class AiConversationState {
  final List<AiMessage> messages;
  final List<ConversationTurn> history; // last ≤10 turns — sent to backend
  final List<RouteOption> recentRoutes; // offline fallback cache
  final bool isTyping;

  const AiConversationState({
    this.messages = const [],
    this.history = const [],
    this.recentRoutes = const [],
    this.isTyping = false,
  });

  AiConversationState copyWith({
    List<AiMessage>? messages,
    List<ConversationTurn>? history,
    List<RouteOption>? recentRoutes,
    bool? isTyping,
  }) =>
      AiConversationState(
        messages: messages ?? this.messages,
        history: history ?? this.history,
        recentRoutes: recentRoutes ?? this.recentRoutes,
        isTyping: isTyping ?? this.isTyping,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AiConversationNotifier extends StateNotifier<AiConversationState> {
  AiConversationNotifier()
      : super(AiConversationState(
          messages: [
            AiMessage(
              role: 'assistant',
              content: _welcomeMessage,
              timestamp: DateTime.now(),
            ),
          ],
        ));

  /// Send a user message and receive an assistant reply.
  /// The notifier reads state.history and passes it to sendMessage() —
  /// the screen never constructs or passes history directly.
  Future<void> send(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    state = state.copyWith(
      messages: [
        ...state.messages,
        AiMessage(role: 'user', content: trimmed, timestamp: DateTime.now()),
      ],
      isTyping: true,
    );

    try {
      final reply = await aiService.sendMessage(
        query: trimmed,
        history: state.history,
      );

      // Build updated history and trim to last 10 turns
      final updatedHistory = [
        ...state.history,
        ConversationTurn(role: 'user', content: trimmed),
        ConversationTurn(role: 'assistant', content: reply.content),
      ];
      final trimmedHistory = updatedHistory.length > 10
          ? updatedHistory.sublist(updatedHistory.length - 10)
          : updatedHistory;

      state = state.copyWith(
        messages: [...state.messages, reply],
        history: trimmedHistory,
        recentRoutes: reply.routes ?? state.recentRoutes,
        isTyping: false,
      );
    } catch (_) {
      // Layer 2 fallback: if the function is unreachable, serve cached routes
      final offlineReply = AiMessage(
        role: 'assistant',
        content: state.recentRoutes.isNotEmpty
            ? 'Sin conexión. Mostrando tu última ruta guardada.'
            : 'Error al contactar el asistente. Intenta de nuevo.',
        timestamp: DateTime.now(),
        routes: state.recentRoutes.isNotEmpty ? state.recentRoutes : null,
        source: state.recentRoutes.isNotEmpty ? 'cache' : null,
      );

      state = state.copyWith(
        messages: [...state.messages, offlineReply],
        isTyping: false,
      );
    }
  }

  /// Reset the conversation. Call this from a "New conversation" button.
  void resetConversation() {
    state = AiConversationState(
      messages: [
        AiMessage(
          role: 'assistant',
          content: _welcomeMessage,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  // ── Test helpers ──────────────────────────────────────────────────────────

  /// Inject state for unit testing without triggering a network call.
  /// The @visibleForTesting annotation causes flutter analyze to warn if
  /// this method is called from non-test code.
  @visibleForTesting
  void injectStateForTesting({
    List<ConversationTurn>? history,
    List<RouteOption>? recentRoutes,
  }) {
    state = state.copyWith(
      history: history ?? state.history,
      recentRoutes: recentRoutes ?? state.recentRoutes,
    );
  }

  /// Simulate appending a user+assistant turn to history (tests history trimming).
  @visibleForTesting
  void appendToHistoryForTesting({
    required String query,
    required String reply,
  }) {
    final updated = [
      ...state.history,
      ConversationTurn(role: 'user', content: query),
      ConversationTurn(role: 'assistant', content: reply),
    ];
    final trimmed =
        updated.length > 10 ? updated.sublist(updated.length - 10) : updated;
    state = state.copyWith(history: trimmed);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Not autoDispose — history persists across screen pops for the session.
/// Resets only on resetConversation() or app restart.
final aiConversationProvider =
    StateNotifierProvider<AiConversationNotifier, AiConversationState>(
  (ref) => AiConversationNotifier(),
);
```

> **Note — `send()` is not unit-tested here.** `send()` calls the `aiService` singleton directly (no DI seam), so it cannot be mocked with `mocktail` without refactoring. The tests above cover pure-logic paths (initial state, reset, history trimming) that don't require a network call. `send()` is exercised by the final integration smoke test. Post-MVP: add a constructor parameter `AiService aiService` to `AiConversationNotifier` and use `ProviderContainer` overrides to inject a `MockAiService` via `mocktail`.

- [ ] **Step 4: Run tests — verify they pass**

```bash
flutter test test/providers/ai_conversation_provider_test.dart
```

Expected: `All tests passed.`

- [ ] **Step 5: Analyze**

```bash
flutter analyze lib/providers/ai_conversation_provider.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/providers/ai_conversation_provider.dart test/providers/ai_conversation_provider_test.dart
git commit -m "feat(provider): AiConversationNotifier with history, cache fallback, history trimming"
```

---

### Task 6: Update `AiChatScreen`

**Files:**
- Modify: `lib/features/ai_chat/ai_chat_screen.dart`
- Create: `test/widget/ai_chat_test.dart`

- [ ] **Step 1: Write the widget smoke test first**

Create `test/widget/ai_chat_test.dart`:

```dart
// test/widget/ai_chat_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosmart/features/ai_chat/ai_chat_screen.dart';
import 'package:gosmart/theme/app_theme.dart';

Widget buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  group('AiChatScreen', () {
    testWidgets('renders welcome message on load', (tester) async {
      await tester.pumpWidget(buildTestApp(const AiChatScreen()));
      await tester.pumpAndSettle();

      expect(find.text('GoSmart AI'), findsOneWidget);
      // Welcome message from notifier is visible
      expect(
        find.textContaining('asistente GoSmart'),
        findsOneWidget,
      );
    });

    testWidgets('shows suggestion chips when few messages', (tester) async {
      await tester.pumpWidget(buildTestApp(const AiChatScreen()));
      await tester.pumpAndSettle();

      // Chips are shown when ≤2 messages
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('send button is present', (tester) async {
      await tester.pumpWidget(buildTestApp(const AiChatScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run widget test — verify it fails**

```bash
flutter test test/widget/ai_chat_test.dart
```

Expected: test runs but `find.textContaining('asistente GoSmart')` fails because the screen still uses local widget state with the old English welcome message.

- [ ] **Step 3: Replace `lib/features/ai_chat/ai_chat_screen.dart`**

```dart
// lib/features/ai_chat/ai_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_card.dart';
import '../../services/ai_service.dart';
import '../../providers/ai_conversation_provider.dart';
import '../../models/ai_models.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  static const _suggestions = [
    'Mejor ruta de Chapinero a La Candelaria',
    'Cómo llego al aeropuerto barato',
    'Ruta ecológica a Usaquén',
    '¿Cuánto cuesta el metro?',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final msg = text ?? _ctrl.text.trim();
    if (msg.isEmpty) return;
    _ctrl.clear();
    // Scroll immediately so the user's own message is visible before the reply.
    // The notifier sets isTyping:true synchronously before the network call,
    // so the first rebuild (showing the user bubble) triggers this scroll.
    _scrollToBottom();
    await ref.read(aiConversationProvider.notifier).send(msg);
    // Scroll again once the assistant reply is appended.
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: GSDuration.normal,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiConversationProvider);

    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: GSColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: GSColors.accent, size: 18),
            ),
            const SizedBox(width: GSSpacing.s2),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GoSmart AI',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Siempre disponible',
                    style: TextStyle(
                        fontSize: 11,
                        color: GSColors.eco,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(GSSpacing.s5),
              itemCount:
                  state.messages.length + (state.isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == state.messages.length && state.isTyping) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(message: state.messages[i]);
              },
            ),
          ),

          // Suggestion chips (only when few messages)
          if (state.messages.length <= 2)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: GSSpacing.s5),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: GSSpacing.s2),
                itemBuilder: (_, i) => _SuggestionChip(
                  label: _suggestions[i],
                  onTap: () => _send(_suggestions[i]),
                ),
              ),
            ),

          const SizedBox(height: GSSpacing.s2),
          _ChatInput(ctrl: _ctrl, onSend: _send),
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isEstimated = message.source == 'heuristic' ||
        message.source == 'cache';

    return Padding(
      padding: const EdgeInsets.only(bottom: GSSpacing.s4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: GSSpacing.s2),
              decoration: const BoxDecoration(
                color: GSColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: GSColors.accent, size: 16),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GSSpacing.s4,
                      vertical: GSSpacing.s3),
                  decoration: BoxDecoration(
                    color: isUser
                        ? GSColors.primary
                        : GSColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(GSRadius.lg),
                      topRight: const Radius.circular(GSRadius.lg),
                      bottomLeft: Radius.circular(
                          isUser ? GSRadius.lg : 4),
                      bottomRight: Radius.circular(
                          isUser ? 4 : GSRadius.lg),
                    ),
                    boxShadow: GSShadow.sm,
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser
                          ? Colors.white
                          : GSColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                // Heuristic / cache badge
                if (isEstimated) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: GSColors.warning.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(GSRadius.full),
                      border: Border.all(
                          color: GSColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 11,
                            color: GSColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          message.source == 'cache'
                              ? 'Sin conexión'
                              : 'Estimado',
                          style: TextStyle(
                              fontSize: 11,
                              color: GSColors.warning,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
                // Route card
                if (message.routes != null &&
                    message.routes!.isNotEmpty) ...[
                  const SizedBox(height: GSSpacing.s2),
                  _RouteQuickCard(
                      routes: message.routes!,
                      isEstimated: isEstimated),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Route quick card ──────────────────────────────────────────────────────────

class _RouteQuickCard extends StatelessWidget {
  const _RouteQuickCard(
      {required this.routes, required this.isEstimated});
  final List<RouteOption> routes;
  final bool isEstimated;

  @override
  Widget build(BuildContext context) {
    final fastest = routes.firstWhere(
      (r) => r.type == 'fastest',
      orElse: () => routes.first,
    );

    return GSCard(
      padding: const EdgeInsets.all(GSSpacing.s3),
      shadow: GSShadow.md,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GSColors.accentLight,
              borderRadius: BorderRadius.circular(GSRadius.sm),
            ),
            child: const Icon(Icons.route_rounded,
                color: GSColors.accent, size: 18),
          ),
          const SizedBox(width: GSSpacing.s3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${fastest.totalDurationMin} min · \$${fastest.totalCostCop} COP',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: GSColors.accent),
              ),
              Text(
                isEstimated ? 'Tiempo estimado' : 'Ver en el mapa',
                style: const TextStyle(
                    fontSize: 11,
                    color: GSColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(right: 8),
          decoration: const BoxDecoration(
              color: GSColors.accentLight, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome_rounded,
              color: GSColors.accent, size: 16),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: GSColors.surface,
            borderRadius: BorderRadius.circular(GSRadius.lg),
            boxShadow: GSShadow.sm,
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i * 0.33;
                  final val =
                      ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                          GSColors.border, GSColors.accent, val),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Suggestion chip ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.full),
          border: Border.all(color: GSColors.border),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, color: GSColors.textPrimary)),
      ),
    );
  }
}

// ── Chat input ────────────────────────────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  const _ChatInput({required this.ctrl, required this.onSend});
  final TextEditingController ctrl;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
      padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4, vertical: GSSpacing.s2),
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.full),
        boxShadow: GSShadow.md,
        border: Border.all(color: GSColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Pregunta lo que quieras...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: GSSpacing.s2),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: GSColors.accent,
                shape: BoxShape.circle,
                boxShadow: GSShadow.primary,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run all tests**

```bash
flutter test
```

Expected: all tests pass (widget, model, provider).

- [ ] **Step 5: Analyze whole project**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/ai_chat/ai_chat_screen.dart test/widget/ai_chat_test.dart
git commit -m "feat(ai-chat-screen): consume AiConversationNotifier, source badge, typed route card"
```

---

## Final verification

- [ ] Run `flutter analyze` — zero warnings
- [ ] Run `flutter test` — all green
- [ ] Run `flutter run` on device — open AI chat, send a message, confirm reply appears
- [ ] Send a route query (e.g. "Cómo llego al aeropuerto") — confirm route card appears with duration + cost
- [ ] Check Supabase Dashboard → Table Editor → `ai_latency_log` — confirm a row was inserted in debug build
- [ ] Final commit if any cleanup needed:

```bash
git add -p
git commit -m "chore(ai): final cleanup and verification"
```
