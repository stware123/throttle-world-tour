# Throttle: World Tour

A 3D motorbike racing game that runs in the browser — desktop, phone or tablet.

**Play:** open the GitHub Pages link for this repository. On Android, use Chrome's menu → *Install app* (or *Add to Home screen*) to install it full-screen; it works offline after the first visit.

## What's in it
- **World Tour** — 13 rounds across 10 countries: superbike circuits and road courses, desert and forest scramblers, and motocross (including a night-time arenacross).
- **Real Circuits** — 15 rounds: Snetterton, Thruxton, Silverstone, Donington Park, Brands Hatch, Oulton Park, Knockhill, Assen, Mugello, Phillip Island, Laguna Seca, Cadwell Park, Ulster GP (Dundrod), North West 200 and the TT Mountain Course, with corner names on screen.
- **Time Trial** — every track, best-lap ghost, live split and a top-10 leaderboard per track (saved in your browser).
- **Online** — world leaderboards for every track, race any player's best-lap ghost, and live races for up to 8 riders using a 4-letter race code (empty spots can be filled with computer riders).
- **Helmet cam** — ride from inside the helmet: visor and chin bar, the screen and a live dash, head that looks through the corners and tucks in on the straights.
- **TV-style replays** — watch your best lap, a world record or anyone's saved lap, with a director cutting between trackside long-lens cameras, drones, a helicopter, tracking, tail, front and tank cams, a fly-by and the helmet cam, ending in slow motion at the line.
- Keyboard, Xbox/PlayStation controller, or touch controls.

## Online setup (for the repo owner)
Online features use Supabase. Run `supabase/throttle_online_setup.sql` once in the project's SQL Editor. The game reads the project URL and the public *anon* key at build time; the anon key is safe to publish. All writes go through database functions that validate lap times and rate-limit submissions.

## Controls
| | Keyboard | Controller | Touch |
|---|---|---|---|
| Throttle | W / ↑ | RT / A | GAS |
| Brake | S / ↓ / Space | LT / X | BRAKE |
| Steer | A D / ← → | Left stick | ◀ ▶ (or tilt) |
| Camera / Respawn / Pause | C / R / Esc | Y / Back / Start | top-right buttons |

## Credits and data
- Built with [three.js](https://threejs.org) (MIT).
- Isle of Man TT Mountain Course (full 37.73 miles): OpenStreetMap relation 188240, (c) OpenStreetMap contributors, [ODbL](https://opendatacommons.org/licenses/odbl/).
- Brands Hatch and Cadwell Park (surveyed): layout (c) OpenStreetMap contributors (ODbL); heights, widths, ground and trees from the Environment Agency LIDAR Composite DTM 1 m, (c) Environment Agency copyright and/or database right 2022, Open Government Licence v3.0; prepared by [Wreckfest-RealCircuits](https://github.com/GreyManSoftware/Wreckfest-RealCircuits) (MIT).
- Silverstone outline: [TUMFTM racetrack-database](https://github.com/TUMFTM/racetrack-database) (derived from OpenStreetMap data), LGPL-3.0.
- Mugello outline: [bacinger/f1-circuits](https://github.com/bacinger/f1-circuits), MIT.
- Other real circuits are hand-traced approximations from their corner sequences; the TT, North West 200 and Ulster GP courses are scaled down. This is an unofficial fan game and is not affiliated with any circuit, series or event organiser.
