-- Daily Sudoku: one shared medium puzzle per day, ranked by pure elapsed
-- time. The puzzle is client-generated (the generator is Dart-only, same
-- constraint as races) and seeded first-writer-wins into daily_puzzles.
-- The day boundary is fixed to Asia/Seoul and computed exclusively
-- server-side — no RPC accepts a date from the client, so client clocks
-- and timezones can never disagree about which day a puzzle or result
-- belongs to.

create table public.daily_puzzles (
  puzzle_date date primary key,
  puzzle jsonb not null,
  solution jsonb not null,
  fixed_mask jsonb not null,
  difficulty text not null default 'medium',
  created_by uuid references public.profiles,
  created_at timestamptz not null default now()
);

create table public.daily_results (
  puzzle_date date not null references public.daily_puzzles,
  profile_id uuid not null references public.profiles on delete cascade,
  elapsed_seconds integer not null check (elapsed_seconds > 0),
  mistakes integer not null default 0,
  hints_used integer not null default 0,
  finished_at timestamptz not null default now(),
  primary key (puzzle_date, profile_id)
);

-- Serves get_daily_leaderboard's exact ordering.
create index daily_results_rank_idx
  on public.daily_results (puzzle_date, elapsed_seconds, finished_at);

-- No SELECT/INSERT/UPDATE/DELETE grants at all on either table — every
-- access goes through the SECURITY DEFINER functions below. RLS enabled
-- as belt-and-braces should a grant ever appear later.
alter table public.daily_puzzles enable row level security;
alter table public.daily_results enable row level security;

-- Today's puzzle row as jsonb, or null if nobody has seeded it yet. The
-- solution ships to the client (GameController needs it for mistake
-- detection — same accepted trade-off as races).
create function public.get_daily_puzzle()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select to_jsonb(d) from daily_puzzles d
    where puzzle_date = (now() at time zone 'Asia/Seoul')::date;
$$;

revoke execute on function public.get_daily_puzzle() from public, anon;
grant execute on function public.get_daily_puzzle() to authenticated;

-- Structural + validity check on a candidate daily puzzle: 9x9 shapes,
-- solution rows/columns/boxes are each a permutation of 1..9, the puzzle
-- agrees with the solution wherever non-zero, and fixed_mask is true
-- exactly where the puzzle is non-zero. Stricter than races'
-- mark_puzzle_ready because a bad seed here poisons the whole day for
-- every user, not just one match. Internal only — no role can call it.
create function public.is_valid_daily_puzzle(
  p_puzzle jsonb, p_solution jsonb, p_fixed_mask jsonb
) returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  r int; c int; b int;
  v int; pv int;
  seen int[];
begin
  if jsonb_typeof(p_puzzle) != 'array'
     or jsonb_typeof(p_solution) != 'array'
     or jsonb_typeof(p_fixed_mask) != 'array'
     or jsonb_array_length(p_puzzle) != 9
     or jsonb_array_length(p_solution) != 9
     or jsonb_array_length(p_fixed_mask) != 9 then
    return false;
  end if;
  for r in 0..8 loop
    if jsonb_array_length(p_puzzle->r) != 9
       or jsonb_array_length(p_solution->r) != 9
       or jsonb_array_length(p_fixed_mask->r) != 9 then
      return false;
    end if;
    for c in 0..8 loop
      v := (p_solution->r->>c)::int;
      pv := (p_puzzle->r->>c)::int;
      if v not between 1 and 9 or pv not between 0 and 9 then
        return false;
      end if;
      if pv != 0 and pv != v then
        return false;
      end if;
      if ((p_fixed_mask->r->>c)::boolean) != (pv != 0) then
        return false;
      end if;
    end loop;
  end loop;
  for r in 0..8 loop
    seen := array_fill(0, array[9]);
    for c in 0..8 loop
      v := (p_solution->r->>c)::int;
      seen[v] := seen[v] + 1;
    end loop;
    if 1 != all(seen) then return false; end if;
  end loop;
  for c in 0..8 loop
    seen := array_fill(0, array[9]);
    for r in 0..8 loop
      v := (p_solution->r->>c)::int;
      seen[v] := seen[v] + 1;
    end loop;
    if 1 != all(seen) then return false; end if;
  end loop;
  for b in 0..8 loop
    seen := array_fill(0, array[9]);
    for r in 0..2 loop
      for c in 0..2 loop
        v := (p_solution->((b/3)*3 + r)->>((b%3)*3 + c))::int;
        seen[v] := seen[v] + 1;
      end loop;
    end loop;
    if 1 != all(seen) then return false; end if;
  end loop;
  return true;
