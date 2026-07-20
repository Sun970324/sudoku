-- Phase 2 (rank season): season-aware Elo + the monthly rollover.
--
-- Two behavior changes land here:
--   1. apply_race_result now also tracks per-season wins/losses and bases its
--      K-factor on *season* games played (not lifetime), so every season opens
--      with a high-K calibration burst that quickly re-sorts players after the
--      soft reset.
--   2. end_season_if_due() archives the ending season's standings, soft-resets
--      every profile's rating toward the 1200 baseline, clears the per-season
--      counters, and opens the next season. A daily pg_cron job runs it; it
--      no-ops until the active season actually reaches its ends_at, so it's
--      safe to run any number of times.

-- 1) Season-aware Elo. Signature unchanged (0007); only the game-count source
--    and the two extra counter increments differ from the previous body — the
--    Elo math and the races rating_after/delta writes are byte-identical.
create or replace function public.apply_race_result(p_race_id uuid, p_winner uuid, p_loser uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_winner_rating integer;
  v_winner_games integer;
  v_winner_tier text;
  v_loser_rating integer;
  v_loser_games integer;
  v_loser_tier text;
  v_k_winner integer;
  v_k_loser integer;
  v_expected_winner double precision;
  v_new_winner_rating integer;
  v_new_loser_rating integer;
begin
  -- K-factor now calibrates per season: the first 30 games of *this* season
  -- get the high K, so a soft-reset player re-sorts quickly each season.
  select rating, season_wins + season_losses, tier into v_winner_rating, v_winner_games, v_winner_tier
    from profiles where id = p_winner;
  select rating, season_wins + season_losses, tier into v_loser_rating, v_loser_games, v_loser_tier
    from profiles where id = p_loser;

  v_k_winner := case when v_winner_games < 30 then 32 else 16 end;
  v_k_loser := case when v_loser_games < 30 then 32 else 16 end;
  v_expected_winner := 1.0 / (1.0 + power(10.0, (v_loser_rating - v_winner_rating) / 400.0));

  v_new_winner_rating := round(v_winner_rating + v_k_winner * (1 - v_expected_winner));
  v_new_loser_rating := round(v_loser_rating - v_k_loser * (1 - v_expected_winner));

  update profiles set
      wins = wins + 1,
      season_wins = season_wins + 1,
      rating = v_new_winner_rating,
      tier = tier_for_rating(v_new_winner_rating, tier)
    where id = p_winner;

  update profiles set
      losses = losses + 1,
      season_losses = season_losses + 1,
      rating = v_new_loser_rating,
      tier = tier_for_rating(v_new_loser_rating, tier)
    where id = p_loser;

  -- player_a is always exactly one of {p_winner, p_loser}, so the two-branch
  -- case is exhaustive.
  update races set
      player_a_rating_after = case when player_a = p_winner then v_new_winner_rating else v_new_loser_rating end,
      player_a_rating_delta = case when player_a = p_winner then v_new_winner_rating - v_winner_rating else v_new_loser_rating - v_loser_rating end,
      player_b_rating_after = case when player_b = p_winner then v_new_winner_rating else v_new_loser_rating end,
      player_b_rating_delta = case when player_b = p_winner then v_new_winner_rating - v_winner_rating else v_new_loser_rating - v_loser_rating end
    where id = p_race_id;
end;
$$;

-- 2) The monthly rollover. SECURITY DEFINER, not granted to any client role —
--    only the pg_cron job (and a manual admin call) ever runs it. Idempotent:
--    it self-gates on the active season's ends_at, so extra runs are no-ops.
create function public.end_season_if_due()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_season seasons%rowtype;
begin
  -- Lock the active season so a manual run can't collide with the cron run.
  select * into v_season from seasons where status = 'active' for update;

  -- Nothing to do until the active season has actually reached its end.
  if not found or now() < v_season.ends_at then
    return;
  end if;

  -- (a) Archive final standings for everyone who played this season, ranked by
  --     rating with the same tiebreak as the live leaderboard (0013).
  insert into season_standings (season_id, profile_id, final_rating, final_tier, final_rank, wins, losses)
  select v_season.id, p.id, p.rating, p.tier,
         rank() over (order by p.rating desc, p.created_at asc),
         p.season_wins, p.season_losses
    from profiles p
    where p.season_wins + p.season_losses > 0;

  -- (b) Soft-reset every profile toward the 1200 baseline (compression 0.5),
  --     recompute tier, and clear the per-season counters. Lifetime wins/losses
  --     are deliberately left untouched. Both SET expressions read the
  --     pre-update row, so tier is computed from the new rating.
  update profiles set
      rating = round(1200 + (rating - 1200) * 0.5)::int,
      tier = tier_for_rating(round(1200 + (rating - 1200) * 0.5)::int, tier),
      season_wins = 0,
      season_losses = 0;

  -- (c) Close this season and open the next, ending at the first of the month
  --     after the new start, 00:00 KST (same convention as the Season 1 seed).
  update seasons set status = 'ended' where id = v_season.id;
  insert into seasons (started_at, ends_at, status)
    values (
      now(),
      (date_trunc('month', (now() at time zone 'Asia/Seoul')) + interval '1 month')
        at time zone 'Asia/Seoul',
      'active'
    );
end;
$$;

revoke execute on function public.end_season_if_due() from public, anon, authenticated;

-- 3) Run the rollover check daily at 00:10 KST (15:10 UTC). It self-gates on
--    ends_at, so a daily tick costs nothing until the month actually turns.
create extension if not exists pg_cron;

select cron.schedule(
  'end-season-if-due',
  '10 15 * * *',
  $job$select public.end_season_if_due();$job$
);
