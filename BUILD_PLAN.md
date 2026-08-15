# BUILD_PLAN.md

What gets built, in what order, and how the places where v0.1 and v0.2
contradict each other were settled.

---

## v0.1 — follow `SLICE.md`

`SLICE.md` is the build order and it is better than anything invented later:
five slices, each ending in a running clickable game, each with a time target.
**Do not replace it with a phase plan.** Slice 0 is the current slice.

The one thing worth adding: slices 0–3 are all human-verifiable only. The
machine-checkable harness is slice 4 (`tools/sim_runner.gd`), which is scheduled
last. That is the right order for a human building it, and the wrong order for
an agent building it unattended, because slices 0–3 then run with nothing but
the boot check to catch regressions.

**If v0.1 is built autonomously, pull slice 4 forward to slice 1.** A sim runner
that plays randomly needs no UI, and once it exists every later slice gets a
free regression check. If v0.1 is built with a human at the keyboard, leave the
order as written.

## v0.2 — two phases

`GAME_SPEC_v0.2 §10` is a verification contract, probably by accident. Nine of
its ten acceptance criteria are machine-checkable:

| # | Criterion | Headless? |
|---|-----------|-----------|
| 1 | Both verify commands green | ✅ |
| 2 | A human can complete a full 6-combat run | ❌ **human** |
| 3 | Downed → revived → later dies permanently | ✅ |
| 4 | Cloning resets XP and writes a critical log line | ✅ |
| 5 | Fire destroys a system if ignored, extinguishes if answered | ✅ |
| 6 | TOCK repairable by Vela and nobody else | ✅ |
| 7 | Seventh class requires JSON only | ✅ |
| 8 | Nothing communicated by colour or animation alone | ✅ ¹ |
| 9 | 500 games, zero crashes, five metrics | ✅ |
| 10 | Win rate 15–35%, reported not retuned | ✅ |

¹ Reduces to "every state change emits a `LogEvent`" — assert the event stream
contains one per state transition.

So an agent can prove nine of ten to itself. **Criterion 2 is the checkpoint.**
No amount of green tests establishes that the game is worth playing, and CI
containers render over software rasterisation, which is enough for correctness
and useless for judging feel.

Phase A: the sim layer — classes, crew states, XP, medical slot, fire, the
structured log. Phase B: the UI for all of it, plus the human run.

---

## v0.1 → v0.2 deltas

v0.2 was written without v0.1 in front of it, and it shows. Most of these are
ordinary version-to-version growth. Four points needed a call and all four are
now decided.

### Ordinary growth — no decision needed

| Thing | v0.1 | v0.2 |
|-------|------|------|
| Crew count | 3 | 6 |
| Crew names | Smith, Vasquez, Okonkwo (explicitly placeholder) | Smith, Ostrow, Vela, Mazur, Kwon, TOCK |
| Manning bonus | +10% flat | +20% at L1, +35% at L2, by per-system XP |
| Repair rate | 1 damage / 4s | same, but Engineer does 2 points per tick |
| Crew death | immediate and permanent | ACTIVE → DOWNED (30s bleed) → DEAD |
| Medbay | a system, max_power 2, 4 HP/s | one medical slot: Medbay **or** Clone Bay, same 4 HP/s per bar |
| Enemy ship | no power management, random targeting | unchanged, but enemies burn too |
| Sim runner | 200 runs, target 5–40% | 500 runs, target 15–35% |

The Medbay numbers match exactly across both specs. That is the one place the
two documents were clearly written with each other in view.

### Decided 1 — four rooms

**v0.1 ships four rooms: Shields, Engines, Weapons, Medbay.** As specced in
`GAME_SPEC_v0.1 §4` and `SLICE.md` slice 0.

Six rooms had been agreed earlier, before the v0.1 spec surfaced — Reactor and
Cargo as systemless rooms that burn, on the argument that a ship where every
room is critical makes fire a timer rather than a spatial decision. That
argument still holds, but it is a v0.2 argument: fire does not exist in v0.1,
so the extra rooms would be inert.

**The expansion to six happens in v0.2, in the same slice that adds fire.**
`data/ship_layout.json` gains two entries and an adjacency list; nothing else
changes. The v0.2 target layout:

```
  Weapons ── Shields ── Medical
     │          │          │
  Reactor ── Engines ──  Cargo
```

### Decided 2 — the two text events stay in the tree

**v0.1 encounter 2 is a Distress beacon and encounter 4 is a Derelict hauler.
`GAME_SPEC_v0.2 §8` calls for "6 combats, all fights, no events".**

Read literally that deletes two working features. **Instead: keep both events
implemented, behind a flag that v0.2 turns off.** The v0.2 run is combats only
as specced; the event code stays.

The reason is `VOICE_AND_EVENTS.md §2`, which uses `derelict_hauler` as *the*
worked example of the v0.4 event format, line pools and all. Deleting the v0.1
implementation and rebuilding it in v0.4 throws away the only event code that
will ever have been playtested.

### Decided 3 — crew XP is v0.2

**Removed from `SLICE.md` slice 2.** `GAME_SPEC_v0.1` never mentioned XP;
`GAME_SPEC_v0.2 §5` introduces it as new. The slice plan had pulled a v0.2
feature forward.

v0.1's job is to prove the loop is fun with interchangeable crew. XP is the
first mechanic that makes a *specific* crew member irreplaceable, which is
exactly what v0.2 §0 says v0.2 is for.

### Decided 4 — one mission, and the chain length is now open

**The immediate target is a single playable combat, not an encounter chain.**
`SLICE.md` slice 0 already describes exactly this, so nothing in the build order
changes; what changes is that slices 1–3 are not queued behind it as a foregone
conclusion.

**Both encounter counts are superseded**: five in `GAME_SPEC_v0.1 §5` and six in
`GAME_SPEC_v0.2 §8`. The number is an open decision to be made after the single
mission has been played, because how long a run should be is a pacing question
and pacing is not machine-checkable.

Everything else in `GAME_SPEC_v0.1 §5` still stands — the enemy templates, the
jump-screen options, the scrap rewards. Only the count is open.

---

## Rules for an agent running unattended

1. **Commit at every green checkpoint** — one slice per commit, per `CLAUDE.md`.
   An uncommitted context overflow loses hours.
2. **Never weaken a test to make it pass.** Converting a failing assertion into a
   skip, widening a tolerance, or deleting a case is the documented way these
   runs go wrong. If a test is wrong, say so; do not silently adjust it.
3. **Report `[PLAY-GATED]` numbers, never tune them.**
4. **Stop at the slice boundary**, even with context left.
5. **If the spec is ambiguous, stop and ask.** Do not invent a workaround for
   something a human can settle in one sentence.
