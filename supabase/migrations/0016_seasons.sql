-- Phase 1 (rank season): the season calendar. Introduces a time-boxed ranked
-- season without changing any gameplay/Elo yet — the rollover + soft-reset
-- land in a later migration. profiles.rating/tier are reinterpreted as the
-- *current season's* values (no data change needed), and per-season win/loss
-- counters are added alongside the existing lifetime wins/losses so a later
-- K-factor/leaderboard can be season-scoped.

create table public.seasons (
  id serial primary key,
  started_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'active' check (status in ('active', 'ended')),
  created_at timestamptz not null default now()
);

-- At most one active season at a time; the rollover flips the old one to
-- 'ended' in the same transaction it inserts the next.
create unique index seasons_one_active_idx on public.seasons (status)
  where status = 'active';

alter table public.seasons enable row level security;

create policy "Seasons are viewable by everyone"
  on public.seasons for select using (true);

grant select on public.seasons to anon, authenticated;
-- No insert/update/delete grant: seasons are written only by the (future)
-- SECURITY DEFINER rollover function.

-- Final standings snapshot, written once per player when a season ends, so a
-- past season's rank/tier/rating survives the soft-reset that immediately
-- follows. Also the ledger the "past seasons" profile display reads from.
create table public.season_standings (
  season_id integer not null references public.seasons(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  final_rating integer not null,
  final_tier text not null,
  final_rank integer not null,
  wins integer not null,
  losses integer not null,
  primary key (season_id, profile_id)
);

alter table public.season_standings enable row level security;

create policy "Standings are viewable by everyone"
  on public.season_standings for select using (true);

grant select on public.season_standings to anon, authenticated;

-- Per-season win/loss counters. profiles.wins/losses stay the lifetime
-- (career) record; these reset to 0 each season and will drive the season
-- K-factor calibration + season leaderboard filter in a later phase. Not
-- granted to authenticated (like rating/tier/wins/losses, only SECURITY
-- DEFINER functions ever write them).
alter table public.profiles
  add column season_wins integer not null default 0,
  add column season_losses integer not null default 0;

-- Seed Season 1: starts now, ends at the first of next month, 00:00 KST (the
-- app's audience). Existing ratings carry in unchanged — Season 1 is a
-- natural start, not a reset. The month boundary is computed in Seoul
-- wall-clock time, then converted back to an instant.
insert into public.seasons (started_at, ends_at, status)
values (
  now(),
  (date_trunc('month', (now() at time zone 'Asia/Seoul')) + interval '1 month')
    at time zone 'Asia/Seoul',
  'active'
);
