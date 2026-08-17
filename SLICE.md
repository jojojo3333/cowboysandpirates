# SLICE.md

**CURRENT SLICE: 1**

Slice 0 is done. The slices below were renumbered when the cargo hold rescue
became the first playable thing — what was slice 0 is now slice 1, and so on.

Build only the current slice. When it runs and is committed, stop and wait.

**One mission, not a chain.** The immediate target is a single combat that a
human can play start to finish. The encounter chain — five in `GAME_SPEC v0.1
§5`, six in `GAME_SPEC v0.2 §8` — is deferred, and its length is an open number
to be decided after the single mission has been played. Both counts in the
specs are superseded until then. Slice 4 stays written as-is because the jump
screen and reward numbers are still what it needs to build; only the count is
open.

---

# Render passes — a separate track

Presentation work does not belong in the slice sequence. Slices are missions and
mechanics, numbered in build order; how the ship *looks* cuts across all of them
and gets revisited many times, so it is numbered on its own track: **RENDER PASS
1, 2, 3 …**, independent of `CURRENT SLICE`.

Two numbering options were rejected. "Slice 1.5" implies it belongs between two
mission slices and stops working the second time it happens — and it will happen
often. "Slice 0" is taken by the cargo hold rescue, which is shipped, and reusing
the number would make the build order ambiguous forever.

The rules that hold for slices hold here too: the game must run and be clickable
at the end of every pass, and `tools/verify.sh` must be green before it is
committed.

**A render pass may never change a simulation number.** If the balance report
moves, something has leaked from `ui/` into `sim/` and the pass is wrong. The
report is the check: it read 39.4s for both plans before RENDER PASS 1 and 39.4s
after all three.

**Replacing the ship is not a render pass.** A new plate with a different set of
compartments changes how far apart things are, and distance is a simulation
number. The corridor work of 2026-08-16 moved the report from 39.4s to **42.4s**
for exactly that reason and no other — see the note under RENDER PASS 3. If a
pass that only changes how the ship is *drawn* moves the report, that is still
the bug this rule is here to catch.

## Where the ship art comes from — settled

Checked, not assumed. **Void War** is Tundra, two people *plus a contract
artist*. **FTL** ships are a hand-drawn `ship_base` PNG plus one authored PNG
per interior room, positioned by a layout file. **Cosmoteer** assembles ships
from hand-drawn 64×64 modules. In all three the art comes first and the data
describes the art.

We do the same: **one ship plate per ship** (`ASSETS.md` has the spec and the
generation prompt), rooms traced from it as polygons in plate coordinates. Code
draws state only.

Drawing a hull from primitives has a ceiling, and it is not about polygon count
— it is information. A painted hull carries thousands of individually decided
pixels; procedural code derives detail from a handful of parameters, and rules
produce regularity, which the eye reads as machine-made.

## RENDER PASS 1 — "It looked like a text adventure"  ✅ DONE (superseded)

Six flat grey rectangles in a value range 0.09–0.19 wide, called "an A4 sheet
with a point on the front". Pass 1 built a drawn hull with chamfers, nacelles,
lit interiors, thick walls and a starfield. All of it was deleted in pass 2 —
kept here only because it is the evidence for the paragraph above.

## RENDER PASS 2 — the plate is the ship  ✅ DONE

- `assets/ship/hull_plate.png` replaces every drawn primitive. Rooms are traced
  polygons, so an irregular compartment highlights along its own outline.
- Grid `col`/`row` deleted. Adjacency is the chain the art shows. The simulation
  only ever read `adjacent`, so this cost `sim/` nothing.
- The engine got switched on: `CanvasTexture` with a derived normal map, one
  `PointLight2D` per compartment, additive over a darkened plate. An unpowered
  compartment can now simply go dark.
- Hover feedback on compartments and crew, taken from the uploaded GRIMSHIP
  prototype.

## RENDER PASS 3 — crew are people  ✅ DONE

- `tools/render_crew.gd` renders the CC0 Kenney Mini Characters through a
  `SubViewport`. The models are **rigged** — `walk`, `idle`, `die`, and about
  twenty more — so these are real animation cycles.
