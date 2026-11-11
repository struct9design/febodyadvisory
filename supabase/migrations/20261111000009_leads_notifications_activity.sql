-- Website leads, in-app notifications, team invitations and the activity feed.

create table public.leads (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(name) between 1 and 120),
  email text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 254),
  goal text check (goal in ('Ganar masa muscular', 'Perder grasa', 'Recomposición', 'Competir')),
  plan_interest text,
  message text check (length(message) <= 2000),
  status text not null default 'new' check (status in ('new', 'contacted', 'converted', 'discarded')),
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null default '',
  link text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index on public.notifications (profile_id, created_at desc);

create table public.team_invitations (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  full_name text not null,
  role public.app_role not null check (role in ('coach', 'nutritionist', 'billing')),
  invited_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz
);

create table public.activity_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles (id) on delete set null,
  client_id uuid references public.clients (id) on delete cascade,
  action text not null,
  entity text not null,
  entity_id uuid,
  summary text not null default '',
  created_at timestamptz not null default now()
);
create index on public.activity_log (created_at desc);

-- ---------- notifications fired by the database so no code path can forget them

create function private.notify(target uuid, k text, t text, b text, l text) returns void
language sql security definer set search_path = '' as $$
  insert into public.notifications (profile_id, kind, title, body, link)
  select target, k, t, b, l where target is not null
$$;

create function private.on_check_in_reviewed() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'reviewed' and old.status <> 'reviewed' then
    perform private.notify(
      (select profile_id from public.clients where id = new.client_id),
      'check_in_reviewed', 'Tu check-in está revisado',
      coalesce(left(new.coach_feedback, 140), ''), '/app/progreso'
    );
  end if;
  return new;
end;
$$;
create trigger check_ins_notify after update on public.check_ins
  for each row execute function private.on_check_in_reviewed();

create function private.on_proposal_reviewed() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status <> 'pending' and old.status = 'pending' then
    perform private.notify(
      (select profile_id from public.clients where id = new.client_id),
      'food_proposal', case new.status when 'approved' then 'Propuesta aprobada' else 'Propuesta rechazada' end,
      new.text, '/app/nutricion'
    );
  end if;
  return new;
end;
$$;
create trigger food_proposals_notify after update on public.food_proposals
  for each row execute function private.on_proposal_reviewed();

-- ---------- activity feed («Actividad reciente»)

create function private.log_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  summary text;
begin
  -- IF branches, not CASE: plpgsql resolves every NEW.field in one expression up front.
  if tg_table_name = 'weigh_ins' then
    summary := format('registró pesaje: %s kg%s', replace(new.kg::text, '.', ','), case when new.fasted then ' en ayunas' else '' end);
  elsif tg_table_name = 'check_ins' and tg_op = 'INSERT' then
    summary := format('envió el check-in de la semana %s', new.week);
  elsif tg_table_name = 'check_ins' then
    summary := format('revisó el check-in de la semana %s', new.week);
  elsif tg_table_name = 'body_composition' then
    summary := format('registró composición: %s %% graso', replace(new.body_fat_pct::text, '.', ','));
  elsif tg_table_name = 'invoices' then
    summary := format('validó el pago %s', new.number);
  elsif tg_table_name = 'training_plans' then
    summary := 'publicó un plan de entrenamiento';
  elsif tg_table_name = 'nutrition_plans' then
    summary := 'publicó un plan nutricional';
  else
    summary := lower(tg_op);
  end if;
  insert into public.activity_log (actor_id, client_id, action, entity, entity_id, summary)
  values ((select auth.uid()), new.client_id, lower(tg_op), tg_table_name, new.id, summary);
  return new;
end;
$$;

create trigger weigh_ins_activity after insert on public.weigh_ins
  for each row execute function private.log_activity();
create trigger check_ins_activity_insert after insert on public.check_ins
  for each row execute function private.log_activity();
create trigger check_ins_activity_review after update of status on public.check_ins
  for each row when (new.status = 'reviewed' and old.status <> 'reviewed') execute function private.log_activity();
create trigger body_composition_activity after insert on public.body_composition
  for each row execute function private.log_activity();
create trigger invoices_activity after update of status on public.invoices
  for each row when (new.status = 'paid' and old.status <> 'paid') execute function private.log_activity();
create trigger training_plans_activity after update of status on public.training_plans
  for each row when (new.status = 'published' and old.status <> 'published') execute function private.log_activity();
create trigger nutrition_plans_activity after update of status on public.nutrition_plans
  for each row when (new.status = 'published' and old.status <> 'published') execute function private.log_activity();

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

-- ---------- RLS

alter table public.leads enable row level security;
alter table public.notifications enable row level security;
alter table public.team_invitations enable row level security;
alter table public.activity_log enable row level security;

-- The public contact form inserts; nobody outside admin can read leads.
create policy "leads: public create" on public.leads for insert to anon, authenticated
  with check (status = 'new');
create policy "leads: admin" on public.leads for all to authenticated
  using (private.auth_role() = 'admin') with check (private.auth_role() = 'admin');

create policy "notifications: own" on public.notifications for select to authenticated
  using (profile_id = (select auth.uid()));
create policy "notifications: mark read" on public.notifications for update to authenticated
  using (profile_id = (select auth.uid())) with check (profile_id = (select auth.uid()));
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

create policy "team_invitations: admin" on public.team_invitations for all to authenticated
  using (private.has_perm('equipo') and private.auth_role() = 'admin')
  with check (private.has_perm('equipo') and private.auth_role() = 'admin');

create policy "activity_log: read" on public.activity_log for select to authenticated
  using (
    private.auth_role() = 'admin'
    or (client_id is not null and private.is_staff() and private.auth_role() <> 'billing' and private.can_access_client(client_id))
    or (private.auth_role() = 'billing' and entity = 'invoices')
  );
