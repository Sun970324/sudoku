-- Phase 4 (rank season): Challenger becomes a real, earnable tier. The 0006
-- design left it dormant ("only kept while already challenger"); now a daily
-- job crowns the top 10 players at rating >= 1900 and demotes everyone else
-- who no longer qualifies. Runs at 00:20 KST — ten minutes after the season
-- rollover check (0017) — so on reset day it re-evaluates the *post-reset*
-- ladder rather than the one about to be archived.

create function public.update_challenger_tiers()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Demote first: a fallen challenger lands on whatever tier their rating
  -- actually merits (not blindly 'master' — they may have dropped further),
  -- via tier_for_rating with a non-challenger current tier so the
  -- keep-challenger branch can't fire.
  update profiles set tier = tier_for_rating(rating, 'master')
    where tier = 'challenger'
      and id not in (
        select id from profiles
          where rating >= 1900
          order by rating desc, created_at asc
          limit 10);

  -- Then promote the current top 10 (same tiebreak as the leaderboard).
  -- Rating-based selection is unaffected by the demotions above, so the two
  -- statements agree on who qualifies.
  update profiles set tier = 'challenger'
    where tier <> 'challenger'
      and id in (
        select id from profiles
          where rating >= 1900
          order by rating desc, created_at asc
          limit 10);
end;
$$;

revoke execute on function public.update_challenger_tiers() from public, anon, authenticated;

select cron.schedule(
  'update-challenger-tiers',
  '20 15 * * *',
  $job$select public.update_challenger_tiers();$job$
);
