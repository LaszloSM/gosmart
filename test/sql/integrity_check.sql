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
  -- Bypass FK triggers for this transaction so we can insert a card with a
  -- fake user_id without needing a real auth.users row.
  SET LOCAL session_replication_role = replica;

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

DO $$ BEGIN RAISE NOTICE '=== All integrity checks passed ==='; END $$;
