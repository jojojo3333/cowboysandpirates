# CLAUDE.md — working agreement

Read this before touching anything. It is short on purpose.

## What this is

A real-time-with-pause roguelike in the FTL lineage. Godot 4.7, GDScript.
Setting is `SETTING.md`: Sol in 2100, a gold rush, no aliens and no FTL.
You command a small ship and six people, and the entire design goal is that
losing one of them costs you something.

## Engine

**Godot 4.7 stable, pinned.** `tools/setup_godot.sh` fetches it to
`.godot-bin/` (gitignored). Do not upgrade the pin casually — `tools/verify.sh`
and the v0.3 agent tooling both key off 4.7.

The container has no GPU. Godot renders 2D over software rasterisation, which
is fine for correctness and useless for judging feel. **Never conclude from a
container screenshot that something feels good.** Correctness is machine-checkable
here; feel is not, and pretending otherwise is the main way this project can go
wrong.

## The two verify commands

`GAME_SPEC_v0.2 §10.1` requires both to be green. They are:

```
tools/verify.sh static     # parses, imports, and validates data
tools/verify.sh sim        # headless test suite + 500-run balance report
```

`static` proves the project loads: every GDScript parses, the project imports
without error, and every file in `data/` matches the contract its consumer
expects. `sim` proves the game works: the test suite in `tests/` passes, and
`sim/sim_runner.gd` completes 500 headless games with zero crashes and prints
the metrics `GAME_SPEC_v0.2 §10.9` asks for.

`tools/verify.sh` with no argument runs both. **A change is not done until both
are green.** If a test is inconvenient, fix the code — do not weaken the test,
skip it, or widen a tolerance to make it pass. That specific failure mode is why
this paragraph exists.

## Architectural rules that outrank convenience

These are not style preferences. Breaking any of them costs a rewrite later,
and each one is load-bearing for a version that has not been built yet.

1. **`sim/` never imports from `ui/`.** The simulation runs headless with no
   scene tree attached. This is what makes 500-run balance testing possible and
   it is the reason the two-phase build below works at all.
2. **The log emits structured events, never formatted strings.** `sim/` pushes
   objects with `type`, `severity`, `subjects`, `values`. `ui/` turns them into
   text. See `GAME_SPEC_v0.2 §7a` and `VOICE_AND_EVENTS.md §6` — TOCK's voice
   system subscribes to this same stream in v0.4, and strings here mean rewriting
   every call site then.
3. **No class logic in GDScript.** Classes live in `data/classes.json`. Adding a
   seventh class must require editing JSON only — that is acceptance criterion 7
   and it is tested, not assumed.
4. **No visual-only state changes.** If it matters, it writes a log line. This
   outranks aesthetics permanently, including after the art pass.
5. **`[PLAY-GATED]` values are placeholders, not decisions.** Build them as
   written, expose them in `data/`, move on. Do not tune them because a sim run
   looked off — report the number and stop.

## Document map

| File | Version | Status |
|------|---------|--------|
| `GAME_SPEC_v0.1.md` | v0.1 | **Reconstructed. Unconfirmed — see its header.** |
| `GAME_SPEC_v0.2.md` | v0.2 | Authoritative. The current build target. |
| `SETTING.md` | v0.3 | Written early so `data/` is regionally organised and §6 is settled. |
| `VOICE_AND_EVENTS.md` | v0.4 | Written early. **Only §6 is built now.** |
| `ARCHITECTURE.md` | — | How `sim/` and `ui/` divide. Read before adding a file. |
| `BUILD_PLAN.md` | — | The two build phases and what each must prove. |

When two documents disagree, the lower version number wins for anything already
built, and `GAME_SPEC_v0.2.md` wins for anything being built now. Later-version
documents are constraints on the future, not licences to build ahead.

## Scope discipline

`GAME_SPEC_v0.2 §3` is a list of things that must not be built. It is not
advisory. No map, no stations, no second currency, no boarding, no hacking, no
Heat, no save/load, no art, no audio. The Soldier is deliberately the weakest
class and the Medic is deliberately near-useless alongside a Clone Bay. **Both
are correct. Do not invent compensating mechanics.**

If you finish early, the answer is more tests, not more features.
