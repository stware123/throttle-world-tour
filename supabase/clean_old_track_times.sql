-- Throttle: World Tour: remove world-board times (and their ghost laps) set on the surveyed
-- circuits before they were rebuilt with the real line, corners and elevation.
-- Run once in the Supabase SQL Editor. Step 1 only shows what will go; step 2 deletes it.

-- 1) Preview: how many times will be removed, per track
select track, count(*) as old_times
from public.tt_times
where (track in ('brands', 'cadwell', 'donington') and updated_at < timestamptz '2026-11-10 20:30:00+00')
   or (track in ('castlecombe', 'pembrey', 'silverstone', 'oulton', 'snetterton', 'thruxton', 'knockhill') and updated_at < timestamptz '2026-11-11 20:00:00+00')
group by track order by track;

-- 2) Delete them (every board: dry, wet, snow and daily challenge)
delete from public.tt_times
where (track in ('brands', 'cadwell', 'donington') and updated_at < timestamptz '2026-11-10 20:30:00+00')
   or (track in ('castlecombe', 'pembrey', 'silverstone', 'oulton', 'snetterton', 'thruxton', 'knockhill') and updated_at < timestamptz '2026-11-11 20:00:00+00');
