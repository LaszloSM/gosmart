-- 019_signup_fix.sql
-- Arreglo: al crear un usuario, Supabase Auth corre los triggers de auth.users
-- con su propio rol (supabase_auth_admin) y search_path "auth". El trigger de
-- la billetera (008) no era SECURITY DEFINER ni fijaba el search_path, así que
-- no encontraba public.wallets y el alta fallaba con "Database error creating
-- new user". Ahora corre como dueño, con nombres calificados.
-- Seguro de re-ejecutar.

CREATE OR REPLACE FUNCTION public.generate_gosmart_card_number()
RETURNS TEXT AS $$
BEGIN
  RETURN 'GS-' ||
    lpad(floor(random() * 10000)::text, 4, '0') || '-' ||
    lpad(floor(random() * 10000)::text, 4, '0') || '-' ||
    lpad(floor(random() * 10000)::text, 4, '0');
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE OR REPLACE FUNCTION public.create_wallet_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.wallets (user_id, card_number, balance)
  VALUES (NEW.id, public.generate_gosmart_card_number(), 10000)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.create_wallet_for_new_user() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_wallet_create ON auth.users;
CREATE TRIGGER on_auth_user_wallet_create
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.create_wallet_for_new_user();
