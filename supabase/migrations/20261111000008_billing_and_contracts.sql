-- Invoices (card, Bizum, cash), payment proofs, versioned contract templates and signatures.

create type public.payment_method as enum ('card', 'bizum', 'cash');
create type public.invoice_status as enum ('pending', 'proof_submitted', 'paid', 'overdue', 'void');
create type public.contract_status as enum ('pending', 'signed', 'expiring', 'expired');

create table public.invoice_counters (
  year smallint primary key,
  last integer not null default 0
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  number text not null unique,
  client_id uuid not null references public.clients (id) on delete restrict,
  concept text not null,
  installment smallint,
  installments_total smallint,
  amount_cents integer not null check (amount_cents > 0),
  issued_on date not null default current_date,
  due_date date not null,
  method public.payment_method not null,
  status public.invoice_status not null default 'pending',
  proof_path text,
  proof_submitted_at timestamptz,
  reminded_at timestamptz,
  paid_at timestamptz,
  validated_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index on public.invoices (client_id);
create index on public.invoices (status, due_date);

-- FÉ-2026-001, FÉ-2026-002… gapless per year (Spanish invoicing requires a correlative series).
create function private.assign_invoice_number() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  y smallint := extract(year from new.issued_on);
  n integer;
begin
  if new.number is not null and new.number <> '' then
    return new;
  end if;
  insert into public.invoice_counters (year, last) values (y, 1)
  on conflict (year) do update set last = public.invoice_counters.last + 1
  returning last into n;
  new.number := format('FÉ-%s-%s', y, lpad(n::text, 3, '0'));
  return new;
end;
$$;
create trigger invoices_number before insert on public.invoices
  for each row execute function private.assign_invoice_number();
alter table public.invoices alter column number set default '';

create table public.contract_templates (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans (id) on delete restrict,
  version_major smallint not null default 1,
  version_minor smallint not null default 0,
  body text not null,
  updated_at timestamptz not null default now(),
  unique (plan_id, version_major, version_minor)
);

create table public.contracts (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete restrict,
  template_id uuid not null references public.contract_templates (id) on delete restrict,
  status public.contract_status not null default 'pending',
  sent_at timestamptz not null default now(),
  valid_until date,
  signed_at timestamptz,
  -- Evidence for a simple e-signature (eIDAS art. 25 / LSSI art. 23-24).
  document_hash text,
  signer_ip inet,
  signer_user_agent text,
  health_data_consent_at timestamptz,
  withdrawal_waiver_at timestamptz,
  pdf_path text,
  created_at timestamptz not null default now()
);
create index on public.contracts (client_id);

-- ---------- client actions (RPC): the only way a client can change billing rows

create function public.submit_payment_proof(invoice uuid, path text)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.invoices
  set proof_path = path, proof_submitted_at = now(), status = 'proof_submitted'
  where id = invoice
    and client_id = private.my_client_id()
    and status in ('pending', 'overdue')
    and path like client_id::text || '/%';
  if not found then
    raise exception 'No se puede adjuntar el justificante a esta factura' using errcode = '42501';
  end if;
end;
$$;
revoke execute on function public.submit_payment_proof(uuid, text) from public, anon;
grant execute on function public.submit_payment_proof(uuid, text) to authenticated;

-- Called from our server (service role) so IP and user agent come from the real request.
create function public.sign_contract(
  contract uuid, signer uuid, doc_hash text, ip inet, user_agent text, health_consent boolean, withdrawal_waiver boolean
)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not health_consent then
    raise exception 'Falta el consentimiento para tratar datos de salud' using errcode = '22023';
  end if;
  update public.contracts c
  set status = 'signed', signed_at = now(), document_hash = doc_hash, signer_ip = ip,
      signer_user_agent = user_agent, health_data_consent_at = now(),
      withdrawal_waiver_at = case when withdrawal_waiver then now() end
  from public.clients cl
  where c.id = contract and cl.id = c.client_id and cl.profile_id = signer and c.status = 'pending';
  if not found then
    raise exception 'Contrato no disponible para firma' using errcode = '42501';
  end if;
end;
$$;
revoke execute on function public.sign_contract(uuid, uuid, text, inet, text, boolean, boolean) from public, anon, authenticated;
grant execute on function public.sign_contract(uuid, uuid, text, inet, text, boolean, boolean) to service_role;

-- ---------- RLS

alter table public.invoice_counters enable row level security;
alter table public.invoices enable row level security;
alter table public.contract_templates enable row level security;
alter table public.contracts enable row level security;

create policy "invoices: read" on public.invoices for select to authenticated
  using (client_id = private.my_client_id() or (private.has_perm('pagos') and private.can_admin_client(client_id)));
create policy "invoices: billing write" on public.invoices for all to authenticated
  using (private.has_perm('pagos') and private.auth_role() in ('admin', 'billing'))
  with check (private.has_perm('pagos') and private.auth_role() in ('admin', 'billing'));

create policy "contract_templates: read" on public.contract_templates for select to authenticated
  using (
    private.has_perm('contratos')
    or exists (select 1 from public.contracts c where c.template_id = contract_templates.id and c.client_id = private.my_client_id())
  );
create policy "contract_templates: write" on public.contract_templates for all to authenticated
  using (private.has_perm('contratos') and private.auth_role() in ('admin', 'billing'))
  with check (private.has_perm('contratos') and private.auth_role() in ('admin', 'billing'));

create policy "contracts: read" on public.contracts for select to authenticated
  using (client_id = private.my_client_id() or (private.has_perm('contratos') and private.can_admin_client(client_id)));
create policy "contracts: write" on public.contracts for all to authenticated
  using (private.has_perm('contratos') and private.auth_role() in ('admin', 'billing'))
  with check (private.has_perm('contratos') and private.auth_role() in ('admin', 'billing'));
