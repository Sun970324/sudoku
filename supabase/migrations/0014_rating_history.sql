-- Phase 5 stretch: rating trend graph. No new table — the per-race rating
-- outcome is already persisted on `races` (0007's player_*_rating_after/
-- delta columns), so this RPC just derives the caller's chronological rating
-- series from their finished ranked races. Private/friend races carry a null
-- delta (0010 gates apply_race_result for them), so the delta-not-null
-- filter excludes them exactly like RaceService.fetchHistory does.
--
-- Returns the most recent 100 ranked races, oldest-first, each as
-- {finished_at, rating, delta} where rating is the caller's own
-- post-race rating. The client prepends the pre-first-race baseline
-- (rating - delta of the earliest point) so the trend starts from where the
-- player began rather than after their first result.
create function public.get_my_rating_history()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with mine as (
    select finished_at,
           case when player_a = auth.uid()
                then player_a_rating_after else player_b_rating_after end as rating,
           case when player_a = auth.uid()
                then player_a_rating_delta else player_b_rating_delta end as delta
      from races
      where status = 'finished'
        and (player_a = auth.uid() or player_b = auth.uid())
        and (case when player_a = auth.uid()
                  then player_a_rating_delta else player_b_rating_delta end) is not null
      order by finished_at desc
      limit 100
  )
  select coalesce(
    (select jsonb_agg(jsonb_build_object(
        'finished_at', finished_at, 'rating', rating, 'delta', delta
      ) order by finished_at asc)
      from mine),
    '[]'::jsonb);
$$;

revoke execute on function public.get_my_rating_history() from public, anon;
grant execute on function public.get_my_rating_history() to authenticated;
