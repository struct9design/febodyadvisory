-- Demo data taken from the prototypes. Every demo account uses @demo.febodyadvisory.com and the
-- password «febody-demo», so the whole set can be removed with:
--   delete from auth.users where email like '%@demo.febodyadvisory.com';
-- Exercise and food lists are placeholders until the real library replaces them.
-- Dates are relative to current_date so the demo never goes stale.

-- ---------------------------------------------------------------- helpers
create or replace function pg_temp.demo_user(p_email text, p_name text, p_role public.app_role)
returns uuid language plpgsql as $$
declare uid uuid;
begin
  select id into uid from auth.users where email = p_email;
  if uid is not null then return uid; end if;
  uid := gen_random_uuid();
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', p_email,
    extensions.crypt('febody-demo', extensions.gen_salt('bf')), now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email'), 'role', p_role),
    jsonb_build_object('full_name', p_name), now(), now(), '', '', '', ''
  );
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), uid, uid::text,
    jsonb_build_object('sub', uid::text, 'email', p_email, 'email_verified', true), 'email', now(), now(), now());
  return uid;
end;
$$;

create temp table demo_ids (key text primary key, id uuid not null);

create or replace function pg_temp.id(k text) returns uuid language sql as $$
  select id from demo_ids where key = k
$$;

-- ---------------------------------------------------------------- team
insert into demo_ids values
  ('jm', pg_temp.demo_user('josemiguel@demo.febodyadvisory.com', 'José Miguel', 'admin')),
  ('carlos', pg_temp.demo_user('carlos@demo.febodyadvisory.com', 'Carlos Ruiz', 'coach')),
  ('lucia', pg_temp.demo_user('lucia@demo.febodyadvisory.com', 'Lucía Pardo', 'nutritionist')),
  ('marta', pg_temp.demo_user('marta@demo.febodyadvisory.com', 'Marta Gil', 'billing'));

update public.profiles set calendar_color = 'ink' where id = pg_temp.id('jm');
update public.profiles set calendar_color = 'gold-deep' where id = pg_temp.id('carlos');
update public.profiles set calendar_color = 'ok' where id = pg_temp.id('lucia');
update public.profiles set calendar_color = 'danger' where id = pg_temp.id('marta');

-- ---------------------------------------------------------------- plans
insert into public.plans (slug, name, description, price_cents, installments, duration_weeks, sort) values
  ('esencial', 'Esencial', 'Estructura y criterio para quien entrena con autonomía.', 17900, 1, 12, 1),
  ('integral', 'Integral', 'Seguimiento cercano para progresar sin estancarse.', 24900, 3, 12, 2),
  ('premium-completo', 'Premium completo', 'Entrenamiento, nutrición y revisiones con todo el equipo.', 32700, 3, 12, 3),
  ('competicion', 'Competición', 'Preparación completa para subir a tarima en natural.', 89400, 6, 24, 4)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------- muscle groups (PROVISIONAL ranges)
insert into public.muscle_groups (id, name, sets_min, sets_max, sort) values
  ('pecho', 'Pecho', 10, 20, 1), ('espalda', 'Espalda', 10, 20, 2), ('hombro', 'Hombro', 10, 20, 3),
  ('biceps', 'Bíceps', 8, 16, 4), ('triceps', 'Tríceps', 8, 16, 5), ('cuadriceps', 'Cuádriceps', 10, 20, 6),
  ('isquios', 'Isquios', 8, 16, 7), ('gluteo', 'Glúteo', 8, 16, 8), ('gemelo', 'Gemelo', 8, 14, 9)
on conflict (id) do nothing;

