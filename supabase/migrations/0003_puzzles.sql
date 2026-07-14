-- Phase 2: puzzles table for async puzzle sharing (PIN + text code). Also
-- the storage races (Phase 3) will reuse for delivering the shared board to
-- both players, hence columns mirror SudokuPuzzle's fields directly rather
-- than a single opaque JSON blob.

create table public.puzzles (
  id uuid primary key default gen_random_uuid(),
  puzzle jsonb not null,
  solution jsonb not null,
  fixed_mask jsonb not null,
  difficulty text not null,
  share_pin text unique,
  created_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '90 days')
);

grant select on public.puzzles to anon, authenticated;
grant insert on public.puzzles to authenticated;

alter table public.puzzles enable row level security;

create policy "Puzzles are viewable by everyone"
  on public.puzzles for select
  using (true);

-- Anyone signed in, including anonymous/guest sessions, can share a puzzle.
-- No PII involved and rows fall out of relevance after expires_at, so an
-- unauthenticated full-table scan being technically possible (no index-only
-- PIN lookup enforced) is an accepted trade-off rather than a gap.
create policy "Authenticated users can create puzzles"
  on public.puzzles for insert
  to authenticated
  with check (auth.uid() = created_by);