exception when others then
  -- Malformed jsonb (non-numeric cells, wrong types) lands here rather
  -- than surfacing as a cast error to the caller.
  return false;
end;
$$;

revoke execute on function public.is_valid_daily_puzzle(jsonb, jsonb, jsonb)
  from public, anon, authenticated;

-- First-writer-wins seeding of today's puzzle. Difficulty is hardcoded
-- 'medium' server-side. Always returns the canonical row — which may be a
-- concurrent caller's puzzle, not the one just uploaded — so the losing
-- client needs no separate re-fetch after the insert race.
create function public.create_daily_puzzle(
  p_puzzle jsonb, p_solution jsonb, p_fixed_mask jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_row daily_puzzles;
begin
  if not is_valid_daily_puzzle(p_puzzle, p_solution, p_fixed_mask) then
    raise exception 'invalid daily puzzle payload';
  end if;

  insert into daily_puzzles (puzzle_date, puzzle, solution, fixed_mask, difficulty, created_by)
    values (v_today, p_puzzle, p_solution, p_fixed_mask, 'medium', auth.uid())
    on conflict (puzzle_date) do nothing;

  select * into v_row from daily_puzzles where puzzle_date = v_today;
  return to_jsonb(v_row);
end;
$$;

revoke execute on function public.create_daily_puzzle(jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.create_daily_puzzle(jsonb, jsonb, jsonb) to authenticated;

-- Verifies the board against TODAY's server-held solution, then records
-- the caller's first completion only (on conflict do nothing). Returns
-- true only when a new row was actually recorded — false for a wrong
-- board, no puzzle today (e.g. finished just past the KST midnight
-- boundary), or an already-recorded completion. Elapsed time is
-- client-reported (accepted MVP trade-off, same as races).
create function public.submit_daily_result(
  p_board jsonb, p_elapsed_seconds integer, p_mistakes integer, p_hints_used integer
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_solution jsonb;
begin
  select solution into v_solution from daily_puzzles where puzzle_date = v_today;
  if v_solution is null or p_board != v_solution then
    return false;
  end if;
  if p_elapsed_seconds is null or p_elapsed_seconds <= 0
     or p_mistakes is null or p_mistakes < 0
     or p_hints_used is null or p_hints_used < 0 then
    return false;
  end if;

  insert into daily_results (puzzle_date, profile_id, elapsed_seconds, mistakes, hints_used)
    values (v_today, auth.uid(), p_elapsed_seconds, p_mistakes, p_hints_used)
    on conflict do nothing;
  return found;
end;
$$;

revoke execute on function public.submit_daily_result(jsonb, integer, integer, integer) from public, anon;
grant execute on function public.submit_daily_result(jsonb, integer, integer, integer) to authenticated;

-- Today's leaderboard in one round trip: total finisher count, the
-- caller's rank/time (null when not yet completed — doubles as the
-- "already completed today?" check), and the top 10. Ordering is
-- elapsed_seconds asc with finished_at asc as the tie-break, so the
-- tie-break rule lives in exactly one place.
create function public.get_daily_leaderboard()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with ranked as (
    select r.profile_id, p.username, r.elapsed_seconds,
           rank() over (order by r.elapsed_seconds asc, r.finished_at asc) as rnk
      from daily_results r
      join profiles p on p.id = r.profile_id
      where r.puzzle_date = (now() at time zone 'Asia/Seoul')::date
  )
  select jsonb_build_object(
    'total', (select count(*) from ranked),
    'my_rank', (select rnk from ranked where profile_id = auth.uid()),
    'my_elapsed_seconds',
      (select elapsed_seconds from ranked where profile_id = auth.uid()),
    'entries', coalesce(
      (select jsonb_agg(jsonb_build_object(
          'rank', rnk, 'profile_id', profile_id,
          'username', username, 'elapsed_seconds', elapsed_seconds
        ) order by rnk)
        from (select * from ranked order by rnk limit 10) top),
      '[]'::jsonb)
  );
$$;

revoke execute on function public.get_daily_leaderboard() from public, anon;
grant execute on function public.get_daily_leaderboard() to authenticated;
