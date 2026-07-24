-- Private (friend) races, joined by a short room code shared out-of-band
-- (e.g. KakaoTalk). A private race plays out exactly like a ranked one —
-- same puzzle exchange, ready-check, finish/forfeit resolution — but is
-- friendly: no Elo, no wins/losses, no tier movement (see the gated
-- apply_race_result calls at the bottom).

alter table public.races add column is_private boolean not null default false;

-- A waiting room is deliberately NOT a `races` row: the client's match
-- detection (watchForMatch / fetchActiveMatch) treats any non-terminal
-- races row naming you as player_a as "you've been matched", so a
-- creator-only waiting row there would pollute ranked matchmaking. The
-- races row is only created at join time (join_private_room), preserving
-- the invariant that `races` holds established matches only — which also
-- means the creator learns of the join through the exact same
-- watch-for-my-race path ranked matchmaking already uses.
create table public.race_rooms (
  code text primary key,
  creator uuid not null references public.profiles on delete cascade,
  difficulty text not null,
  created_at timestamptz not null default now()
);

-- One open room per creator: create_private_room deletes the previous one
-- first, and this index backstops any race between two concurrent creates.
create unique index race_rooms_one_per_creator on public.race_rooms (creator);

alter table public.race_rooms enable row level security;
-- No client grants at all — stricter than matchmaking_queue. Create, join,
-- and cancel all go through the SECURITY DEFINER RPCs below; a joiner finds
-- the room by code inside join_private_room, and the creator learns of the
-- join via the races row appearing, so clients never read this table. No
-- realtime publication either, for the same reason.

-- Creates (or replaces) the caller's room and returns its 6-char join code.
-- Charset omits 0/O/1/I/L so a code read aloud or retyped from a screenshot
-- can't be mistyped through lookalikes. random() is not cryptographic, but
-- a join code guarded by expiry + single-use consumption is not a security
-- boundary — same trade-off as the race channel's plain-uuid naming.
create function public.create_private_room(p_difficulty text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_self uuid := auth.uid();
  v_chars constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  v_code text;
begin
  -- A stale room from a crash or a re-tap simply gets replaced.
  delete from race_rooms where creator = v_self;

  loop
    select string_agg(substr(v_chars, 1 + floor(random() * 31)::int, 1), '')
      into v_code
      from generate_series(1, 6);
    begin
      insert into race_rooms (code, creator, difficulty)
        values (v_code, v_self, p_difficulty);
      return v_code;
    exception when unique_violation then
      -- Code collision (~1 in 31^6): just roll again.
      null;
    end;
  end loop;
end;
$$;

revoke execute on function public.create_private_room(text) from public, anon;
grant execute on function public.create_private_room(text) to authenticated;

-- Joins the room for [p_code]: consumes the room (codes are single-use) and
-- creates the actual race with the creator as player_a / puzzle_provider —
-- mirroring ranked matchmaking, where the waiting side is always player_a,
-- so the creator's existing watch-for-my-race stream fires. Raises for an
-- unknown, expired (30 min), or self-owned code; the row lock closes the
-- window against two joiners consuming the same room at once.
create function public.join_private_room(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_self uuid := auth.uid();
  v_room race_rooms%rowtype;
  v_race_id uuid;
begin
  select * into v_room
    from race_rooms
    where code = upper(trim(p_code))
    for update;

  if not found
     or v_room.created_at < now() - interval '30 minutes'
     or v_room.creator = v_self then
    raise exception 'room not found';
  end if;

  delete from race_rooms where code = v_room.code;

  insert into races (player_a, player_b, puzzle_provider, difficulty, status, is_private)
    values (v_room.creator, v_self, v_room.creator, v_room.difficulty,
            'pending_puzzle', true)
    returning id into v_race_id;
  return v_race_id;
end;
$$;

revoke execute on function public.join_private_room(text) from public, anon;
grant execute on function public.join_private_room(text) to authenticated;

-- Cancels the caller's open room. Also aborts any private race a joiner
-- managed to create in the same instant (cancel and join racing each
-- other) — the joiner's client sees the aborted status through its normal
-- race stream and exits cleanly, instead of waiting forever on a puzzle
-- from a creator who already left.
create function public.cancel_private_room()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from race_rooms where creator = auth.uid();
  update races
    set status = 'aborted', finished_at = now()
    where player_a = auth.uid()
      and is_private
      and status in ('pending_puzzle', 'ready');
end;
$$;

revoke execute on function public.cancel_private_room() from public, anon;
grant execute on function public.cancel_private_room() to authenticated;

-- submit_race_finish / abort_race: byte-identical to the 0007 bodies except
-- the final apply_race_result is gated on the race not being private, so a
-- friendly match resolves (finished / forfeit = opponent wins) without
-- touching rating, wins/losses, tier, or the rating_after/delta columns —
-- which also keeps private races out of fetchHistory's delta-not-null
-- filter, deliberately: friendly matches don't show in race history (MVP).

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

  if not v_race.is_private then
    perform apply_race_result(p_race_id, v_self, v_opponent);
  end if;

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

  if not v_race.is_private then
    perform apply_race_result(p_race_id, v_opponent, v_self);
  end if;
end;
$$;
