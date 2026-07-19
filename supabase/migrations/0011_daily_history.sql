-- The caller's own daily-puzzle completion history, for the calendar view
-- on the stats screen. This is the one daily RPC that accepts dates from the
-- client — every other one (0009) is hardcoded to today's KST date — but it
-- is safe because it only ever returns the caller's own rows (auth.uid()),
-- and the range is capped, so it can't be used to scan the table.

create function public.get_my_daily_history(p_from date, p_to date)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'puzzle_date', r.puzzle_date,
      'elapsed_seconds', r.elapsed_seconds,
      'mistakes', r.mistakes
    ) order by r.puzzle_date), '[]'::jsonb)
  from daily_results r
  where r.profile_id = auth.uid()
    and r.puzzle_date between p_from and p_to
    -- Bound the window (a calendar shows one month at a time) so a client
    -- can't request an unbounded scan.
    and p_to - p_from between 0 and 62;
$$;

revoke execute on function public.get_my_daily_history(date, date) from public, anon;
grant execute on function public.get_my_daily_history(date, date) to authenticated;
