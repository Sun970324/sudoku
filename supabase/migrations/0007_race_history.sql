-- Persists each race's rating outcome so a completed race can show
-- "1244 (+24)" in a history list later — profiles.rating only ever holds
-- the *current* rating, so the delta at each individual race has to be
-- captured at the moment apply_race_result computes it, or it's lost.

alter table public.races
  add column player_a_rating_after integer,
  add column player_a_rating_delta integer,
  add column player_b_rating_after integer,
  add column player_b_rating_delta integer;

-- apply_race_result now also needs the race id to write these columns
-- back, so its signature changes — drop the old 2-arg version first since
-- `create or replace` can't change a function's parameter list in place.
drop function public.apply_race_result(uuid, uuid);

create function public.apply_race_result(p_race_id uuid, p_winner uuid, p_loser uuid)
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

  -- player_a is always exactly one of {p_winner, p_loser} (the race's own
  -- two participants), so the two-branch case is exhaustive.
  update races set
      player_a_rating_after = case when player_a = p_winner then v_new_winner_rating else v_new_loser_rating end,
      player_a_rating_delta = case when player_a = p_winner then v_new_winner_rating - v_winner_rating else v_new_loser_rating - v_loser_rating end,
      player_b_rating_after = case when player_b = p_winner then v_new_winner_rating else v_new_loser_rating end,
      player_b_rating_delta = case when player_b = p_winner then v_new_winner_rating - v_winner_rating else v_new_loser_rating - v_loser_rating end
    where id = p_race_id;
end;
$$;

revoke execute on function public.apply_race_result(uuid, uuid, uuid) from public, anon, authenticated;

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

  perform apply_race_result(p_race_id, v_self, v_opponent);

  return true;
end;
$$;

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

  perform apply_race_result(p_race_id, v_opponent, v_self);
end;
$$;