-- ---------------------------------------------------------------- exercise library (placeholder)
create temp table demo_ex (k text primary key, name text, mp text, ms text[], eq text, dur int, cues text[], err text);
insert into demo_ex values
  ('banca', 'Press de banca con barra', 'pecho', '{triceps,hombro}', 'Barra', 102, '{"Escápulas retraídas y deprimidas todo el recorrido","Barra al esternón bajo, codos a unos 45°","Pies firmes; empuja el suelo y mantén el glúteo en el banco"}', 'Rebotar la barra en el pecho y perder la retracción escapular.'),
  ('remo_apoyo', 'Remo con apoyo en pecho', 'espalda', '{biceps}', 'Máquina', 75, '{"Pecho pegado al apoyo en todo momento","Lleva los codos hacia la cadera","Controla la bajada 2–3 s"}', 'Tirar con los brazos y subir los hombros hacia las orejas.'),
  ('inclinado', 'Press inclinado con mancuernas', 'pecho', '{hombro,triceps}', 'Mancuernas', 80, '{"Banco a 30°, no más","Mancuernas bajan a la altura del pecho alto","Junta ligeramente al subir sin chocar"}', 'Inclinar demasiado el banco y convertirlo en un press de hombro.'),
  ('jalon', 'Jalón unilateral', 'espalda', '{biceps}', 'Polea', null, '{"Estira completamente arriba","Codo hacia el bolsillo trasero","Torso estable, sin balanceo"}', 'Rotar el torso para mover más peso.'),
  ('laterales', 'Elevaciones laterales', 'hombro', '{}', 'Mancuernas', 58, '{"Ligera inclinación hacia delante","Sube hasta la línea del hombro","Codo ligeramente flexionado y fijo"}', 'Subir con impulso y encoger los trapecios.'),
  ('sentadilla', 'Sentadilla trasera', 'cuadriceps', '{gluteo}', 'Barra', 125, '{"Respira y bloquea el core antes de bajar","Rodillas siguen la línea de los pies","Profundidad: cadera por debajo de la rodilla"}', 'Perder la tensión abdominal en el punto más bajo.'),
  ('rumano', 'Peso muerto rumano', 'isquios', '{gluteo,espalda}', 'Barra', 108, '{"Cadera atrás, rodillas apenas flexionadas","Barra pegada a las piernas","Baja hasta sentir estiramiento, no hasta el suelo"}', 'Redondear la zona lumbar para bajar más.'),
  ('prensa', 'Prensa inclinada', 'cuadriceps', '{gluteo}', 'Máquina', 65, '{"Zona lumbar pegada al respaldo","Baja controlado hasta 90° o más","No bloquees rodillas arriba"}', 'Despegar la cadera del asiento al bajar.'),
  ('femoral_tumbado', 'Curl femoral tumbado', 'isquios', '{}', 'Máquina', 55, '{"Cadera pegada al banco","Flexión completa","Bajada en 3 s"}', 'Levantar la cadera para ayudarte.'),
  ('gemelo_pie', 'Gemelo de pie', 'gemelo', '{}', 'Máquina', null, '{"Estiramiento completo abajo con pausa","Sube hasta la punta máxima","Rodillas fijas"}', 'Rebotar en el estiramiento.'),
  ('militar', 'Press militar con barra', 'hombro', '{triceps}', 'Barra', 95, '{"Glúteo y abdomen apretados","Cabeza pasa por delante al subir","Barra sobre la vertical del pie medio"}', 'Arquear en exceso la zona lumbar.'),
  ('dominadas', 'Dominadas lastradas', 'espalda', '{biceps}', 'Peso corporal', 90, '{"Empieza colgado con escápulas activas","Pecho hacia la barra","Baja hasta extensión completa"}', 'Medias repeticiones sin bajar del todo.'),
  ('press_maquina', 'Press de pecho en máquina', 'pecho', '{triceps,hombro}', 'Máquina', null, '{"Asiento con agarres a mitad del pecho","Escápulas atrás contra el respaldo","Sin bloquear codos"}', 'Separar la espalda del respaldo al empujar.'),
  ('remo_barra', 'Remo con barra', 'espalda', '{biceps}', 'Barra', 70, '{"Torso a unos 45° y estable","Barra hacia el ombligo","Aprieta escápulas arriba"}', 'Erguirse con cada repetición.'),
  ('curl_z', 'Curl de bíceps con barra Z', 'biceps', '{}', 'Barra', null, '{"Codos pegados al cuerpo","Sin balanceo","Extensión completa abajo"}', 'Usar la cadera para subir el peso.'),
  ('triceps_polea', 'Extensión de tríceps en polea', 'triceps', '{}', 'Polea', 50, '{"Codos fijos a los lados","Extiende por completo","Controla la vuelta"}', 'Mover los hombros y los codos hacia delante.'),
  ('hip_thrust', 'Hip thrust con barra', 'gluteo', '{isquios}', 'Barra', 85, '{"Escápulas en el banco, mirada al frente","Tibias verticales arriba","Retroversión pélvica al final"}', 'Hiperextender la zona lumbar en lugar de extender cadera.'),
  ('bulgara', 'Sentadilla búlgara', 'cuadriceps', '{gluteo}', 'Mancuernas', null, '{"Pie delantero lejos del banco","Baja vertical, rodilla trasera casi al suelo","Empuja con todo el pie delantero"}', 'Apoyar el peso en la pierna trasera.'),
  ('femoral_sentado', 'Curl femoral sentado', 'isquios', '{}', 'Máquina', null, '{"Rodilla alineada con el eje de la máquina","Torso ligeramente inclinado adelante","Flexión completa"}', 'Recortar el rango en la parte de estiramiento.'),
  ('extension_cuad', 'Extensión de cuádriceps', 'cuadriceps', '{}', 'Máquina', null, '{"Agárrate fuerte al asiento","Pausa 1 s arriba","Baja controlado"}', 'Lanzar el peso con impulso.'),
  ('gemelo_sentado', 'Gemelo sentado', 'gemelo', '{}', 'Máquina', null, '{"Estiramiento completo con pausa","Sube al máximo","Ritmo controlado"}', 'Rebotar y acortar el recorrido.');

insert into public.exercises (name, muscle_primary, muscles_secondary, equipment, video_path, video_duration_s, cues, common_error, created_by)
select name, mp, ms, eq, case when dur is not null then 'demo/' || k || '.mp4' end, dur, cues, err, pg_temp.id('jm')
from demo_ex;
insert into demo_ids select 'ex:' || d.k, e.id from demo_ex d join public.exercises e on e.name = d.name;

