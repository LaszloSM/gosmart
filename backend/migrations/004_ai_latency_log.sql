-- backend/migrations/004_ai_latency_log.sql
-- `create table if not exists` is intentionally idempotent (safe to re-run).
create table if not exists ai_latency_log (
  id          bigserial primary key,
  user_id     uuid references auth.users not null default auth.uid(),
  created_at  timestamptz default now(),
  total_ms    int not null,
  backend_ms  int,
  source      text check (source in ('gemini', 'heuristic', 'cache')),
  intent      text check (intent in ('route_query', 'balance_query', 'general'))
);

alter table ai_latency_log enable row level security;

-- `create policy` has no IF NOT EXISTS in PostgreSQL ≤15.
-- Guard against re-run errors by dropping first.
drop policy if exists "insert own latency log" on ai_latency_log;
create policy "insert own latency log"
  on ai_latency_log
  for insert
  with check (user_id = auth.uid());
