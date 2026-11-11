-- RLS matrix: logs in as each demo role and checks what it can see and do.
-- Requires seed.sql (run with `supabase test db` after `supabase db reset`).
begin;
create extension if not exists pgtap with schema extensions;
select plan(42);

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
end;
$$;
create function pg_temp.cid(p_email text) returns uuid language sql as $$
  select c.id from public.clients c join auth.users u on u.id = c.profile_id where u.email = p_email
$$;

-- Resolve ids as postgres before switching roles.
create temp table ids as select
  pg_temp.cid('alejandro@demo.febodyadvisory.com') as alejandro,
  pg_temp.cid('laura@demo.febodyadvisory.com') as laura,
  pg_temp.cid('sergio@demo.febodyadvisory.com') as sergio,
  (select id from public.threads where client_id = pg_temp.cid('laura@demo.febodyadvisory.com')) as laura_thread;
grant select on ids to authenticated, anon;

-- ================================================================ client (Alejandro)
select pg_temp.login('alejandro@demo.febodyadvisory.com');
set local role authenticated;

select is((select count(*) from public.clients)::int, 1, 'cliente: solo ve su ficha');
select is((select count(*) from public.weigh_ins where client_id <> (select alejandro from ids))::int, 0, 'cliente: no ve pesajes ajenos');
select ok((select count(*) from public.weigh_ins) > 100, 'cliente: ve sus pesajes');
select is((select count(*) from public.training_plans)::int, 1, 'cliente: ve su plan publicado');
select is((select count(*) from public.invoices where client_id <> (select alejandro from ids))::int, 0, 'cliente: no ve facturas ajenas');
select is((select count(*) from public.leads)::int, 0, 'cliente: no ve leads');
select is((select count(*) from public.role_permissions)::int, 0, 'cliente: no ve la matriz de permisos');
select is((select count(*) from public.profiles where role = 'client')::int, 1, 'cliente: solo ve su propio perfil de cliente');
select is((select count(*) from public.threads)::int, 1, 'cliente: solo su conversación');

select lives_ok(
  $$ insert into public.weigh_ins (client_id, measured_at, kg, fasted) values ((select alejandro from ids), now() + interval '1 hour', 78.1, true) $$,
  'cliente: registra su pesaje');
select throws_ok(
  $$ insert into public.weigh_ins (client_id, measured_at, kg, fasted) values ((select sergio from ids), now(), 90, true) $$,
  '42501', null, 'cliente: no puede registrar pesajes de otro');
select throws_ok(
  $$ insert into public.training_items (day_id, exercise_id, sets) select day_id, exercise_id, 3 from public.training_items limit 1 $$,
  '42501', null, 'cliente: no edita su plan de entrenamiento');

update public.check_ins set coach_feedback = 'me autoapruebo', status = 'reviewed' where client_id = (select alejandro from ids);
reset role;
select is((select status from public.check_ins where client_id = (select alejandro from ids) and week = 6), 'pending', 'cliente: no puede marcar su check-in como revisado');
select pg_temp.login('alejandro@demo.febodyadvisory.com');
set local role authenticated;

select throws_ok($$ update public.profiles set role = 'admin' where id = auth.uid() $$, '42501', null, 'cliente: no puede cambiarse el rol');
select throws_ok($$ select public.set_member_access(auth.uid(), 'admin', 'active') $$, '42501', null, 'cliente: no puede usar la RPC de roles');
with u as (update public.invoices set status = 'paid' where client_id = (select alejandro from ids) returning 1)
select is((select count(*) from u)::int, 0, 'cliente: no puede marcar facturas como pagadas');

-- ================================================================ coach (Carlos: 5 asignados + Nerea nueva)
reset role;
select pg_temp.login('carlos@demo.febodyadvisory.com');
set local role authenticated;

select is((select count(*) from public.clients)::int, 6, 'entrenador: ve solo sus 6 clientes asignados');
select is((select count(*) from public.weigh_ins where client_id = (select laura from ids))::int, 0, 'entrenador: no ve pesajes de clientes ajenos');
select ok((select count(*) from public.weigh_ins where client_id = (select alejandro from ids)) > 0, 'entrenador: ve pesajes de su cliente');
select is((select count(*) from public.invoices)::int, 0, 'entrenador: sin permiso de pagos no ve facturas');
select is((select count(*) from public.leads)::int, 0, 'entrenador: no ve leads');