-- ---------------------------------------------------------------- foods (placeholder, per 100 g)
insert into public.foods (name, category, kcal, protein, carbs, fat) values
  ('Arroz blanco (crudo)', 'c', 350, 7, 78, 0.6), ('Pasta (cruda)', 'c', 355, 12, 72, 1.5), ('Patata', 'c', 77, 2, 17, 0.1),
  ('Boniato', 'c', 86, 1.6, 20, 0.1), ('Copos de avena', 'c', 375, 13, 60, 7), ('Pan integral', 'c', 250, 9, 45, 3.5),
  ('Tortitas de arroz', 'c', 385, 8, 81, 3), ('Plátano', 'c', 90, 1.1, 21, 0.3), ('Frutos rojos', 'c', 45, 1, 9, 0.3),
  ('Miel', 'c', 304, 0.3, 82, 0), ('Pechuga de pollo', 'p', 110, 23, 0, 1.5), ('Pechuga de pavo', 'p', 105, 24, 0, 1),
  ('Merluza', 'p', 75, 17, 0, 0.6), ('Ternera magra', 'p', 130, 21, 0, 5), ('Claras de huevo', 'p', 50, 11, 0.7, 0.2),
  ('Proteína de suero', 'p', 380, 78, 6, 5), ('Yogur griego 0 %', 'p', 60, 10, 4, 0), ('Aceite de oliva virgen extra', 'f', 884, 0, 0, 100),
  ('Aguacate', 'f', 160, 2, 2, 15), ('Nueces', 'f', 650, 15, 7, 65), ('Crema de cacahuete', 'f', 590, 25, 15, 50),
  ('Brócoli', 'v', 35, 2.8, 4, 0.4), ('Ensalada variada', 'v', 20, 1.2, 3, 0.2)
on conflict (name) do nothing;
-- Not offered as authorised swaps in the prototype.
update public.foods set swappable = false
where name in ('Plátano', 'Frutos rojos', 'Miel', 'Tortitas de arroz', 'Proteína de suero', 'Yogur griego 0 %');

-- ---------------------------------------------------------------- clients
create temp table demo_cli (k text primary key, email text, name text, plan text, status public.client_status,
  coach text, nutri text, start_off int, end_off int, goal text, weight numeric, fat numeric);
insert into demo_cli values
  ('c1', 'alejandro', 'Alejandro Martín', 'premium-completo', 'active', 'carlos', 'lucia', -47, 37, 'Recomposición', 78.3, 14.6),
  ('c2', 'laura', 'Laura Iglesias', 'integral', 'active', 'jm', 'lucia', -70, 14, 'Definición', 61.2, 21.4),
  ('c3', 'david', 'David Romero', 'competicion', 'active', 'jm', 'jm', -133, 39, 'Competición · 6 dic', 82.9, 8.1),
  ('c4', 'sergio', 'Sergio Navas', 'esencial', 'active', 'carlos', 'lucia', -34, 58, 'Pérdida de grasa', 90.4, 22.8),
  ('c5', 'ivan', 'Iván Sáez', 'premium-completo', 'ending', 'jm', 'lucia', -88, 4, 'Definición', 74.0, 12.9),
  ('c6', 'pablo', 'Pablo Ortega', 'integral', 'active', 'carlos', 'lucia', -52, 39, 'Volumen', 85.1, 17.2),
  ('c7', 'nerea', 'Nerea Campos', 'premium-completo', 'new', 'carlos', 'lucia', -2, 82, 'Recomposición', 63.5, 24.0),
  ('c8', 'cristina', 'Cristina Vela', 'premium-completo', 'ending', 'jm', 'lucia', -175, 9, 'Mantenimiento', 58.7, 19.3),
  ('c9', 'ruben', 'Rubén Lozano', 'esencial', 'new', 'carlos', 'jm', -14, 78, 'Volumen', 79.8, 18.5),
  ('c10', 'hugo', 'Hugo Marín', 'competicion', 'active', 'jm', 'lucia', -161, 34, 'Competición · 13 dic', 88.2, 9.4),
  ('c11', 'marina', 'Marina Soto', 'integral', 'paused', 'carlos', 'lucia', -71, 20, 'Pérdida de grasa', 66.0, 23.1),
  ('c12', 'andrea', 'Andrea Molina', 'integral', 'new', 'jm', 'lucia', 0, 84, 'Recomposición', 59.4, 25.2);

insert into demo_ids select 'u:' || k, pg_temp.demo_user(email || '@demo.febodyadvisory.com', name, 'client') from demo_cli;

insert into public.clients (profile_id, plan_id, status, goal, coach_id, nutritionist_id, start_date, end_date)
select pg_temp.id('u:' || d.k), p.id, d.status, d.goal, pg_temp.id(d.coach), pg_temp.id(d.nutri),
  current_date + d.start_off, current_date + d.end_off
from demo_cli d join public.plans p on p.slug = d.plan
on conflict (profile_id) do nothing;
insert into demo_ids select d.k, c.id from demo_cli d join public.clients c on c.profile_id = pg_temp.id('u:' || d.k);

