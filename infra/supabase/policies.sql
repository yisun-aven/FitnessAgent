-- =========================================
-- RLS: profiles, goals, tasks  (safe to rerun)
-- =========================================

-- 1) Enable and force RLS
alter table public.profiles enable row level security;
alter table public.goals    enable row level security;
alter table public.tasks    enable row level security;

-- (Optional but recommended) Force RLS even for table owners
alter table public.profiles force row level security;
alter table public.goals    force row level security;
alter table public.tasks    force row level security;

-- =========================================
-- PROFILES POLICIES
-- =========================================
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_delete_own" on public.profiles;

-- Insert own profile (id must equal auth.uid())
create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check (id = auth.uid());

-- Select own profile
create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());

-- Update own profile
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Optional: delete own profile
create policy "profiles_delete_own"
  on public.profiles
  for delete
  to authenticated
  using (id = auth.uid());

-- =========================================
-- GOALS POLICIES
-- =========================================
drop policy if exists "goals_insert_own" on public.goals;
drop policy if exists "goals_select_own" on public.goals;
drop policy if exists "goals_update_own" on public.goals;
drop policy if exists "goals_delete_own" on public.goals;

-- Insert own goals
create policy "goals_insert_own"
  on public.goals
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- Select own goals
create policy "goals_select_own"
  on public.goals
  for select
  to authenticated
  using (user_id = auth.uid());

-- Update own goals
create policy "goals_update_own"
  on public.goals
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Delete own goals
create policy "goals_delete_own"
  on public.goals
  for delete
  to authenticated
  using (user_id = auth.uid());

-- =========================================
-- TASKS POLICIES
-- =========================================
drop policy if exists "tasks_insert_own" on public.tasks;
drop policy if exists "tasks_select_own" on public.tasks;
drop policy if exists "tasks_update_own" on public.tasks;
drop policy if exists "tasks_delete_own" on public.tasks;

-- Insert own tasks
create policy "tasks_insert_own"
  on public.tasks
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- Select own tasks
create policy "tasks_select_own"
  on public.tasks
  for select
  to authenticated
  using (user_id = auth.uid());

-- Update own tasks
create policy "tasks_update_own"
  on public.tasks
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Delete own tasks
create policy "tasks_delete_own"
  on public.tasks
  for delete
  to authenticated
  using (user_id = auth.uid());
