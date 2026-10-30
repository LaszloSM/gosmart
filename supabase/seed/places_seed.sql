-- supabase/seed/places_seed.sql
-- Semilla mínima del directorio para probar el buscador antes del
-- levantamiento de campo (Fase 1). TODAS las coordenadas son aproximadas
-- (source='semilla', verified=false) y la app las muestra como "aprox.".
-- Reemplazar con datos de campo; no usar como verdad. Al elegir uno sin
-- verificar, la app pide a Google su punto real (place_search.dart): estas
-- coordenadas solo se usan si Google no responde.
-- 2026-10-30: plaza Almirante Padilla, muelle, catedral, aeropuerto, terminal de Riohacha, Uniguajira y
-- parque central de Maicao llevan el punto que dio Google/OpenStreetMap en la
-- prueba del emulador (la semilla estaba corrida ~800 m al sur). Siguen sin
-- verificar en campo. Re-ejecutar actualiza alias y punto de las filas de la
-- semilla sin tocar las demás.
INSERT INTO places (name, aliases, city, kind, lat, lng, source, verified) VALUES
  ('Muelle Turístico de Riohacha', '{el muelle,muelle}', 'riohacha', 'turismo', 11.5532, -72.9064, 'semilla', false),
  ('Parque Almirante Padilla', '{parque padilla,la plaza,plaza padilla,plaza almirante padilla,parque jose prudencio padilla,plaza principal}', 'riohacha', 'referencia', 11.5515, -72.9097, 'semilla', false),
  ('Catedral Nuestra Señora de los Remedios', '{la catedral}', 'riohacha', 'referencia', 11.5518, -72.9092, 'semilla', false),
  ('Malecón de Riohacha', '{la playa,el malecon,la primera}', 'riohacha', 'turismo', 11.5452, -72.9040, 'semilla', false),
  ('Aeropuerto Almirante Padilla', '{aeropuerto}', 'riohacha', 'terminal', 11.5271, -72.9183, 'semilla', false),
  ('Terminal de Transportes de Riohacha', '{la terminal,terminal}', 'riohacha', 'terminal', 11.5407, -72.9113, 'semilla', false),
  ('Universidad de La Guajira', '{uniguajira,la universidad}', 'riohacha', 'educacion', 11.5118, -72.8706, 'semilla', false),
  ('Parque Central de Maicao', '{el parque,la plaza}', 'maicao', 'referencia', 11.3792, -72.2514, 'semilla', false),
  ('Mezquita Omar Ibn Al-Khattab', '{la mezquita}', 'maicao', 'referencia', 11.3825, -72.2420, 'semilla', false),
  ('Terminal de Maicao', '{la terminal,terminal}', 'maicao', 'terminal', 11.3790, -72.2370, 'semilla', false),
  ('Cuatro Vías', '{cuatro vias,las cuatro vias}', 'corredor', 'via', 11.3270, -72.5550, 'semilla', false),
  ('Cuestecitas', '{}', 'corredor', 'via', 11.2050, -72.6160, 'semilla', false)
ON CONFLICT (city, name) DO UPDATE
  SET aliases = ARRAY(SELECT DISTINCT unnest(places.aliases || EXCLUDED.aliases)),
      lat = EXCLUDED.lat,
      lng = EXCLUDED.lng
  WHERE places.source = 'semilla';