-- Six coach measurements per client trending to the current values (as in the panel prototype).
insert into public.body_composition (client_id, measured_on, weight_kg, body_fat_pct, method, recorded_by)
select pg_temp.id(d.k), current_date - (5 - i) * 14 - 1,
  round(case when d.goal = 'Volumen' then d.weight - (5 - i) * 0.35 else d.weight + (5 - i) * 0.45 end, 1),
  round(case when d.goal = 'Volumen' then d.fat - (5 - i) * 0.1 else d.fat + (5 - i) * 0.4 end, 1),
  'skinfold_7', pg_temp.id(d.coach)
from demo_cli d cross join generate_series(0, 5) as i
where d.k not in ('c7', 'c12');

-- ---------------------------------------------------------------- Alejandro: training plan
do $$
declare
  plan uuid; day uuid;
  days jsonb := '[
    {"name":"Torso A","wd":0,"items":[
      ["banca","6–8 / 8–10 / 10–12","2 / 2 / 1",180,"Fuerza e hipertrofia","75 %","Rest-pause · serie 3"],
      ["remo_apoyo","8–10 / 8–10 / 10–12","2 / 1 / 1",150,"Hipertrofia","—","Pausa 1 s arriba"],
      ["inclinado","8–10 / 8–10 / 10–12","2 / 1 / 1",150,"Hipertrofia","—","Excéntrica 3 s"],
      ["jalon","10–12 / 10–12 / 12–15","1 / 1 / 0",90,"Hipertrofia","—","Serie descendente final"],
      ["laterales","12–15 / 12–15 / 15–20","1 / 1 / 0",90,"Hipertrofia","—","Parciales al fallo"]]},
    {"name":"Pierna A","wd":1,"items":[
      ["sentadilla","5–7 / 5–7 / 6–8 / 6–8","2 / 2 / 1 / 1",210,"Fuerza","80 %","Top set + back-off"],
      ["rumano","8–10 / 8–10 / 8–10","2 / 2 / 1",150,"Hipertrofia","—","Excéntrica 3 s"],
      ["prensa","10–12 / 10–12 / 12–15","1 / 1 / 0",120,"Hipertrofia","—","Pies medios, rango completo"],
      ["femoral_tumbado","10–12 / 10–12 / 12–15","1 / 1 / 0",90,"Hipertrofia","—","Pausa 1 s en contracción"],
      ["gemelo_pie","10–12 / 10–12 / 12–15 / 12–15","1 / 1 / 0 / 0",90,"Hipertrofia","—","Pausa 2 s abajo"]]},
    {"name":"Torso B","wd":3,"items":[
      ["militar","6–8 / 6–8 / 8–10","2 / 2 / 1",180,"Fuerza e hipertrofia","75 %","Recto, sin impulso"],
      ["dominadas","6–8 / 6–8 / 8–10","2 / 1 / 1",150,"Hipertrofia","—","Lastre en cinturón"],
      ["press_maquina","10–12 / 10–12 / 12–15","1 / 1 / 0",120,"Hipertrofia","—","Serie descendente final"],
      ["remo_barra","8–10 / 8–10 / 10–12","2 / 1 / 1",120,"Hipertrofia","—","Torso a 45°"],
      ["curl_z","10–12 / 10–12 / 12–15","1 / 1 / 0",90,"Hipertrofia","—","Excéntrica 3 s"],
      ["triceps_polea","10–12 / 12–15 / 12–15","1 / 1 / 0",90,"Hipertrofia","—","Pausa en extensión"]]},
    {"name":"Pierna B","wd":4,"items":[
      ["hip_thrust","8–10 / 8–10 / 10–12","2 / 1 / 1",150,"Hipertrofia","—","Pausa 2 s arriba"],
      ["bulgara","8–10 / 8–10 / 10–12","2 / 1 / 1",120,"Hipertrofia","—","Mancuernas"],
      ["femoral_sentado","10–12 / 10–12 / 12–15","1 / 1 / 0",90,"Hipertrofia","—","Excéntrica 3 s"],
      ["extension_cuad","12–15 / 12–15 / 15–20","1 / 0 / 0",90,"Hipertrofia","—","Parciales al fallo"],
      ["gemelo_sentado","12–15 / 12–15 / 15–20","1 / 0 / 0",60,"Hipertrofia","—","Pausa 2 s abajo"]]}
  ]';
  d jsonb; it jsonb; n int;
