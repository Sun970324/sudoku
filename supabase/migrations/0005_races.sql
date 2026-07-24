-- Phase 3: matchmaking queue + races. Puzzle data lives directly on `races`
-- as jsonb (no separate puzzles table — Phase 2's was dropped in 0004, and
-- a race's puzzle is never reused/looked-up by anything else).

create table public.matchmaking_queue (
  profile_id uuid primary key references public.profiles on delete cascade,
  difficulty text not null,
  rating integer not null,
  joined_at timestamptz not null default now()
);

alter table public.matchmaking_queue enable row level security;

-- No SELECT grant/policy at all: the client never queries this table
-- directly, only inserts/deletes its own row. Learning about a match
-- happens via a `races` row appearing (see enqueue_for_race), not by
-- polling the queue.
grant insert, delete on public.matchmaking_queue to authenticated;

create policy "Users can enqueue themselves"
  on public.matchmaking_queue for insert
  to authenticated
  with check (auth.uid() = profile_id);

create policy "Users can dequeue themselves"
  on public.matchmaking_queue for delete
  to authenticated
  using (auth.uid() = profile_id);

create table public.races (
  id uuid primary key default gen_random_uuid(),
  player_a uuid not null references public.profiles,
  player_b uuid not null references public.profiles,
  -- Always the player who was already waiting in the queue (see
  -- enqueue_for_race) — always equals player_a. Kept as its own column
  -- (rather than relying on that convention) so the intent is explicit at
  -- every call site that checks "am I the one who should upload a puzzle?".
  puzzle_provider uuid not null references public.profiles,
  puzzle jsonb,
  solution jsonb,
  fixed_mask jsonb,
  difficulty text not null,
  status text not null default 'pending_puzzle',
  winner_id uuid references public.profiles,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.races enable row level security;

-- No client INSERT/UPDATE/DELETE grants at all — every write goes through
-- the SECURITY DEFINER functions below, so status transitions and the
-- solution-vs-submitted-board check can never be bypassed from the client.
grant select on public.races to authenticated;

create policy "Players can view their own race"
  on public.races for select
  to authenticated
  using (auth.uid() = player_a or auth.uid() = player_b);

-- Lets clients subscribe to `races` via Postgres Changes (matchmaking/race
-- status updates). No equivalent needed for matchmaking_queue — nothing
-- subscribes to it.
alter publication supabase_realtime add table public.races;

-- Registers the caller for [p_difficulty]. If someone is already waiting,
-- matches with them immediately (locking their queue row with SKIP LOCKED
-- so a third concurrent caller can't also grab them) and returns the new
-- race's id — the waiting player becomes player_a/puzzle_provider, the
-- caller becomes player_b. Otherwise enqueues the caller and returns null;
-- that client learns about its eventual match by watching for a `races`
-- row naming it as player_a.
create function public.enqueue_for_race(p_difficulty text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_self uuid := auth.uid();
  v_opponent_id uuid;
  v_race_id uuid;
begin
  -- Clear any stale entry from a previous session before searching/enqueuing.
  delete from matchmaking_queue where profile_id = v_self;

  select profile_id into v_opponent_id
    from matchmaking_queue
    where difficulty = p_difficulty
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
      values (v_self, p_difficulty, (select rating from profiles where id = v_self));
    return null;
  end if;
end;
$$;

-- Supabase's `public` schema grants EXECUTE to anon/authenticated/
-- service_role by default privilege when a function is created, regardless
-- of the `revoke ... from public` above (that only strips the PUBLIC
-- pseudo-role's grant, not each named role's own) — anon must be revoked
-- explicitly too, same lesson as 0002_lock_down_handle_new_user.sql.
revoke execute on function public.enqueue_for_race(text) from public, anon;
grant execute on function public.enqueue_for_race(text) to authenticated;

-- Only the designated puzzle_provider, and only while still pending, may
-- upload the puzzle. Raises if the caller isn't allowed to (wrong race,
-- wrong player, or already past pending_puzzle) so the client sees a clear
-- error instead of a silent no-op.
create function public.mark_puzzle_ready(
  p_race_id uuid,
  p_puzzle jsonb,
  p_solution jsonb,
  p_fixed_mask jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update races
    set puzzle = p_puzzle, solution = p_solution, fixed_mask = p_fixed_mask, status = 'ready'
    where id = p_race_id and puzzle_provider = auth.uid() and status = 'pending_puzzle';

  if not found then
    raise exception 'race % is not awaiting a puzzle from you', p_race_id;
  end if;
end;
$$;

revoke execute on function public.mark_puzzle_ready(uuid, jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.mark_puzzle_ready(uuid, jsonb, jsonb, jsonb) to authenticated;

-- Either player may call this once both are ready (client learns "both
-- ready" via Realtime Presence on the race's channel) — recording
-- started_at server-side so neither client can unilaterally start early.
-- A no-op (not an error) if already started: both clients racing to call
-- this, or one calling after the other already flipped it, are both
-- expected, not failures.
create function public.start_race(p_race_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update races
    set status = 'in_progress', started_at = now()
    where id = p_race_id
      and status = 'ready'
      and (auth.uid() = player_a or auth.uid() = player_b);
end;
$$;

revoke execute on function public.start_race(uuid) from public, anon;
grant execute on function public.start_race(uuid) to authenticated;

-- Verifies the submitted board against the server-held solution (never
-- trusting the client's own "I won" claim), then a `status = 'in_progress'`
-- compare-and-swap decides the race atomically — if both players finish
-- within the same instant, only the update that actually flips the row
-- wins. Returns true only for the submission that won the race; false for
-- a wrong board (caller should keep playing) or one that lost the CAS
-- (race already decided). wins/losses are updated in the same transaction
-- as the status flip so they can never drift from the race outcome; rating
-- changes are Phase 4.
create function public.submit_race_finish(p_race_id uuid, p_board jsonb)
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

  update profiles set wins = wins + 1 where id = v_self;
  update profiles set losses = losses + 1 where id = v_opponent;

  return true;
end;
$$;

revoke execute on function public.submit_race_finish(uuid, jsonb) from public, anon;
grant execute on function public.submit_race_finish(uuid, jsonb) to authenticated;

-- Either player can abort any not-yet-decided race (explicit "give up"
-- action only — no automatic timeout/disconnect forfeiture in this MVP).
-- No rating or win/loss change.
create function public.abort_race(p_race_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update races
    set status = 'aborted', finished_at = now()
    where id = p_race_id
      and status not in ('finished', 'aborted')
      and (auth.uid() = player_a or auth.uid() = player_b);
end;
$$;

revoke execute on function public.abort_race(uuid) from public, anon;
grant execute on function public.abort_race(uuid) to authenticated;
