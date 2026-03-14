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