- One sheet per model per clip: columns are frames, rows are eight facings.
- Crew animation runs on a clock that stops with the simulation. Restrained crew
  hold a single frame.
- Before this, crew were generated from pixel loops — two ellipses and a
  highlight. Three rounds of parameter tuning could not have fixed that.

**Reported, not tuned:** the balance report read 39.4s for both plans through
all three passes, with end HP [100 ×5] hack and [75 ×5] fight.

## RENDER PASS 4 — the crew are seen from above  ✅ DONE, 2026-08-17

The owner's observation, and the whole pass in one line: **the ship was drawn
from above and the crew were drawn from the side.** Void War shows you a helmet,
a pair of shoulders, and a bit of arm and leg when someone moves. We were
showing a standing figure on a top-down deck.

- Render camera raised from **62° to 80°**. It is one constant,
  `CAMERA_PITCH` in `tools/render_soldier.gd`.
- **The walk was rebuilt, not rescaled.** Raising the camera changes which
  movements survive projection: at 80° sideways and forwards movement land on
  screen at full value and vertical movement is worth 0.17. The old stride was
  mostly vertical — knee lift, torso bob — and the torso hides the legs from
  above anyway. The new one is hip/shoulder counter-rotation, leg splay, arm
  spread and lateral sway. `ASSETS.md` has the table.
- **`--mode angles`** shoots the figure down a list of pitches onto one contact
  sheet and prints each one's bounding box. It exists because the 62° decision
  rested on an untested claim — that a pure overhead human is "a blob" — which
  the first contact sheet disproved at every angle up to 90.
- **`--mode bake` now measures `CREW_ART_OFFSET` and prints it**, instead of it
  being hand-tuned and re-guessed. It moved from -9.0 to -3.5 on this pass.
- `--mode preview` shoots at the game's pitch instead of dropping to 18°.
- `tools/verify.sh rules` gained a check that `render_soldier.gd` and
  `preview_models.gd` hold the same pitch — a candidate model judged at the
  wrong angle is judged wrongly, and that script exists only to judge them.

**Reported, not tuned: 40.3s for both plans, unchanged**, end HP [100 ×5] hack
and [75 ×5] fight. Which is the point of the rule — this pass changed only how
crew are photographed, so the number had no business moving, and it did not.

**Still open, and it is the owner's call:** 80° is a taste decision, not a
legibility one. Comparison renders at 62/70/80/88 in the game and 62/70/76/82/90
of the figure went to the owner on 2026-08-17.

## Corridors and walk routes — 2026-08-16

Not a render pass: it changed the ship, not the way the ship is drawn.

The known bug was that crew walked through walls — `_walk_position()` moved them
room centre → door → room centre in straight lines, so they cut across
bulkheads. The fix was data. The owner supplied a new plate with a full corridor
network and a yellow guidance stripe painted down every corridor specifically so
it could be traced, and it was: thirteen compartments as polygons, nine
waypoints on the stripe, and a door tapping each compartment onto the graph.
`ui/corridor_map.gd` expands each room hop into that polyline; `sim/` still asks
for a chain of rooms and knows nothing about geometry.

Checked by looking, not by reasoning: a walk from turret control to the hold was
captured frame by frame, and every corridor point of all 78 room-to-room routes
was tested against the bulkheads in the art. None crosses one.

Rooms also gained a `capacity` and `sim/` now refuses a move into a full
compartment and logs the refusal.

**Reported, not tuned: 42.4s for both plans**, up from 39.4s, end HP unchanged
at [100 ×5] hack and [75 ×5] fight. The whole difference is one transit. On the
old six-room plate turret control was three hops from the hold; on this one it
is four. Nothing was retuned to hide that and nothing should be.

## Travel costs distance — 2026-08-16

Also not a render pass. The corridor work left two things wrong, both reported
from play: crew ducked *into* every room on the way past, and a move next door
cost the same three seconds as a move the length of the ship.

