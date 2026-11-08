-- CycleSync migration 2: settings for the full app, overlap guard, account deletion.
-- Run once in the Supabase SQL Editor after 20261108000000_initial_schema.sql.

-- ---------- New settings ----------
alter table public.profiles
  add column if not exists onboarding_completed boolean not null default false,
  add column if not exists show_fertile_window boolean not null default false;

alter table public.reminder_preferences
  add column if not exists fertile_reminder_enabled boolean not null default false;

-- ---------- Prevent overlapping period records ----------
-- The app warns first; this is the safety net. A period with no end date
-- counts as running up to today, but never more than 14 days.
create or replace function public.prevent_period_overlap()
returns trigger language plpgsql set search_path = '' as $$
begin
  if exists (
    select 1 from public.periods p
    where p.user_id = new.user_id
      and p.id <> new.id
      and daterange(p.start_date, coalesce(p.end_date, least(greatest(p.start_date, current_date), p.start_date + 13)), '[]')
          && daterange(new.start_date, coalesce(new.end_date, least(greatest(new.start_date, current_date), new.start_date + 13)), '[]')
  ) then
    raise exception 'period_overlap' using errcode = 'P0001',
      hint = 'This period overlaps another recorded period.';
  end if;
  return new;
end;
$$;

drop trigger if exists periods_no_overlap on public.periods;
create trigger periods_no_overlap before insert or update on public.periods
  for each row execute function public.prevent_period_overlap();

-- ---------- Account deletion ----------
-- Deletes the signed-in user's login. All their rows are removed by the
-- "on delete cascade" foreign keys. A user can only ever delete themselves.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
