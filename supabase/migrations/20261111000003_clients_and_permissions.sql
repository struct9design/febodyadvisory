-- Core: plans, clients, configurable permissions and the RLS helpers every other table uses.

create type public.client_status as enum ('new', 'active', 'ending', 'paused', 'finished');

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  price_cents integer not null check (price_cents >= 0),
  installments smallint not null default 1 check (installments between 1 and 12),
  duration_weeks smallint not null check (duration_weeks > 0),
  active boolean not null default true,
  sort smallint not null default 0
);

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles (id) on delete cascade,
  plan_id uuid references public.plans (id) on delete set null,
  status public.client_status not null default 'new',
  goal text not null default '',
  coach_id uuid references public.profiles (id) on delete set null,
  nutritionist_id uuid references public.profiles (id) on delete set null,
  start_date date,
  end_date date,
  phone text,
  created_at timestamptz not null default now(),
  check (end_date is null or start_date is null or end_date >= start_date)
);
create index on public.clients (coach_id);
create index on public.clients (nutritionist_id);

-- Permission keys mirror the matrix in «Equipo y permisos». Admin is implicit (always true).
create table public.permission_keys (
  key text primary key,
  label text not null,
  sort smallint not null default 0
);

create table public.role_permissions (
  role public.app_role not null check (role in ('coach', 'nutritionist', 'billing')),
  permission_key text not null references public.permission_keys (key) on delete cascade,
  enabled boolean not null default false,
  primary key (role, permission_key)
);

insert into public.permission_keys (key, label, sort) values
  ('clientes_todos', 'Ver todos los clientes', 1),
  ('checkins', 'Revisar check-ins', 2),
  ('entrenos', 'Editar entrenamientos', 3),
  ('dietas', 'Editar dietas', 4),
  ('composicion', 'Registrar composición corporal', 5),
  ('biblioteca', 'Subir vídeos de ejercicios', 6),
  ('mensajes', 'Mensajes con clientes', 7),
  ('pagos', 'Ver pagos y facturas', 8),
  ('contratos', 'Gestionar contratos', 9),
  ('exportar', 'Exportar datos', 10),
  ('equipo', 'Gestionar equipo', 11);

insert into public.role_permissions (role, permission_key, enabled)
select r.role, k.key, k.key = any (r.defaults)
from public.permission_keys k
cross join (values
  ('coach'::public.app_role, array['checkins', 'entrenos', 'composicion', 'biblioteca', 'mensajes']),
  ('nutritionist'::public.app_role, array['checkins', 'dietas', 'composicion', 'mensajes']),
  ('billing'::public.app_role, array['pagos', 'contratos', 'mensajes', 'exportar'])
) as r(role, defaults);

-- ---------- RLS helpers (private schema, not exposed through the API)

create function private.has_perm(p text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select case private.auth_role()
    when 'admin' then true
    when 'client' then false
    else coalesce((
      select rp.enabled from public.role_permissions rp
      where rp.role = private.auth_role() and rp.permission_key = p
    ), false)
  end
$$;

create function private.my_client_id()
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select id from public.clients where profile_id = (select auth.uid())
$$;

-- Health data access: own data for clients, assigned clients for coach/nutritionist,
-- everything for admin, never for billing.
create function private.can_access_client(cid uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select case private.auth_role()
    when 'admin' then true
    when 'client' then cid = private.my_client_id()
    when 'coach' then private.has_perm('clientes_todos')
      or exists (select 1 from public.clients c where c.id = cid and c.coach_id = (select auth.uid()))
    when 'nutritionist' then private.has_perm('clientes_todos')
      or exists (select 1 from public.clients c where c.id = cid and c.nutritionist_id = (select auth.uid()))
    else false
  end
$$;

-- Staff member acting on a client with a given permission (clients themselves excluded).
create function private.staff_can(cid uuid, p text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select private.auth_role() in ('admin', 'coach', 'nutritionist')
    and private.can_access_client(cid)
    and private.has_perm(p)
$$;

-- Administrative access (billing): client list, invoices, contracts. No health data.
create function private.can_admin_client(cid uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select private.can_access_client(cid)
    or (private.auth_role() = 'billing' and (private.has_perm('pagos') or private.has_perm('contratos')))
$$;

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

-- ---------- RLS

alter table public.plans enable row level security;
alter table public.clients enable row level security;
alter table public.permission_keys enable row level security;
alter table public.role_permissions enable row level security;

create policy "plans: public read active" on public.plans
  for select to anon using (active);
create policy "plans: read" on public.plans
  for select to authenticated using (active or private.is_staff());
create policy "plans: admin write" on public.plans
  for all to authenticated
  using (private.auth_role() = 'admin') with check (private.auth_role() = 'admin');

create policy "clients: read" on public.clients
  for select to authenticated using (private.can_admin_client(id));
create policy "clients: admin write" on public.clients
  for all to authenticated
  using (private.auth_role() = 'admin') with check (private.auth_role() = 'admin');

create policy "permission_keys: staff read" on public.permission_keys
  for select to authenticated using (private.is_staff());

create policy "role_permissions: staff read" on public.role_permissions
  for select to authenticated using (private.is_staff());
create policy "role_permissions: admin write" on public.role_permissions
  for update to authenticated
  using (private.auth_role() = 'admin') with check (private.auth_role() = 'admin');

-- Profiles: let coaches/clients see the people they work with (names on the client card, chat header).
create policy "profiles: client sees own team" on public.profiles
  for select to authenticated
  using (exists (
    select 1 from public.clients c
    where c.profile_id = (select auth.uid()) and profiles.id in (c.coach_id, c.nutritionist_id)
  ));

-- Tighten phase-1 "staff read": coaches/nutritionists only see colleagues and their own clients.
alter policy "profiles: staff read" on public.profiles
  using (
    private.auth_role() in ('admin', 'billing')
    or (private.is_staff() and profiles.role <> 'client')
    or (private.is_staff() and exists (
      select 1 from public.clients c where c.profile_id = profiles.id and private.can_access_client(c.id)
    ))
  );