begin
  insert into public.training_plans (client_id, name, status, published_at, created_by)
  values (pg_temp.id('c1'), 'Bloque 2 · Definición', 'published', now() - interval '5 days', pg_temp.id('carlos'))
  returning id into plan;
  n := 0;
  for d in select * from jsonb_array_elements(days) loop
    insert into public.training_days (plan_id, name, weekday, sort)
    values (plan, d ->> 'name', (d ->> 'wd')::smallint, n) returning id into day;
    n := n + 1;
    for it in select * from jsonb_array_elements(d -> 'items') loop
      insert into public.training_items (day_id, exercise_id, sort, sets, rep_range, rir, rest_seconds, objective, pct_rm, technique_note)
      values (day, pg_temp.id('ex:' || (it ->> 0)), 0,
        array_length(string_to_array(it ->> 1, ' / '), 1), it ->> 1, it ->> 2, (it ->> 3)::smallint, it ->> 4, it ->> 5, it ->> 6);
    end loop;
  end loop;
  -- keep insertion order as sort order
  update public.training_items ti set sort = x.rn
  from (select id, row_number() over (partition by day_id order by ctid) - 1 as rn from public.training_items) x
  where x.id = ti.id;
end $$;

-- PR history (top set per session), weeks back from today.
insert into public.workout_sessions (client_id, performed_on, started_at, finished_at)
select pg_temp.id('c1'), current_date - w * 14 - e.off, now() - (w * 14 + e.off) * interval '1 day', now() - (w * 14 + e.off) * interval '1 day' + interval '70 minutes'
from (values (0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5)) as e(idx, off)
cross join generate_series(0, 6) as w;

with hist(ex, w, kg, reps) as (values
  ('banca', 6, 75, 8), ('banca', 5, 77.5, 8), ('banca', 4, 77.5, 9), ('banca', 3, 80, 8), ('banca', 2, 80, 9), ('banca', 1, 82.5, 8), ('banca', 0, 82.5, 9),
  ('sentadilla', 5, 100, 6), ('sentadilla', 4, 102.5, 6), ('sentadilla', 3, 105, 6), ('sentadilla', 2, 105, 7), ('sentadilla', 1, 107.5, 7), ('sentadilla', 0, 110, 6),
  ('rumano', 4, 90, 8), ('rumano', 3, 92.5, 8), ('rumano', 2, 95, 8), ('rumano', 1, 97.5, 8), ('rumano', 0, 100, 8),
  ('militar', 4, 47.5, 8), ('militar', 3, 50, 7), ('militar', 2, 50, 8), ('militar', 1, 52.5, 7), ('militar', 0, 52.5, 8),
  ('dominadas', 4, 10, 6), ('dominadas', 3, 12.5, 6), ('dominadas', 2, 15, 5), ('dominadas', 1, 15, 6), ('dominadas', 0, 17.5, 6),
  ('hip_thrust', 4, 120, 10), ('hip_thrust', 3, 130, 10), ('hip_thrust', 2, 135, 10), ('hip_thrust', 1, 140, 10), ('hip_thrust', 0, 145, 9)
), off(ex, o) as (values ('banca', 0), ('sentadilla', 1), ('rumano', 2), ('militar', 3), ('dominadas', 4), ('hip_thrust', 5))
insert into public.workout_sets (session_id, exercise_id, set_index, kg, reps, rir_real, done)
select s.id, pg_temp.id('ex:' || h.ex), 1, h.kg, h.reps, 1, true
from hist h join off o using (ex)
join public.workout_sessions s on s.client_id = pg_temp.id('c1') and s.performed_on = current_date - h.w * 14 - o.o;

-- Today's Torso A in progress: first two bench sets done.
with s as (
  insert into public.workout_sessions (client_id, day_id, performed_on)
  select pg_temp.id('c1'), d.id, current_date from public.training_days d
  join public.training_plans p on p.id = d.plan_id where p.client_id = pg_temp.id('c1') and d.name = 'Torso A'
  returning id, day_id
)
insert into public.workout_sets (session_id, training_item_id, set_index, kg, reps, rir_real, done)
select s.id, ti.id, v.i, 80, v.reps, 2, true
from s join public.training_items ti on ti.day_id = s.day_id and ti.sort = 0
cross join (values (1, 8), (2, 9)) as v(i, reps);

-- ---------------------------------------------------------------- Alejandro: closed diet ON / OFF / REFEED
do $$
declare
  plan uuid; meal uuid; dt public.day_type; fc numeric; ff numeric; m jsonb; it jsonb; n int;
  meals jsonb := '[
    {"name":"Desayuno","time":"08:00","items":[["Copos de avena",80],["Claras de huevo",250],["Frutos rojos",100],["Crema de cacahuete",20]]},
    {"name":"Comida","time":"14:00","items":[["Arroz blanco (crudo)",100],["Pechuga de pollo",170],["Aceite de oliva virgen extra",12],["Brócoli",150]]},
    {"name":"Pre-entreno","time":"17:00","items":[["Pan integral",80],["Pechuga de pavo",90],["Plátano",120]]},
    {"name":"Post-entreno","time":"19:30","items":[["Proteína de suero",35],["Tortitas de arroz",40],["Miel",20]]},
    {"name":"Cena","time":"21:30","items":[["Merluza",230],["Patata",350],["Aceite de oliva virgen extra",15],["Ensalada variada",150]]}
  ]';
