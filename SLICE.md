# SLICE.md

**CURRENT SLICE: 1**

Slice 0 is done. The slices below were renumbered when the cargo hold rescue
became the first playable thing — what was slice 0 is now slice 1, and so on.

Build only the current slice. When it runs and is committed, stop and wait.

**One mission, not a chain.** The immediate target is a single combat that a
human can play start to finish. The encounter chain — five in `GAME_SPEC_v0.1
§5`, six in `GAME_SPEC_v0.2 §8` — is deferred, and its length is an open number
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
after.

## Where the ship art has to come from

**Finding: the current approach does not reach the Void War look, and the reason
is structural rather than a matter of effort.** This was checked rather than
assumed, after a human compared our hull to Void War's and said ours still looks
like it was built in a 2D shape program. That diagnosis is correct.

### What the reference games actually do

- **Void War** is made by Tundra, a two-person studio, *plus contractors —
  including an additional artist*. That hull is authored pixel art, paid for.
- **FTL** ships are a hand-drawn `ship_base` PNG for the hull plus one authored
  PNG per interior room (`room_weapons_8.png` and so on), positioned by a
  layout file. Modders either fit their layout to existing room images or draw
  new ones. **The art comes first; the data describes the art.**
- **Cosmoteer** is the exception that shows the middle path: every ship is
  assembled procedurally from *hand-drawn modules* on a grid, 64×64 pixels per
  1×1 tile. The assembly is code. The density is art.

Ours is inverted: `ship_layout.json` drives `_draw()` primitives, which produce
the picture. That is the one arrangement none of the three reference games use.

### Why more primitives will not close the gap

Not because of polygon count. Because of information. A Void War hull carries
thousands of individually decided pixels. Procedural code derives detail from a
handful of parameters, and rules produce regularity, which the eye reads as
machine-made. Adding greebles procedurally makes the render *busier*, not more
authored — and "procedurally greebled" is its own recognisable look, worse than
clean geometry. RENDER PASS 1 took the primitive approach roughly as far as it
goes; the remaining distance is not more of the same.

### Two separate problems, not one

1. **The grid.** Rooms are a uniform 3×2 block of identical rectangles. FTL's
   unit cell is 35×35 px and rooms are variable multiples of it — 1×1, 2×1, 2×2
   — which is most of why its ships look built rather than tabulated. Our layout
   format has no room width or height at all. **This is a data problem and it is
   independent of where art comes from.** Fixing it costs no assets.
2. **The marks.** Primitives instead of authored tiles. This is the art problem.

Fixing 2 without fixing 1 buys detailed tiles arranged in a spreadsheet.

### The three routes, and the recommendation

| | Route | Result | Cost |
|---|---|---|---|
| A | One authored hull PNG per ship, FTL-style | Best. What the references do. | An artist, or a CC0 find that does not appear to exist |
| B | **Modular authored tiles, assembled by code, Cosmoteer-style** | Close. Density from art, variety from code | ~30–40 tiles, once |
| C | Render tiles from CC0 3D kits | Feeds B without an artist | Tooling; style is Kenney-clean, not grimdark |

**Recommended: B, fed initially by C or by a bought tileset.** It fits what
already exists — the layout, geometry, lighting and composition work from RENDER
PASS 1 all survive; only "what gets drawn per cell" changes from primitives to
textures. The tile set is small and finite: floor variants, wall straight and
corner and end, door, hull edge straight and corner and nose and stern, plus one
interior per system.

Route A is worth noting is *not* available off the shelf. The large CC0
spaceship packs — Wisedawn's 211 sprites, generated with Vesselforge from
Kenney's spaceship parts — are **exterior** ships seen from outside. An
FTL-style cutaway interior is a different and much rarer asset.

### The open decision

Where the tiles come from: bought (grimdark modular sci-fi interior tilesets
exist on itch for roughly the price of a coffee), commissioned, rendered from
3D, or generated. **Generated art is a rule conflict, not a free option** —
`CLAUDE.md` rule 2 requires CC0 with documented provenance, which model output
does not have. Changing that rule is the owner's call, not something to route
around quietly.

## RENDER PASS 1 — "It looked like a text adventure"  ✅ DONE

The ship view was six flat grey rectangles, a hairline outline and a triangle
for a nose, all inside a value range about 0.09–0.19 wide. A human called it
"an A4 sheet with a point on the front", which was accurate.

Nothing here is a new mechanic and nothing is clickable that was not clickable
before. All of it is in `ui/ship_view.gd`, plus one new data file.

- **A hull that is not the room block plus a margin.** Cut corners, a narrowed
  nose with a bridge module and a canopy, a tapered stern, and two full-length
  engine nacelles carried outside the body on struts. The nacelles are the load-
  bearing part: a wide, short hull cannot express length or direction on its
  own, and mass off the main axis is the one thing a rectangle cannot fake.
- **Space to sit in.** A deterministic starfield — hashed, not random, because
  `sim/rng.gd` owns the only RNG and a reseeding starfield would flicker — over
  a banded gradient, with one dust cloud and a vignette.
- **Lit interiors.** Room floors are now *lighter* than the hull around them,
  which is what makes them read as decks with the lights on. They were darker,
  which read as holes cut in a diagram. Plus a floor panel grid and a bevel lit
  from one direction.
- **Walls with thickness**, 8px with a lit edge and a dark edge, and doors as a
  recess with two leaves and a lit threshold. 2px lines are a floor plan.
- **The whole ordered route** drawn as a crawling dashed line to a pulsing
  destination ring, instead of one straight segment to the next room.
- **Furniture**, from `data/room_props.json` — see the next section.
- Crew markers get a cast shadow, a shaded disc and a plate behind the name,
  which small text needs once the floor underneath it has texture.

**Reported, not tuned:** the balance report is unchanged at 39.4s for both
plans, with end HP [100 ×5] for hack and [75 ×5] for fight.

**Not done, and deliberately:** crew are still coloured discs. Sprites for them
are a later pass — see `ASSETS.md` for how they get rendered when that happens.

### Props are data, and only Medbay has any

`data/room_props.json` places furniture by fractions of the room rectangle, so
props keep their position and proportion at any window size. It is **decoration
only**: nothing in it is clickable, `sim/` never reads it, and an empty prop list
is the normal case. That is why it is a separate file from `ship_layout.json`,
which is what the simulation treats as truth.

Only Medbay is furnished, on purpose — one room is enough to judge whether
imported art and drawn geometry can share a screen before three sprites become
thirty. `tools/validate_data.gd` fails the build if a prop names a room that
does not exist, a sprite file that is not in `assets/props/`, or a coordinate
outside 0..1.

**The open question this pass exists to answer:** Kenney's station kit is bright,
clean and pastel; Deadweight is Sol in 2100 and worn out. The props are
modulated toward the ship's palette by one constant, `COL_PROP` in
`ui/ship_view.gd`. Whether that is enough, or whether the styles simply do not
belong together, is a judgement call for a human looking at the screen — a
headless screenshot cannot answer it, per `CLAUDE.md`.

---

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

Reported, not tuned: both plans resolve in **39.4s** of simulated time under
random-legal play. The difference between them is entirely moral and entirely
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
`GAME_SPEC_v0.1` does not mention XP and `GAME_SPEC_v0.2 §5` introduces it as
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
