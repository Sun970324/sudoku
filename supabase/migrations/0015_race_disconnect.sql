-- Phase 5 stretch: server-verified disconnect forfeit. Presence (client-
-- reported) can't be trusted to award a win — a tampered client could claim
-- one every race. Instead each player heartbeats into their own last_seen
-- column every ~10s while racing, and claim_disconnect_win only awards the
-- win if the OPPONENT's heartbeat has gone stale, which the server checks
-- itself. This keeps the existing anti-cheat invariant (you can never make
-- the opponent lose unless they genuinely stopped playing).

alter table public.races
  add column player_a_last_seen timestamptz,
  add column player_b_last_seen timestamptz;

-- Refreshes the caller's own heartbeat. No-op unless the race is in progress
-- and the caller is a participant, so a stale client can't poke a decided
-- race back to life.
create function public.race_heartbeat(p_race_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_self uuid := auth.uid();
begin
  update races set
      player_a_last_seen =
        case when player_a = v_self then now() else player_a_last_seen end,
      player_b_last_seen =
        case when player_b = v_self then now() else player_b_last_seen end
    where id = p_race_id
      and status = 'in_progress'
      and (player_a = v_self or player_b = v_self);
end;
$$;

revoke execute on function public.race_heartbeat(uuid) from public, anon;
grant execute on function public.race_heartbeat(uuid) to authenticated;

-- Awards the in-progress race to the caller iff the opponent's heartbeat has
-- gone stale (no heartbeat for >= 30s, or none at all >= 30s after the race
-- started). The 30s server threshold sits below the client's 45s grace so a
-- claim fired after the grace reliably passes, while a brief background/
-- network blip (which resumes heartbeating within seconds) never does.
-- Same finished/winner/Elo path as submit_race_finish/abort_race, CAS-guarded
-- on status='in_progress' so a simultaneous real finish still resolves once.
create function public.claim_disconnect_win(p_race_id uuid)
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
    set status = 'finished', winner_id = v_self, finished_at = now()
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

revoke execute on function public.claim_disconnect_win(uuid) from public, anon;
grant execute on function public.claim_disconnect_win(uuid) to authenticated;