begin
  insert into public.nutrition_plans (client_id, mode, status, meals_per_day, published_at, created_by)
  values (pg_temp.id('c1'), 'closed', 'published', 5, now() - interval '5 days', pg_temp.id('lucia'))
  returning id into plan;
  foreach dt in array array['ON', 'OFF', 'REFEED']::public.day_type[] loop
    fc := case dt when 'ON' then 1 when 'OFF' then 0.55 else 1.4 end;
    ff := case dt when 'ON' then 1 when 'OFF' then 1.5 else 0.7 end;
    n := 0;
    for m in select * from jsonb_array_elements(meals) loop
      insert into public.meals (plan_id, day_type, name, time, sort)
      values (plan, dt, m ->> 'name', (m ->> 'time')::time, n) returning id into meal;
      n := n + 1;
      for it in select * from jsonb_array_elements(m -> 'items') loop
        insert into public.meal_items (meal_id, food_id, grams, sort)
        select meal, f.id,
          case f.category when 'c' then greatest(5, round((it ->> 1)::numeric * fc / 5) * 5)
                          when 'f' then greatest(5, round((it ->> 1)::numeric * ff / 5) * 5)
                          else (it ->> 1)::numeric end,
          0
        from public.foods f where f.name = it ->> 0;
      end loop;
    end loop;
    -- Targets = what the pautado adds up to, rounded to 5 g.
    insert into public.nutrition_targets (plan_id, day_type, protein_g, carbs_g, fat_g)
    select plan, dt, round(sum(f.protein * mi.grams / 100) / 5) * 5, round(sum(f.carbs * mi.grams / 100) / 5) * 5, round(sum(f.fat * mi.grams / 100) / 5) * 5
    from public.meal_items mi join public.meals ml on ml.id = mi.meal_id join public.foods f on f.id = mi.food_id
    where ml.plan_id = plan and ml.day_type = dt;
  end loop;
end $$;

-- ---------------------------------------------------------------- Alejandro: weigh-ins, measurements, goals, phases
insert into public.weigh_ins (client_id, measured_at, kg, fasted)
select pg_temp.id('c1'),
  (current_date - (119 - i)) + time '07:30' + (i % 4) * interval '10 minutes',
  round((81.6 - 3.2 * (i / 119.0) + 0.32 * sin(i * 1.7) + 0.18 * sin(i * 0.37))::numeric, 1),
  true
from generate_series(0, 118) as i;

insert into public.measurements (client_id, measured_on, waist, hip, chest, arm, thigh) values
  (pg_temp.id('c1'), current_date - 47, 83.5, 97.2, 104.0, 37.6, 58.8),
  (pg_temp.id('c1'), current_date - 1, 81.5, 96.0, 104.5, 38.0, 58.5);

insert into public.goals (client_id, metric, label, unit, start_value, target_value, due_date) values
  (pg_temp.id('c1'), 'weight_avg', 'Peso medio', 'kg', 80.1, 78.0, current_date - 5),
  (pg_temp.id('c1'), 'waist', 'Cintura', 'cm', 83.5, 80.5, current_date - 5),
  (pg_temp.id('c1'), 'body_fat', '% graso', '%', 15.8, 12.0, current_date + 37),
  (pg_temp.id('c1'), 'e1rm_bench', 'Press banca 1RM est.', 'kg', 100, 110, current_date + 37);

insert into public.phases (client_id, name, start_date, end_date) values
  (pg_temp.id('c1'), 'Recomposición', current_date - 47, current_date - 6),
  (pg_temp.id('c1'), 'Definición', current_date - 5, current_date + 37);

-- ---------------------------------------------------------------- check-ins
insert into public.check_ins (client_id, week, submitted_at, status, weight_kg, waist_cm, energy, hunger, sleep, stress, adherence, client_note, coach_feedback, reviewed_by, reviewed_at)
values
  (pg_temp.id('c1'), 6, now() - interval '2 hours', 'pending', 78.3, 81.5, 7, 6, 8, 5, 9, 'Buena semana. Me costó la cena del sábado por un evento familiar.', null, null, null),
  (pg_temp.id('c3'), 10, now() - interval '13 hours', 'pending', 82.9, 76.0, 6, 8, 6, 6, 10, 'Algo más cansado en pierna. Posing diario hecho.', null, null, null),
  (pg_temp.id('c9'), 2, now() - interval '3 hours', 'pending', 79.8, 84.0, 8, 5, 7, 4, 8, 'Me adapto bien al volumen. Duermo poco entre semana.', null, null, null),
  (pg_temp.id('c11'), 9, now() - interval '7 days', 'pending', 66.0, 72.0, 5, 7, 5, 8, 5, 'Semana difícil, he faltado a dos entrenos por trabajo.', null, null, null),
  (pg_temp.id('c6'), 7, now() - interval '2 days', 'reviewed', 85.1, 86.5, 7, 5, 7, 5, 8, 'Rodilla algo molesta en sentadilla.', 'Cambiamos sentadilla por prensa dos semanas y vemos evolución.', pg_temp.id('carlos'), now() - interval '2 days'),
  (pg_temp.id('c2'), 10, now() - interval '3 days', 'reviewed', 61.2, 66.0, 8, 6, 8, 4, 9, 'Muy bien con el ajuste de carbohidratos.', 'Perfecto, mantenemos una semana más y revisamos.', pg_temp.id('jm'), now() - interval '3 days'),
  (pg_temp.id('c10'), 22, now() - interval '4 days', 'reviewed', 88.2, 79.0, 6, 8, 6, 7, 9, 'Hambre alta por las noches.', 'Añadimos 150 g de verdura en la cena y caseína antes de dormir.', pg_temp.id('lucia'), now() - interval '4 days');