Both came from the same cause — movement was modelled room-to-room. Adjacency is
now what the ship actually is: **every compartment that opens onto the corridor
is adjacent to every other**, because you never pass through a room to reach
another one, you walk down the corridor. Life support is the single exception,
opening only into the reactor.

That alone would have made the ship meaningless, since every trip becomes one
hop. So transit is no longer a flat fee: it is **distance divided by speed**,
with the distance measured along the corridor polyline at trace time and stored
in `ship_layout.json` as a plain number. `sim/` divides and never reads a
coordinate, which is the rule that let the whole ship be replaced without the
simulation noticing.

**The speed was carried forward, not invented.** 103 px/s is the old six-room
ship's average hop (309 px) at its authored 3.0 s. The pace the game had is the
pace it still has; what changed is that the pace now applies to a distance.

Travel now ranges from 4.4 s across the corridor to 13.2 s bow to stern. Speed
is read per crew member, so armour can slow someone down later without touching
this again.

**Reported, not tuned: 40.3s for both plans**, down from 42.4s, end HP unchanged.
Turret control to the hold is one continuous 1034 px walk — 10.0 s — where the
hop model charged 12 s for four hops.

## Crew who walk — 2026-08-16

The Kenney crew were replaced. Every crew member, TOCK included, is now the
Silver Soldier, separated by class colour: amber commander, red soldier, green
engineer, blue pilot, pink medic, cyan synthetic. Enemies will use the same
figure in greys when there are enemies.

**The model ships no walk cycle**, despite the filename. Measured in
`ASSETS.md`: its one 12.72 s clip is a weapon-handling loop and the feet never
move. What it does have is a clean 211-bone rig, so the walk is authored on it
in `tools/render_soldier.gd` and baked to the same sheet format the game already
read. No new runtime cost: three PNGs, about 650 KB.

TOCK loses his robot chassis for now. That is the owner's call — an android who
walks beats a robot who glides, and this is the only model in the project that
can move.

Reported, not tuned: **40.3s**, unchanged. Art does not touch the simulation.

## Still open

Crew art is Kenney cartoon, not grimdark. TOCK is a human model with a cold
tint. There is no UI chrome, no fire, no damage, no enemy ship.

## Slice 0 — "The Cargo Hold"  ✅ DONE

The first playable thing. One situation, one decision, no combat.

Boarders took the ship and left the crew restrained in the hold. TOCK was
DISABLED in the fight, so they left him where he fell — which is why he is the
only one loose. He reboots, states the situation, and proposes two ways out:
cut the boarders' suit oxygen, or take the weapons cached in the hold and fight.

- 6 rooms drawn top-down as one connected hull, from `data/ship_layout.json`.
  Walls carry a door exactly where the adjacency list says two rooms connect.
- 5 crew TIED in the cargo hold. Click any reachable room and TOCK walks the
  whole route through the rooms between; click a captive to cut them loose.
- Two plans with genuinely different outcomes. Hack: nobody aboard is hurt.
  Fight: everyone ends at 75 HP, including the people who were still tied,
  because a firefight in the hold does not care who is restrained.
- `SPACE` pauses. The sim owns `time_scale`; `get_tree().paused` is never used.
- Every state change writes a structured `LogEvent`. The UI formats them; in
  v0.4 the bark system subscribes to the same stream with no sim changes.
- **No fail state.** Damage floors at 1 HP. Nobody dies in this scene.

**Done when:** a human can launch it, pick a plan, route TOCK to the hold, free
all five, and reach the end screen without touching the console. ✅

Reported, not tuned: both plans resolve in **42.4s** of simulated time under
random-legal play — 39.4s until the ship was replaced on 2026-08-16, when turret
control went from three hops from the hold to four. The difference between them is entirely moral and entirely
in the HP column, which is the intended shape.

## Slice 1 — Mission 2: the boarders' ship attacks (target: 30 min)

The smallest combat that is genuinely playable. One fight, nothing else.

- Player ship: `hull = 30`. Enemy ship: `hull = 15`, evasion 0%.
- One player weapon: charge 8.0s, 1 damage. Fires automatically when charged
  at the currently selected enemy room.
