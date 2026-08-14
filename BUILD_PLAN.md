# BUILD_PLAN.md

How this gets built: two autonomous phases with one human checkpoint between
them. Written down because the failure mode of long agent runs is trying to
build everything at once and running out of context halfway.

---

## Why two phases and not one

The specs are unusually well suited to autonomous work, for a reason that was
probably not deliberate: **`GAME_SPEC_v0.2 §10` is a verification contract.**
Nine of its ten acceptance criteria are machine-checkable.

| # | Criterion | Checkable headless? |
|---|-----------|---------------------|
| 1 | Both verify commands green | ✅ |
| 2 | A human can complete a full 6-combat run | ❌ **human** |
| 3 | Downed → revived → later dies permanently | ✅ |
| 4 | Cloning resets XP and writes a critical log line | ✅ |
| 5 | Fire destroys a system if ignored, extinguishes if answered | ✅ |
| 6 | TOCK repairable by Vela and nobody else | ✅ |
| 7 | Seventh class requires JSON only | ✅ |
| 8 | Nothing communicated by colour or animation alone | ✅ ¹ |
| 9 | 500 games, zero crashes, five metrics reported | ✅ |
| 10 | Win rate 15–35%, reported not retuned | ✅ |

¹ Checkable as written, because the rule reduces to "every state change emits a
`LogEvent`" — assert the event stream contains one per state transition.

An agent can therefore prove nine of ten to itself and iterate without a human
in the loop. **Criterion 2 is the checkpoint, and it is the whole reason there
are two phases rather than one.** No amount of green tests establishes that the
game is worth playing.

## What the container can and cannot judge

Godot 4.7 runs headless here over software rasterisation. That is enough to
prove correctness and nowhere near enough to judge feel: framerate is not
representative, and no screenshot answers whether a fight is tense.

**Correctness is delegated. Feel is not delegable.** Every phase boundary below
sits exactly on that line.

---

## Phase 1 — v0.1, "The Loop"

**Target:** `GAME_SPEC_v0.1.md`. Ends playable.

Deliverables:
- All of `sim/` for v0.1: ship, systems, power, shields, evasion, weapons,
  charge, hit resolution, crew manning and repair, enemy AI, encounter chain
- `data/ship_layout.json`, `data/enemies.json`
- Minimal `ui/`: grey rectangles, power bars, crew dots, target selection,
  jump screen. **No art. The spec forbids it and it would be thrown away.**
- `tests/` covering the sim, and `sim/sim_runner.gd` with seed reproducibility
- `tools/verify.sh` green on both commands

Exit condition: **a human plays five encounters end to end.**

**Blocked on:** the four open questions in `GAME_SPEC_v0.1.md §6`. They are
structural, and guessing wrong means rebuilding the ship model in Phase 2.

### Checkpoint — the only part that needs you

After Phase 1, play it and answer three things. Nothing else is asked of you.

1. Is the fight interesting with no crew layer at all? If not, v0.2 will not
   save it — the crew layer amplifies a good fight and cannot manufacture one.
2. The `[PLAY-GATED]` numbers: which are wrong, and in which direction? Direction
   is enough. Do not supply values.
3. Are five encounters too many or too few for one sitting?

## Phase 2 — v0.2, "The Crew Layer"

**Target:** `GAME_SPEC_v0.2.md`, which is authoritative and needs no
reconstruction.

Deliverables:
- Classes from `data/classes.json`, zero class logic in GDScript
- Crew states: ACTIVE / DOWNED / DEAD, and ACTIVE / DISABLED / DESTROYED
- Per-system crew XP, and its destruction by cloning
- The medical slot: Medbay **or** Clone Bay, `F1` to toggle in dev
- Fire: ignition, spread over adjacency, crew damage, extinguishing
- The structured combat log — `LogEvent` from day one, never strings
- Encounters 5 → 6
- Balance report split by medical loadout and by TOCK survival (§9)

Exit condition: all ten acceptance criteria, with criterion 2 verified by you.

## Not in either phase

`SETTING.md` is a v0.3 document and `VOICE_AND_EVENTS.md` is a v0.4 document.
They are in the repo as constraints, not as work. **Only `VOICE_AND_EVENTS.md §6`
is built now** — structured log events — and it is folded into Phase 2 where it
belongs rather than being a phase of its own.

Nothing in `GAME_SPEC_v0.2 §3` gets built early because it seemed easy.

---

## Rules for the agent running a phase

1. **Commit at every green checkpoint.** A phase is hours of work; an
   uncommitted context overflow loses all of it. Commit when both verify
   commands pass, every time, with a message naming what now works.
2. **Never weaken a test to make it pass.** Converting a failing assertion into
   a skip, widening a tolerance, or deleting a case is the documented way these
   runs go wrong. If a test is wrong, say so in the commit message and explain
   why — do not silently adjust it.
3. **Report `[PLAY-GATED]` numbers, never tune them.** If the 500-run report
   says the win rate is 4%, that is the deliverable. Retuning quietly destroys
   the only signal the checkpoint has.
4. **Stop at the phase boundary.** Do not start Phase 2 because Phase 1 finished
   early and the context still has room.
5. **If an inference in `GAME_SPEC_v0.1.md` turns out to be unbuildable, stop and
   say so.** Do not invent a workaround for a spec that a human can correct in
   one sentence.
