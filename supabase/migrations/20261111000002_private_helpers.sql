-- RLS helpers live outside the exposed API schema so they can't be called via /rest/v1/rpc.
create schema if not exists private;
grant usage on schema private to authenticated;

-- Policies reference functions by OID, so moving them keeps existing policies working.
alter function public.auth_role() set schema private;
alter function public.is_staff() set schema private;

create or replace function private.is_staff()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(private.auth_role() in ('admin', 'coach', 'nutritionist', 'billing'), false)
$$;

create or replace function public.set_member_access(member uuid, new_role public.app_role, new_status public.profile_status)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if private.auth_role() is distinct from 'admin' then
    raise exception 'Solo el administrador puede cambiar roles' using errcode = '42501';
  end if;
  if member = (select auth.uid()) and new_role <> 'admin' then
    raise exception 'El administrador no puede quitarse su propio rol' using errcode = '42501';
  end if;
  update public.profiles set role = new_role, status = new_status where id = member;
end;
$$;