with u as (update public.training_items set technique_note = 'nota del coach'
  where day_id in (select d.id from public.training_days d join public.training_plans p on p.id = d.plan_id where p.client_id = (select alejandro from ids))
  returning 1)
select ok((select count(*) from u) > 0, 'entrenador: edita el entreno de su cliente');

with u as (update public.nutrition_targets set protein_g = 1 returning 1)
select is((select count(*) from u)::int, 0, 'entrenador: sin permiso de dietas no edita dietas');

with u as (update public.role_permissions set enabled = true returning 1)
select is((select count(*) from u)::int, 0, 'entrenador: no cambia la matriz de permisos');

select throws_ok(
  $$ insert into public.messages (thread_id, body) values ((select laura_thread from ids), 'hola') $$,
  '42501', null, 'entrenador: no escribe a clientes ajenos');
select lives_ok(
  $$ insert into public.messages (thread_id, body) select id, 'Revisado.' from public.threads where client_id = (select alejandro from ids) $$,
  'entrenador: escribe a su cliente');

-- Permission matrix is enforced live: admin revokes «entrenos» and the coach loses write access.
reset role;
update public.role_permissions set enabled = false where role = 'coach' and permission_key = 'entrenos';
select pg_temp.login('carlos@demo.febodyadvisory.com');
set local role authenticated;
with u as (update public.training_items set technique_note = 'sin permiso' returning 1)
select is((select count(*) from u)::int, 0, 'entrenador: al quitarle «entrenos» deja de poder editar');
reset role;
update public.role_permissions set enabled = true where role = 'coach' and permission_key = 'entrenos';

-- ================================================================ nutritionist (Lucía)
select pg_temp.login('lucia@demo.febodyadvisory.com');
set local role authenticated;
select is((select count(*) from public.clients)::int, 10, 'nutricionista: ve solo sus 10 clientes');
with u as (update public.nutrition_targets set protein_g = protein_g returning 1)
select is((select count(*) from u)::int, 3, 'nutricionista: edita la dieta de su cliente');
with u as (update public.training_items set technique_note = 'x' returning 1)
select is((select count(*) from u)::int, 0, 'nutricionista: no edita entrenos');
with u as (update public.food_proposals set status = 'approved' returning 1)
select is((select count(*) from u)::int, 1, 'nutricionista: aprueba propuestas de alimento');

-- ================================================================ billing (Marta)
reset role;
select pg_temp.login('marta@demo.febodyadvisory.com');
set local role authenticated;
select is((select count(*) from public.clients)::int, 12, 'administración: ve todos los clientes (datos administrativos)');
select is((select count(*) from public.weigh_ins)::int, 0, 'administración: nunca ve pesajes');
select is((select count(*) from public.check_ins)::int, 0, 'administración: nunca ve check-ins');
select is((select count(*) from public.body_composition)::int, 0, 'administración: nunca ve composición corporal');
select is((select count(*) from public.invoices)::int, 12, 'administración: ve todas las facturas');
select is((select count(*) from public.threads)::int, 12, 'administración: puede escribir a cualquier cliente');

-- ================================================================ admin
reset role;
select pg_temp.login('josemiguel@demo.febodyadvisory.com');
set local role authenticated;
select is((select count(*) from public.weigh_ins where client_id = (select laura from ids))::int, 0, 'admin: Laura no tiene pesajes en la demo');
select is((select count(*) from public.leads)::int, 2, 'admin: ve los leads');
select lives_ok(
  $$ select public.set_member_access((select id from public.profiles where email = 'carlos@demo.febodyadvisory.com'), 'coach', 'active') $$,
  'admin: gestiona roles');

-- ================================================================ anon (web pública)
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select lives_ok($$ insert into public.leads (name, email, goal) values ('Test', 'test@example.com', 'Competir') $$, 'anónimo: envía el formulario de contacto');
select is((select count(*) from public.plans)::int, 4, 'anónimo: ve los planes');

select * from finish();
rollback;
