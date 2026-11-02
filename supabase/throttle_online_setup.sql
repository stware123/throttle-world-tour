-- =====================================================================
-- Throttle: World Tour — online leaderboards, ghosts and live races
-- Paste this whole script into Supabase → SQL Editor → New query → Run.
-- Safe to run more than once.
-- =====================================================================

-- 1) Track list with real lap lengths (used to reject impossible times)
create table if not exists public.tt_tracks (
  id        text primary key,
  length_m  int  not null,
  laps      int  not null
);

insert into public.tt_tracks (id, length_m, laps) values
  ('wessex',2753,3),('kingsmoor',1895,3),('cotswold',3328,2),('sahara',3664,2),('lommel',2073,3),
  ('amalfi',3088,2),('forest',3055,2),('canyon',2206,3),('manx',4431,2),('outback',3934,2),
  ('alpine',3451,2),('arena',1142,4),('tokyo',3191,3),('snetterton',4778,2),('thruxton',3790,3),
  ('silverstone',5891,2),('donington',4020,3),('brands',3908,3),('oulton',4307,3),('knockhill',2050,4),
  ('assen',4542,2),('mugello',5245,2),('phillip',4448,3),('laguna',3602,3),('cadwell',3480,3),
  ('ulster',6000,2),('nw200',14436,2),('iomtt',60720,1),('losail',5380,3)
on conflict (id) do update set length_m = excluded.length_m, laps = excluded.laps;

-- 2) One row per rider name per track: their best total time and best-lap ghost.
--    Riders are identified by name (not case sensitive), so the same name on a
--    new phone or after a reinstall carries on with the same world times.
create table if not exists public.tt_times (
  id           bigint generated always as identity primary key,
  track        text not null references public.tt_tracks(id),
  player_id    uuid not null,
  name         text not null check (char_length(name) between 1 and 16),
  total_ms     int  not null,
  best_lap_ms  int  not null,
  ghost        text,
  ghost_ms     int,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- 2b) Upgrade from version 1 (one row per device) to one row per name. Safe to rerun.
alter table public.tt_times add column if not exists name_key text generated always as (lower(trim(name))) stored;
-- where the same name has several rows, move the fastest lap (and its ghost) onto the row with the best total
with r as (
  select id, track, name_key,
         row_number() over (partition by track, name_key order by total_ms, id)    as by_total,
         row_number() over (partition by track, name_key order by best_lap_ms, id) as by_lap
  from public.tt_times),
pair as (
  select k.id as keep_id, l.id as lap_id from r k join r l on l.track = k.track and l.name_key = k.name_key
  where k.by_total = 1 and l.by_lap = 1 and k.id <> l.id)
update public.tt_times t set
  best_lap_ms = s.best_lap_ms,
  ghost    = case when s.ghost is not null then s.ghost    else t.ghost    end,
  ghost_ms = case when s.ghost is not null then s.ghost_ms else t.ghost_ms end
from pair, public.tt_times s
where t.id = pair.keep_id and s.id = pair.lap_id and s.best_lap_ms < t.best_lap_ms;
-- then drop the extra rows, keeping each name's best
delete from public.tt_times a using public.tt_times b
where a.track = b.track and a.name_key = b.name_key and (b.total_ms, b.id) < (a.total_ms, a.id);
alter table public.tt_times drop constraint if exists tt_times_track_player_id_key;
create unique index if not exists tt_times_track_name on public.tt_times (track, name_key);
-- 2c) Which bike (class and upgrades) set each time, shown on the boards
alter table public.tt_times add column if not exists bike text;       -- bike that set the best total time
alter table public.tt_times add column if not exists lap_bike text;   -- bike that set the best lap
create index if not exists tt_times_board on public.tt_times (track, total_ms);
create index if not exists tt_times_lap   on public.tt_times (track, best_lap_ms);

-- 1b) Times set on an older, shorter version of a course can't stand on the full-length one:
--      anything faster than a lap at 82 m/s average on the current length is cleared. Safe to rerun.
delete from public.tt_times t using public.tt_tracks k
where t.track = k.id and t.best_lap_ms < (k.length_m / 82.0 * 1000)::int;

-- 3) Submission log for simple rate limiting
create table if not exists public.tt_submissions (
  player_id uuid not null,
  at        timestamptz not null default now()
);
create index if not exists tt_sub_player on public.tt_submissions (player_id, at);

-- 4) Lock the tables down: the game only talks to the functions below
alter table public.tt_tracks      enable row level security;
alter table public.tt_times       enable row level security;
alter table public.tt_submissions enable row level security;
drop policy if exists "tracks readable" on public.tt_tracks;
create policy "tracks readable" on public.tt_tracks for select using (true);

