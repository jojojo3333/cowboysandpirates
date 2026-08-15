# CLAUDE.md — working agreement

Read this, then `GAME_SPEC_v0.1.md`, then the top of `SLICE.md`, before doing
anything.

## What this is

A real-time-with-pause roguelike in the Void War lineage. Godot 4.7, GDScript.
Working title **Deadweight**. Setting is `SETTING.md`: Sol in 2100, a gold rush,
no aliens and no FTL. You command a small ship and a crew, and the whole design
goal is that losing one of them costs you something.

Nothing is built yet. `SLICE.md` says **CURRENT SLICE: 0**.

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
- `GAME_SPEC_v0.2 §1` — inside a quoted reviewer comparison *of* Void War *to*
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

## Hard constraints — violating these breaks the build

1. **One scene only.** `main.tscn` holds a single `Control` node named `Main`
   with `main.gd` attached. **Never create or hand-edit another `.tscn`.**
   All UI nodes are constructed in GDScript at runtime.
2. **No addons and no plugins.** For UI chrome — panels, buttons, the log —
   `ColorRect`, `Label`, `Button`, `ProgressBar`, `VBoxContainer`,
   `HBoxContainer`, `PanelContainer`, `GridContainer`, `MarginContainer`,
   `ScrollContainer`. The ship itself is drawn: a `Control` with `_draw()`,
   plus `Node2D`, `Polygon2D` and `Line2D` where they help.

   **Imported assets are allowed only under CC0, with documented provenance.**
   Every imported file gets an entry in `ASSETS.md` naming its source, its
   licence and the date it was fetched. No exceptions, including "just a
   placeholder we will swap later" — placeholder art is how unlicensed art
   ships. Assets extracted from another game are never acceptable regardless
   of licence claims.
3. **Static typing everywhere.** `var hull: int = 30`, `func fire() -> void:`.
   Godot 4.7 treats several type-inference warnings as errors, so this is not a
   style preference — untyped code fails `verify static`.
4. **Simulation and UI stay separate.** Files under `sim/` must not reference
   any Node, Control, or scene API — plain `RefCounted` classes over data.
5. **All balance numbers live in `data/*.json`.** No hardcoded stats in code.
6. **One RNG.** `sim/rng.gd` wraps a seeded `RandomNumberGenerator`.
   Global `randi()` / `randf()` are forbidden.
7. **No class logic in GDScript** (from v0.2). Classes live in
   `data/classes.json`; adding a seventh must require editing JSON only.
8. **No visual-only state changes** (from v0.2). If it matters, it writes a log
   line. This outranks aesthetics permanently, including after the art pass.

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

These are the two commands `GAME_SPEC_v0.2 §10.1` requires to be green. Under
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

| File | Version | Status |
|------|---------|--------|
| `SLICE.md` | v0.1 | The build order. Current slice at the top. |
| `GAME_SPEC_v0.1.md` | v0.1 | Authoritative. Nothing here is built yet. |
| `GAME_SPEC_v0.2.md` | v0.2 | Authoritative for v0.2. Not started. |
| `SETTING.md` | v0.3 | Written early so `data/` is regionally organised and §6 is settled. |
| `VOICE_AND_EVENTS.md` | v0.4 | Written early. **Only §6 is built, and only in v0.2.** |
| `ARCHITECTURE.md` | — | How `sim/` and `ui/` divide. Read before adding a file. |
| `BUILD_PLAN.md` | — | Phases, and the v0.1 → v0.2 deltas that need decisions. |

Later-version documents are constraints on the future, not licences to build
ahead. When two disagree about something already built, the lower version wins.

## Scope discipline

`GAME_SPEC_v0.1 §2` and `GAME_SPEC_v0.2 §3` are lists of things that must not be
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
