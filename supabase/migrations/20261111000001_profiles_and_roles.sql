-- Phase 1: profiles + roles. Role lives in profiles (source of truth for RLS).
create type public.app_role as enum ('admin', 'coach', 'nutritionist', 'billing', 'client');
create type public.profile_status as enum ('active', 'invited', 'disabled');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  email text not null,
  avatar_url text,
  role public.app_role not null default 'client',
  status public.profile_status not null default 'active',
  calendar_color text check (calendar_color in ('ink', 'gold-deep', 'ok', 'danger', 'bronze', 'muted')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- security definer so policies can read the caller's role without recursing into profiles RLS.
create function public.auth_role()
returns public.app_role
language sql stable security definer
set search_path = ''
as $$
  select role from public.profiles where id = (select auth.uid())
$$;

create function public.is_staff()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(public.auth_role() in ('admin', 'coach', 'nutritionist', 'billing'), false)
$$;

revoke execute on function public.auth_role() from public, anon;
grant execute on function public.auth_role() to authenticated;
revoke execute on function public.is_staff() from public, anon;
grant execute on function public.is_staff() to authenticated;

create policy "profiles: self read" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy "profiles: staff read" on public.profiles
  for select to authenticated
  using (public.is_staff());

create policy "profiles: admin write" on public.profiles
  for all to authenticated
  using (public.auth_role() = 'admin')
  with check (public.auth_role() = 'admin');

create policy "profiles: self update" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Non-admins may only touch harmless columns of their own row; role/status stay admin-only.
revoke update on public.profiles from authenticated;
grant update (full_name, avatar_url) on public.profiles to authenticated;

-- Column grants above also bind admins, so role/status changes go through this checked RPC.
create function public.set_member_access(member uuid, new_role public.app_role, new_status public.profile_status)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if public.auth_role() is distinct from 'admin' then
    raise exception 'Solo el administrador puede cambiar roles' using errcode = '42501';
  end if;
  if member = (select auth.uid()) and new_role <> 'admin' then
    raise exception 'El administrador no puede quitarse su propio rol' using errcode = '42501';
  end if;
  update public.profiles set role = new_role, status = new_status where id = member;
end;
$$;

revoke execute on function public.set_member_access(uuid, public.app_role, public.profile_status) from public, anon;
grant execute on function public.set_member_access(uuid, public.app_role, public.profile_status) to authenticated;

-- New auth user → profile. Role comes from app_metadata, which only the service role can set.
create function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, role, status)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce((new.raw_app_meta_data ->> 'role')::public.app_role, 'client'),
    (case when new.invited_at is not null and new.last_sign_in_at is null then 'invited' else 'active' end)::public.profile_status
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- First sign-in after an invitation activates the profile.
create function public.handle_user_signed_in()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.last_sign_in_at is distinct from old.last_sign_in_at then
    update public.profiles set status = 'active' where id = new.id and status = 'invited';
  end if;
  return new;
end;
$$;

create trigger on_auth_user_signed_in
  after update of last_sign_in_at on auth.users
  for each row execute function public.handle_user_signed_in();

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.handle_user_signed_in() from public, anon, authenticated;
