-- Training: library, plans (days → items), workout sessions and sets, personal records.

create type public.publish_status as enum ('draft', 'published', 'archived');

-- Recommended weekly volume (effective sets). Seed values are provisional until confirmed.
create table public.muscle_groups (
  id text primary key,
  name text not null,
  sets_min smallint not null check (sets_min >= 0),
  sets_max smallint not null,
  sort smallint not null default 0,
  check (sets_max >= sets_min)
);

create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  muscle_primary text not null references public.muscle_groups (id),
  muscles_secondary text[] not null default '{}',
  equipment text not null default '',
  video_path text,
  video_duration_s integer check (video_duration_s > 0),
  cues text[] not null default '{}',
  common_error text not null default '',
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.training_plans (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  name text not null default 'Plan de entrenamiento',
  status public.publish_status not null default 'draft',
  published_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index on public.training_plans (client_id);
-- One live plan per client; drafts and archived ones can coexist.
create unique index training_plans_one_published on public.training_plans (client_id) where status = 'published';

create table public.training_days (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.training_plans (id) on delete cascade,
  name text not null,
  weekday smallint check (weekday between 0 and 6),
  sort smallint not null default 0
);
create index on public.training_days (plan_id);

create table public.training_items (
  id uuid primary key default gen_random_uuid(),
  day_id uuid not null references public.training_days (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id),
  sort smallint not null default 0,
  sets smallint not null check (sets between 1 and 20),
  rep_range text not null default '',
  rir text not null default '',
  rest_seconds smallint not null default 120 check (rest_seconds >= 0),
  objective text not null default '',
  pct_rm text not null default '',
  technique_note text not null default ''
);
create index on public.training_items (day_id);

create table public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  day_id uuid references public.training_days (id) on delete set null,
  performed_on date not null default current_date,
  started_at timestamptz not null default now(),
  finished_at timestamptz
);
create index on public.workout_sessions (client_id, performed_on);

-- A set belongs to a planned item, a library exercise, or a free «ejercicio adicional».
create table public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  training_item_id uuid references public.training_items (id) on delete set null,
  exercise_id uuid references public.exercises (id) on delete set null,
  extra_name text,
  extra_muscle text references public.muscle_groups (id),
  set_index smallint not null check (set_index >= 1),
  kg numeric(6, 2) check (kg >= 0),
  reps smallint check (reps >= 0),
  rir_real numeric(3, 1),
  done boolean not null default false,
  created_at timestamptz not null default now(),
  check (training_item_id is not null or exercise_id is not null or (extra_name is not null and extra_muscle is not null))
);
create index on public.workout_sets (session_id);

create table public.exercise_swap_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  training_item_id uuid not null references public.training_items (id) on delete cascade,
  reason text not null check (length(reason) between 1 and 1000),
  status text not null default 'pending' check (status in ('pending', 'resolved', 'rejected')),
  response text,
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Estimated 1RM (Epley) for every completed set; PR flags are computed in the app.
create view public.set_estimates
with (security_invoker = true) as
select
  ws.id as set_id,
  s.client_id,
  s.performed_on,
  coalesce(ws.exercise_id, ti.exercise_id) as exercise_id,
  ws.kg,
  ws.reps,
  round(ws.kg * (1 + ws.reps / 30.0), 1) as e1rm
from public.workout_sets ws
join public.workout_sessions s on s.id = ws.session_id
left join public.training_items ti on ti.id = ws.training_item_id
where ws.done and ws.kg > 0 and ws.reps > 0 and coalesce(ws.exercise_id, ti.exercise_id) is not null;

-- ---------- helpers to resolve the owning client of nested rows

create function private.client_of_training_plan(pid uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select client_id from public.training_plans where id = pid
$$;

create function private.client_of_training_day(did uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select p.client_id from public.training_days d join public.training_plans p on p.id = d.plan_id where d.id = did
$$;

create function private.training_day_visible(did uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.training_days d join public.training_plans p on p.id = d.plan_id
    where d.id = did
      and private.can_access_client(p.client_id)
      and (private.auth_role() <> 'client' or p.status = 'published')
  )
$$;

create function private.client_of_session(sid uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select client_id from public.workout_sessions where id = sid
$$;

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

-- ---------- RLS

alter table public.muscle_groups enable row level security;
alter table public.exercises enable row level security;
alter table public.training_plans enable row level security;
alter table public.training_days enable row level security;
alter table public.training_items enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_sets enable row level security;
alter table public.exercise_swap_requests enable row level security;

create policy "muscle_groups: read" on public.muscle_groups for select to authenticated using (true);
create policy "muscle_groups: admin write" on public.muscle_groups for all to authenticated
  using (private.auth_role() = 'admin') with check (private.auth_role() = 'admin');

create policy "exercises: read" on public.exercises for select to authenticated using (true);
create policy "exercises: library write" on public.exercises for all to authenticated
  using (private.has_perm('biblioteca') and private.auth_role() <> 'billing')
  with check (private.has_perm('biblioteca') and private.auth_role() <> 'billing');

create policy "training_plans: read" on public.training_plans for select to authenticated
  using (private.can_access_client(client_id) and (private.auth_role() <> 'client' or status = 'published'));
create policy "training_plans: staff write" on public.training_plans for all to authenticated
  using (private.staff_can(client_id, 'entrenos')) with check (private.staff_can(client_id, 'entrenos'));

create policy "training_days: read" on public.training_days for select to authenticated
  using (private.training_day_visible(id));
create policy "training_days: staff write" on public.training_days for all to authenticated
  using (private.staff_can(private.client_of_training_plan(plan_id), 'entrenos'))
  with check (private.staff_can(private.client_of_training_plan(plan_id), 'entrenos'));

create policy "training_items: read" on public.training_items for select to authenticated
  using (private.training_day_visible(day_id));
create policy "training_items: staff write" on public.training_items for all to authenticated
  using (private.staff_can(private.client_of_training_day(day_id), 'entrenos'))
  with check (private.staff_can(private.client_of_training_day(day_id), 'entrenos'));

-- Clients log their own workouts; staff with «entrenos» can read them.
create policy "workout_sessions: read" on public.workout_sessions for select to authenticated
  using (client_id = private.my_client_id() or private.staff_can(client_id, 'entrenos'));
create policy "workout_sessions: client write" on public.workout_sessions for all to authenticated
  using (client_id = private.my_client_id()) with check (client_id = private.my_client_id());

create policy "workout_sets: read" on public.workout_sets for select to authenticated
  using (
    private.client_of_session(session_id) = private.my_client_id()
    or private.staff_can(private.client_of_session(session_id), 'entrenos')
  );
create policy "workout_sets: client write" on public.workout_sets for all to authenticated
  using (private.client_of_session(session_id) = private.my_client_id())
  with check (private.client_of_session(session_id) = private.my_client_id());

create policy "swap_requests: read" on public.exercise_swap_requests for select to authenticated
  using (client_id = private.my_client_id() or private.staff_can(client_id, 'entrenos'));
create policy "swap_requests: client create" on public.exercise_swap_requests for insert to authenticated
  with check (client_id = private.my_client_id() and status = 'pending');
create policy "swap_requests: staff resolve" on public.exercise_swap_requests for update to authenticated
  using (private.staff_can(client_id, 'entrenos')) with check (private.staff_can(client_id, 'entrenos'));
