-- supabase/migrations/022_offer_cards.sql
-- Ofertas como en InDrive: el pasajero ve quién ofrece (nombre de pila,
-- calificación, vehículo) y a cuánto está, no solo el precio. Solo el
-- pasajero de la solicitud las ve; la placa y la ubicación exacta del
-- conductor siguen ocultas hasta que acepta (ride_driver_view).
-- Seguro de re-ejecutar.

DROP FUNCTION IF EXISTS ride_offer_cards(UUID);
CREATE FUNCTION ride_offer_cards(p_request_id UUID)
RETURNS TABLE (id UUID, fare INTEGER, first_name TEXT, vehicle TEXT,
               rating NUMERIC, ratings INTEGER, pickup_km NUMERIC, eta_min INTEGER,
               created_at TIMESTAMPTZ) AS $$
  SELECT o.id, o.fare, split_part(d.full_name, ' ', 1),
         nullif(trim(coalesce(v.brand, '') || ' ' || coalesce(v.color, '')), ''),
         ur.avg_stars, coalesce(ur.total, 0)::INTEGER,
         round((gs_meters(l.lat, l.lng, r.origin_lat, r.origin_lng) / 1000)::NUMERIC, 1),
         -- En la ciudad, ~20 km/h puerta a puerta (moto o taxi) + 1 min de arranque.
         CASE WHEN l.lat IS NULL THEN NULL
              ELSE (ceil(gs_meters(l.lat, l.lng, r.origin_lat, r.origin_lng) / 1000 / 20 * 60) + 1)::INTEGER
         END,
         o.created_at
  FROM ride_requests r
  JOIN ride_offers o ON o.request_id = r.id AND o.status = 'pending'
  JOIN drivers d ON d.user_id = o.driver_id
  LEFT JOIN LATERAL (SELECT vv.brand, vv.color FROM vehicles vv
                     WHERE vv.driver_id = d.user_id LIMIT 1) v ON true
  LEFT JOIN driver_locations l ON l.driver_id = d.user_id
  LEFT JOIN LATERAL user_rating(d.user_id) ur ON true
  WHERE r.id = p_request_id AND r.passenger_id = auth.uid() AND r.status = 'open'
  ORDER BY o.fare, o.created_at
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION ride_offer_cards(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION ride_offer_cards(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
