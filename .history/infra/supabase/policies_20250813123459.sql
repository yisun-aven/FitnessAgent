-- Enable RLS
alter table public.profiles enable row level security;
alter table public.goals enable row level security;
alter table public.tasks enable row level security;

-- Policies: owner-only access
create policy if not exists "Profiles are viewable by owner" on public.profiles
  for select using (auth.uid() = id);
create policy if not exists "Profiles are insertable by owner" on public.profiles
  for insert with check (auth.uid() = id);
create policy if not exists "Profiles are updatable by owner" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

create policy if not exists "Goals are viewable by owner" on public.goals
  for select using (auth.uid() = user_id);
create policy if not exists "Goals are modifiable by owner" on public.goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "Tasks are viewable by owner" on public.tasks
  for select using (auth.uid() = user_id);
create policy if not exists "Tasks are modifiable by owner" on public.tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