-- 5) Submit a time trial result (validates it, keeps each player's best)
drop function if exists public.tt_submit(text, uuid, text, int, int, text, int);
create or replace function public.tt_submit(
  p_track text, p_player uuid, p_name text,
  p_total_ms int, p_best_lap_ms int, p_ghost text, p_ghost_ms int, p_bike text default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  t record; v_min_lap int; v_name text; v_row public.tt_times; v_rank int; v_lap_rank int;
begin
  select * into t from tt_tracks where id = p_track;
  if not found then raise exception 'unknown track'; end if;
  -- nothing can average more than 82 m/s (about 183 mph) over a lap
  v_min_lap := (t.length_m / 82.0 * 1000)::int;
  if p_best_lap_ms < v_min_lap then raise exception 'lap time not possible'; end if;
  if p_total_ms < p_best_lap_ms * t.laps * 0.995 or p_total_ms > 3600000 then raise exception 'total time not possible'; end if;
  if p_ghost is not null and (char_length(p_ghost) > 400000 or p_ghost_ms is null or abs(p_ghost_ms - p_best_lap_ms) > 1500) then p_ghost := null; p_ghost_ms := null; end if;
  if (select count(*) from tt_submissions where player_id = p_player and at > now() - interval '10 minutes') >= 30 then
    raise exception 'too many submissions, try again in a few minutes';
  end if;
  insert into tt_submissions (player_id) values (p_player);

  v_name := left(regexp_replace(trim(coalesce(p_name, '')), '[^[:print:]]', '', 'g'), 16);
  if v_name = '' then v_name := 'Rider'; end if;

  insert into tt_times (track, player_id, name, total_ms, best_lap_ms, ghost, ghost_ms, bike, lap_bike)
  values (p_track, p_player, v_name, p_total_ms, p_best_lap_ms, p_ghost, p_ghost_ms, left(p_bike, 40), left(p_bike, 40))
  on conflict (track, name_key) do update set
    name        = excluded.name,
    player_id   = excluded.player_id,
    total_ms    = least(tt_times.total_ms, excluded.total_ms),
    bike        = case when excluded.total_ms < tt_times.total_ms then excluded.bike else tt_times.bike end,
    lap_bike    = case when excluded.best_lap_ms < tt_times.best_lap_ms then excluded.lap_bike else coalesce(tt_times.lap_bike, tt_times.bike) end,
    best_lap_ms = least(tt_times.best_lap_ms, excluded.best_lap_ms),
    ghost       = case when excluded.best_lap_ms < tt_times.best_lap_ms and excluded.ghost is not null then excluded.ghost else tt_times.ghost end,
    ghost_ms    = case when excluded.best_lap_ms < tt_times.best_lap_ms and excluded.ghost is not null then excluded.ghost_ms else tt_times.ghost_ms end,
    updated_at  = now()
  returning * into v_row;

  select 1 + count(*) into v_rank from tt_times where track = p_track and total_ms < v_row.total_ms;
  select 1 + count(*) into v_lap_rank from tt_times where track = p_track and best_lap_ms < v_row.best_lap_ms;
  return json_build_object('rank', v_rank, 'lap_rank', v_lap_rank, 'total_ms', v_row.total_ms, 'best_lap_ms', v_row.best_lap_ms);
end $$;

-- 6) Read a track's leaderboard (no ghost data, so it stays small)
drop function if exists public.tt_board(text, int);
create or replace function public.tt_board(p_track text, p_limit int default 20)
returns table (id bigint, name text, total_ms int, best_lap_ms int, has_ghost boolean, updated_at timestamptz, player_id uuid, bike text, lap_bike text)
language sql stable security definer set search_path = public as $$
  select id, name, total_ms, best_lap_ms, ghost is not null, updated_at, player_id, bike, coalesce(lap_bike, bike)
  from tt_times where track = p_track
  order by total_ms asc limit least(greatest(p_limit, 1), 50);
$$;

-- 7) Fetch one rider's best-lap ghost to race against
create or replace function public.tt_ghost(p_id bigint)
returns table (name text, ghost text, ghost_ms int, track text)
language sql stable security definer set search_path = public as $$
  select name, ghost, ghost_ms, track from tt_times where id = p_id;
$$;

-- 7b) A rider's own world best on a track, looked up by name (works on any device)
create or replace function public.tt_mine(p_track text, p_name text)
returns table (total_ms int, best_lap_ms int, rank int, has_ghost boolean)
language sql stable security definer set search_path = public as $$
  select t.total_ms, t.best_lap_ms,
         (select 1 + count(*) from tt_times x where x.track = t.track and x.total_ms < t.total_ms)::int,
         t.ghost is not null
  from tt_times t where t.track = p_track and t.name_key = lower(trim(p_name)) limit 1;
$$;

-- 8) Fastest lap holder with a ghost, per track
drop function if exists public.tt_record_ghost(text);
create or replace function public.tt_record_ghost(p_track text)
returns table (id bigint, name text, best_lap_ms int, bike text)
language sql stable security definer set search_path = public as $$
  select id, name, best_lap_ms, coalesce(lap_bike, bike) from tt_times where track = p_track and ghost is not null order by best_lap_ms asc limit 1;
$$;

revoke all on function public.tt_submit(text, uuid, text, int, int, text, int, text) from public;
grant execute on function public.tt_submit(text, uuid, text, int, int, text, int, text) to anon, authenticated;
grant execute on function public.tt_board(text, int)       to anon, authenticated;
grant execute on function public.tt_ghost(bigint)          to anon, authenticated;
grant execute on function public.tt_record_ghost(text)     to anon, authenticated;
grant execute on function public.tt_mine(text, text)       to anon, authenticated;

-- Live races use Supabase Realtime "broadcast" and "presence" channels.
-- Nothing to create here. Just make sure Realtime is enabled for the project and
-- that Realtime Settings does NOT have "Private channels only" switched on.
