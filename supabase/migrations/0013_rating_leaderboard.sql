-- Phase 5 stretch: global rating leaderboard. Ranks players by rating
-- (desc), restricted to those who have actually played a ranked game
-- (wins + losses > 0) so the board isn't flooded with never-played 1200
-- guests. Returns the same single-jsonb shape as get_daily_leaderboard:
-- total count + the caller's own rank/rating (null if they haven't played)
-- + the top 100 entries.

-- Serves the RPC's exact ordering. Partial (played-only) to match the WHERE
-- filter, so the index stays small and covers the ranked set precisely.
create index profiles_rating_leaderboard_idx
  on public.profiles (rating desc, created_at asc)
  where wins + losses > 0;

create function public.get_rating_leaderboard()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with ranked as (
    select p.id, p.username, p.rating, p.tier, p.wins, p.losses,
           rank() over (order by p.rating desc, p.created_at asc) as rnk
      from profiles p
      where p.wins + p.losses > 0
  )
  select jsonb_build_object(
    'total', (select count(*) from ranked),
    'my_rank', (select rnk from ranked where id = auth.uid()),
    'my_rating', (select rating from ranked where id = auth.uid()),
    'entries', coalesce(
      (select jsonb_agg(jsonb_build_object(
          'rank', rnk, 'profile_id', id, 'username', username,
          'rating', rating, 'tier', tier, 'wins', wins, 'losses', losses
        ) order by rnk)
        from (select * from ranked order by rnk limit 100) top),
      '[]'::jsonb)
  );
$$;

revoke execute on function public.get_rating_leaderboard() from public, anon;
grant execute on function public.get_rating_leaderboard() to authenticated;
