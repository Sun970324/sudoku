-- Phase 4: Elo rating + tier calculation, applied wherever a race is
-- decided — a normal finish (submit_race_finish) and a mid-race forfeit
-- (abort_race, redefined below to resolve exactly like a loss instead of a
-- no-consequence cancellation, so quitting can't dodge a rating hit).
-- Challenger (top-50-of-Master) isn't implemented yet — no real population
-- to rank yet, so tier_for_rating only ever assigns bronze..master itself,
-- though it already preserves 'challenger' if something later sets it, so
-- that future scheduled job won't need to touch this function again.

create function public.tier_for_rating(p_rating integer, p_current_tier text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_rating >= 1900 and p_current_tier = 'challenger' then 'challenger'
    when p_rating >= 1900 then 'master'
    when p_rating >= 1700 then 'diamond'
    when p_rating >= 1500 then 'platinum'
    when p_rating >= 1300 then 'gold'
    when p_rating >= 1100 then 'silver'
    else 'bronze'
  end;
$$;

revoke execute on function public.tier_for_rating(integer, text) from public, anon;

-- Standard Elo, K=32 under 30 games played (wins+losses) else 16. Not
-- exposed to clients at all (no grant to authenticated either) — only
-- called from within submit_race_finish/abort_race, which run as this
-- function's owner (security definer), so no explicit grant is needed for
-- those internal calls.
create function public.apply_race_result(p_winner uuid, p_loser uuid)
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
  select rating, wins + losses, tier into v_winner_rating, v_winner_games, v_winner_tier
    from profiles where id = p_winner;
  select rating, wins + losses, tier into v_loser_rating, v_loser_games, v_loser_tier
    from profiles where id = p_loser;

  v_k_winner := case when v_winner_games < 30 then 32 else 16 end;
  v_k_loser := case when v_loser_games < 30 then 32 else 16 end;
  v_expected_winner := 1.0 / (1.0 + power(10.0, (v_loser_rating - v_winner_rating) / 400.0));

  v_new_winner_rating := round(v_winner_rating + v_k_winner * (1 - v_expected_winner));
  v_new_loser_rating := round(v_loser_rating - v_k_loser * (1 - v_expected_winner));

  update profiles set
      wins = wins + 1,
      rating = v_new_winner_rating,
      tier = tier_for_rating(v_new_winner_rating, tier)
    where id = p_winner;

  update profiles set
      losses = losses + 1,
      rating = v_new_loser_rating,
      tier = tier_for_rating(v_new_loser_rating, tier)
    where id = p_loser;
end;
$$;

revoke execute on function public.apply_race_result(uuid, uuid) from public, anon, authenticated;

-- Replaces the flat wins/losses-only update from 0005 with the Elo/tier
-- calculation above; the compare-and-swap and solution-verification logic
-- is unchanged.
create or replace function public.submit_race_finish(p_race_id uuid, p_board jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_race races%rowtype;
  v_self uuid := auth.uid();
  v_opponent uuid;
begin
  select * into v_race from races where id = p_race_id;

  if not found or (v_self != v_race.player_a and v_self != v_race.player_b) then
    raise exception 'not a participant in race %', p_race_id;
  end if;

  if v_race.status != 'in_progress' or p_board != v_race.solution then
    return false;
  end if;

  v_opponent := case when v_self = v_race.player_a then v_race.player_b else v_race.player_a end;

  update races
    set status = 'finished', winner_id = v_self, finished_at = now()
    where id = p_race_id and status = 'in_progress';

  if not found then
    return false;
  end if;

  perform apply_race_result(v_self, v_opponent);

  return true;
end;
$$;

-- Redefines abort_race: forfeiting a race that's already `in_progress` now
-- resolves it exactly like a normal finish (status='finished', opponent as
-- winner, full Elo applied) instead of a no-consequence 'aborted' — so
-- quitting can't be used to dodge a rating hit for a race you're about to
-- lose. Aborting before the race actually started (pending_puzzle/ready,
-- nothing at stake yet) still cleanly cancels with no rating change.
create or replace function public.abort_race(p_race_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_race races%rowtype;
  v_self uuid := auth.uid();
  v_opponent uuid;
begin
  select * into v_race from races where id = p_race_id;

  if not found or (v_self != v_race.player_a and v_self != v_race.player_b) then
    raise exception 'not a participant in race %', p_race_id;
  end if;

  if v_race.status in ('finished', 'aborted') then
    return;
  end if;

  v_opponent := case when v_self = v_race.player_a then v_race.player_b else v_race.player_a end;

  if v_race.status != 'in_progress' then
    update races
      set status = 'aborted', finished_at = now()
      where id = p_race_id and status not in ('finished', 'aborted');
    return;
  end if;

  update races
    set status = 'finished', winner_id = v_opponent, finished_at = now()
    where id = p_race_id and status = 'in_progress';

  if not found then
    return;
  end if;

  perform apply_race_result(v_opponent, v_self);
end;
$$;