-- ---------------------------------------------------------------- queue items from the panel prototype
insert into public.food_proposals (meal_item_id, client_id, text)
select mi.id, pg_temp.id('c1'), 'Quinoa en lugar de arroz'
from public.meal_items mi join public.meals m on m.id = mi.meal_id join public.foods f on f.id = mi.food_id
where m.name = 'Comida' and m.day_type = 'ON' and f.name = 'Arroz blanco (crudo)'
  and m.plan_id = (select id from public.nutrition_plans where client_id = pg_temp.id('c1'));

insert into public.exercise_swap_requests (client_id, training_item_id, reason)
select pg_temp.id('c1'), ti.id, 'Molestia en el hombro derecho en la última serie.'
from public.training_items ti join public.exercises e on e.id = ti.exercise_id
join public.training_days d on d.id = ti.day_id join public.training_plans p on p.id = d.plan_id
where p.client_id = pg_temp.id('c1') and e.name = 'Press inclinado con mancuernas';

-- ---------------------------------------------------------------- calendar (current week, Monday = start)
with wk as (select date_trunc('week', current_date)::date as mon),
ev(day, hour, dur, title, owner, client, type) as (values
  (0, 9.0, 60, 'Revisión · Laura Iglesias', 'jm', 'c2', 'review'), (0, 11.0, 60, 'Revisión · Pablo Ortega', 'carlos', 'c6', 'review'),
  (0, 16.0, 60, 'Ajuste dieta · Marina Soto', 'lucia', 'c11', 'review'), (1, 10.0, 90, 'Valoración · Nerea Campos', 'carlos', 'c7', 'assessment'),
  (1, 12.0, 60, 'Cobros semanales', 'marta', null, 'task'), (1, 17.0, 60, 'Posing · David Romero', 'jm', 'c3', 'posing'),
  (2, 9.0, 60, 'Ajuste dieta · Iván Sáez', 'lucia', 'c5', 'review'), (2, 9.5, 45, 'Valoración · Andrea Molina', 'jm', 'c12', 'assessment'),
  (2, 10.0, 60, 'Revisión · Alejandro Martín', 'carlos', 'c1', 'review'), (2, 12.0, 60, 'Revisión · David Romero', 'jm', 'c3', 'review'),
  (2, 12.5, 45, 'Seguimiento impago · Sergio Navas', 'marta', 'c4', 'call'), (2, 13.0, 60, 'Revisión · Rubén Lozano', 'carlos', 'c9', 'review'),
  (2, 18.5, 60, 'Posing · Hugo Marín', 'jm', 'c10', 'posing'), (3, 10.0, 60, 'Revisión · Sergio Navas', 'carlos', 'c4', 'review'),
  (3, 11.0, 60, 'Valoración nutricional · Andrea Molina', 'lucia', 'c12', 'assessment'), (3, 17.0, 90, 'Grabación vídeos de técnica', 'jm', null, 'task'),
  (4, 9.0, 60, 'Revisión · Cristina Vela', 'jm', 'c8', 'review'), (4, 12.0, 60, 'Renovaciones del mes', 'marta', null, 'task'),
  (4, 16.0, 60, 'Revisión · Hugo Marín', 'lucia', 'c10', 'review'), (5, 10.0, 120, 'Simulacro de tarima · David Romero', 'jm', 'c3', 'posing')
)
insert into public.events (owner_id, client_id, type, title, starts_at, duration_min)
select pg_temp.id(owner), pg_temp.id(client), type::public.event_type, title,
  ((select mon from wk) + day) + make_interval(mins => (hour * 60)::int), dur
from ev;

insert into public.events (owner_id, is_team, type, title, starts_at, duration_min)
values (pg_temp.id('jm'), true, 'meeting', 'Reunión de equipo', (date_trunc('week', current_date)::date + 2) + time '16:00', 60);

