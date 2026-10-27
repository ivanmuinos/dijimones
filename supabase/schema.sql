-- Dijimones: esquema de Supabase (PRD 8.7). Correr entero en el SQL Editor del proyecto.
-- Identidad: login anónimo (Auth > Sign In / Providers > "Allow anonymous sign-ins").

-- Perfil público del jugador (nombre del tamer)
create table if not exists public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  name        text not null check (char_length(name) between 1 and 16),
  clan_id     uuid,
  created_at  timestamptz not null default now()
);

-- Clanes: compiten sumando las mejores runs de sus miembros
create table if not exists public.clans (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique check (char_length(name) between 2 and 24),
  tag         text not null unique check (tag ~ '^[A-Z0-9]{2,5}$'),
  owner_id    uuid not null references auth.users on delete cascade,
  created_at  timestamptz not null default now()
);
alter table public.profiles
  drop constraint if exists profiles_clan_fk,
  add constraint profiles_clan_fk foreign key (clan_id) references public.clans on delete set null;

-- Cada run terminada (ranking por mapa / modo / global)
create table if not exists public.runs (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users on delete cascade,
  name        text not null,
  character   text not null,          -- agumon / gabumon / patamon
  stage       text not null,          -- file_island
  mode        text not null check (mode in ('clasico', 'supervivencia')),
  seconds     int  not null check (seconds between 0 and 86400),
  kills       int  not null check (kills between 0 and 1000000),
  level       int  not null check (level between 1 and 999),
  won         boolean not null default false,
  players     int  not null default 1 check (players between 1 and 4),
  created_at  timestamptz not null default now()
);
create index if not exists runs_rank_idx on public.runs (stage, mode, seconds desc, kills desc);

-- Guardado en la nube (progreso meta, PRD 7.7)
create table if not exists public.saves (
  user_id     uuid primary key references auth.users on delete cascade,
  data        text not null,
  version     int  not null default 1,
  updated_at  timestamptz not null default now()
);

-- Seguridad: cada uno solo escribe lo suyo; rankings y perfiles se leen públicamente
alter table public.profiles enable row level security;
alter table public.clans    enable row level security;
alter table public.runs     enable row level security;
alter table public.saves    enable row level security;

drop policy if exists "perfiles visibles" on public.profiles;
create policy "perfiles visibles" on public.profiles for select using (true);
drop policy if exists "mi perfil" on public.profiles;
create policy "mi perfil" on public.profiles for all
  using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "clanes visibles" on public.clans;
create policy "clanes visibles" on public.clans for select using (true);
drop policy if exists "crear clan" on public.clans;
create policy "crear clan" on public.clans for insert with check (auth.uid() = owner_id);
drop policy if exists "dueño del clan" on public.clans;
create policy "dueño del clan" on public.clans for update using (auth.uid() = owner_id);

drop policy if exists "runs visibles" on public.runs;
create policy "runs visibles" on public.runs for select using (true);
drop policy if exists "subir mis runs" on public.runs;
create policy "subir mis runs" on public.runs for insert with check (auth.uid() = user_id);

drop policy if exists "mi save" on public.saves;
create policy "mi save" on public.saves for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Ranking: mejor run de cada jugador por mapa y modo
create or replace view public.leaderboard with (security_invoker = true) as
select distinct on (stage, mode, user_id)
  stage, mode, user_id, name, character, seconds, kills, level, won, players, created_at
from public.runs
order by stage, mode, user_id, seconds desc, kills desc;

-- Ranking de clanes: suma de la mejor run (en kills) de cada miembro
create or replace view public.clan_leaderboard with (security_invoker = true) as
select c.id, c.name, c.tag, count(distinct p.id) as members, coalesce(sum(best.kills), 0) as score
from public.clans c
left join public.profiles p on p.clan_id = c.id
left join lateral (
  select max(r.kills) as kills from public.runs r where r.user_id = p.id
) best on true
group by c.id;
