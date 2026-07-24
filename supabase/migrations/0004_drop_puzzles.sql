-- PIN-based puzzle sharing (0003) is removed in favor of a purely local
-- text code (no server round trip, no sign-in needed). The puzzles table's
-- only consumer was the PIN flow, so nothing in the app touches it anymore
-- — dropping it rather than leaving a dead table + RLS policies around.
-- Phase 3's race-puzzle-delivery mechanism will define its own schema when
-- that phase is actually scoped.
drop table public.puzzles;
