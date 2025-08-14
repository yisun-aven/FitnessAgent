-- Enable RLS
alter table public.profiles enable row level security;
alter table public.goals enable row level security;
alter table public.tasks enable row level security;

-- Policies: owner-only access (drop-if-exists to allow re-running safely)
-- profiles
drop policy if exists "Profiles are viewable by owner" on public.profiles;
drop policy if exists "Profiles are insertable by owner" on public.profiles;
drop policy if exists "Profiles are updatable by owner" on public.profiles;

create policy "Profiles are viewable by owner" on public.profiles
  for select using (auth.uid() = id);
create policy "Profiles are insertable by owner" on public.profiles
  for insert with check (auth.uid() = id);
create policy "Profiles are updatable by owner" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- goals
drop policy if exists "Goals are viewable by owner" on public.goals;
drop policy if exists "Goals are modifiable by owner" on public.goals;

create policy "Goals are viewable by owner" on public.goals
  for select using (auth.uid() = user_id);
create policy "Goals are modifiable by owner" on public.goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- tasks
drop policy if exists "Tasks are viewable by owner" on public.tasks;
drop policy if exists "Tasks are modifiable by owner" on public.tasks;

create policy "Tasks are viewable by owner" on public.tasks
  for select using (auth.uid() = user_id);
create policy "Tasks are modifiable by owner" on public.tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
