-- CycleSync initial schema v1
-- Applied manually in the Supabase SQL Editor on 2026-11-08.
-- Future changes: add a NEW migration file; never edit this one.

create extension if not exists pgcrypto;

-- ---------- Tables ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  average_cycle_length smallint
    check (average_cycle_length is null or average_cycle_length between 15 and 60),
  average_period_length smallint
    check (average_period_length is null or average_period_length between 1 and 15),
  timezone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.periods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  start_date date not null,
  end_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint period_dates_valid check (end_date is null or end_date >= start_date)
);
create index periods_user_start_idx on public.periods(user_id, start_date desc);

create table public.daily_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null,
  flow text not null default 'none'
    check (flow in ('none','spotting','light','medium','heavy')),
  symptoms text[] not null default '{}'
    check (symptoms <@ array['cramps','headache','bloating','acne','breast_tenderness',
                             'fatigue','nausea','back_pain','other']::text[]),
  mood text[] not null default '{}'
    check (mood <@ array['happy','calm','neutral','anxious','sad','irritable',
                         'low_energy','other']::text[]),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, log_date)
);

create table public.reminder_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  period_reminder_enabled boolean not null default false,
  reminder_days_before smallint
    check (reminder_days_before is null or reminder_days_before between 1 and 5),
  daily_reminder_enabled boolean not null default false,
  daily_reminder_time time,
  neutral_notification_text boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- Row Level Security ----------
alter table public.profiles enable row level security;
alter table public.periods enable row level security;
alter table public.daily_logs enable row level security;
alter table public.reminder_preferences enable row level security;

create policy "profile_select_own" on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy "profile_insert_own" on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));
create policy "profile_update_own" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "periods_select_own" on public.periods for select to authenticated
  using (user_id = (select auth.uid()));
create policy "periods_insert_own" on public.periods for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "periods_update_own" on public.periods for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "periods_delete_own" on public.periods for delete to authenticated
  using (user_id = (select auth.uid()));

create policy "daily_logs_select_own" on public.daily_logs for select to authenticated
  using (user_id = (select auth.uid()));
create policy "daily_logs_insert_own" on public.daily_logs for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "daily_logs_update_own" on public.daily_logs for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "daily_logs_delete_own" on public.daily_logs for delete to authenticated
  using (user_id = (select auth.uid()));

create policy "reminders_select_own" on public.reminder_preferences for select to authenticated
  using (user_id = (select auth.uid()));
create policy "reminders_insert_own" on public.reminder_preferences for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "reminders_update_own" on public.reminder_preferences for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "reminders_delete_own" on public.reminder_preferences for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------- Automatic updated_at ----------
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger periods_updated_at before update on public.periods
  for each row execute function public.set_updated_at();
create trigger daily_logs_updated_at before update on public.daily_logs
  for each row execute function public.set_updated_at();
create trigger reminder_preferences_updated_at before update on public.reminder_preferences
  for each row execute function public.set_updated_at();

-- ---------- Create profile + reminder row on sign-up ----------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id)
    on conflict (id) do nothing;
  insert into public.reminder_preferences (user_id) values (new.id)
    on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Only the trigger may run this; block direct API calls (Security Advisor).
revoke execute on function public.handle_new_user() from public, anon, authenticated;
