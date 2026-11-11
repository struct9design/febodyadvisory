-- Calendar events and client ↔ team messaging (Realtime).

create type public.event_type as enum ('review', 'call', 'posing', 'meeting', 'payment', 'milestone', 'assessment', 'task');

create table public.events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles (id) on delete cascade,
  client_id uuid references public.clients (id) on delete cascade,
  is_team boolean not null default false,
  type public.event_type not null,
  title text not null,
  notes text not null default '',
  starts_at timestamptz not null,
  duration_min smallint not null default 60 check (duration_min between 5 and 720),
  created_at timestamptz not null default now(),
  check (owner_id is not null or is_team)
);
create index on public.events (starts_at);
create index on public.events (client_id);

create table public.threads (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null unique references public.clients (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index on public.messages (thread_id, created_at);

create function private.client_of_thread(tid uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select client_id from public.threads where id = tid
$$;

-- Billing can write to any client about payments; coach/nutritionist only to their clients.
create function private.can_message_client(cid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cid = private.my_client_id()
    or (private.has_perm('mensajes') and (private.auth_role() = 'billing' or private.can_access_client(cid)))
$$;

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

-- Every client gets a thread automatically.
create function private.create_client_thread() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.threads (client_id) values (new.id) on conflict do nothing;
  return new;
end;
$$;
create trigger clients_create_thread after insert on public.clients
  for each row execute function private.create_client_thread();

alter table public.events enable row level security;
alter table public.threads enable row level security;
alter table public.messages enable row level security;

create policy "events: read" on public.events for select to authenticated
  using (
    private.auth_role() = 'admin'
    or owner_id = (select auth.uid())
    or (is_team and private.is_staff())
    or (client_id is not null and client_id = private.my_client_id())
  );
create policy "events: staff write own" on public.events for all to authenticated
  using (private.is_staff() and (owner_id = (select auth.uid()) or private.auth_role() = 'admin'))
  with check (
    private.is_staff()
    and (owner_id = (select auth.uid()) or private.auth_role() = 'admin')
    and (client_id is null or private.can_admin_client(client_id))
  );

create policy "threads: read" on public.threads for select to authenticated
  using (private.can_message_client(client_id));

create policy "messages: read" on public.messages for select to authenticated
  using (private.can_message_client(private.client_of_thread(thread_id)));
create policy "messages: send" on public.messages for insert to authenticated
  with check (sender_id = (select auth.uid()) and private.can_message_client(private.client_of_thread(thread_id)));

-- Only read receipts can change after sending.
create policy "messages: mark read" on public.messages for update to authenticated
  using (private.can_message_client(private.client_of_thread(thread_id)) and sender_id <> (select auth.uid()));
revoke update on public.messages from authenticated;
grant update (read_at) on public.messages to authenticated;

alter publication supabase_realtime add table public.messages;
