# ARCHITECTURE.md

How the code divides, and why the division is worth defending.

---

## 1. The one rule

**`sim/` is a headless library. `ui/` is a viewer.**

`sim/` computes the game. It has no nodes, no scenes, no input handling, no
timers owned by the engine, and it never imports anything from `ui/`. It
advances by being handed a delta and returns what changed.

`ui/` draws what `sim/` reports and turns clicks into calls back into `sim/`.
It holds no authoritative state. If the UI is deleted, the game still runs —
you just cannot see it.

### Why this is not architecture astronautics

Three concrete things depend on it, all of them already written into the specs:

- **`GAME_SPEC_v0.2 §10.9`** requires 500 headless games with a balance report.
  That is impossible in any reasonable time if the simulation needs a scene tree
  and real-time timers.
- **`GAME_SPEC_v0.2 §7a`** requires structured log events. The formatter lives in
  `ui/` precisely because a second consumer arrives in v0.4.
- **`VOICE_AND_EVENTS.md §6`** is that second consumer. TOCK's bark system
  subscribes to the same event stream. If `sim/` is entangled with `ui/`, adding
  it means touching every call site.

The rule also happens to be what makes this project buildable in two autonomous
phases instead of one supervised slog. See `BUILD_PLAN.md`.

---

## 2. Layout

```
sim/                    headless, no scene tree, no Node
  game_state.gd         run state: hull, scrap, encounter index, crew roster
  ship.gd               rooms, systems, power allocation, adjacency
  system.gd             one system: damage, power, manning, repair
  crew_member.gd        HP, state machine, per-system XP, class lookup
  combat.gd             the tick: charge, fire, resolve, spread, bleed
  fire.gd               ignition, damage, spread, extinguish
  log_event.gd          the structured event object
  log_bus.gd            append-only event stream, subscribable
  rng.gd                seeded RNG — every roll goes through this
  data_loader.gd        parses data/*.json into runtime structs
  sim_runner.gd         headless 500-run harness, prints the §10.9 report

ui/                     scenes, nodes, drawing, input
  combat_screen.gd      the ship view
  log_view.gd           formats LogEvents into coloured text
  crew_panel.gd         portraits, HP, XP, state
  jump_screen.gd        repair / upgrade between encounters

data/                   content. no logic.
  classes.json          class definitions and bonus keys
  crew.json             the six starting crew
  ship_layout.json      rooms, systems, adjacency        [Phase 1]
  enemies.json          six encounter templates          [Phase 1]

tests/                  headless GUT/GdUnit specs against sim/ only
tools/                  setup_godot.sh, verify.sh
```

`ui/` filenames are indicative; Phase 2 may reshape them. `sim/` filenames are
not — tests and the balance harness key off them.

---

## 3. Determinism

**Every random decision goes through `sim/rng.gd`, seeded per run.**

No `randf()` scattered through combat code. A run seed must reproduce a run
exactly, because the 500-run harness is worthless if a failure cannot be replayed,
and because "it only happens sometimes" is otherwise unfixable.

The seed is printed in the balance report and accepted as a CLI argument.

---

## 4. The log bus

`sim/` pushes `LogEvent` objects onto an append-only stream. Consumers subscribe.

```gdscript
# sim/log_event.gd
var type: String        # "SYSTEM_DESTROYED", "CREW_DOWNED", "CLONE_RESTORED"
var severity: String    # "neutral" | "warning" | "critical"
var subjects: Array     # crew ids, system ids
var values: Dictionary  # damage amounts, timers
var t: float            # seconds since encounter start
```

Consumers, in order of arrival:

| Consumer | Version | Reads |
|----------|---------|-------|
| `ui/log_view.gd` | v0.2 | everything, formats to coloured text |
| `sim/sim_runner.gd` | v0.2 | counts deaths, clone restores, encounter index |
| bark system | v0.4 | a subset, per `VOICE_AND_EVENTS.md §4` |

**No consumer may mutate an event.** The stream is the record of what happened.

The event vocabulary is a closed set defined in `sim/log_event.gd`. Adding a
`type` is a deliberate act — the v0.4 trigger table in `VOICE_AND_EVENTS.md §4`
maps onto these names, so inventing one ad hoc creates a bark trigger that will
never fire.

---

## 5. Data contracts

`data/*.json` is content and may change without code changes. **Ids may not
change**, because save data and (from v0.4) event scripts key off them.

`sim/data_loader.gd` validates on load and fails loudly. A missing key is a
crash at startup, not a null at hour three. `tools/verify.sh static` runs this
validation as its main job.

The `bonuses` dict in `classes.json` is deliberately sparse — the format carries
far more than v0.2 populates. **Unknown bonus keys must load without error and
be ignored**, so that v0.3 keys can be authored before the code reads them.
Known-but-unimplemented is a warning; malformed is a failure.

---

## 6. What lives nowhere yet

Named so nobody invents a home for them early:

- **Sector map, nodes, stations** — v0.3. Not `sim/`, not yet.
- **Events and line pools** — v0.4, `data/events.json`, per `VOICE_AND_EVENTS.md §2`.
- **Barks and TTS** — v0.4, `data/barks.json`. Text is the source of truth and
  the game must run with zero audio files present.
- **Save/load** — explicitly out of scope in v0.2 (`§3`). Do not add a
  serialisation layer "while we are here". It will be wrong, because it will be
  written before the map exists.
