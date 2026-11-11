-- Progress: weigh-ins, body composition (coach-entered), measurements, check-ins, goals, phases.

create type public.photo_view as enum ('front', 'side', 'back');

create table public.weigh_ins (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  measured_at timestamptz not null,
  kg numeric(5, 2) not null check (kg > 30 and kg < 250),
  fasted boolean not null default true,
  created_at timestamptz not null default now(),
  unique (client_id, measured_at)
);
create index on public.weigh_ins (client_id, measured_at desc);

-- Lean and fat mass are derived (weight × %), never stored.
create table public.body_composition (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  measured_on date not null,
  weight_kg numeric(5, 2) not null check (weight_kg > 30 and weight_kg < 250),
  body_fat_pct numeric(4, 1) not null check (body_fat_pct > 2 and body_fat_pct < 60),
  method text not null check (method in ('skinfold_7', 'skinfold_3', 'bioimpedance', 'dexa')),
  recorded_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index on public.body_composition (client_id, measured_on);

create table public.measurements (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  measured_on date not null,
  waist numeric(5, 1),
  hip numeric(5, 1),
  chest numeric(5, 1),
  arm numeric(5, 1),
  thigh numeric(5, 1),
  created_at timestamptz not null default now(),
  unique (client_id, measured_on)
);

create table public.check_ins (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  week smallint not null check (week >= 0),
  submitted_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending', 'reviewed')),
  weight_kg numeric(5, 2),
  waist_cm numeric(5, 1),
  energy smallint check (energy between 1 and 10),
  hunger smallint check (hunger between 1 and 10),
  sleep smallint check (sleep between 1 and 10),
  stress smallint check (stress between 1 and 10),
  adherence smallint check (adherence between 1 and 10),
  client_note text not null default '',
  coach_feedback text,
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  unique (client_id, week)
);
create index on public.check_ins (status, submitted_at);

create table public.check_in_photos (
  id uuid primary key default gen_random_uuid(),
  check_in_id uuid not null references public.check_ins (id) on delete cascade,
  view public.photo_view not null,
  path text not null,
  unique (check_in_id, view)
);

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  metric text not null,
  label text not null,
  unit text not null default '',
  start_value numeric(7, 2) not null,
  target_value numeric(7, 2) not null,
  due_date date,
  created_at timestamptz not null default now()
);

create table public.phases (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  name text not null,
  start_date date not null,
  end_date date not null,
  check (end_date >= start_date)
);

-- Clients can't touch review fields, staff can't rewrite what the client answered.
create function private.guard_check_in()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if private.auth_role() = 'client' then
    if old.status = 'reviewed' then
      raise exception 'Este check-in ya está revisado' using errcode = '42501';
    end if;
    new.status := old.status;
    new.coach_feedback := old.coach_feedback;
    new.reviewed_by := old.reviewed_by;
    new.reviewed_at := old.reviewed_at;
  else
    new.client_id := old.client_id;
    new.week := old.week;
    new.submitted_at := old.submitted_at;
    new.weight_kg := old.weight_kg;
    new.waist_cm := old.waist_cm;
    new.energy := old.energy;
    new.hunger := old.hunger;
    new.sleep := old.sleep;
    new.stress := old.stress;
    new.adherence := old.adherence;
    new.client_note := old.client_note;
    if new.status = 'reviewed' and old.status <> 'reviewed' then
      new.reviewed_by := (select auth.uid());
      new.reviewed_at := now();
    end if;
  end if;
  return new;
end;
$$;

create trigger check_ins_guard before update on public.check_ins
  for each row execute function private.guard_check_in();

create function private.client_of_check_in(cid uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select client_id from public.check_ins where id = cid
$$;

-- Any staff member with a health permission over the client can read progress data.
create function private.staff_reads_health(cid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.staff_can(cid, 'checkins') or private.staff_can(cid, 'composicion')
    or private.staff_can(cid, 'entrenos') or private.staff_can(cid, 'dietas')
$$;

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

-- ---------- RLS

alter table public.weigh_ins enable row level security;
alter table public.body_composition enable row level security;
alter table public.measurements enable row level security;
alter table public.check_ins enable row level security;
alter table public.check_in_photos enable row level security;
alter table public.goals enable row level security;
alter table public.phases enable row level security;

create policy "weigh_ins: read" on public.weigh_ins for select to authenticated
  using (client_id = private.my_client_id() or private.staff_reads_health(client_id));
create policy "weigh_ins: client write" on public.weigh_ins for all to authenticated
  using (client_id = private.my_client_id()) with check (client_id = private.my_client_id());

create policy "body_composition: read" on public.body_composition for select to authenticated
  using (client_id = private.my_client_id() or private.staff_reads_health(client_id));
create policy "body_composition: staff write" on public.body_composition for all to authenticated
  using (private.staff_can(client_id, 'composicion')) with check (private.staff_can(client_id, 'composicion'));

create policy "measurements: read" on public.measurements for select to authenticated
  using (client_id = private.my_client_id() or private.staff_reads_health(client_id));
create policy "measurements: write" on public.measurements for all to authenticated
  using (client_id = private.my_client_id() or private.staff_can(client_id, 'composicion'))
  with check (client_id = private.my_client_id() or private.staff_can(client_id, 'composicion'));

create policy "check_ins: read" on public.check_ins for select to authenticated
  using (client_id = private.my_client_id() or private.staff_reads_health(client_id));
create policy "check_ins: client create" on public.check_ins for insert to authenticated
  with check (client_id = private.my_client_id() and status = 'pending' and coach_feedback is null);
create policy "check_ins: update" on public.check_ins for update to authenticated
  using (client_id = private.my_client_id() or private.staff_can(client_id, 'checkins'))
  with check (client_id = private.my_client_id() or private.staff_can(client_id, 'checkins'));

create policy "check_in_photos: read" on public.check_in_photos for select to authenticated
  using (
    private.client_of_check_in(check_in_id) = private.my_client_id()
    or private.staff_reads_health(private.client_of_check_in(check_in_id))
  );
create policy "check_in_photos: client write" on public.check_in_photos for all to authenticated
  using (private.client_of_check_in(check_in_id) = private.my_client_id())
  with check (private.client_of_check_in(check_in_id) = private.my_client_id());

create policy "goals: read" on public.goals for select to authenticated
  using (client_id = private.my_client_id() or private.staff_reads_health(client_id));
create policy "goals: staff write" on public.goals for all to authenticated
  using (private.staff_can(client_id, 'entrenos') or private.staff_can(client_id, 'dietas'))
  with check (private.staff_can(client_id, 'entrenos') or private.staff_can(client_id, 'dietas'));

create policy "phases: read" on public.phases for select to authenticated
  using (client_id = private.my_client_id() or private.staff_reads_health(client_id));
create policy "phases: staff write" on public.phases for all to authenticated
  using (private.staff_can(client_id, 'entrenos') or private.staff_can(client_id, 'dietas'))
  with check (private.staff_can(client_id, 'entrenos') or private.staff_can(client_id, 'dietas'));
