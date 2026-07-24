-- Phase 5 stretch: rating-band matchmaking. matchmaking_queue.rating has
-- always been stored per waiting player, but enqueue_for_race never read
-- it — matching was pure FIFO regardless of skill gap. Now a candidate is
-- only matched if the caller's rating is within a band of the candidate's
-- rating, and that band widens the longer the candidate has waited (+50
-- every 15s beyond the base +-150) so a sparse rating pocket never waits
-- forever for an opponent — after a couple of minutes waiting, almost
-- anyone qualifies.
create or replace function public.enqueue_for_race(p_difficulty text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_self uuid := auth.uid();
  v_self_rating integer;
  v_opponent_id uuid;
  v_race_id uuid;
begin
  -- Clear any stale entry from a previous session before searching/enqueuing.
  delete from matchmaking_queue where profile_id = v_self;

  select rating into v_self_rating from profiles where id = v_self;

  select profile_id into v_opponent_id
    from matchmaking_queue
    where difficulty = p_difficulty
      and abs(rating - v_self_rating) <=
        150 + 50 * floor(extract(epoch from (now() - joined_at)) / 15)
    order by joined_at
    limit 1
    for update skip locked;

  if found then
    delete from matchmaking_queue where profile_id = v_opponent_id;
    insert into races (player_a, player_b, puzzle_provider, difficulty, status)
      values (v_opponent_id, v_self, v_opponent_id, p_difficulty, 'pending_puzzle')
      returning id into v_race_id;
    return v_race_id;
  else
    insert into matchmaking_queue (profile_id, difficulty, rating)
      values (v_self, p_difficulty, v_self_rating);
    return null;
  end if;
end;
$$;
