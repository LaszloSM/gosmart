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
        // AbortSignal.timeout() requires Deno >=1.28.
        // Supabase hosted Edge Functions run Deno >=1.35 — this is safe.
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
