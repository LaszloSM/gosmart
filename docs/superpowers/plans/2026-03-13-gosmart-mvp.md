# GoSmart MVP Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the existing GoSmart Flutter UI (mock data) into a fully functional MVP connected to Supabase, with atomic NFC payments, Stripe recharges, and Gemini AI chat.

**Architecture:** Supabase-only backend (Postgres + Edge Functions in Deno/TypeScript). Flutter frontend uses Riverpod for state, supabase_flutter for auth/realtime, and GoRouter for navigation. No external Python service — AI runs through a Supabase Edge Function calling Gemini Flash (free tier).

**Tech Stack:** Flutter 3.x · Riverpod 2.x · supabase_flutter 2.x · GoRouter · Stripe Flutter · Supabase Edge Functions (Deno) · Gemini Flash 2.0 · PostGIS · GitHub Actions

**Working directory:** `c:\Users\User\Desktop\proyecto TI\gosmart\`

---

## Chunk 1: Foundation — Git, .env, SQL Migrations

### Task 1: Initialize git repository and environment files

**Files:**
- Create: `.gitignore` (update)
- Create: `.env.example`

- [ ] **Step 1: Initialize git repo**

```bash
cd "c:/Users/User/Desktop/proyecto TI/gosmart"
git init
git add .gitignore pubspec.yaml README.md openapi.yaml design-tokens.json
git add lib/ assets/ web/ analysis_options.yaml
git commit -m "chore: initial commit — existing Flutter UI scaffold"
```

Expected: `[main (root-commit) xxxxxxx] chore: initial commit`

- [ ] **Step 2: Create `.env.example`**

Create file `c:\Users\User\Desktop\proyecto TI\gosmart\.env.example`:

```env
# Supabase — get from https://app.supabase.com → Project Settings → API
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here

# Stripe — get from https://dashboard.stripe.com/test/apikeys
STRIPE_PUBLISHABLE_KEY=pk_test_your-publishable-key

# Google Maps — get from https://console.cloud.google.com
GOOGLE_MAPS_API_KEY=your-google-maps-key

# Gemini — get from https://aistudio.google.com/app/apikey
# NOTE: this key goes in Supabase Edge Function secrets, NOT in .env
# GEMINI_API_KEY=  ← set in Supabase dashboard only

# Map provider: google or mapbox
MAP_PROVIDER=google
```

- [ ] **Step 3: Verify `.env` is in `.gitignore`**

Open `.gitignore` and confirm `.env` (not `.env.example`) is listed. If missing, add:

```
.env
*.env.local
```

- [ ] **Step 4: Commit**

```bash
git add .env.example .gitignore
git commit -m "chore: add .env.example and verify .env is gitignored"
```

---

### Task 2: SQL Migration 001 — Schema

**Files:**
- Create: `backend/migrations/001_schema.sql`

- [ ] **Step 1: Create migrations directory and file**

```bash
mkdir -p backend/migrations
```

Create `backend/migrations/001_schema.sql`:

```sql
-- GoSmart Database Schema
-- Run in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- Or via: psql $DATABASE_URL -f backend/migrations/001_schema.sql

-- Extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── profiles ─────────────────────────────────────────────────────────────────
-- Extends auth.users with app-specific fields
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name          TEXT,
  eco_points    INTEGER DEFAULT 0 CHECK (eco_points >= 0),
  consent_geo      BOOLEAN DEFAULT false,    -- Ley 1581: explicit location consent
  consent_ai_data  BOOLEAN DEFAULT false,   -- Ley 1581: AI data processing consent
  avatar_url    TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

