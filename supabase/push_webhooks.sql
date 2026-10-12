-- Webhooks de push: INSERT en ride_requests y road_reports → Edge Function push.
-- Lo corre .github/workflows/supabase-deploy.yml con -v url=... -v secret=...
-- (el secreto no vive en el repo). Mismo formato que los Database Webhooks:
-- {type, table, record}. pg_net encola la llamada: si falla, el INSERT sigue.
CREATE EXTENSION IF NOT EXISTS pg_net;

SELECT set_config('gs.push_url', :'url', false),
       set_config('gs.push_secret', :'secret', false) \g /dev/null

DO $do$
BEGIN
  EXECUTE format($f$
    CREATE OR REPLACE FUNCTION public.gs_push_hook() RETURNS TRIGGER AS $b$
    BEGIN
      BEGIN
        PERFORM net.http_post(
          url := %L,
          body := jsonb_build_object('type', TG_OP, 'table', TG_TABLE_NAME,
                                     'record', to_jsonb(NEW)),
          headers := jsonb_build_object('Content-Type', 'application/json',
                                        'x-webhook-secret', %L),
          timeout_milliseconds := 5000);
      EXCEPTION WHEN OTHERS THEN
        NULL;  -- un push fallido nunca bloquea el pedido ni el reporte
      END;
      RETURN NEW;
    END;
    $b$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public$f$,
    current_setting('gs.push_url'), current_setting('gs.push_secret'));
END
$do$;

REVOKE ALL ON FUNCTION public.gs_push_hook() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS gs_push_ride_requests ON public.ride_requests;
CREATE TRIGGER gs_push_ride_requests AFTER INSERT ON public.ride_requests
  FOR EACH ROW EXECUTE FUNCTION public.gs_push_hook();

DROP TRIGGER IF EXISTS gs_push_road_reports ON public.road_reports;
CREATE TRIGGER gs_push_road_reports AFTER INSERT ON public.road_reports
  FOR EACH ROW EXECUTE FUNCTION public.gs_push_hook();
