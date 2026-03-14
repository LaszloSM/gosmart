// GoSmart — ai-chat Edge Function
// Uses Gemini Flash (free tier) for conversational AI in Spanish
// user_id ALWAYS from JWT — never from request body

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

type Intent = "route_query" | "balance_query" | "general";

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

function buildMockRoutes() {
  // MVP heuristic — replace with A* over real stop graph in post-MVP
  return [
    {
      id: "route_fastest",
      type: "fastest",
      total_duration_min: 35,
      total_cost_cop: 2900,
      total_co2_kg: 0.4,
      legs: [{ mode: "bus", line: "Bus Expreso", duration_min: 35, cost_cop: 2900 }],
    },
    {
      id: "route_cheapest",
      type: "cheapest",
      total_duration_min: 55,
      total_cost_cop: 2400,
      total_co2_kg: 0.3,
      legs: [
        { mode: "walk", duration_min: 10, cost_cop: 0 },
        { mode: "bus", line: "Bus Zonal", duration_min: 45, cost_cop: 2400 },
      ],
    },
    {
      id: "route_eco",
      type: "eco",
      total_duration_min: 45,
      total_cost_cop: 0,
      total_co2_kg: 0.0,
      legs: [{ mode: "bike", duration_min: 45, cost_cop: 0 }],
    },
  ];
}

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

  // user_id comes from JWT — body.user_id is intentionally ignored

  let body: { query?: string; user_location?: unknown; context?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: CORS_HEADERS,
    });
  }

  const { query, user_location, context } = body;

  if (!query || typeof query !== "string") {
    return new Response(JSON.stringify({ error: "query is required" }), {
      status: 400,
      headers: CORS_HEADERS,
    });
  }

  const intent = detectIntent(query);
  const routes = intent === "route_query" ? buildMockRoutes() : null;

  // Call Gemini Flash
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  let reply = FALLBACK_REPLY;

  if (geminiKey) {
    try {
      const contents = [
        ...(context
          ? [{ role: "user", parts: [{ text: context }] }]
          : []),
        { role: "user", parts: [{ text: query }] },
      ];

      const resp = await fetch(`${GEMINI_URL}?key=${geminiKey}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents,
          generationConfig: {
            maxOutputTokens: 512,
            temperature: 0.7,
          },
        }),
      });

      if (resp.ok) {
        const data = await resp.json();
        reply =
          data.candidates?.[0]?.content?.parts?.[0]?.text ?? FALLBACK_REPLY;
      } else {
        console.warn("Gemini non-200:", resp.status);
      }
    } catch (e) {
      console.warn("Gemini call failed:", e);
      // Use FALLBACK_REPLY
    }
  }

  return new Response(
    JSON.stringify({ reply, routes, intent }),
    { headers: CORS_HEADERS },
  );
});
