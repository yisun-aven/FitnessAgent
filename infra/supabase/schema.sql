-- Enable extension required for gen_random_uuid()
create extension if not exists pgcrypto;

-- Profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamp with time zone default now(),
  -- core onboarding
  sex text,
  dob date,
  height_cm numeric,
  weight_kg numeric,
  unit_pref text,
  activity_level text,
  fitness_level text,
  -- optional health metrics
  resting_hr numeric,
  max_hr numeric,
  body_fat_pct numeric,
  -- medical/safety
  medical_conditions text,
  injuries text,
  -- UX / scheduling
  timezone text,
  locale text,
  availability_days integer[]
);

-- Goals
create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  type text not null,
  target_value numeric,
  target_date date,
  status text default 'active',
  created_at timestamp with time zone default now()
);

-- Tasks
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  goal_id uuid references public.goals(id) on delete set null,
  title text not null,
  description text,
  due_at timestamp with time zone,
  status text default 'pending',
  calendar_event_id text,
  created_at timestamp with time zone default now()
);

-- Explicitly enable Row Level Security
alter table public.profiles enable row level security;
alter table public.goals enable row level security;
alter table public.tasks enable row level security;
