-- Keepalive table for the GitHub Action in .github/workflows/supabase-keepalive.yml.
--
-- An anonymous read that RLS answers with [] did not count as activity: the
-- project paused on 2026-09-12 and again on 2026-10-07 while those reads
-- returned 200. The Action now signs in as a dedicated keepalive user and
-- upserts one row here, a real authenticated write.
--
-- Run once in the Supabase SQL editor. Safe to re-run.

create table if not exists keepalive (
  user_id   uuid primary key default auth.uid() references auth.users on delete cascade,
  pinged_at timestamptz not null default now()
);

alter table keepalive enable row level security;

drop policy if exists "own row select" on keepalive;
drop policy if exists "own row insert" on keepalive;
drop policy if exists "own row update" on keepalive;

create policy "own row select" on keepalive
  for select using (auth.uid() = user_id);
create policy "own row insert" on keepalive
  for insert with check (auth.uid() = user_id);
create policy "own row update" on keepalive
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
