-- Phase 3 (rank season): season-scope the ranked leaderboard and the rating
-- trend, so both read as *this season's* table rather than an all-time one.
--
-- Note: players whose only ranked games predate Season 1 (0016) drop off the
-- leaderboard until they play a ranked race this season — intended, since the
-- board now answers "who's ranked this season?".

-- The serving partial index follows the RPC's new WHERE filter exactly
-- (season counters instead of lifetime), same rationale as 0013.
drop index public.profiles_rating_leaderboard_idx;
create index profiles_rating_leaderboard_idx
  on public.profiles (rating desc, created_at asc)
  where season_wins + season_losses > 0;

-- Same payload shape as before — entry wins/losses now carry the *season*
-- record (sourced from season_wins/season_losses) so every number on the
-- board is season-scoped; the client parses the same keys unchanged.
-- CREATE OR REPLACE preserves the 0013 grants (authenticated only).
create or replace function public.get_rating_leaderboard()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with ranked as (
    select p.id, p.username, p.rating, p.tier,
           p.season_wins as wins, p.season_losses as losses,
           rank() over (order by p.rating desc, p.created_at asc) as rnk
      from profiles p
      where p.season_wins + p.season_losses > 0
  )
  select jsonb_build_object(
    'total', (select count(*) from ranked),
    'my_rank', (select rnk from ranked where id = auth.uid()),
    'my_rating', (select rating from ranked where id = auth.uid()),
    'entries', coalesce(
      (select jsonb_agg(jsonb_build_object(
          'rank', rnk, 'profile_id', id, 'username', username,
          'rating', rating, 'tier', tier, 'wins', wins, 'losses', losses
        ) order by rnk)
        from (select * from ranked order by rnk limit 100) top),
      '[]'::jsonb)
  );
$$;

-- The rating trend likewise only covers the active season's races, so the
-- chart never spans a soft-reset discontinuity (the reset happens between
-- seasons, not at a race, so it would otherwise appear as an unexplained
-- jump between two points).
create or replace function public.get_my_rating_history()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with mine as (
    select finished_at,
           case when player_a = auth.uid()
                then player_a_rating_after else player_b_rating_after end as rating,
           case when player_a = auth.uid()
                then player_a_rating_delta else player_b_rating_delta end as delta
      from races
      where status = 'finished'
        and finished_at >= (select started_at from seasons where status = 'active')
        and (player_a = auth.uid() or player_b = auth.uid())
        and (case when player_a = auth.uid()
                  then player_a_rating_delta else player_b_rating_delta end) is not null
      order by finished_at desc
      limit 100
  )
  select coalesce(
    (select jsonb_agg(jsonb_build_object(
        'finished_at', finished_at, 'rating', rating, 'delta', delta
      ) order by finished_at asc)
      from mine),
    '[]'::jsonb);
$$;
