// GoSmart — authorize Edge Function
// Validates NFC/QR tap, atomically deducts balance, publishes Realtime event
// Security: user_id is ALWAYS derived from JWT, never from request body

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: CORS_HEADERS,
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Unauthorized" }, 401);

  // Client with user JWT — RLS will enforce ownership
  const userClient: SupabaseClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) return json({ error: "Unauthorized" }, 401);

  let body: {
    card_id?: string;
    validator_id?: string;
    amount?: number;
    idempotency_key?: string;
    mode?: string;
    route_id?: string;
  };

  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const { card_id, validator_id, amount, idempotency_key, mode = "bus" } =
    body;

  if (!card_id || !validator_id || !idempotency_key) {
    return json(
      { error: "Missing required fields: card_id, validator_id, amount, idempotency_key" },
      400,
    );
  }
  if (typeof amount !== "number" || amount <= 0) {
    return json({ error: "amount must be a positive number" }, 400);
  }

  // Verify card ownership via RLS (if card doesn't belong to user, returns empty)
  const { data: card, error: cardErr } = await userClient
    .from("cards")
    .select("id")
    .eq("id", card_id)
    .single();

  if (cardErr || !card) return json({ error: "Card not found" }, 404);

  // Service role client for atomic DB function (bypasses RLS)
  const serviceClient: SupabaseClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: result, error: fnErr } = await serviceClient.rpc(
    "authorize_payment",
    {
      p_card_id: card_id,
      p_amount: amount,
      p_validator_id: validator_id,
      p_idempotency_key: idempotency_key,
      p_mode: mode,
    },
  );

  if (fnErr) {
    console.error("authorize_payment error:", fnErr);
    return json({ error: "Internal error" }, 500);
  }

  // Publish Realtime event to validator channel
  if (result?.status === "authorized") {
    try {
      await serviceClient.channel(`validators:${validator_id}`).send({
        type: "broadcast",
        event: "payment",
        payload: {
          tx_id: result.tx_id,
          amount,
          card_id,
          status: "authorized",
          timestamp: new Date().toISOString(),
        },
      });
    } catch (rtErr) {
      // Non-fatal: log but don't fail the response
      console.warn("Realtime publish failed:", rtErr);
    }
  }

  const httpStatus = result?.status === "authorized"
    ? 200
    : result?.code === "INSUFFICIENT_BALANCE"
    ? 402
    : result?.code === "CARD_LOCKED"
    ? 403
    : result?.code === "CARD_NOT_FOUND"
    ? 404
    : 400;

  return json(result, httpStatus);
});
