-- Nutrition: food database, plans per day type, meals, swaps, proposals and saved meals.

create type public.food_category as enum ('p', 'c', 'f', 'v');
create type public.diet_mode as enum ('closed', 'open');
create type public.day_type as enum ('ON', 'OFF', 'REFEED');
create type public.review_status as enum ('pending', 'approved', 'rejected');

-- Macros per 100 g.
create table public.foods (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category public.food_category not null,
  kcal numeric(6, 1) not null check (kcal >= 0),
  protein numeric(5, 1) not null check (protein >= 0),
  carbs numeric(5, 1) not null check (carbs >= 0),
  fat numeric(5, 1) not null check (fat >= 0),
  -- Authorised swaps are limited to foods flagged as interchangeable within their category.
  swappable boolean not null default true
);

create table public.nutrition_plans (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  mode public.diet_mode not null default 'closed',
  status public.publish_status not null default 'draft',
  meals_per_day smallint not null default 5 check (meals_per_day between 2 and 8),
  -- Day type per weekday, Monday = 0. Drives ON/OFF/REFEED in the client app and calendar.
  week_pattern public.day_type[] not null default '{ON,ON,OFF,ON,ON,REFEED,OFF}'
    check (array_length(week_pattern, 1) = 7),
  published_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index on public.nutrition_plans (client_id);
create unique index nutrition_plans_one_published on public.nutrition_plans (client_id) where status = 'published';

create table public.nutrition_targets (
  plan_id uuid not null references public.nutrition_plans (id) on delete cascade,
  day_type public.day_type not null,
  protein_g smallint not null check (protein_g >= 0),
  carbs_g smallint not null check (carbs_g >= 0),
  fat_g smallint not null check (fat_g >= 0),
  primary key (plan_id, day_type)
);

create table public.meals (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.nutrition_plans (id) on delete cascade,
  day_type public.day_type not null,
  name text not null,
  time time,
  sort smallint not null default 0
);
create index on public.meals (plan_id, day_type);

create table public.meal_items (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null references public.meals (id) on delete cascade,
  food_id uuid not null references public.foods (id),
  grams smallint not null check (grams > 0),
  sort smallint not null default 0
);
create index on public.meal_items (meal_id);

-- Client-chosen authorised equivalence; one active swap per item.
create table public.food_swaps (
  id uuid primary key default gen_random_uuid(),
  meal_item_id uuid not null unique references public.meal_items (id) on delete cascade,
  client_id uuid not null references public.clients (id) on delete cascade,
  food_id uuid not null references public.foods (id),
  grams smallint not null check (grams > 0),
  created_at timestamptz not null default now()
);

create table public.food_proposals (
  id uuid primary key default gen_random_uuid(),
  meal_item_id uuid not null references public.meal_items (id) on delete cascade,
  client_id uuid not null references public.clients (id) on delete cascade,
  text text not null check (length(text) between 1 and 500),
  status public.review_status not null default 'pending',
  response text,
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- «Comidas habituales» saved from the open-diet calculator.
create table public.saved_meals (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  name text not null,
  items jsonb not null check (jsonb_typeof(items) = 'array'),
  created_at timestamptz not null default now()
);

-- Daily meal check-off («Marcar como realizada»).
create table public.meal_logs (
  client_id uuid not null references public.clients (id) on delete cascade,
  meal_id uuid not null references public.meals (id) on delete cascade,
  eaten_on date not null default current_date,
  primary key (client_id, meal_id, eaten_on)
);

-- ---------- helpers

create function private.client_of_nutrition_plan(pid uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select client_id from public.nutrition_plans where id = pid
$$;

create function private.client_of_meal(mid uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select p.client_id from public.meals m join public.nutrition_plans p on p.id = m.plan_id where m.id = mid
$$;

create function private.client_of_meal_item(iid uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select p.client_id from public.meal_items i
  join public.meals m on m.id = i.meal_id
  join public.nutrition_plans p on p.id = m.plan_id
  where i.id = iid
$$;

create function private.nutrition_plan_visible(pid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.nutrition_plans p
    where p.id = pid
      and private.can_access_client(p.client_id)
      and (private.auth_role() <> 'client' or p.status = 'published')
  )
$$;

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

-- ---------- RLS

alter table public.foods enable row level security;
alter table public.nutrition_plans enable row level security;
alter table public.nutrition_targets enable row level security;
alter table public.meals enable row level security;
alter table public.meal_items enable row level security;
alter table public.food_swaps enable row level security;
alter table public.food_proposals enable row level security;
alter table public.saved_meals enable row level security;
alter table public.meal_logs enable row level security;

create policy "foods: read" on public.foods for select to authenticated using (true);
create policy "foods: diet staff write" on public.foods for all to authenticated
  using (private.has_perm('dietas') and private.auth_role() <> 'billing')
  with check (private.has_perm('dietas') and private.auth_role() <> 'billing');

create policy "nutrition_plans: read" on public.nutrition_plans for select to authenticated
  using (private.nutrition_plan_visible(id));
create policy "nutrition_plans: staff write" on public.nutrition_plans for all to authenticated
  using (private.staff_can(client_id, 'dietas')) with check (private.staff_can(client_id, 'dietas'));

create policy "nutrition_targets: read" on public.nutrition_targets for select to authenticated
  using (private.nutrition_plan_visible(plan_id));
create policy "nutrition_targets: staff write" on public.nutrition_targets for all to authenticated
  using (private.staff_can(private.client_of_nutrition_plan(plan_id), 'dietas'))
  with check (private.staff_can(private.client_of_nutrition_plan(plan_id), 'dietas'));

create policy "meals: read" on public.meals for select to authenticated
  using (private.nutrition_plan_visible(plan_id));
create policy "meals: staff write" on public.meals for all to authenticated
  using (private.staff_can(private.client_of_nutrition_plan(plan_id), 'dietas'))
  with check (private.staff_can(private.client_of_nutrition_plan(plan_id), 'dietas'));

create policy "meal_items: read" on public.meal_items for select to authenticated
  using (private.nutrition_plan_visible((select m.plan_id from public.meals m where m.id = meal_id)));
create policy "meal_items: staff write" on public.meal_items for all to authenticated
  using (private.staff_can(private.client_of_meal(meal_id), 'dietas'))
  with check (private.staff_can(private.client_of_meal(meal_id), 'dietas'));

create policy "food_swaps: read" on public.food_swaps for select to authenticated
  using (client_id = private.my_client_id() or private.staff_can(client_id, 'dietas'));
create policy "food_swaps: client write" on public.food_swaps for all to authenticated
  using (client_id = private.my_client_id())
  with check (client_id = private.my_client_id() and private.client_of_meal_item(meal_item_id) = client_id);

create policy "food_proposals: read" on public.food_proposals for select to authenticated
  using (client_id = private.my_client_id() or private.staff_can(client_id, 'dietas'));
create policy "food_proposals: client create" on public.food_proposals for insert to authenticated
  with check (
    client_id = private.my_client_id()
    and status = 'pending'
    and private.client_of_meal_item(meal_item_id) = client_id
  );
create policy "food_proposals: staff review" on public.food_proposals for update to authenticated
  using (private.staff_can(client_id, 'dietas')) with check (private.staff_can(client_id, 'dietas'));

create policy "saved_meals: own" on public.saved_meals for all to authenticated
  using (client_id = private.my_client_id()) with check (client_id = private.my_client_id());
create policy "saved_meals: staff read" on public.saved_meals for select to authenticated
  using (private.staff_can(client_id, 'dietas'));

create policy "meal_logs: own" on public.meal_logs for all to authenticated
  using (client_id = private.my_client_id())
  with check (client_id = private.my_client_id() and private.client_of_meal(meal_id) = client_id);
create policy "meal_logs: staff read" on public.meal_logs for select to authenticated
  using (private.staff_can(client_id, 'dietas'));
