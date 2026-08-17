# CLAUDE.md — working agreement

Read this, then the top of `SLICE.md`, before doing anything. `BACKLOG.md`
is the queue of everything known to be missing or wanted — and it is the **only**
file that holds one. Do not start a second.

## What this is

A real-time-with-pause roguelike in the Void War lineage. Godot 4.7, GDScript.
Working title **Deadweight**. Setting is `SETTING.md`: Sol in 2100, a gold rush,
no aliens and no FTL. You command a small ship and a crew, and the whole design
goal is that losing one of them costs you something.

Slice 0 ships and three render passes are done. `SLICE.md` has the current
slice at the top and the state of the art pipeline below it.

### The visual reference is Void War, not FTL

**Void War** (Tundra, two people plus a contract artist) is the look and tone we
are aiming at: dark techno-gothic, low saturation, heavy hull detail. It is not
"pretty" and players have complained it is hard to read because it is so
monotone — both true, and still closer to what this project wants than FTL's
bright primaries.

"FTL" survives in these documents in four places only, where a verifiable fact
about that specific game is being cited and swapping the name would make the
sentence false:

- `CLAUDE.md` above — **"no FTL" there means faster-than-light travel**, the
  setting rule. It is not a reference to the game at all.
- `VOICE_AND_EVENTS.md §1` — FTL's sales record is the evidence for the
  no-plot argument. Void War is a 2024 indie and cannot carry that claim.
- `GAME_SPEC v0.2 §1` — inside a quoted reviewer comparison *of* Void War *to*
  FTL. Editing a quotation is not a rename.
- `SETTING.md §4` — FTL's ship-unlock structure is the documented mechanic
  being borrowed. Whether Void War unlocks ships the same way is unverified.

Everywhere else — projection, room scale, silhouette, palette — the reference
is Void War.

## Slice discipline — the most important rule

We build in slices. **Every slice ends with a running, clickable game.** Never
leave the project in a state where `godot --path .` does not launch something
playable. A half-finished system that breaks the build is worse than no system.

The current slice is at the top of `SLICE.md`. Build only that slice. Do not
start the next one without being asked.

## How this project is built

None of this is a prohibition. Earlier versions of this file carried a list of
hard constraints — one scene only, never create a `.tscn`, no addons, the ship
is drawn in `_draw()`. They cost the project two render passes and a rewrite,
because they encoded a pipeline none of the reference games use, written before
anyone had checked how those games are actually made. They are gone.

What is left is a short list of things that are true, with the reason attached.
Where a reason stops applying, change the practice.

**Use the whole engine.** `.tscn` scenes, the editor, `TileMap`, `PointLight2D`,
`CanvasModulate`, normal maps, `GPUParticles2D`, `ShaderMaterial`,
`AnimatedSprite2D`, `Tween`, addons, plugins — all available, all fair game. The
project spent a long time calling `draw_rect` in a corner while the engine sat
unused next to it. If Godot has a feature for the problem, use the feature.

**The ship is art; code draws state.** Hull, compartment floors, bulkheads and
doors come from a ship plate (`ASSETS.md`). Code draws what changes: selection,
crew, doors, fire, breach, targeting, route, damage. The test — if it would look
identical in a paused screenshot with nothing selected, it belongs in the plate.
This is not a restriction, it is where the quality comes from: FTL and Void War
both work this way, and drawing a hull from polygons has a ceiling that more
polygons do not raise.

**Static typing.** `var hull: int = 30`, `func fire() -> void:`. Not a style
preference — Godot 4.7 treats several type-inference warnings as errors, so
untyped code fails `verify static`.

**`sim/` holds no Node or scene API.** Plain `RefCounted` classes over data.
This is the reason the entire renderer could be thrown away and rebuilt twice
without the simulation noticing, and why the balance report read 39.4s through
every one of those rewrites. It is worth keeping for that alone. It reads 40.3s
since 2026-08-16, when the ship was replaced and travel started costing distance
rather than a flat fee per room — both content changes, not render passes, and
both *supposed* to move the number.

**One seeded RNG** in `sim/rng.gd`. Global `randi()`/`randf()` make runs
unreproducible, which breaks the balance harness.

**Balance numbers live in `data/*.json`**, classes in `data/classes.json`.

**If it matters, it writes a log line.** State the player needs must not be
carried by colour or animation alone. This is the game's spine, not decoration:
the log is what makes a real-time-with-pause game readable, and `VOICE_AND_EVENTS`
§6 subscribes to the same stream.

## Godot 4 gotchas — these have cost real time before

- **Godot 4 signal syntax only:** `button.pressed.connect(_on_pressed)`.
  Never `connect("pressed", self, "_on_pressed")` — that is Godot 3 and fails.
- **No `yield`** — use `await`. No `KinematicBody`, no `PoolStringArray`,
  no `OS.get_ticks_msec()` for gameplay timing.
- **Never use `get_tree().paused` for the game pause.** It freezes UI input too.
  The sim owns `time_scale: float` (0.0 or 1.0) and every tick uses
  `delta * time_scale`. `_process` keeps running; the simulation does not.
- **Every UI node must be inside a container or have an explicit
  `position` + `custom_minimum_size`.** Free-floating Controls default to
  zero size at (0,0) and become invisible. This is the #1 cause of
  "the game runs but the screen is empty".
- **Indentation is tabs**, not spaces. Mixed indentation is a parse error.
- `class_name` must be globally unique across the project.

## Engine and environment