-- ---------------------------------------------------------------- messages
with msg(client, who, body, ago) as (values
  ('c1', 'c', 'Subido el check-in de la semana 6.', interval '95 minutes'),
  ('c1', 'carlos', 'Perfecto, lo reviso a las 10:00.', interval '83 minutes'),
  ('c1', 'c', '¿Puedo cambiar el arroz de la comida por patata?', interval '70 minutes'),
  ('c4', 'carlos', 'Sergio, ¿todo bien? Llevas 6 días sin registrar.', interval '2 days'),
  ('c4', 'c', 'Semana complicada en el trabajo, retomo hoy.', interval '3 hours'),
  ('c6', 'c', 'Me molesta la rodilla izquierda en la sentadilla.', interval '5 hours'),
  ('c3', 'jm', 'El sábado simulacro de tarima a las 10:00.', interval '1 day 2 hours'),
  ('c3', 'c', 'Allí estaré. ¿Llevo el bañador de competición?', interval '1 day 1 hour'),
  ('c3', 'jm', 'Sí, y el bronceador para probar el tono.', interval '1 day'),
  ('c12', 'jm', 'Bienvenida, Andrea. Hoy a las 9:30 hacemos la valoración.', interval '4 hours'),
  ('c12', 'c', '¡Genial! Ya tengo las fotos preparadas.', interval '3 hours 40 minutes'),
  ('c2', 'c', 'Gracias por el ajuste, me encuentro mucho mejor.', interval '1 day')
)
insert into public.messages (thread_id, sender_id, body, created_at, read_at)
select t.id, case when m.who = 'c' then pg_temp.id('u:' || m.client) else pg_temp.id(m.who) end,
  m.body, now() - m.ago, case when m.who <> 'c' or m.client in ('c3', 'c2') then now() - m.ago end
from msg m join public.threads t on t.client_id = pg_temp.id(m.client);

-- ---------------------------------------------------------------- invoices
insert into public.invoices (client_id, concept, installment, installments_total, amount_cents, issued_on, due_date, method, status, paid_at, validated_by, proof_path, proof_submitted_at)
select pg_temp.id(c), concept, inst, total, amount * 100, current_date + issued, current_date + due, method::public.payment_method, status::public.invoice_status,
  case when status = 'paid' then now() + (due || ' days')::interval end,
  case when status = 'paid' then pg_temp.id('marta') end,
  case when status = 'proof_submitted' then pg_temp.id(c)::text || '/justificantes/demo.pdf' end,
  case when status = 'proof_submitted' then now() - interval '5 hours' end
from (values
  ('c1', 'Premium completo · cuota 1 de 3', 1, 3, 109, -47, -47, 'card', 'paid'),
  ('c9', 'Esencial · pago único', null, null, 179, -14, -14, 'card', 'paid'),
  ('c1', 'Premium completo · cuota 2 de 3', 2, 3, 109, -17, -17, 'card', 'paid'),
  ('c3', 'Competición · cuota 5 de 6', 5, 6, 149, -10, -10, 'card', 'paid'),
  ('c2', 'Integral · cuota 3 de 3', 3, 3, 83, -9, -9, 'bizum', 'paid'),
  ('c10', 'Competición · cuota 6 de 6', 6, 6, 149, -8, -8, 'bizum', 'paid'),
  ('c4', 'Esencial · cuota 2 de 3', 2, 3, 109, -3, -3, 'bizum', 'overdue'),
  ('c7', 'Premium completo · cuota 1 de 3', 1, 3, 109, -2, -2, 'bizum', 'proof_submitted'),
  ('c12', 'Integral · pago único', null, null, 249, 0, 0, 'bizum', 'proof_submitted'),
  ('c5', 'Premium completo · renovación', null, null, 327, 0, 4, 'card', 'pending'),
  ('c6', 'Integral · cuota 2 de 3', 2, 3, 83, 0, 9, 'cash', 'pending'),
  ('c1', 'Premium completo · cuota 3 de 3', 3, 3, 109, 0, 13, 'card', 'pending')
) as v(c, concept, inst, total, amount, issued, due, method, status)
order by issued, c;

-- ---------------------------------------------------------------- contracts
insert into public.contract_templates (plan_id, version_major, version_minor, body, updated_at)
select p.id, v.maj, v.min, format('Condiciones del plan %s (v%s.%s). Texto provisional pendiente de revisión legal.', p.name, v.maj, v.min), now() - v.age
from public.plans p join (values
  ('esencial', 1, 4, interval '244 days'), ('integral', 2, 0, interval '163 days'),
  ('premium-completo', 2, 1, interval '71 days'), ('competicion', 1, 2, interval '180 days')
) as v(slug, maj, min, age) on v.slug = p.slug
on conflict do nothing;

insert into public.contracts (client_id, template_id, status, sent_at, valid_until, signed_at, health_data_consent_at)
select c.id, t.id,
  case when d.k in ('c7', 'c12') then 'pending' when d.k in ('c5', 'c8') then 'expiring' else 'signed' end::public.contract_status,
  case d.k when 'c7' then now() - interval '4 days' when 'c12' then now() else c.start_date::timestamptz end,
  c.end_date,
  case when d.k not in ('c7', 'c12') then c.start_date::timestamptz end,
  case when d.k not in ('c7', 'c12') then c.start_date::timestamptz end
from demo_cli d join public.clients c on c.id = pg_temp.id(d.k)
join public.contract_templates t on t.plan_id = c.plan_id;

-- ---------------------------------------------------------------- leads
insert into public.leads (name, email, goal, message) values
  ('Mario Herrera', 'mario.herrera@example.com', 'Ganar masa muscular', 'Llevo 3 años entrenando y me he estancado.'),
  ('Elena Ríos', 'elena.rios@example.com', 'Competir', 'Quiero preparar mi primera competición natural en 2027.');
