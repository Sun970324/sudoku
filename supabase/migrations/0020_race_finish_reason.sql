-- Tags *why* a race reached `finished`, so a client that's still mid-puzzle
-- when the race gets decided out from under it (opponent gave up,
-- disconnected, finished first, or forfeited on their 3rd mistake) can show
-- the right "you won/lost because ___" message instead of a generic result.
-- Null for any race decided before this migration.

alter table public.races
  add column finish_reason text
    check (finish_reason is null or finish_reason in
      ('completed', 'gave_up', 'disconnected', 'mistakes'));

-- Byte-identical to the 0010 body except finish_reason = 'completed' on the
-- winning update.
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
    set status = 'finished', winner_id = v_self, finished_at = now(), finish_reason = 'completed'
    where id = p_race_id and status = 'in_progress';

  if not found then
    return false;
  end if;

  if not v_race.is_private then
    perform apply_race_result(p_race_id, v_self, v_opponent);
  end if;

  return true;
end;
$$;

-- Byte-identical to the 0015 body except finish_reason = 'disconnected' on
-- the winning update.
create or replace function public.claim_disconnect_win(p_race_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_race races%rowtype;
  v_self uuid := auth.uid();
  v_opponent uuid;
  v_opp_last_seen timestamptz;
begin
  select * into v_race from races where id = p_race_id;

  if not found or (v_self != v_race.player_a and v_self != v_race.player_b) then
    raise exception 'not a participant in race %', p_race_id;
  end if;

  if v_race.status != 'in_progress' then
    return false;
  end if;

  if v_self = v_race.player_a then
    v_opponent := v_race.player_b;
    v_opp_last_seen := v_race.player_b_last_seen;
  else
    v_opponent := v_race.player_a;
    v_opp_last_seen := v_race.player_a_last_seen;
  end if;

  if v_opp_last_seen is null then
    -- Opponent never heartbeated — only stale if the race has been running
    -- long enough that they clearly had the chance to and didn't.
    if v_race.started_at is null
        or v_race.started_at > now() - interval '30 seconds' then
      return false;
    end if;
  elsif v_opp_last_seen > now() - interval '30 seconds' then
    return false;
  end if;

  update races
    set status = 'finished', winner_id = v_self, finished_at = now(), finish_reason = 'disconnected'
    where id = p_race_id and status = 'in_progress';

  if not found then
    return false;
  end if;

  if not v_race.is_private then
    perform apply_race_result(p_race_id, v_self, v_opponent);
  end if;

  return true;
end;
$$;

-- p_reason distinguishes an explicit give-up from a self-reported 3-mistake
-- forfeit (see GameController.maxMistakes) — both resolve identically
-- (opponent wins, full Elo applied unless private), just tagged differently
-- so the opponent's client can show the right message. This is a signature
-- change (new param), so the old single-arg version is dropped first —
-- otherwise it would linger alongside the new one and PostgREST would see
-- two ambiguous overloads for a plain {p_race_id} call.
drop function if exists public.abort_race(uuid);

create function public.abort_race(p_race_id uuid, p_reason text default 'gave_up')
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
  if p_reason not in ('gave_up', 'mistakes') then
    raise exception 'invalid abort reason %', p_reason;
  end if;

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
    set status = 'finished', winner_id = v_opponent, finished_at = now(), finish_reason = p_reason
    where id = p_race_id and status = 'in_progress';

  if not found then
    return;
  end if;

  if not v_race.is_private then
    perform apply_race_result(p_race_id, v_opponent, v_self);
  end if;
end;
$$;

revoke execute on function public.abort_race(uuid, text) from public, anon;
grant execute on function public.abort_race(uuid, text) to authenticated;
