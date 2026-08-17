# Deadweight

A real-time-with-pause roguelike. Godot 4.7, GDScript. Sol in 2100, a gold rush,
no aliens and no faster-than-light travel. You command a small ship and a crew,
and the design goal is that losing one of them costs you something.

```
tools/setup_godot.sh                                  # once
.godot-bin/Godot_v4.7-stable_linux.x86_64 --path .    # play it
tools/verify.sh                                       # check it
```

---

## Which of these files are yours

**This is the map, and it is sorted by who needs it — not by topic.** There is
no need to read a file from the other column to understand your own.

### The owner's four

Everything about *what the game is*. Nothing in here is code.

| File | The question it answers |
|---|---|
| **`BACKLOG.md`** | **What happens next.** The only ordered queue in the project. Start here. |
| **`SYSTEMS.md`** | **What the game can already do**, what is half done, and what is known to be missing. |
| **`MISSION_01.md`** | What mission 1 is, beat by beat, and what building each beat costs. |
| **`SETTING.md`** + **`world/`** | The fiction. `world/` is the writing room and belongs to the owner outright — prose in, JSON out, never the reverse without saying so. |

### The builder's five

How it is made. Safe to ignore unless you are changing code.

| File | The question it answers |
|---|---|
| `CLAUDE.md` | The working agreement: house rules, Godot traps, what to run before calling anything done. |
| `ARCHITECTURE.md` | How `sim/` and `ui/` divide, and why that division is worth defending. |
| `ASSETS.md` | Where every imported file came from, and what a new one has to satisfy. |
| `VOICE_AND_EVENTS.md` | How the game is written — TOCK's rules, event structure. |
| `GAME_SPEC.md` | The rules of the game. **Being remade** — written in the first hour and overtaken; see `BACKLOG.md`. |

**Why not fewer files.** They were merged once already: `SLICE.md`,
`NEXT_SESSION.md`, `BUILD_PLAN.md` and two spec versions are gone, folded into
the files above. What is left divides cleanly by audience, and merging across
that line would mean the owner reading Godot trivia to find out what the game
does. Four files is a readable set; nine files with no map was not.

---

## The layout

```
sim/     the simulation. Plain data classes, no nodes, no scenes.
         Runs headless. If ui/ were deleted the game would still work.
ui/      the viewer. Draws what sim/ reports, turns clicks into calls back in.
data/    content and balance numbers as JSON. No logic.
assets/  art and audio. Everything here is recorded in ASSETS.md.
tools/   the checks, the renderers, the harnesses.
world/   the writing room.
```

## What "verify" means

Four commands, and a change is not done until all four are green.

| | |
|---|---|
| `tools/verify.sh rules` | The house rules, as executable checks rather than prose. |
| `tools/verify.sh static` | Every script parses; every data file satisfies its contract. |
| `tools/verify.sh sim` | The simulation, headless, played many times, reporting how long it takes. |
| `tools/verify.sh play` | The assembled game — real buttons, real mouse events, played to the end and asserted. |

**A check that cannot fail is worth nothing.** Every assertion here was run
against a deliberately broken build before being kept, because several of the
early ones passed on a genuinely broken game.
