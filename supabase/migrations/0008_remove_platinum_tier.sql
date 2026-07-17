-- Keep the six player-facing tiers aligned with the six puzzle difficulties.
-- Existing Platinum profiles move to Diamond before future Elo updates use
-- the revised tier ladder.
update public.profiles set tier = 'diamond' where tier = 'platinum';

create or replace function public.tier_for_rating(p_rating integer, p_current_tier text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_rating >= 1900 and p_current_tier = 'challenger' then 'challenger'
    when p_rating >= 1700 then 'master'
    when p_rating >= 1500 then 'diamond'
    when p_rating >= 1300 then 'gold'
    when p_rating >= 1100 then 'silver'
    else 'bronze'
  end;
$$;

revoke execute on function public.tier_for_rating(integer, text) from public, anon;