**Godot 4.7 stable, pinned.** `tools/setup_godot.sh` fetches it to `.godot-bin/`
(gitignored). The original prototype targeted 4.3; 4.7 is stricter about typing
and is what the v0.3 agent tooling needs.

CI containers have no GPU, so Godot renders 2D over software rasterisation.
That is enough for correctness and useless for judging feel. **Never conclude
from a headless screenshot that something feels good.** Correctness is
machine-checkable; feel is not, and pretending otherwise is the main way this
project can go wrong.

## Verify after every change — run these yourself, do not ask

```
tools/verify.sh rules      # the house rules, as checks instead of prose
tools/verify.sh static     # parses, imports, and validates data
tools/verify.sh sim        # headless test suite + balance report
tools/verify.sh play       # the assembled game, played through and asserted
tools/verify.sh            # all four
```

**`play` is the one that sees the game the player sees.** `sim` runs the
simulation with no UI attached — which is why it survived two renderer rewrites,
and equally why it cannot see a crew member drawn outside the compartment they
are standing in, or a panel that resolved to the wrong size. `tools/play.gd`
presses the real buttons, steps the clock by hand at a fixed 1/30 s, and asserts
through `tools/game_probe.gd`. `ARCHITECTURE.md 5b` explains the split; the short
version is **ask the running game what is true, do not infer it from pixels**.

**A check that cannot fail is worth nothing.** Every assertion in `play.gd` and
every rule in `check_rules.py` was run against a deliberately broken build before
being kept. This is not ceremony: two of the first three attempts silently passed
on a genuinely broken game, and one of them was passing on layout numbers that
were meaningless because headless Godot had not laid the UI out. Break it on
purpose, watch it go red, then put it back.

**`rules` exists because this document does not work on its own.** Everything it
checks was already written down here, and several were broken anyway — a rule in
a document is something a reader might remember, and a rule in a check is
something that stops them. It caught three latent instances of the
invisible-Control bug in `main.gd` the first time it ran.

**When a rule is agreed, add it to `tools/check_rules.py` in the same breath as
writing it down.** A rule that exists only as prose will be followed until it is
inconvenient. If a check turns out to be wrong, argue with it and change it — do
not weaken it to get a green.

These are the two commands `GAME_SPEC v0.2 §10.1` requires to be green. Under
the hood `static` is the `godot --headless --quit` boot check plus the data
contract validator; you do not need to run the raw command or read `run.log`
yourself, because `verify.sh` greps for `SCRIPT ERROR` / `Parse Error` and fails
on them. Godot exits 0 on script parse errors, so the output must be inspected
rather than trusted — that is what the script does.

**A change is not done until both are green.** If a test is inconvenient, fix
the code — do not weaken the test, skip it, or widen a tolerance to make it
pass. If a test is genuinely wrong, say so and explain why; do not silently
adjust it. **If you cannot run the command, say so plainly instead of assuming
it passed.**

## Document map

| File | What it is |
|------|------------|
| `BACKLOG.md` | **What is next.** The one ordered queue, plus the briefs for work done outside this repo. |
| `SLICE.md` | Build order, current slice at the top, render passes below |
| `GAME_SPEC.md` | Design spec, v0.1 and v0.2 in one file |
| `SYSTEMS.md` | **What the game can do.** Built, half built, known missing. Not a queue. |
| `MISSION_01.md` | What mission 1 is, and everything building it requires. Not a queue. |
| `ARCHITECTURE.md` | How `sim/` and `ui/` divide |
| `ASSETS.md` | Every imported file, the ship plate spec, the render pipeline |
| `SETTING.md` | Sol in 2100 — regions, factions, tone |
| `VOICE_AND_EVENTS.md` | Writing and event structure. Only §6 is built. |
| `world/` | **The owner's folder.** Storyboard, crew, missions, world. Prose in, JSON out — never the reverse without saying so. |
| `assets/` | **The shared drop.** Art goes in, gets recorded in `ASSETS.md`, gets wired up. |

`GAME_SPEC_v0.1.md`, `GAME_SPEC_v0.2.md` and `BUILD_PLAN.md` were merged away —
they had grown overlapping goals, non-goals, determinism and acceptance
sections that drifted apart.

## Scope discipline

**`GAME_SPEC.md`'s "not in this version" lists are retired, 2026-08-17.** They
were written in the first hour, before anything had been tried, and the project
has stepped over them repeatedly and correctly — crew pathfinding, then
boarding, enemy crew and story, all of which mission 1 needs. A prohibition
everyone ignores is worse than none, because it teaches the reader to skip the
file. The document is being remade; `BACKLOG.md` holds that item.

**What survives, until it is dropped on purpose.** Two entries in there are
real design rather than stale scope-marking, and they exist to stop power creep:
the Soldier is deliberately the weakest class, and the Medic is deliberately
near-useless alongside a Clone Bay. **Do not invent compensating mechanics.**
Change them by deciding to, not by forgetting they were deliberate.

Retiring a list of non-goals is not licence to build whatever. The rule that
replaces it is simpler and harder: **build the thing that was asked for.** If
the shape of a feature is ambiguous, ask. If you finish a slice early, the
answer is more tests, not more features.

## Working style

- Plan first, in plan mode. No code until the plan is approved.
- One slice per commit. Commit as soon as the slice runs and verify is green.
- Prefer boring, obvious code. This is a prototype that will be rewritten.
- Report `[PLAY-GATED]` numbers, never tune them. If the sim says the win rate
  is 4%, that is the deliverable.