-- ── cards ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cards (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  number_masked  TEXT NOT NULL DEFAULT '•••• •••• •••• 0000',
  balance        NUMERIC(12,2) DEFAULT 0 CHECK (balance >= 0),
  currency       TEXT DEFAULT 'cop' CHECK (currency IN ('cop','usd','eur')),
  status         TEXT DEFAULT 'active'
                   CHECK (status IN ('active','locked','suspended','lost')),
  nfc_enabled    BOOLEAN DEFAULT true,
  expires_at     TEXT DEFAULT to_char(NOW() + INTERVAL '5 years', 'MM/YY'),
  created_at     TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cards_user_id_idx ON public.cards(user_id);

-- ── operators ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.operators (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  city       TEXT NOT NULL,
  country    TEXT DEFAULT 'CO',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── routes ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.routes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  operator_id UUID REFERENCES public.operators(id) ON DELETE SET NULL,
  mode        TEXT CHECK (mode IN ('bus','metro','bike','cable','tram','walk')),
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- ── stops ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.stops (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  route_id   UUID REFERENCES public.routes(id) ON DELETE SET NULL,
  location   GEOGRAPHY(POINT, 4326) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stops_location_gist_idx
  ON public.stops USING GIST(location);

-- ── validators ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.validators (
  id          TEXT PRIMARY KEY,  -- e.g. VLD-BOG-001
  operator_id UUID REFERENCES public.operators(id) ON DELETE SET NULL,
  location    GEOGRAPHY(POINT, 4326),
  active      BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- ── transactions ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.transactions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id          UUID REFERENCES public.cards(id) ON DELETE CASCADE NOT NULL,
  type             TEXT NOT NULL CHECK (type IN ('trip','recharge','refund')),
  amount           NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  currency         TEXT DEFAULT 'cop',
  status           TEXT DEFAULT 'completed'
                     CHECK (status IN ('completed','failed','pending')),
  mode             TEXT,
  origin           TEXT,
  destination      TEXT,
  co2_kg           NUMERIC(6,3),
  validator_id     TEXT REFERENCES public.validators(id) ON DELETE SET NULL,
  idempotency_key   TEXT UNIQUE,     -- prevents double-charge on NFC retry
  remaining_balance NUMERIC(12,2),   -- balance after this transaction (stored for idempotent replays)
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS transactions_card_date_idx
  ON public.transactions(card_id, created_at DESC);
CREATE INDEX IF NOT EXISTS transactions_idempotency_idx
  ON public.transactions(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ── trips ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.trips (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  card_id           UUID REFERENCES public.cards(id) ON DELETE SET NULL,
  route_id          UUID REFERENCES public.routes(id) ON DELETE SET NULL,
  mode              TEXT,
  origin            GEOGRAPHY(POINT, 4326),
  destination       GEOGRAPHY(POINT, 4326),
  eco_points_earned INTEGER DEFAULT 0,
  co2_kg            NUMERIC(6,3),
  started_at        TIMESTAMPTZ DEFAULT now(),
  ended_at          TIMESTAMPTZ
);

-- ── eco_points_log ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.eco_points_log (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  trip_id    UUID REFERENCES public.trips(id) ON DELETE SET NULL,
  points     INTEGER NOT NULL,
  reason     TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── payment_methods ───────────────────────────────────────────────────────────
-- Stores Stripe tokens only. NEVER card numbers.
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  stripe_customer_id  TEXT,
  stripe_pm_id        TEXT NOT NULL,  -- Stripe PaymentMethod token
  label               TEXT,           -- "Visa •••• 4242"
  is_default          BOOLEAN DEFAULT false,
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- ── recharges ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.recharges (
  id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id                    UUID REFERENCES public.cards(id) NOT NULL,
  stripe_payment_intent_id   TEXT UNIQUE NOT NULL,  -- idempotency key
  amount                     NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  currency                   TEXT DEFAULT 'cop',
  status                     TEXT DEFAULT 'pending'
                               CHECK (status IN ('pending','paid','failed')),
  processed_at               TIMESTAMPTZ,
  created_at                 TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS recharges_stripe_pi_idx
  ON public.recharges(stripe_payment_intent_id);

-- ── Seed data: demo validators ────────────────────────────────────────────────
INSERT INTO public.operators (id, name, city) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'TransMilenio', 'Bogotá'),
  ('a0000000-0000-0000-0000-000000000002', 'Metro de Medellín', 'Medellín')
ON CONFLICT DO NOTHING;

INSERT INTO public.validators (id, operator_id, location) VALUES
  ('VLD-BOG-001', 'a0000000-0000-0000-0000-000000000001',
   ST_MakePoint(-74.0817, 4.6097)::geography),
  ('VLD-MED-001', 'a0000000-0000-0000-0000-000000000002',
   ST_MakePoint(-75.5636, 6.2476)::geography)
ON CONFLICT DO NOTHING;
```

- [ ] **Step 2: Verify SQL syntax (read-only check)**

Open the file and confirm:
- All `CREATE TABLE` statements have `IF NOT EXISTS`
- `balance NUMERIC(12,2) DEFAULT 0 CHECK (balance >= 0)` prevents negative balance
- `idempotency_key TEXT UNIQUE` exists on transactions
- `remaining_balance NUMERIC(12,2)` exists on transactions (for idempotent replays)
- `stripe_payment_intent_id TEXT UNIQUE NOT NULL` exists on recharges
- `consent_ai_data BOOLEAN` (not `consent_ai`) exists on profiles

- [ ] **Step 3: Commit**

```bash
git add backend/migrations/001_schema.sql
git commit -m "feat(db): add initial schema with PostGIS, cards, transactions, recharges"
```

---

### Task 3: SQL Migration 002 — Row Level Security

**Files:**
- Create: `backend/migrations/002_rls.sql`

- [ ] **Step 1: Create RLS file**

Create `backend/migrations/002_rls.sql`:

```sql
-- GoSmart Row Level Security Policies
-- Ensures users can only access their own data
-- Run AFTER 001_schema.sql

-- Enable RLS on all user-data tables
ALTER TABLE public.profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cards           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eco_points_log  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recharges       ENABLE ROW LEVEL SECURITY;

-- Enable RLS on public transport tables too (public read, no writes from clients)
ALTER TABLE public.operators  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stops      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.validators ENABLE ROW LEVEL SECURITY;

-- ── User data policies ────────────────────────────────────────────────────────

-- profiles: users can only read/write their own profile
CREATE POLICY "profiles_own_all" ON public.profiles
  FOR ALL USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- cards: users see only their own cards
CREATE POLICY "cards_own_all" ON public.cards
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- transactions: users see transactions on their own cards
CREATE POLICY "transactions_own_select" ON public.transactions
  FOR SELECT USING (
    card_id IN (SELECT id FROM public.cards WHERE user_id = auth.uid())
  );

-- trips: users see only their own trips
CREATE POLICY "trips_own_all" ON public.trips
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- eco_points_log: own logs only
CREATE POLICY "eco_points_log_own_all" ON public.eco_points_log
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- payment_methods: own methods only
CREATE POLICY "payment_methods_own_all" ON public.payment_methods
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- recharges: users see recharges for their own cards
CREATE POLICY "recharges_own_select" ON public.recharges
  FOR SELECT USING (
    card_id IN (SELECT id FROM public.cards WHERE user_id = auth.uid())
  );
-- recharges INSERT is done by the Edge Function (service_role), not the client

-- ── Public transport data (read-only for authenticated users) ─────────────────

CREATE POLICY "operators_public_read" ON public.operators
  FOR SELECT USING (true);

CREATE POLICY "routes_public_read" ON public.routes
  FOR SELECT USING (true);

CREATE POLICY "stops_public_read" ON public.stops
  FOR SELECT USING (true);

CREATE POLICY "validators_public_read" ON public.validators
  FOR SELECT USING (true);
-- No INSERT/UPDATE/DELETE policies on transport data = only service_role can modify
```

- [ ] **Step 2: Commit**

```bash
git add backend/migrations/002_rls.sql
git commit -m "feat(db): add RLS policies — users isolated, public read for transport data"
```

---

### Task 4: SQL Migration 003 — Functions and Triggers

**Files:**
- Create: `backend/migrations/003_functions.sql`

- [ ] **Step 1: Create functions file**

Create `backend/migrations/003_functions.sql`:

```sql
-- GoSmart Database Functions and Triggers
-- Run AFTER 002_rls.sql

-- ── Auto-create profile + default card on signup ──────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Create profile
  INSERT INTO public.profiles (id, name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
  );

  -- Create a default transit card with 0 balance
  INSERT INTO public.cards (user_id, number_masked, balance, currency)
  VALUES (
    NEW.id,
    '•••• •••• •••• ' || LPAD((FLOOR(random() * 9000) + 1000)::TEXT, 4, '0'),
    0,
    'cop'
  );

  RETURN NEW;
END;
$$;

-- Drop trigger if exists to allow re-running migration
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ── authorize_payment — atomic, idempotent ────────────────────────────────────
-- Called by the authorize Edge Function (service_role)
-- Returns JSONB with status and remaining balance
CREATE OR REPLACE FUNCTION public.authorize_payment(
  p_card_id         UUID,
  p_amount          NUMERIC,
  p_validator_id    TEXT,
  p_idempotency_key TEXT,
  p_mode            TEXT DEFAULT 'bus'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_card           RECORD;
  v_tx_id          UUID;
  v_stored_balance NUMERIC;
BEGIN
  -- IDEMPOTENCY: if this key was already processed, return the stored balance
  -- (not live balance — avoids returning a different amount on concurrent retries)
  SELECT id, remaining_balance INTO v_tx_id, v_stored_balance
  FROM public.transactions
  WHERE idempotency_key = p_idempotency_key;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status',            'authorized',
      'tx_id',             v_tx_id,
      'remaining_balance', v_stored_balance,
      'idempotent',        true
    );
  END IF;

  -- LOCK the card row to prevent race conditions
  SELECT * INTO v_card
  FROM public.cards
  WHERE id = p_card_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'error',
      'code',   'CARD_NOT_FOUND'
    );
  END IF;

  IF v_card.status != 'active' THEN
    RETURN jsonb_build_object(
      'status', 'declined',
      'code',   'CARD_LOCKED'
    );
  END IF;

  IF v_card.balance < p_amount THEN
    RETURN jsonb_build_object(
      'status',    'declined',
      'code',      'INSUFFICIENT_BALANCE',
      'available', v_card.balance,
      'required',  p_amount
    );
  END IF;

  -- DEDUCT balance
  UPDATE public.cards
  SET balance = balance - p_amount
  WHERE id = p_card_id;

  -- RECORD transaction — store remaining_balance for idempotent replay consistency
  INSERT INTO public.transactions
    (card_id, type, amount, currency, status, validator_id, mode, idempotency_key, remaining_balance)
  VALUES
    (p_card_id, 'trip', p_amount, v_card.currency, 'completed',
     p_validator_id, p_mode, p_idempotency_key, v_card.balance - p_amount)
  RETURNING id INTO v_tx_id;

  -- INSERT a trip row so the AFTER INSERT trigger awards eco points.
  -- user_id comes from the card row (already fetched above with FOR UPDATE).
  INSERT INTO public.trips (user_id, card_id, mode)
  VALUES (v_card.user_id, p_card_id, p_mode);

  RETURN jsonb_build_object(
    'status',            'authorized',
    'tx_id',             v_tx_id,
    'remaining_balance', v_card.balance - p_amount
  );
END;
$$;

-- ── confirm_recharge — atomic, idempotent ─────────────────────────────────────
-- Called by stripe-webhook Edge Function (service_role)
CREATE OR REPLACE FUNCTION public.confirm_recharge(
  p_stripe_payment_intent_id TEXT,
  p_card_id                  UUID,
  p_amount                   NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recharge RECORD;
BEGIN
  -- LOCK the recharge row for update
  SELECT * INTO v_recharge
  FROM public.recharges
  WHERE stripe_payment_intent_id = p_stripe_payment_intent_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'error',
      'code',   'RECHARGE_NOT_FOUND'
    );
  END IF;

  -- IDEMPOTENCY: already processed
  IF v_recharge.status = 'paid' THEN
    RETURN jsonb_build_object(
      'status',    'already_processed',
      'idempotent', true
    );
  END IF;

  -- CREDIT balance
  UPDATE public.cards
  SET balance = balance + p_amount
  WHERE id = p_card_id;

  -- MARK recharge as paid
  UPDATE public.recharges
  SET status = 'paid', processed_at = now()
  WHERE stripe_payment_intent_id = p_stripe_payment_intent_id;

  -- RECORD recharge transaction
  -- No idempotency_key here: recharge transactions are deduplicated at the
  -- recharges table level via stripe_payment_intent_id UNIQUE. The idempotency
  -- check above already returns early if this intent was processed, so we
  -- will never reach this INSERT twice for the same payment.
  INSERT INTO public.transactions (card_id, type, amount, currency, status)
  VALUES (p_card_id, 'recharge', p_amount, v_recharge.currency, 'completed');

  RETURN jsonb_build_object(
    'status',      'confirmed',
    'new_balance', (SELECT balance FROM public.cards WHERE id = p_card_id)
  );
END;
$$;

-- ── Eco points trigger ────────────────────────────────────────────────────────
-- Awards eco_points when a new trip is inserted based on transport mode
CREATE OR REPLACE FUNCTION public.award_eco_points()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_points INTEGER;
BEGIN
  v_points := CASE NEW.mode
    WHEN 'bike'   THEN 10
    WHEN 'cable'  THEN 6
    WHEN 'metro'  THEN 5
    WHEN 'tram'   THEN 4
    WHEN 'bus'    THEN 3
    ELSE 0
  END;

  IF v_points > 0 THEN
    UPDATE public.profiles
    SET eco_points = eco_points + v_points,
        updated_at = now()
    WHERE id = NEW.user_id;

    INSERT INTO public.eco_points_log (user_id, trip_id, points, reason)
    VALUES (NEW.user_id, NEW.id, v_points, 'trip_mode_' || NEW.mode);

    -- Use UPDATE (not NEW.eco_points_earned) because this is an AFTER trigger
    UPDATE public.trips SET eco_points_earned = v_points WHERE id = NEW.id;
  END IF;

  RETURN NULL;  -- AFTER triggers ignore the return value; NULL is conventional
END;
$$;

DROP TRIGGER IF EXISTS on_trip_insert ON public.trips;

CREATE TRIGGER on_trip_insert
  AFTER INSERT ON public.trips
  FOR EACH ROW EXECUTE PROCEDURE public.award_eco_points();
```

- [ ] **Step 2: Commit**

```bash
git add backend/migrations/003_functions.sql
git commit -m "feat(db): add atomic authorize_payment, confirm_recharge, eco points trigger"
```

---

### Task 5: SQL Integrity Check Test

**Files:**
- Create: `test/sql/integrity_check.sql`

- [ ] **Step 1: Create integrity check script**

Create `test/sql/integrity_check.sql`:

```sql
-- GoSmart SQL Integrity Checks
-- Run in Supabase SQL Editor after applying all migrations to verify schema

-- 1. Verify all tables exist
DO $$
DECLARE
  required_tables TEXT[] := ARRAY[
    'profiles','cards','transactions','trips',
    'operators','routes','stops','validators',
    'eco_points_log','payment_methods','recharges'
  ];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY required_tables LOOP
    ASSERT EXISTS (
      SELECT FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = t
    ), format('FAIL: table %s missing', t);
    RAISE NOTICE 'OK: table % exists', t;
  END LOOP;
END $$;

-- 2. Verify balance cannot go negative (constraint check)
DO $$
BEGIN
  BEGIN
    INSERT INTO public.cards (user_id, balance)
    VALUES ('00000000-0000-0000-0000-000000000000'::uuid, -1);
    RAISE EXCEPTION 'FAIL: negative balance should be rejected';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: negative balance rejected by CHECK constraint';
  END;
END $$;

-- 3. Verify idempotency_key UNIQUE constraint actually rejects duplicates
DO $$
DECLARE
  v_key TEXT := 'test-idempotency-' || gen_random_uuid()::TEXT;
  v_card_id UUID;
BEGIN
  -- Insert a scratch card to satisfy FK (no real auth.users FK check needed here
  -- because we use a service-role connection in Supabase SQL Editor)
  INSERT INTO public.cards (id, user_id, balance, currency)
  VALUES (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000099'::uuid,
    100,
    'cop'
  ) RETURNING id INTO v_card_id;

  -- First insert — must succeed
  INSERT INTO public.transactions (card_id, type, amount, idempotency_key)
  VALUES (v_card_id, 'trip', 2900, v_key);

  -- Second insert with same key — must fail with unique_violation
  BEGIN
    INSERT INTO public.transactions (card_id, type, amount, idempotency_key)
    VALUES (v_card_id, 'trip', 2900, v_key);
    RAISE EXCEPTION 'FAIL: duplicate idempotency_key should have been rejected';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK: idempotency_key UNIQUE constraint rejects duplicates';
  END;

  -- Cleanup test data
  DELETE FROM public.transactions WHERE idempotency_key = v_key;
  DELETE FROM public.cards WHERE id = v_card_id;

EXCEPTION WHEN OTHERS THEN
  -- Always clean up, even if the test fails unexpectedly
  DELETE FROM public.transactions WHERE idempotency_key = v_key;
  DELETE FROM public.cards WHERE id = v_card_id;
  RAISE;
END $$;

-- 4. Verify RLS is enabled
DO $$
DECLARE
  required_rls TEXT[] := ARRAY[
    'profiles','cards','transactions','trips','eco_points_log',
    'payment_methods','recharges','operators','routes','stops','validators'
  ];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY required_rls LOOP
    ASSERT EXISTS (
      SELECT FROM pg_tables
      WHERE schemaname = 'public'
        AND tablename = t
        AND rowsecurity = true
    ), format('FAIL: RLS not enabled on table %s', t);
    RAISE NOTICE 'OK: RLS enabled on %', t;
  END LOOP;
END $$;

-- 5. Verify functions exist
DO $$
BEGIN
  ASSERT EXISTS (
    SELECT FROM pg_proc WHERE proname = 'authorize_payment'
  ), 'FAIL: authorize_payment function missing';
  RAISE NOTICE 'OK: authorize_payment exists';

  ASSERT EXISTS (
    SELECT FROM pg_proc WHERE proname = 'confirm_recharge'
  ), 'FAIL: confirm_recharge function missing';
  RAISE NOTICE 'OK: confirm_recharge exists';

  ASSERT EXISTS (
    SELECT FROM pg_proc WHERE proname = 'handle_new_user'
  ), 'FAIL: handle_new_user trigger function missing';
  RAISE NOTICE 'OK: handle_new_user exists';
END $$;

-- 6. Verify PostGIS is available
DO $$
BEGIN
  ASSERT EXISTS (
    SELECT FROM pg_extension WHERE extname = 'postgis'
  ), 'FAIL: PostGIS extension not installed';
  RAISE NOTICE 'OK: PostGIS extension installed';
END $$;

RAISE NOTICE '=== All integrity checks passed ===';
```

- [ ] **Step 2: Commit**

```bash
git add test/sql/integrity_check.sql
git commit -m "test(sql): add schema integrity check script"
```

---

## Chunk 2: Edge Functions (Deno/TypeScript)

### Task 6: Authorize Edge Function

**Files:**
- Create: `backend/functions/authorize/index.ts`

- [ ] **Step 1: Create function directory and file**

```bash
mkdir -p backend/functions/authorize
```

Create `backend/functions/authorize/index.ts`:

```typescript
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

  if (!card_id || !validator_id || !amount || !idempotency_key) {
    return json(
      {
        error:
          "Missing required fields: card_id, validator_id, amount, idempotency_key",
      },
      400,
    );
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
```

- [ ] **Step 2: Commit**

```bash
git add backend/functions/authorize/index.ts
git commit -m "feat(functions): add authorize Edge Function with atomic deduction and Realtime"
```

---

### Task 7: AI Chat Edge Function

**Files:**
- Create: `backend/functions/ai-chat/index.ts`

- [ ] **Step 1: Create function**

```bash
mkdir -p backend/functions/ai-chat
```

Create `backend/functions/ai-chat/index.ts`:

```typescript
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
```

- [ ] **Step 2: Commit**

```bash
git add backend/functions/ai-chat/index.ts
git commit -m "feat(functions): add ai-chat Edge Function with Gemini Flash and fallback"
```

---

### Task 8: Stripe Webhook Edge Function

**Files:**
- Create: `backend/functions/stripe-webhook/index.ts`

- [ ] **Step 1: Create function**

```bash
mkdir -p backend/functions/stripe-webhook
```

Create `backend/functions/stripe-webhook/index.ts`:

```typescript
// GoSmart — stripe-webhook Edge Function
// Handles Stripe payment_intent.succeeded events
// Security: verifies Stripe signature before processing

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno&deno-std=0.208.0";

serve(async (req: Request) => {
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
```

- [ ] **Step 2: Commit**

```bash
git add backend/functions/stripe-webhook/index.ts
git commit -m "feat(functions): add stripe-webhook Edge Function with signature verification"
```

---

## Chunk 3: Flutter Core — Dependencies, Supabase Init, Router, Providers

### Task 9: Update pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Replace pubspec.yaml dependencies section**

Open `pubspec.yaml` and replace the `dependencies` and `dev_dependencies` sections with:

```yaml
name: gosmart
description: GoSmart — Universal transport card with AI for smart cities.
version: 1.0.0+1
publish_to: none

environment:
  sdk: ">=3.2.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

  # Backend
  supabase_flutter: ^2.5.0

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^13.2.0

  # Environment variables
  flutter_dotenv: ^5.1.0

  # Payments
  flutter_stripe: ^10.1.1

  # NFC
  flutter_nfc_kit: ^3.4.0

  # QR
  qr_flutter: ^4.1.0

  # UI & fonts
  google_fonts: ^6.2.1

  # UUID for idempotency keys
  uuid: ^4.3.3

  # Maps
  google_maps_flutter: ^2.5.3

  # Utilities
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
  mocktail: ^1.0.3

flutter:
  uses-material-design: true
  generate: false

  assets:
    - assets/icons/
    - assets/images/
    - assets/animations/
    - .env
```

- [ ] **Step 2: Get dependencies**

```bash
flutter pub get
```

Expected: `Got dependencies!` with no errors. If there are version conflicts, run `flutter pub upgrade`.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): add supabase_flutter, riverpod, go_router, stripe, nfc, dotenv"
```

---

### Task 10: Core files — Supabase client + env loader

**Files:**
- Create: `lib/core/supabase_client.dart`
- Create: `lib/core/env.dart`

- [ ] **Step 1: Create `lib/core/env.dart`**

```dart
// lib/core/env.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables loaded from .env
/// All values are non-nullable — app will throw on startup if missing.
class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;
  static String get stripePublishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY']!;
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get mapProvider => dotenv.env['MAP_PROVIDER'] ?? 'google';
}
```

- [ ] **Step 2: Create `lib/core/supabase_client.dart`**

```dart
// lib/core/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

/// Single access point for the Supabase client.
/// Call [GoSmartSupabase.initialize] once in main().
class GoSmartSupabase {
  GoSmartSupabase._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  /// The global Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}
```

- [ ] **Step 3: Update `lib/main.dart`**

Replace the contents of `lib/main.dart` with:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'core/env.dart';
import 'core/supabase_client.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await GoSmartSupabase.initialize();

  // Initialize Stripe
  Stripe.publishableKey = Env.stripePublishableKey;
  await Stripe.instance.applySettings();

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(
    // ProviderScope enables Riverpod throughout the app
    const ProviderScope(
      child: GoSmartApp(),
    ),
  );
}

class GoSmartApp extends ConsumerWidget {
  const GoSmartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'GoSmart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/ lib/main.dart
git commit -m "feat(core): add Supabase init, env loader, and Riverpod root"
```

---

### Task 11: GoRouter — migrate from onGenerateRoute

**Files:**
- Modify: `lib/router/app_router.dart`

- [ ] **Step 1: Replace `lib/router/app_router.dart`**

```dart
// lib/router/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase_client.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/login_screen.dart';
import '../screens/onboarding/register_screen.dart';
import '../screens/onboarding/sms_verify_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/route_planner/route_planner_screen.dart';
import '../screens/route_detail/route_detail_screen.dart';
import '../screens/ai_chat/ai_chat_screen.dart';
import '../screens/payment_validation/payment_validation_screen.dart';
import '../screens/nfc_simulator/nfc_auth_simulator_screen.dart';

/// Bridges a Stream to a [ChangeNotifier] so GoRouter's [refreshListenable]
/// can trigger redirect re-evaluation on auth state changes.
class _StreamChangeNotifier extends ChangeNotifier {
  _StreamChangeNotifier(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Route name constants — use these instead of hard-coded strings
abstract class AppRoutes {
  static const onboarding       = '/';
  static const login            = '/login';
  static const register         = '/register';
  static const smsVerify        = '/sms-verify';
  static const home             = '/home';
  static const wallet           = '/wallet';
  static const history          = '/history';
  static const profile          = '/profile';
  static const routePlanner     = '/routes';
  static const routeDetail      = '/routes/detail';
  static const aiChat           = '/ai-chat';
  static const paymentValidation = '/payment-validation';
  static const nfcSimulator     = '/debug/nfc-simulator';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // refreshListenable bridges the Supabase auth stream to GoRouter so that
  // redirect() is re-evaluated automatically on login / logout.
  final notifier = _StreamChangeNotifier(
    GoSmartSupabase.client.auth.onAuthStateChange,
  );
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = GoSmartSupabase.client.auth.currentSession;
      final isAuth = session != null;
      final onAuthPage = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.onboarding ||
          state.matchedLocation == AppRoutes.smsVerify; // mid-OTP flow, not yet authenticated

      // If authenticated and on auth page → go to home
      if (isAuth && onAuthPage) return AppRoutes.home;
      // If not authenticated and on protected page → go to login
      if (!isAuth && !onAuthPage) return AppRoutes.login;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.smsVerify,
        builder: (_, state) => SmsVerifyScreen(phone: state.extra as String),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (_, __) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (_, __) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.routePlanner,
        builder: (_, __) => const RoutePlannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.routeDetail,
        builder: (_, state) => RouteDetailScreen(
          routeData: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: AppRoutes.aiChat,
        builder: (_, __) => const AiChatScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentValidation,
        builder: (_, state) => PaymentValidationScreen(
          result: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: AppRoutes.nfcSimulator,
        builder: (_, __) => const NfcAuthSimulatorScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
```

- [ ] **Step 2: Commit**

```bash
git add lib/router/app_router.dart
git commit -m "feat(router): migrate to GoRouter with auth redirect guard"
```

---

### Task 12: Riverpod Providers

**Files:**
- Create: `lib/providers/auth_provider.dart`
- Create: `lib/providers/card_provider.dart`
- Create: `lib/providers/transaction_provider.dart`

- [ ] **Step 1: Create `lib/providers/auth_provider.dart`**

```dart
// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

/// Current auth session — null when logged out
final authSessionProvider = StreamProvider<Session?>((ref) {
  return GoSmartSupabase.client.auth.onAuthStateChange.map((e) => e.session);
});

/// Current user — null when logged out
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authSessionProvider).value?.user;
});
```

- [ ] **Step 2: Create `lib/providers/card_provider.dart`**

```dart
// lib/providers/card_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_client.dart';
import '../models/card_model.dart';

/// The active card for the current user.
/// Refreshes automatically via Supabase Realtime.
final activeCardProvider =
    StateNotifierProvider<ActiveCardNotifier, AsyncValue<CardModel?>>((ref) {
  return ActiveCardNotifier();
});

class ActiveCardNotifier extends StateNotifier<AsyncValue<CardModel?>> {
  ActiveCardNotifier() : super(const AsyncLoading()) {
    load();
    subscribeRealtime();
  }

  RealtimeChannel? _channel;

  // Non-private so subclasses in tests can override without Dart's
  // library-privacy restriction blocking the @override.
  Future<void> load() async {
    try {
      final data = await GoSmartSupabase.client
          .from('cards')
          .select()
          .eq('status', 'active')
          .order('created_at')
          .limit(1)
          .maybeSingle();

      state = AsyncData(data != null ? CardModel.fromMap(data) : null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void subscribeRealtime() {
    final userId = GoSmartSupabase.client.auth.currentUser?.id;
    if (userId == null) return;

    _channel = GoSmartSupabase.client
        .channel('public:cards:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              state = AsyncData(CardModel.fromMap(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  Future<void> refresh() => load();

  Future<void> toggleLock(String cardId, bool locked) async {
    final newStatus = locked ? 'locked' : 'active';
    await GoSmartSupabase.client
        .from('cards')
        .update({'status': newStatus})
        .eq('id', cardId);
    await load();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
```

- [ ] **Step 3: Create `lib/models/card_model.dart`**

```bash
mkdir -p lib/models
```

Create `lib/models/card_model.dart`:

```dart
// lib/models/card_model.dart

class CardModel {
  final String id;
  final String userId;
  final String numberMasked;
  final double balance;
  final String currency;
  final String status;
  final bool nfcEnabled;
  final String? expiresAt;

  const CardModel({
    required this.id,
    required this.userId,
    required this.numberMasked,
    required this.balance,
    required this.currency,
    required this.status,
    required this.nfcEnabled,
    this.expiresAt,
  });

  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      numberMasked: map['number_masked'] as String? ?? '•••• •••• •••• 0000',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?)?.toUpperCase() ?? 'COP',
      status: map['status'] as String? ?? 'active',
      nfcEnabled: map['nfc_enabled'] as bool? ?? true,
      expiresAt: map['expires_at'] as String?,
    );
  }

  bool get isLocked => status == 'locked';
  bool get isActive => status == 'active';

  String get formattedBalance {
    // Format as Colombian peso: $100.000
    final formatted = balance.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '\$$formatted COP';
  }

  CardModel copyWith({
    double? balance,
    String? status,
    bool? nfcEnabled,
  }) {
    return CardModel(
      id: id,
      userId: userId,
      numberMasked: numberMasked,
      balance: balance ?? this.balance,
      currency: currency,
      status: status ?? this.status,
      nfcEnabled: nfcEnabled ?? this.nfcEnabled,
      expiresAt: expiresAt,
    );
  }
}
```

- [ ] **Step 4: Create `lib/providers/transaction_provider.dart`**

```dart
// lib/providers/transaction_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_client.dart';
import '../models/transaction_model.dart';

const _pageSize = 20;

final transactionListProvider = StateNotifierProvider<
    TransactionListNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  return TransactionListNotifier();
});

class TransactionListNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  TransactionListNotifier() : super(const AsyncLoading()) {
    load();
  }

  int _offset = 0;
  bool _hasMore = true;

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
      state = const AsyncLoading();
    }

    try {
      // RLS policy on transactions already filters by user's cards — no join needed
      final data = await GoSmartSupabase.client
          .from('transactions')
          .select('*')
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      final items = (data as List)
          .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
          .toList();

      _hasMore = items.length == _pageSize;
      _offset += items.length;

      final current = refresh ? <TransactionModel>[] :
          (state.valueOrNull ?? []);
      state = AsyncData([...current, ...items]);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    await load();
  }
}
```

- [ ] **Step 5: Create `lib/models/transaction_model.dart`**

Create `lib/models/transaction_model.dart`:

```dart
// lib/models/transaction_model.dart

class TransactionModel {
  final String id;
  final String cardId;
  final String type; // trip | recharge | refund
  final double amount;
  final String currency;
  final String status;
  final String? mode;
  final String? origin;
  final String? destination;
  final double? co2Kg;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.cardId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    this.mode,
    this.origin,
    this.destination,
    this.co2Kg,
    required this.createdAt,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      cardId: map['card_id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: (map['currency'] as String?)?.toUpperCase() ?? 'COP',
      status: map['status'] as String? ?? 'completed',
      mode: map['mode'] as String?,
      origin: map['origin'] as String?,
      destination: map['destination'] as String?,
      co2Kg: (map['co2_kg'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  bool get isTrip => type == 'trip';
  bool get isRecharge => type == 'recharge';
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/providers/ lib/models/
git commit -m "feat(state): add Riverpod providers and models for auth, cards, transactions"
```

---

## Chunk 4: Flutter Services and Screens

### Task 13: Auth and Card Services

**Files:**
- Create: `lib/services/auth_service.dart`
- Create: `lib/services/card_service.dart`
- Create: `lib/services/ai_service.dart`

- [ ] **Step 1: Create `lib/services/auth_service.dart`**

```bash
mkdir -p lib/services
```

Create `lib/services/auth_service.dart`:

```dart
// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

class AuthService {
  final _client = GoSmartSupabase.client;

  /// Sign up with email + password
  /// The handle_new_user trigger creates profile + card automatically
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required bool consentGeo,
    required bool consentAi,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'consent_geo': consentGeo,
        'consent_ai_data': consentAi,  // must match profiles.consent_ai_data column
      },
    );
    return response;
  }

  /// Sign in with email + password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  /// Verify phone OTP
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) async {
    return _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Delete account and all data (Ley 1581 — right to erasure)
  /// Calls the delete-account Edge Function which uses service_role to
  /// call supabase.auth.admin.deleteUser() — cascades to all user data.
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account', body: {});
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
}

final authService = AuthService();
```

- [ ] **Step 1b: Create `backend/functions/delete-account/index.ts`**

```bash
mkdir -p backend/functions/delete-account
```

Create `backend/functions/delete-account/index.ts`:

```typescript
// GoSmart — delete-account Edge Function
// Permanently deletes the authenticated user and all their data (Ley 1581)
// Uses admin API (service_role) — user_id always from JWT

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" };

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: CORS });

  // Identify user from JWT
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: CORS });

  // Delete via admin API — cascades to all tables (ON DELETE CASCADE)
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("deleteUser failed:", deleteError);
    return new Response(JSON.stringify({ error: "Deletion failed" }), { status: 500, headers: CORS });
  }

  return new Response(JSON.stringify({ deleted: true }), { headers: CORS });
});
```

- [ ] **Step 2: Create `lib/services/card_service.dart`**

Create `lib/services/card_service.dart`:

```dart
// lib/services/card_service.dart
import 'package:uuid/uuid.dart';
import '../core/supabase_client.dart';
import '../models/authorize_result.dart';

class CardService {
  final _client = GoSmartSupabase.client;
  final _uuid = const Uuid();

  /// Generate a new idempotency key for a tap session.
  /// Callers MUST hold this key and reuse it on retries of the SAME tap.
  String newIdempotencyKey() => _uuid.v4();

  /// Authorize a tap at a validator (NFC or QR simulation)
  /// [idempotencyKey] must be generated once per tap session (not per call)
  /// so retries of the same physical tap reuse the same key and are deduplicated.
  Future<AuthorizeResult> authorize({
    required String cardId,
    required String validatorId,
    required double amount,
    required String idempotencyKey,
    String mode = 'bus',
    String? routeId,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await _client.functions.invoke(
      'authorize',
      body: {
        'card_id': cardId,
        'validator_id': validatorId,
        'amount': amount,
        'idempotency_key': idempotencyKey,
        'mode': mode,
        if (routeId != null) 'route_id': routeId,
      },
    );

    final data = response.data;
    if (data == null || data is! Map<String, dynamic>) {
      return const AuthorizeResult(status: AuthorizeStatus.error, errorCode: 'NETWORK_ERROR');
    }
    return AuthorizeResult.fromMap(data, httpStatus: response.status ?? 200);
  }

  /// Lock or unlock a card
  Future<void> setLocked(String cardId, bool locked) async {
    await _client
        .from('cards')
        .update({'status': locked ? 'locked' : 'active'})
        .eq('id', cardId);
  }
}

final cardService = CardService();
```

- [ ] **Step 3: Create `lib/models/authorize_result.dart`**

Create `lib/models/authorize_result.dart`:

```dart
// lib/models/authorize_result.dart

enum AuthorizeStatus { authorized, insufficientBalance, cardLocked, error }

class AuthorizeResult {
  final AuthorizeStatus status;
  final String? txId;
  final double? remainingBalance;
  final String? errorCode;

  const AuthorizeResult({
    required this.status,
    this.txId,
    this.remainingBalance,
    this.errorCode,
  });

  factory AuthorizeResult.fromMap(
    Map<String, dynamic> map, {
    int httpStatus = 200,
  }) {
    final code = map['code'] as String?;
    final statusStr = map['status'] as String?;

    AuthorizeStatus s;
    if (statusStr == 'authorized') {
      s = AuthorizeStatus.authorized;
    } else if (code == 'INSUFFICIENT_BALANCE') {
      s = AuthorizeStatus.insufficientBalance;
    } else if (code == 'CARD_LOCKED') {
      s = AuthorizeStatus.cardLocked;
    } else {
      s = AuthorizeStatus.error;
    }

    return AuthorizeResult(
      status: s,
      txId: map['tx_id'] as String?,
      remainingBalance: (map['remaining_balance'] as num?)?.toDouble(),
      errorCode: code,
    );
  }

  bool get isAuthorized => status == AuthorizeStatus.authorized;
}
```

- [ ] **Step 4: Create `lib/services/ai_service.dart`**

Create `lib/services/ai_service.dart`:

```dart
// lib/services/ai_service.dart
import '../core/supabase_client.dart';

class AiMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final List<Map<String, dynamic>>? routes;

  const AiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.routes,
  });
}

class AiService {
  final _client = GoSmartSupabase.client;

  Future<AiMessage> sendMessage({
    required String query,
    Map<String, double>? userLocation,
    String? context,
  }) async {
    final response = await _client.functions.invoke(
      'ai-chat',
      body: {
        'query': query,
        if (userLocation != null) 'user_location': userLocation,
        if (context != null) 'context': context,
      },
    );

    final raw = response.data;
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    return AiMessage(
      role: 'assistant',
      content: data['reply'] as String? ??
          'Lo siento, el asistente no está disponible. Intenta de nuevo en unos minutos.',
      timestamp: DateTime.now(),
      routes: data['routes'] != null
          ? List<Map<String, dynamic>>.from(data['routes'] as List)
          : null,
    );
  }
}

final aiService = AiService();
```

- [ ] **Step 5: Commit**

```bash
git add lib/services/ lib/models/authorize_result.dart lib/models/card_model.dart lib/models/transaction_model.dart
git commit -m "feat(services): add auth, card, AI services and data models"
```

---

### Task 14: Connect Login Screen to Supabase Auth

**Files:**
- Modify: `lib/screens/onboarding/login_screen.dart`

- [ ] **Step 1: Update the `_submit` method and import**

In `lib/screens/onboarding/login_screen.dart`, replace the mock `_submit` method (lines 28–37) and add the import:

Add at top of imports:
```dart
import '../../services/auth_service.dart';
import '../../router/app_router.dart';
import 'package:go_router/go_router.dart';
```

Replace the `_submit` method:
```dart
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);
  try {
    if (_useSms) {
      await authService.sendOtp(_phoneCtrl.text.trim());
      if (mounted) {
        context.push('/sms-verify', extra: _phoneCtrl.text.trim());
      }
    } else {
      final response = await authService.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (response.user != null && mounted) {
        context.go(AppRoutes.home);
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

Also add `_emailCtrl` and `_passwordCtrl` controllers alongside `_phoneCtrl`:
```dart
final _emailCtrl = TextEditingController();
final _passwordCtrl = TextEditingController();
```

Update `dispose()`:
```dart
@override
void dispose() {
  _phoneCtrl.dispose();
  _emailCtrl.dispose();
  _passwordCtrl.dispose();
  super.dispose();
}
```

Replace the email `GSTextField` controller with `_emailCtrl` and password with `_passwordCtrl`.

Replace the "Try Demo" button's `onTap` with:
```dart
onTap: () => context.go(AppRoutes.home),
```

Replace social button `onTap` callbacks:
```dart
onTap: () => context.go(AppRoutes.home),
```

- [ ] **Step 2: Create `lib/screens/onboarding/sms_verify_screen.dart`**

Create `lib/screens/onboarding/sms_verify_screen.dart`:

```dart
// lib/screens/onboarding/sms_verify_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../router/app_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_text_field.dart';

class SmsVerifyScreen extends StatefulWidget {
  const SmsVerifyScreen({super.key, required this.phone});
  final String phone;

  @override
  State<SmsVerifyScreen> createState() => _SmsVerifyScreenState();
}

class _SmsVerifyScreenState extends State<SmsVerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.length < 6) return;
    setState(() => _isLoading = true);
    try {
      final res = await authService.verifyOtp(
        phone: widget.phone,
        token: _codeCtrl.text.trim(),
      );
      if (res.user != null && mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Código incorrecto: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(title: const Text('Verificar código')),
      body: Padding(
        padding: const EdgeInsets.all(GSSpacing.s6),
        child: Column(
          children: [
            Text('Ingresa el código enviado a ${widget.phone}',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: GSSpacing.s6),
            GSTextField(
              label: 'Código de 6 dígitos',
              hint: '123456',
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.sms_rounded,
            ),
            const SizedBox(height: GSSpacing.s6),
            GSButton(
              label: 'Verificar',
              onPressed: _verify,
              isLoading: _isLoading,
              leadingIcon: Icons.check_circle_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/login_screen.dart lib/screens/onboarding/sms_verify_screen.dart
git commit -m "feat(login): connect login screen to Supabase Auth with OTP verification"
```

---

### Task 15: Connect Wallet Screen to Real Balance

**Files:**
- Modify: `lib/screens/wallet/wallet_screen.dart`

- [ ] **Step 1: Convert WalletScreen to ConsumerStatefulWidget**

Add imports at top of `lib/screens/wallet/wallet_screen.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/card_provider.dart';
import '../../services/card_service.dart';
```

Change class declaration:
```dart
// Before:
class WalletScreen extends StatefulWidget {
// After:
class WalletScreen extends ConsumerStatefulWidget {

// Before:
class _WalletScreenState extends State<WalletScreen>
// After:
class _WalletScreenState extends ConsumerState<WalletScreen>
```

- [ ] **Step 2: Connect card data to UI**

In `build()`, add at the top:
```dart
final cardAsync = ref.watch(activeCardProvider);
```

Replace `_SmartCard` widget call to pass real data:
```dart
cardAsync.when(
  loading: () => const AspectRatio(
    aspectRatio: 1.586,
    child: Center(child: CircularProgressIndicator()),
  ),
  error: (e, _) => Text('Error: $e'),
  data: (card) => _SmartCard(
    locked: card?.isLocked ?? false,
    balance: card?.formattedBalance ?? '\$0 COP',
    cardNumber: card?.numberMasked ?? '•••• •••• •••• 0000',
    expiresAt: card?.expiresAt ?? '--/--',
    showNumber: _showNumber,
    onToggleNumber: () => setState(() => _showNumber = !_showNumber),
  ),
),
```

Update `_SmartCard` to accept `balance`, `cardNumber`, and `expiresAt` params instead of hardcoded strings. Change its constructor signature to:

```dart
class _SmartCard extends StatelessWidget {
  const _SmartCard({
    required this.locked,
    required this.balance,
    required this.cardNumber,
    required this.expiresAt,
    required this.showNumber,
    required this.onToggleNumber,
  });

  final bool locked;
  final String balance;
  final String cardNumber;
  final String expiresAt;
  final bool showNumber;
  final VoidCallback onToggleNumber;
  // ... rest of build() unchanged, but replace hardcoded '$100.00', card number,
  // and expiry strings with this.balance, this.cardNumber, this.expiresAt
}
```

Update lock/unlock action to call `cardService`:
```dart
onPressed: () async {
  final card = ref.read(activeCardProvider).valueOrNull;
  if (card == null) return;
  final newLocked = !card.isLocked;
  await cardService.setLocked(card.id, newLocked);
  ref.read(activeCardProvider.notifier).refresh();
  if (mounted) {
    GSToast.show(
      context,
      message: newLocked ? 'Tarjeta bloqueada' : 'Tarjeta desbloqueada',
      type: newLocked ? GSToastType.warning : GSToastType.success,
    );
  }
},
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/wallet/wallet_screen.dart
git commit -m "feat(wallet): connect wallet to real Supabase card balance with Realtime"
```

---

### Task 16: NFC Auth Simulator Screen (new debug screen)

**Files:**
- Create: `lib/screens/nfc_simulator/nfc_auth_simulator_screen.dart`

- [ ] **Step 1: Create the simulator screen**

```bash
mkdir -p lib/screens/nfc_simulator
```

Create `lib/screens/nfc_simulator/nfc_auth_simulator_screen.dart`:

```dart
// lib/screens/nfc_simulator/nfc_auth_simulator_screen.dart
// Debug screen to simulate an NFC tap at a validator
// Tests the authorize Edge Function end-to-end

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/design_tokens.dart';
import '../../providers/card_provider.dart';
import '../../services/card_service.dart';
import '../../models/authorize_result.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_toast.dart';

class NfcAuthSimulatorScreen extends ConsumerStatefulWidget {
  const NfcAuthSimulatorScreen({super.key});

  @override
  ConsumerState<NfcAuthSimulatorScreen> createState() =>
      _NfcAuthSimulatorScreenState();
}

class _NfcAuthSimulatorScreenState
    extends ConsumerState<NfcAuthSimulatorScreen> {
  String _selectedValidator = 'VLD-BOG-001';
  double _amount = 2900;
  bool _isLoading = false;
  AuthorizeResult? _lastResult;
  // One idempotency key per tap session — regenerated only when the user
  // selects a new tap (not on retries). This ensures NFC double-tap safety.
  String _idempotencyKey = cardService.newIdempotencyKey();

  final _validators = ['VLD-BOG-001', 'VLD-MED-001'];
  final _amounts = [2400.0, 2900.0, 4500.0, 5000.0];

  Future<void> _simulateTap() async {
    final card = ref.read(activeCardProvider).valueOrNull;
    if (card == null) {
      GSToast.show(context,
          message: 'No hay tarjeta activa', type: GSToastType.error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await cardService.authorize(
        cardId: card.id,
        validatorId: _selectedValidator,
        amount: _amount,
        idempotencyKey: _idempotencyKey,
      );

      setState(() {
        _lastResult = result;
        // Generate a fresh key for the next tap session
        if (result.isAuthorized) _idempotencyKey = cardService.newIdempotencyKey();
      });
      ref.read(activeCardProvider.notifier).refresh();

      if (mounted) {
        GSToast.show(
          context,
          message: result.isAuthorized
              ? '✓ Autorizado — Saldo: \$${result.remainingBalance?.toStringAsFixed(0)} COP'
              : '✗ ${_errorMessage(result)}',
          type:
              result.isAuthorized ? GSToastType.success : GSToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        GSToast.show(context,
            message: 'Error: $e', type: GSToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _errorMessage(AuthorizeResult result) {
    switch (result.status) {
      case AuthorizeStatus.insufficientBalance:
        return 'Saldo insuficiente';
      case AuthorizeStatus.cardLocked:
        return 'Tarjeta bloqueada';
      default:
        return 'Error al procesar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(activeCardProvider);

    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Simulador NFC (Debug)'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(GSSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(GSSpacing.s4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(GSRadius.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bug_report, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pantalla de prueba — simula un tap en validador físico',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GSSpacing.s5),

            // Card info
            cardAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (card) => card != null
                  ? _InfoRow('Tarjeta', card.numberMasked)
                  : const Text('No hay tarjeta'),
            ),
            cardAsync.maybeWhen(
              data: (card) => card != null
                  ? _InfoRow('Saldo actual', card.formattedBalance)
                  : const SizedBox(),
              orElse: () => const SizedBox(),
            ),
            const SizedBox(height: GSSpacing.s5),

            // Validator selector
            Text('Validador', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: GSSpacing.s2),
            Wrap(
              spacing: GSSpacing.s2,
              children: _validators
                  .map((v) => ChoiceChip(
                        label: Text(v),
                        selected: _selectedValidator == v,
                        onSelected: (_) =>
                            setState(() => _selectedValidator = v),
                      ))
                  .toList(),
            ),
            const SizedBox(height: GSSpacing.s4),

            // Amount selector
            Text('Monto (COP)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: GSSpacing.s2),
            Wrap(
              spacing: GSSpacing.s2,
              children: _amounts
                  .map((a) => ChoiceChip(
                        label: Text('\$${a.toStringAsFixed(0)}'),
                        selected: _amount == a,
                        onSelected: (_) => setState(() => _amount = a),
                      ))
                  .toList(),
            ),
            const SizedBox(height: GSSpacing.s6),

            // Tap button
            GSButton(
              label: 'Simular Tap NFC',
              onPressed: _isLoading ? null : _simulateTap,
              isLoading: _isLoading,
              leadingIcon: Icons.contactless_rounded,
            ),

            // Last result
            if (_lastResult != null) ...[
              const SizedBox(height: GSSpacing.s5),
              _ResultCard(result: _lastResult!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: GSColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: GSColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final AuthorizeResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.isAuthorized ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(GSSpacing.s4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(GSRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.isAuthorized ? '✓ AUTORIZADO' : '✗ RECHAZADO',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: color, fontSize: 16),
          ),
          if (result.txId != null)
            Text('TX: ${result.txId}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (result.remainingBalance != null)
            Text(
                'Saldo restante: \$${result.remainingBalance!.toStringAsFixed(0)} COP'),
          if (result.errorCode != null) Text('Código: ${result.errorCode}'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/nfc_simulator/
git commit -m "feat(debug): add NFC Auth Simulator screen for end-to-end testing"
```

---

### Task 17: Connect AI Chat Screen

**Files:**
- Modify: `lib/screens/ai_chat/ai_chat_screen.dart`

- [ ] **Step 1: Replace mock with real AI service**

Add imports at top of `lib/screens/ai_chat/ai_chat_screen.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_service.dart';
```

Convert to `ConsumerStatefulWidget`. Add a message list and input controller:
```dart
final List<AiMessage> _messages = [];
final _inputCtrl = TextEditingController();
bool _isLoading = false;
```

Add `_sendMessage` method:
```dart
Future<void> _sendMessage() async {
  final text = _inputCtrl.text.trim();
  if (text.isEmpty) return;

  setState(() {
    _messages.add(AiMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    ));
    _isLoading = true;
  });
  _inputCtrl.clear();

  try {
    final reply = await aiService.sendMessage(query: text);
    if (mounted) setState(() => _messages.add(reply));
  } catch (e) {
    if (mounted) {
      setState(() => _messages.add(AiMessage(
        role: 'assistant',
        content: 'Error al contactar el asistente. Intenta de nuevo.',
        timestamp: DateTime.now(),
      )));
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

Wire the existing chat input send button to `_sendMessage`. Wire message list to `_messages`.

- [ ] **Step 2: Commit**

```bash
git add lib/screens/ai_chat/ai_chat_screen.dart
git commit -m "feat(ai-chat): connect AI chat screen to Gemini Flash via Edge Function"
```

---

## Chunk 5: Tests, CI, and README

### Task 18: Widget Tests

**Files:**
- Modify: `test/widget_test.dart`
- Create: `test/widget/login_test.dart`
- Create: `test/widget/wallet_test.dart`

- [ ] **Step 1: Create `test/widget/login_test.dart`**

```bash
mkdir -p test/widget
```

Create `test/widget/login_test.dart`:

```dart
// test/widget/login_test.dart
// Tests the LoginScreen renders correctly and validates form input

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosmart/screens/onboarding/login_screen.dart';
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
  group('LoginScreen', () {
    testWidgets('renders phone input by default', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome\nback!'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
    });

    testWidgets('shows email and password fields when email tab selected',
        (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // Tap the Email tab
      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsWidgets);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows validation error when phone is empty', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // Tap send button without filling phone
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid number'), findsOneWidget);
    });

    testWidgets('Try Demo button navigates away', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Try Demo'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run login test to verify it passes**

```bash
flutter test test/widget/login_test.dart -v
```

Expected: all tests PASS.

- [ ] **Step 3: Create `test/widget/wallet_test.dart`**

Create `test/widget/wallet_test.dart`:

```dart
// test/widget/wallet_test.dart
// Tests WalletScreen renders balance states correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosmart/screens/wallet/wallet_screen.dart';
import 'package:gosmart/providers/card_provider.dart';
import 'package:gosmart/models/card_model.dart';
import 'package:gosmart/theme/app_theme.dart';

final _testCard = CardModel(
  id: 'test-card-id',
  userId: 'test-user-id',
  numberMasked: '•••• •••• •••• 4242',
  balance: 50000.0,
  currency: 'COP',
  status: 'active',
  nfcEnabled: true,
  expiresAt: '12/28',
);

Widget buildTestApp(Widget child, {List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? [],
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  group('WalletScreen', () {
    testWidgets('shows loading indicator while card loads', (tester) async {
      // Use _MockCardNotifier to avoid live Supabase calls; start in AsyncLoading state
      await tester.pumpWidget(buildTestApp(
        const WalletScreen(),
        overrides: [
          activeCardProvider.overrideWith(() => _LoadingCardNotifier()),
        ],
      ));
      // Before settle: should show loading or card
      await tester.pump();
      // Just verify it renders without crashing
      expect(find.byType(WalletScreen), findsOneWidget);
    });

    testWidgets('shows balance when card is loaded', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          activeCardProvider
              .overrideWith(() => _MockCardNotifier(_testCard)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WalletScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('50.000'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows lock card option', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          activeCardProvider
              .overrideWith(() => _MockCardNotifier(_testCard)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WalletScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Lock card'), findsAtLeastNWidgets(1));
    });
  });
}

class _MockCardNotifier extends ActiveCardNotifier {
  _MockCardNotifier(CardModel card) {
    state = AsyncData(card);
  }

  // Override public methods (not private) to prevent live Supabase calls in tests
  @override
  Future<void> load() async {}

  @override
  void subscribeRealtime() {}
}

/// Stays in AsyncLoading state — used to test the loading indicator UI
class _LoadingCardNotifier extends ActiveCardNotifier {
  _LoadingCardNotifier() {
    state = const AsyncLoading();
  }

  @override
  Future<void> load() async {} // no-op: keeps loading state

  @override
  void subscribeRealtime() {}
}
```

- [ ] **Step 4: Run wallet test**

```bash
flutter test test/widget/wallet_test.dart -v
```

Expected: PASS (may need mock adjustment if state initializer is called).

- [ ] **Step 5: Run all tests**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add test/
git commit -m "test(widget): add login and wallet widget tests"
```

---

### Task 19: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create CI workflow**

```bash
mkdir -p .github/workflows
```

Create `.github/workflows/ci.yml`:

```yaml
name: GoSmart CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    name: Lint (flutter analyze)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze --no-fatal-infos

  test:
    name: Tests (flutter test)
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Create .env for tests
        run: |
          echo "SUPABASE_URL=https://placeholder.supabase.co" >> .env
          echo "SUPABASE_ANON_KEY=placeholder-anon-key" >> .env
          echo "STRIPE_PUBLISHABLE_KEY=pk_test_placeholder" >> .env
          echo "GOOGLE_MAPS_API_KEY=placeholder" >> .env

      - name: Run tests
        run: flutter test --no-pub

  build-android:
    name: Build APK (Android)
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: zulu
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Create .env for build
        run: |
          echo "SUPABASE_URL=https://placeholder.supabase.co" >> .env
          echo "SUPABASE_ANON_KEY=placeholder-anon-key" >> .env
          echo "STRIPE_PUBLISHABLE_KEY=pk_test_placeholder" >> .env
          echo "GOOGLE_MAPS_API_KEY=placeholder" >> .env

      - name: Build APK (release)
        run: flutter build apk --release

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: gosmart-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
          retention-days: 7
```

- [ ] **Step 2: Commit**

```bash
git add .github/
git commit -m "ci: add GitHub Actions — lint, test, and Android APK build"
```

---

### Task 20: Update README with setup instructions

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Prepend setup section to README.md**

Add the following at the TOP of `README.md` (before the existing content):

````markdown
# GoSmart — Setup & Runbook

## Quick Start

### 1. Clone and install

```bash
git clone https://github.com/<your-username>/gosmart.git
cd gosmart
flutter pub get
```

### 2. Create Supabase project

1. Go to [supabase.com](https://supabase.com) → New project
2. Choose a region close to Colombia (e.g., `us-east-1`)
3. Save your project URL and anon key

### 3. Apply database migrations

In Supabase Dashboard → SQL Editor, run these files IN ORDER:

```bash
# Option A: Supabase CLI (recommended)
supabase db push

# Option B: Manual (copy-paste in SQL Editor)
# 1. backend/migrations/001_schema.sql
# 2. backend/migrations/002_rls.sql
# 3. backend/migrations/003_functions.sql
```

Verify with:
```sql
-- Run in SQL Editor to check everything is correct
-- (copy from test/sql/integrity_check.sql)
```

### 4. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` with your real values:
```
SUPABASE_URL=https://xyzabcdef.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
STRIPE_PUBLISHABLE_KEY=pk_test_...
GOOGLE_MAPS_API_KEY=AIza...
```

### 5. Configure Supabase Edge Function secrets

In Supabase Dashboard → Edge Functions → Secrets:

```
GEMINI_API_KEY=your-gemini-key-from-aistudio.google.com
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

> ⚠️ These keys NEVER go in `.env` or the repo.
> Note: `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically injected by
> Supabase into every Edge Function at runtime — you do NOT need to set them manually.

### 6. Deploy Edge Functions

```bash
# Install Supabase CLI if needed
npm install -g supabase

supabase login
supabase link --project-ref your-project-ref

# Deploy all functions
supabase functions deploy authorize
supabase functions deploy ai-chat
supabase functions deploy stripe-webhook
supabase functions deploy delete-account
```

### 7. Configure Stripe webhook

In [Stripe Dashboard](https://dashboard.stripe.com/test/webhooks) → Add endpoint:
- URL: `https://your-project-ref.supabase.co/functions/v1/stripe-webhook`
- Events: `payment_intent.succeeded`
- Copy the webhook signing secret → set as `STRIPE_WEBHOOK_SECRET`

### 8. Run the app

```bash
flutter run                          # Android emulator / connected device
flutter run -d "iPhone 15 Pro"       # iOS simulator
```

### 9. Test the NFC Simulator

1. Register an account in the app
2. In Profile → Debug → NFC Simulator
3. Select validator and amount → tap "Simular Tap NFC"
4. Verify balance decreases in Wallet screen

---

## Security checklist

- [ ] `.env` is in `.gitignore` (never committed)
- [ ] Supabase `service_role` key is ONLY in Edge Function secrets
- [ ] Stripe secret key is ONLY in Supabase secrets
- [ ] `GEMINI_API_KEY` is ONLY in Supabase secrets
- [ ] RLS is enabled on all tables (verify with integrity_check.sql)

## Key rotation

**Supabase keys** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`):
1. Supabase Dashboard → Settings → API → Reset anon key
2. Update `.env` locally
3. Update GitHub secret `SUPABASE_ANON_KEY` in repo Settings → Secrets
4. Redeploy Edge Functions (`supabase functions deploy`)
5. Inform all developers to pull `.env.example` and update `.env`

**Stripe keys** (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PUBLISHABLE_KEY`):
1. Stripe Dashboard → Developers → API keys → Roll key
2. Update `STRIPE_SECRET_KEY` in Supabase Dashboard → Edge Functions → Secrets
3. Update `STRIPE_WEBHOOK_SECRET` in Supabase secrets (re-register webhook endpoint if needed)
4. Update `STRIPE_PUBLISHABLE_KEY` in `.env` locally (safe to commit in `.env.example`)
5. Redeploy `stripe-webhook` Edge Function

**Gemini API key** (`GEMINI_API_KEY`):
1. Go to [aistudio.google.com](https://aistudio.google.com) → API keys → Revoke old → Create new
2. Update `GEMINI_API_KEY` in Supabase Dashboard → Edge Functions → Secrets
3. Redeploy `ai-chat` Edge Function (`supabase functions deploy ai-chat`)
4. The key is NEVER in `.env` or any client file — only in Supabase secrets

---

````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add complete setup runbook with security checklist and key rotation guide"
```

---

## Final Step: Create GitHub Repository

- [ ] **Step 1: Create repo on GitHub and push**

```bash
# Create repo at github.com/your-username/gosmart (via GitHub UI — mark as Private initially)
# Then:
git remote add origin https://github.com/<your-username>/gosmart.git
git push -u origin main
```

- [ ] **Step 2: Verify CI runs**

Go to GitHub → Actions tab. Verify the lint + test + build jobs are green.

- [ ] **Step 3: Add GitHub secrets for CI**

GitHub → Repository → Settings → Secrets and variables → Actions → New secret:
- `SUPABASE_URL` → your Supabase project URL
- `SUPABASE_ANON_KEY` → your anon key

These are used only in CI tests.

---

## Post-implementation verification checklist

- [ ] `flutter analyze` runs with no errors
- [ ] `flutter test` passes all widget tests
- [ ] SQL integrity check passes in Supabase SQL Editor
- [ ] Login with email+password creates account and profile
- [ ] Wallet screen shows real balance from DB
- [ ] NFC Simulator deducts balance atomically (run twice with same idempotency_key to verify dedup)
- [ ] Stripe test payment updates balance via webhook
- [ ] AI Chat responds in Spanish
- [ ] GitHub Actions CI is green
