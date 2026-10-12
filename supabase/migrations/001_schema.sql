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
  name          TEXT CHECK (char_length(name) <= 120),
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
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id           UUID REFERENCES public.cards(id) ON DELETE CASCADE NOT NULL,
  type              TEXT NOT NULL CHECK (type IN ('trip','recharge','refund')),
  amount            NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  currency          TEXT DEFAULT 'cop' CHECK (currency IN ('cop','usd','eur')),
  status            TEXT DEFAULT 'completed'
                      CHECK (status IN ('completed','failed','pending')),
  mode              TEXT,
  origin            TEXT,
  destination       TEXT,
  co2_kg            NUMERIC(6,3),
  validator_id      TEXT REFERENCES public.validators(id) ON DELETE SET NULL,
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

CREATE INDEX IF NOT EXISTS trips_user_id_idx ON public.trips(user_id);

-- ── eco_points_log ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.eco_points_log (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  trip_id    UUID REFERENCES public.trips(id) ON DELETE SET NULL,
  points     INTEGER NOT NULL,
  reason     TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS eco_points_log_user_id_idx ON public.eco_points_log(user_id);

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
  card_id                    UUID REFERENCES public.cards(id) ON DELETE RESTRICT NOT NULL,
  -- ON DELETE RESTRICT: intentional — recharge records are financial audit trail.
  -- Cards must be soft-deleted (status='suspended') rather than hard-deleted.
  stripe_payment_intent_id   TEXT UNIQUE NOT NULL,  -- idempotency key
  amount                     NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  currency                   TEXT DEFAULT 'cop' CHECK (currency IN ('cop','usd','eur')),
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
