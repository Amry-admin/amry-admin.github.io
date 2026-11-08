-- CycleSync migration 3: web push reminders for the web app.
-- Run once in the Supabase SQL Editor after migration 2.

-- Browsers that agreed to receive CycleSync notifications.
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now(),
  unique (user_id, endpoint)
);

-- Upcoming reminders, written by the app from the user's own settings.
create table if not exists public.scheduled_pushes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('period', 'fertile', 'daily')),
  send_at timestamptz not null,
  title text not null,
  body text not null,
  repeats_daily boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists scheduled_pushes_due_idx
  on public.scheduled_pushes(send_at);

-- Server-only settings (web push keys). No policies: only the server can read it.
create table if not exists public.push_config (
  id smallint primary key default 1 check (id = 1),
  public_key text not null,
  private_key text not null,
  created_at timestamptz not null default now()
);

alter table public.push_subscriptions enable row level security;
alter table public.scheduled_pushes enable row level security;
alter table public.push_config enable row level security;

create policy "push_subs_select_own" on public.push_subscriptions for select to authenticated
  using (user_id = (select auth.uid()));
create policy "push_subs_insert_own" on public.push_subscriptions for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "push_subs_update_own" on public.push_subscriptions for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "push_subs_delete_own" on public.push_subscriptions for delete to authenticated
  using (user_id = (select auth.uid()));

create policy "scheduled_select_own" on public.scheduled_pushes for select to authenticated
  using (user_id = (select auth.uid()));
create policy "scheduled_insert_own" on public.scheduled_pushes for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "scheduled_delete_own" on public.scheduled_pushes for delete to authenticated
  using (user_id = (select auth.uid()));

-- Every 5 minutes, ask the send-reminders function to send what is due.
-- Replace YOUR-PROJECT with your project reference before running.
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'cyclesync-send-reminders',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://YOUR-PROJECT.supabase.co/functions/v1/send-reminders',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
