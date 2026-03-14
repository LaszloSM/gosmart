// GoSmart — stripe-webhook Edge Function
// Handles Stripe payment_intent.succeeded events
// Security: verifies Stripe signature before processing

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno&deno-std=0.208.0";

serve(async (req: Request) => {
  // No CORS OPTIONS handler: Stripe webhooks are server-to-server only.
  // No browser preflight will reach this endpoint.
  const signature = req.headers.get("stripe-signature");
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");

  if (!signature || !webhookSecret || !stripeKey) {
    return new Response(
      JSON.stringify({ error: "Missing Stripe configuration" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const rawBody = await req.text();
  const stripe = new Stripe(stripeKey, { apiVersion: "2024-06-20" });

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      rawBody,
      signature,
      webhookSecret,
    );
  } catch (err) {
    // Return 400 for invalid signature — Stripe retries on any non-2xx, but
    // we cannot safely process events with unverified signatures. Returning 400
    // causes Stripe to retry (same as 5xx), but the signature will keep failing
    // until the webhook secret is rotated, making it the right signal.
    console.error("Stripe signature verification failed:", err);
    return new Response(
      JSON.stringify({ error: `Webhook signature failed: ${err.message}` }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  if (event.type === "payment_intent.succeeded") {
    const pi = event.data.object as Stripe.PaymentIntent;
    const cardId = pi.metadata?.card_id;

    if (!cardId) {
      console.error("Missing card_id in PaymentIntent metadata:", pi.id);
      // Return 400 (not 500): this is a permanent data error — missing metadata
      // can never be fixed by retrying. While Stripe does retry on 4xx (same as 5xx),
      // returning 400 here signals an unrecoverable configuration error that needs
      // manual investigation, distinguishable from transient 500 DB errors.
      return new Response(
        JSON.stringify({ error: "Missing card_id in metadata" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Amount: Stripe uses smallest currency unit (centavos for COP)
    const amount = pi.amount / 100;

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data, error } = await serviceClient.rpc("confirm_recharge", {
      p_stripe_payment_intent_id: pi.id,
      p_card_id: cardId,
      p_amount: amount,
    });

    if (error) {
      console.error("confirm_recharge DB error:", error);
      // Return 500 — Stripe WILL retry on 5xx
      return new Response(
        JSON.stringify({ error: "Database error" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    console.log("Recharge confirmed:", data);
  }

  // Return 200 for all other event types (Stripe requires 2xx to stop retrying)
  return new Response(
    JSON.stringify({ received: true }),
    { headers: { "Content-Type": "application/json" } },
  );
});
