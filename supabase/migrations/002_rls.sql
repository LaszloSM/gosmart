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

-- ── Public transport data (read-only for anyone, including anonymous) ─────────

CREATE POLICY "operators_public_read" ON public.operators
  FOR SELECT USING (true);

CREATE POLICY "routes_public_read" ON public.routes
  FOR SELECT USING (true);

CREATE POLICY "stops_public_read" ON public.stops
  FOR SELECT USING (true);

CREATE POLICY "validators_public_read" ON public.validators
  FOR SELECT USING (true);
-- No INSERT/UPDATE/DELETE policies on transport data = only service_role can modify