- Enemy has one weapon: 1 damage every 9.0s, hits a random player room
  (rooms exist as clickable boxes only — no systems behind them yet).
- 4 rooms per ship, drawn as labelled `ColorRect`s. Click an enemy room to
  select it as the target; it highlights.
- `SPACE` toggles pause. The game **starts paused**. A visible "PAUSED"
  label. Weapon charge bars must visibly stop when paused.
- Enemy hull 0 → "VICTORY" screen. Player hull 0 → "DESTROYED" screen.
  Both have a RESTART button.

**Done when:** a human can launch it, unpause, watch bars fill, click a target,
and reach either end screen without touching the console.

## Slice 2 — Power and shields (target: 25 min)

- Reactor with 6 power bars, `+`/`−` buttons per system.
- Systems: Shields, Engines, Weapons (Medbay deferred).
- Shields: 1 layer per 2 power, max 2, recharge 1 layer / 4.0s.
  Each layer absorbs 1 damage.
- Engines: +5% evasion per power bar, max 15%. Applies to incoming shots.
- Second weapon: Burst Laser, 2 power, charge 11.0s, 2 shots × 1 damage.
- Weapons only charge if their power cost is covered.
- Enemy gets 1 shield layer.

## Slice 3 — Crew and system damage (target: 25 min)

- 3 crew: Smith, Vasquez, Okonkwo. HP 100. Assign by clicking crew, then room.
  Crew teleport instantly — no pathfinding.
- Damage that gets through shields: −1 hull AND +1 damage to that room's
  system (0–3, at 3 the system is offline). Crew in the room take 15 damage.
- Crew in a damaged room repair 1 damage point per 4.0s.
- Crew in an undamaged room man it: +10% to that system's effect.
- Crew death at 0 HP. Permanent in v0.1. Must not crash.

**Crew XP is not in this slice.** It was listed here originally, but
`GAME_SPEC v0.1` does not mention XP and `GAME_SPEC v0.2 §5` introduces it as
new. XP is the first mechanic that makes a *specific* crew member
irreplaceable, which is what v0.2 is for. v0.1's job is to prove the loop is
fun with interchangeable crew.

## Slice 4 — The run (target: 25 min)

- The 5 hardcoded encounters from the spec, in order.
- Jump screen between encounters: repair 15 scrap → +5 hull,
  upgrade 30 scrap → +1 reactor. Then JUMP.
- The two text events with their choices.
- End screens report jump number, hull, scrap, crew alive.

## Slice 5 — Harness  ◐ PARTLY DONE

`tools/sim_runner.gd` exists and runs, pulled forward from last place because
slices with no harness have nothing but the boot check to catch regressions —
see `BUILD_PLAN.md`. It currently drives the rescue scene and asserts that both
plans resolve, every captive ends ACTIVE above 0 HP, both boarders go down, and
identical seeds produce identical runs.

Still to do, once combat exists:
- Random legal play rather than the scripted competent route
- Win rate, and the seed of any crashing run
- Target win rate 5–40%. Report the number; do not silently retune.

---

## Deferred to v0.2 (do not build)

Clone Bay · boarding · equipment slots · commander abilities · Medbay ·
branching sector map · fire · breaches · oxygen · shops · procedural events ·
save/load · art · audio

---

## Rules for an agent running unattended

_Folded in from `BUILD_PLAN.md`._

1. **Commit at every green checkpoint** — one slice per commit, per `CLAUDE.md`.
   An uncommitted context overflow loses hours.
2. **Never weaken a test to make it pass.** Converting a failing assertion into a
   skip, widening a tolerance, or deleting a case is the documented way these
   runs go wrong. If a test is wrong, say so; do not silently adjust it.
3. **Report `[PLAY-GATED]` numbers, never tune them.**
4. **Stop at the slice boundary**, even with context left.
5. **If the spec is ambiguous, stop and ask.** Do not invent a workaround for
   something a human can settle in one sentence.
