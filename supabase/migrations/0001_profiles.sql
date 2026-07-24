-- Phase 1: profiles table, auto-provisioned on signup (including anonymous
-- sign-in), with a random unique username the user can rename later.

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text not null unique check (char_length(username) between 1 and 20),
  avatar_url text,
  rating integer not null default 1200,
  tier text not null default 'bronze',
  wins integer not null default 0,
  losses integer not null default 0,
  created_at timestamptz not null default now()
);

grant select on public.profiles to anon, authenticated;
-- Column-level grant: authenticated users may only ever change these two
-- columns themselves. rating/tier/wins/losses are written exclusively by
-- SECURITY DEFINER race-resolution functions added in a later phase.
grant update (username, avatar_url) on public.profiles to authenticated;

alter table public.profiles enable row level security;

create policy "Profiles are viewable by everyone"
  on public.profiles for select
  using (true);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Auto-create a profile (with a random placeholder username) whenever a new
-- auth.users row appears, including anonymous sign-ins. Runs as the
-- function owner (security definer) so it isn't subject to the RLS policies
-- above, and retries on a username collision since candidates aren't
-- reserved ahead of time.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  candidate text;
begin
  loop
    candidate := 'Player' || floor(random() * 1000000)::text;
    begin
      insert into public.profiles (id, username) values (new.id, candidate);
      exit;
    exception when unique_violation then
      -- candidate taken, loop and try another
    end;
  end loop;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
