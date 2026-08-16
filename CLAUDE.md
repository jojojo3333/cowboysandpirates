# CLAUDE.md — working agreement

Read this, then the top of `SLICE.md`, before doing anything.

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
without the simulation noticing, and why the balance report has read 39.4s
through every one of those rewrites. It is worth keeping for that alone.

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
tools/verify.sh static     # parses, imports, and validates data
tools/verify.sh sim        # headless test suite + balance report
tools/verify.sh            # both
```

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
| `NEXT_SESSION.md` | What the next session does. Delete it once done. |
| `SLICE.md` | Build order, current slice at the top, render passes below |
| `GAME_SPEC.md` | Design spec, v0.1 and v0.2 in one file |
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

`GAME_SPEC v0.1 §2` and `GAME_SPEC v0.2 §3` are lists of things that must not be
built. They are not advisory. From v0.2: the Soldier is deliberately the weakest
class and the Medic is deliberately near-useless alongside a Clone Bay. **Both
are correct. Do not invent compensating mechanics.**

If the spec is ambiguous, ask. Do not invent mechanics — check the Non-Goals
list first. If you finish a slice early, the answer is more tests, not more
features.

## Working style

- Plan first, in plan mode. No code until the plan is approved.
- One slice per commit. Commit as soon as the slice runs and verify is green.
- Prefer boring, obvious code. This is a prototype that will be rewritten.
- Report `[PLAY-GATED]` numbers, never tune them. If the sim says the win rate
  is 4%, that is the deliverable.
