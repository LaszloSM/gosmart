-- 008_wallet_mock.sql
-- Wallet simulado para GoSmart (proyecto académico — sin pagos reales)

CREATE TABLE IF NOT EXISTS wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  balance INTEGER DEFAULT 10000 CHECK (balance >= 0),
  card_number TEXT UNIQUE,
  card_status TEXT DEFAULT 'active' CHECK (card_status IN ('active', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID REFERENCES wallets(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('recharge', 'trip', 'refund', 'bonus')),
  amount INTEGER NOT NULL,
  description TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_user ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_txn_wallet ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_txn_created ON wallet_transactions(created_at DESC);

-- Genera número de tarjeta GoSmart simulado
CREATE OR REPLACE FUNCTION generate_gosmart_card_number()
RETURNS TEXT AS $$
BEGIN
  RETURN 'GS-' ||
    LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0') || '-' ||
    LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0') || '-' ||
    LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Crea wallet automáticamente al registrarse un nuevo usuario
CREATE OR REPLACE FUNCTION create_wallet_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO wallets (user_id, card_number, balance)
  VALUES (NEW.id, generate_gosmart_card_number(), 10000)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_auth_user_wallet_create ON auth.users;
CREATE TRIGGER on_auth_user_wallet_create
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_wallet_for_new_user();

-- RPC para recarga segura (evita race conditions)
CREATE OR REPLACE FUNCTION recharge_wallet(
  p_user_id UUID,
  p_amount INTEGER,
  p_description TEXT DEFAULT 'Recarga de saldo'
)
RETURNS TABLE (new_balance INTEGER, transaction_id UUID) AS $$
DECLARE
  v_wallet_id UUID;
  v_new_balance INTEGER;
  v_txn_id UUID;
BEGIN
  SELECT id, balance INTO v_wallet_id, v_new_balance
  FROM wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  v_new_balance := v_new_balance + p_amount;

  IF v_new_balance < 0 THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  UPDATE wallets SET balance = v_new_balance, updated_at = NOW()
  WHERE id = v_wallet_id;

  INSERT INTO wallet_transactions (wallet_id, type, amount, description)
  VALUES (
    v_wallet_id,
    CASE WHEN p_amount >= 0 THEN 'recharge' ELSE 'trip' END,
    p_amount,
    p_description
  )
  RETURNING id INTO v_txn_id;

  RETURN QUERY SELECT v_new_balance, v_txn_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own wallet" ON wallets;
CREATE POLICY "Users can view own wallet" ON wallets
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own wallet" ON wallets;
CREATE POLICY "Users can update own wallet" ON wallets
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own wallet_transactions" ON wallet_transactions;
CREATE POLICY "Users can view own wallet_transactions" ON wallet_transactions
  FOR SELECT USING (
    wallet_id IN (SELECT id FROM wallets WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Users can insert own wallet_transactions" ON wallet_transactions;
CREATE POLICY "Users can insert own wallet_transactions" ON wallet_transactions
  FOR INSERT WITH CHECK (
    wallet_id IN (SELECT id FROM wallets WHERE user_id = auth.uid())
  );
