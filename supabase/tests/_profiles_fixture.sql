-- supabase/tests/_profiles_fixture.sql
-- 001_schema.sql pide PostGIS, que no está en el Postgres de CI. Para probar
-- 011+ basta la forma de `profiles` (001 + 005), su RLS (002) y el trigger
-- de alta (003). No se aplica en Supabase.
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name        TEXT CHECK (char_length(name) <= 120),
  eco_points  INTEGER DEFAULT 0,
  avatar_url  TEXT,
  phone       VARCHAR(20),
  cedula      VARCHAR(20),
  city        VARCHAR(100),
  birth_date  DATE,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_own_all" ON public.profiles;
CREATE POLICY "profiles_own_all" ON public.profiles
  FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.fixture_new_profile()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, name) VALUES (NEW.id, split_part(NEW.email, '@', 1));
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS fixture_new_profile ON auth.users;
CREATE TRIGGER fixture_new_profile AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.fixture_new_profile();
